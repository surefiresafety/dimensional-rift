#include "DRRealisticSwingComponent.h"

#include "GameFramework/Character.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Components/CapsuleComponent.h"
#include "Engine/World.h"
#include "CollisionQueryParams.h"

namespace DRSwing
{
	/** Unreal works in centimetres. Everything below is SI, converted at the boundary. */
	static constexpr float UUPerMetre = 100.f;
	static constexpr float GravityMetres = 9.80665f;
	static constexpr float GravityUU = GravityMetres * UUPerMetre;

	static FORCEINLINE float ToMetres(float UU) { return UU / UUPerMetre; }
	static FORCEINLINE FVector ToMetres(const FVector& UU) { return UU / UUPerMetre; }
	static FORCEINLINE FVector ToUU(const FVector& Metres) { return Metres * UUPerMetre; }
}

UDRRealisticSwingComponent::UDRRealisticSwingComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
	// Tick after movement so we are correcting a position the CMC has already settled.
	PrimaryComponentTick.TickGroup = TG_PostPhysics;
}

void UDRRealisticSwingComponent::BeginPlay()
{
	Super::BeginPlay();
	OwnerCharacter = Cast<ACharacter>(GetOwner());
	Movement = OwnerCharacter ? OwnerCharacter->GetCharacterMovement() : nullptr;
}

// ---------------------------------------------------------------------------------------
// Anchor search
//
// A fan of traces above the aim direction, taking the candidate that gives the longest
// usable pendulum rather than the nearest hit. Nearest-hit picks the wall in front of you,
// which is the single worst anchor available: it converts a swing into a face-first stop.
// ---------------------------------------------------------------------------------------
bool UDRRealisticSwingComponent::FindAnchor(const FVector& AimDirection, FVector& OutAnchor) const
{
	const UWorld* World = GetWorld();
	if (!World || !OwnerCharacter) return false;

	const FVector Origin = OwnerCharacter->GetActorLocation();
	const FVector Aim = AimDirection.GetSafeNormal();
	if (Aim.IsNearlyZero()) return false;

	FCollisionQueryParams Params(SCENE_QUERY_STAT(DRSwingAnchor), /*bTraceComplex*/ false, OwnerCharacter);
	Params.bReturnPhysicalMaterial = true;

	const FVector Right = FVector::CrossProduct(FVector::UpVector, Aim).GetSafeNormal();
	float BestScore = -1.f;
	bool bFound = false;

	for (int32 i = 0; i < SearchRayCount; ++i)
	{
		// Spiral the fan so consecutive rays are not co-planar; a grid misses thin geometry
		// like flagpoles and fire escapes, which are the anchors that make a city readable.
		const float T = SearchRayCount > 1 ? float(i) / float(SearchRayCount - 1) : 0.5f;
		const float Elevation = FMath::Lerp(SearchElevationDegrees.X, SearchElevationDegrees.Y, T);
		const float Yaw = FMath::Sin(T * PI * 3.f) * SearchYawHalfAngle;

		FVector Dir = Aim.RotateAngleAxis(-Elevation, Right);
		Dir = Dir.RotateAngleAxis(Yaw, FVector::UpVector);

		FHitResult Hit;
		if (!World->LineTraceSingleByChannel(Hit, Origin, Origin + Dir * MaxRopeLength, AnchorChannel, Params))
			continue;

		const FVector ToHit = Hit.ImpactPoint - Origin;
		if (ToHit.Z < MinAnchorHeight) continue;               // too low to swing from
		const float Dist = ToHit.Size();
		if (Dist < MinRestLength || Dist > MaxRopeLength) continue;

		// Prefer height, then length. A high anchor gives a long arc; a long low one gives a zipline.
		const float Score = ToHit.Z * 2.f + Dist;
		if (Score > BestScore)
		{
			BestScore = Score;
			OutAnchor = Hit.ImpactPoint;
			bFound = true;
		}
	}
	return bFound;
}

bool UDRRealisticSwingComponent::TryAttach(const FVector& AimDirection)
{
	if (bAttached || !OwnerCharacter || !Movement) return false;

	FVector Found;
	if (!FindAnchor(AimDirection, Found))
	{
		OnSwingFailed.Broadcast(AimDirection);
		return false;
	}

	Anchor = Found;
	RestLength = FMath::Clamp((Anchor - OwnerCharacter->GetActorLocation()).Size(), MinRestLength, MaxRopeLength);
	bAttached = true;
	Accumulator = 0.f;

	// Falling, not flying: we keep the CMC's own gravity and collision, and only add rope
	// forces on top. Nothing about the character's velocity is reset, so whatever speed you
	// arrived with carries into the first arc.
	Movement->SetMovementMode(MOVE_Falling);

	OnSwingAttached.Broadcast(Anchor, RestLength);
	return true;
}

void UDRRealisticSwingComponent::Detach()
{
	if (!bAttached) return;
	bAttached = false;
	LastTensionN = 0.f;
	LastStretchAlpha = 0.f;

	// No release impulse. The arc already gave you the speed; adding to it here is exactly
	// the arcade tell we are trying to design out.
	OnSwingDetached.Broadcast(Movement ? Movement->Velocity : FVector::ZeroVector);
}

void UDRRealisticSwingComponent::SetSwingInput(float Forward, float Right, float ReelAxis)
{
	InputForward = FMath::Clamp(Forward, -1.f, 1.f);
	InputRight = FMath::Clamp(Right, -1.f, 1.f);
	InputReel = FMath::Clamp(ReelAxis, -1.f, 1.f);
}

// ---------------------------------------------------------------------------------------
// Solver
//
// Semi-implicit Euler on a fixed substep. Forces are assembled in newtons, divided by mass
// to give an acceleration, and integrated into the CMC's own velocity. The CMC then moves
// the capsule with full collision on the next frame; we never teleport it.
// ---------------------------------------------------------------------------------------
void UDRRealisticSwingComponent::Substep(float Dt)
{
	using namespace DRSwing;

	const FVector Pos = OwnerCharacter->GetActorLocation();
	FVector Vel = Movement->Velocity;                          // cm/s

	const FVector ToAnchor = Anchor - Pos;
	const float Dist = ToAnchor.Size();
	if (Dist < KINDA_SMALL_NUMBER) return;
	const FVector Dir = ToAnchor / Dist;                       // points from body toward anchor

	FVector ForceN = FVector::ZeroVector;                      // newtons

	// --- Gravity ------------------------------------------------------------------------
	// The CMC applies its own gravity during MOVE_Falling, so we do not add it again here.
	// Set GravityScale = 1.0 on the movement component: this component is only honest if the
	// engine underneath it is.

	// --- Air drag: F = 0.5 * rho * v^2 * Cd * A, opposing travel -------------------------
	const FVector VelM = ToMetres(Vel);
	const float SpeedM = VelM.Size();
	if (SpeedM > KINDA_SMALL_NUMBER)
	{
		const float DragN = 0.5f * AirDensity * SpeedM * SpeedM * DragCoefficient * FrontalAreaM2;
		ForceN += -VelM.GetSafeNormal() * DragN;
	}

	// --- Rope: a damped spring that pulls and never pushes -------------------------------
	const float StretchM = ToMetres(Dist - RestLength);
	float TensionN = 0.f;
	if (StretchM > 0.f)
	{
		const float RadialSpeedM = FVector::DotProduct(VelM, -ToMetres(Dir).GetSafeNormal());  // + = moving away
		TensionN = RopeStiffness * StretchM + RopeDamping * FMath::Max(0.f, RadialSpeedM);

		// Past the stretch ceiling the fibre is done extending: solve the remainder as an
		// inelastic constraint so the body cannot tunnel out through a soft spring.
		const float MaxStretchM = ToMetres(RestLength) * MaxStretchRatio;
		if (StretchM > MaxStretchM)
		{
			const float Outward = FVector::DotProduct(Vel, -Dir);
			if (Outward > 0.f) Vel += Dir * Outward;           // kill outward radial velocity
			const float HardRadius = RestLength * (1.f + MaxStretchRatio);
			OwnerCharacter->SetActorLocation(Anchor - Dir * HardRadius, /*bSweep*/ true);
		}

		ForceN += Dir * TensionN;
	}
	LastTensionN = TensionN;
	LastStretchAlpha = RestLength > 0.f
		? FMath::Clamp(ToMetres(Dist - RestLength) / FMath::Max(KINDA_SMALL_NUMBER, ToMetres(RestLength) * MaxStretchRatio), 0.f, 1.f)
		: 0.f;

	// --- Reeling: real work, so it is allowed ---------------------------------------------
	if (!FMath::IsNearlyZero(InputReel))
	{
		RestLength = FMath::Clamp(RestLength - InputReel * (RopeReelForce / BodyMassKg) * Dt * UUPerMetre,
		                          MinRestLength, MaxRopeLength);
		if (InputReel > 0.f) ForceN += Dir * RopeReelForce * InputReel;
	}

	// --- Pump and steer, applied tangentially ----------------------------------------------
	// A body on a swing adds energy by shortening its effective radius at the bottom of the
	// arc and lengthening it at the top. Modelling that literally is unreadable at gamepad
	// resolution, so we apply the same energy as a tangential acceleration instead — the
	// mechanism is real even though the input mapping is not.
	if (!FMath::IsNearlyZero(InputForward) || !FMath::IsNearlyZero(InputRight))
	{
		const FVector Tangent = FVector::VectorPlaneProject(Vel, Dir).GetSafeNormal();
		const FVector Side = FVector::CrossProduct(Dir, Tangent).GetSafeNormal();
		const FVector AccelUU = Tangent * PumpAcceleration * InputForward + Side * SteerAcceleration * InputRight;
		ForceN += ToMetres(AccelUU) * BodyMassKg;
	}

	// --- Integrate ------------------------------------------------------------------------
	const FVector AccelUU = ToUU(ForceN / BodyMassKg);          // F = ma, back to cm/s^2
	Vel += AccelUU * Dt;
	Movement->Velocity = Vel;
}

void UDRRealisticSwingComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
	if (!bAttached || !OwnerCharacter || !Movement) return;

	// Landing, or anything that takes the CMC out of the air, drops the line.
	if (Movement->IsMovingOnGround()) { Detach(); return; }

	Accumulator += DeltaTime;
	int32 Steps = 0;
	while (Accumulator >= SubstepSeconds && Steps < MaxSubstepsPerFrame)
	{
		Substep(SubstepSeconds);
		Accumulator -= SubstepSeconds;
		++Steps;
	}
	// A hitch long enough to exhaust the substep budget is dropped rather than caught up:
	// catching up on a stiff spring is how you get launched through a building.
	if (Steps >= MaxSubstepsPerFrame) Accumulator = 0.f;
}
