#include "DRCharacterMovementComponent.h"
#include "DimensionalRift.h"
#include "GameFramework/Character.h"
#include "GameFramework/Controller.h"
#include "Components/CapsuleComponent.h"
#include "Engine/World.h"
#include "CollisionQueryParams.h"

UDRCharacterMovementComponent::UDRCharacterMovementComponent()
{
	// Anime-hero defaults: fast, floaty-but-controllable air, hard turns.
	MaxWalkSpeed = 750.f;
	MaxAcceleration = 3000.f;
	BrakingDecelerationWalking = 2500.f;
	JumpZVelocity = 950.f;
	AirControl = 0.65f;
	AirControlBoostMultiplier = 1.5f;
	GravityScale = 1.5f;
	BrakingDecelerationFalling = 150.f;
	bOrientRotationToMovement = true;
	RotationRate = FRotator(0.f, 720.f, 0.f);
	bUseFlatBaseForFloorChecks = true;
	SetWalkableFloorAngle(50.f);
}

// ---------------------------------------------------------------------------------
// Anchor search
// ---------------------------------------------------------------------------------

bool UDRCharacterMovementComponent::FindAnchor(FVector& OutAnchor) const
{
	if (!CharacterOwner || !UpdatedComponent || !GetWorld()) return false;

	// Camera-relative search: the player swings where they are looking, not where they face.
	FVector ViewLoc; FRotator ViewRot;
	if (const AController* C = CharacterOwner->GetController()) C->GetPlayerViewPoint(ViewLoc, ViewRot);
	else { ViewLoc = CharacterOwner->GetActorLocation(); ViewRot = CharacterOwner->GetActorRotation(); }

	const FVector Origin = UpdatedComponent->GetComponentLocation();
	FVector Forward = FVector(ViewRot.Vector().X, ViewRot.Vector().Y, 0.f).GetSafeNormal();
	if (Forward.IsNearlyZero()) Forward = CharacterOwner->GetActorForwardVector();
	// Bias the search toward the direction of travel so momentum carries through.
	const FVector Travel = FVector(Velocity.X, Velocity.Y, 0.f).GetSafeNormal();
	if (!Travel.IsNearlyZero()) Forward = (Forward + Travel * 0.5f).GetSafeNormal();
	const float BaseYaw = Forward.Rotation().Yaw;

	FCollisionQueryParams Params(SCENE_QUERY_STAT(DRWebAnchor), false, CharacterOwner);

	bool bFound = false;
	float BestScore = -FLT_MAX;
	FVector Best = FVector::ZeroVector;

	auto Consider = [&](const FHitResult& Hit, float Bonus)
	{
		const FVector ToHit = Hit.ImpactPoint - Origin;
		const float Dist = ToHit.Size();
		if (Dist > MaxRopeLength || ToHit.Z < MinAnchorHeight) return;
		// Favor anchors that are high and ahead; penalize distance a little so nearby ones win ties.
		const float Score = Bonus + ToHit.Z * 0.6f + FVector::DotProduct(ToHit, Forward) * 0.9f - Dist * 0.25f;
		if (Score > BestScore) { BestScore = Score; Best = Hit.ImpactPoint; bFound = true; }
	};

	const float YawOffsets[3] = { -AnchorSearchYawSpread, 0.f, AnchorSearchYawSpread };
	const int32 Rays = FMath::Max(1, AnchorSearchRays);
	for (int32 i = 0; i < Rays; ++i)
	{
		const float T = Rays > 1 ? static_cast<float>(i) / (Rays - 1) : 0.5f;
		const float Elevation = FMath::Lerp(AnchorSearchElevation.X, AnchorSearchElevation.Y, T);
		for (float Yaw : YawOffsets)
		{
			const FVector Dir = FRotator(Elevation, BaseYaw + Yaw, 0.f).Vector();
			const FVector End = Origin + Dir * MaxRopeLength;
			FHitResult Hit;
			// Tagged anchors (WebAnchor channel) always beat raw geometry.
			if (GetWorld()->LineTraceSingleByChannel(Hit, Origin, End, AnchorChannel, Params)) Consider(Hit, 5000.f);
			else if (bAllowWorldStaticAnchors && GetWorld()->LineTraceSingleByChannel(Hit, Origin, End, ECC_WorldStatic, Params)) Consider(Hit, 0.f);
		}
	}

	if (bFound) OutAnchor = Best;
	return bFound;
}

// ---------------------------------------------------------------------------------
// Swing API
// ---------------------------------------------------------------------------------

bool UDRCharacterMovementComponent::TryStartSwing()
{
	if (IsSwinging() || !GetWorld()) return false;
	if (GetWorld()->GetTimeSeconds() - LastReleaseTime < SwingCooldown) return false;
	FVector Anchor;
	if (!FindAnchor(Anchor)) return false;
	StartSwingAt(Anchor);
	return true;
}

void UDRCharacterMovementComponent::StartSwingAt(const FVector& Anchor)
{
	SwingAnchor = Anchor;
	RopeLength = FMath::Clamp((Anchor - UpdatedComponent->GetComponentLocation()).Size(), 300.f, MaxRopeLength);
	bReelingIn = false;
	// Standing start: a small push forward so the first swing has an arc instead of a dead hang.
	if (Velocity.SizeSquared() < FMath::Square(300.f))
	{
		Velocity += CharacterOwner->GetActorForwardVector() * 600.f;
	}
	SetMovementMode(MOVE_Custom, CMOVE_Swing);
	OnSwingStarted.Broadcast(SwingAnchor);
}

void UDRCharacterMovementComponent::ReleaseSwing()
{
	if (!IsSwinging()) return;
	FVector V = Velocity * ReleaseMomentumScale;
	V.Z += ReleaseUpBoost;
	Velocity = V.GetClampedToMaxSize(MaxSwingSpeed * 1.25f);
	LastReleaseTime = GetWorld()->GetTimeSeconds();
	EndCustomMove(MOVE_Falling);
	OnSwingEnded.Broadcast(Velocity);
}

bool UDRCharacterMovementComponent::TryStartZip()
{
	if (IsZipping()) return false;
	FVector Anchor;
	if (!FindAnchor(Anchor)) return false;
	if (IsSwinging()) ReleaseSwing();
	SwingAnchor = Anchor;
	SetMovementMode(MOVE_Custom, CMOVE_Zip);
	OnSwingStarted.Broadcast(SwingAnchor);
	return true;
}

void UDRCharacterMovementComponent::EndCustomMove(EMovementMode NewMode)
{
	bReelingIn = false;
	SetMovementMode(NewMode);
}

// ---------------------------------------------------------------------------------
// UCharacterMovementComponent overrides
// ---------------------------------------------------------------------------------

void UDRCharacterMovementComponent::OnMovementModeChanged(EMovementMode PreviousMovementMode, uint8 PreviousCustomMode)
{
	Super::OnMovementModeChanged(PreviousMovementMode, PreviousCustomMode);
	if (MovementMode == MOVE_Custom)
	{
		bOrientRotationToMovement = false; // we steer the mesh ourselves in FaceVelocity()
	}
	else if (PreviousMovementMode == MOVE_Custom)
	{
		bOrientRotationToMovement = true;
	}
}

float UDRCharacterMovementComponent::GetMaxSpeed() const
{
	if (IsSwinging()) return MaxSwingSpeed;
	if (IsZipping()) return ZipSpeed;
	return Super::GetMaxSpeed();
}

bool UDRCharacterMovementComponent::CanAttemptJump() const
{
	// Jumping out of a swing is the release-at-the-apex move.
	return Super::CanAttemptJump() || IsSwinging();
}

void UDRCharacterMovementComponent::PhysCustom(float DeltaTime, int32 Iterations)
{
	Super::PhysCustom(DeltaTime, Iterations);
	switch (CustomMovementMode)
	{
	case CMOVE_Swing: PhysSwing(DeltaTime, Iterations); break;
	case CMOVE_Zip:   PhysZip(DeltaTime, Iterations);   break;
	default: break;
	}
}

// ---------------------------------------------------------------------------------
// The pendulum
// ---------------------------------------------------------------------------------

void UDRCharacterMovementComponent::PhysSwing(float DeltaTime, int32 Iterations)
{
	if (DeltaTime < MIN_TICK_TIME || !HasValidData()) return;

	const FVector OldLocation = UpdatedComponent->GetComponentLocation();
	FVector Vel = Velocity;

	// 1. Forces: gravity (heavier than normal for a punchy arc) + stick "pumping".
	Vel.Z += GetGravityZ() * SwingGravityScale * DeltaTime;
	if (!Acceleration.IsNearlyZero())
	{
		Vel += Acceleration.GetSafeNormal() * SwingPumpAcceleration * DeltaTime;
	}
	Vel *= FMath::Max(0.f, 1.f - SwingDrag * DeltaTime);

	// 2. Reel in: shortening the rope while moving converts rope length into speed (angular momentum).
	if (bReelingIn)
	{
		RopeLength = FMath::Max(300.f, RopeLength - ReelInSpeed * DeltaTime);
	}

	// 3. Rope tension: when at full extension, cancel any velocity pointing away from the anchor.
	const FVector ToAnchor = SwingAnchor - OldLocation;
	const float Dist = ToAnchor.Size();
	if (Dist > KINDA_SMALL_NUMBER)
	{
		const FVector Radial = ToAnchor / Dist;                 // player -> anchor
		const float Outward = FVector::DotProduct(Vel, -Radial); // > 0 means stretching the rope
		if (Dist >= RopeLength - 1.f && Outward > 0.f)
		{
			Vel += Radial * Outward;                             // remove radial component, keep tangential
		}
	}
	Vel = Vel.GetClampedToMaxSize(MaxSwingSpeed);
	Velocity = Vel;

	// 4. Move with collision.
	const FVector Delta = Velocity * DeltaTime;
	FHitResult Hit(1.f);
	SafeMoveUpdatedComponent(Delta, UpdatedComponent->GetComponentQuat(), true, Hit);
	if (Hit.IsValidBlockingHit())
	{
		HandleImpact(Hit, DeltaTime, Delta);
		SlideAlongSurface(Delta, 1.f - Hit.Time, Hit.Normal, Hit, true);
		if (Hit.ImpactNormal.Z >= GetWalkableFloorZ())
		{
			// Swung into the ground: land and hand back to the walking solver.
			const FVector Landing = Velocity;
			EndCustomMove(MOVE_Walking);
			OnSwingEnded.Broadcast(Landing);
			return;
		}
	}

	// 5. Position projection: pull the capsule back onto the sphere of radius RopeLength.
	const FVector NewLocation = UpdatedComponent->GetComponentLocation();
	const FVector ToAnchorNow = SwingAnchor - NewLocation;
	const float DistNow = ToAnchorNow.Size();
	if (DistNow > RopeLength)
	{
		const FVector Corrected = SwingAnchor - ToAnchorNow.GetSafeNormal() * RopeLength;
		FHitResult CorrectionHit;
		SafeMoveUpdatedComponent(Corrected - NewLocation, UpdatedComponent->GetComponentQuat(), true, CorrectionHit);
	}

	// 6. Velocity is whatever displacement actually happened (position-based dynamics).
	Velocity = (UpdatedComponent->GetComponentLocation() - OldLocation) / DeltaTime;
	FaceVelocity(DeltaTime);

	// Rope went slack above the anchor (looped over the top): drop into a fall.
	if (UpdatedComponent->GetComponentLocation().Z > SwingAnchor.Z)
	{
		ReleaseSwing();
	}
}

void UDRCharacterMovementComponent::PhysZip(float DeltaTime, int32 Iterations)
{
	if (DeltaTime < MIN_TICK_TIME || !HasValidData()) return;

	const FVector Location = UpdatedComponent->GetComponentLocation();
	const FVector ToAnchor = SwingAnchor - Location;
	const float Dist = ToAnchor.Size();
	if (Dist <= ZipArriveDistance)
	{
		Velocity = ToAnchor.GetSafeNormal() * ZipSpeed * 0.25f + FVector(0.f, 0.f, 350.f);
		EndCustomMove(MOVE_Falling);
		OnSwingEnded.Broadcast(Velocity);
		return;
	}

	Velocity = ToAnchor.GetSafeNormal() * ZipSpeed;
	const FVector Delta = Velocity * DeltaTime;
	FHitResult Hit(1.f);
	SafeMoveUpdatedComponent(Delta, UpdatedComponent->GetComponentQuat(), true, Hit);
	if (Hit.IsValidBlockingHit())
	{
		HandleImpact(Hit, DeltaTime, Delta);
		Velocity = FVector::ZeroVector;
		EndCustomMove(Hit.ImpactNormal.Z >= GetWalkableFloorZ() ? MOVE_Walking : MOVE_Falling);
		OnSwingEnded.Broadcast(Velocity);
		return;
	}
	FaceVelocity(DeltaTime);
}

void UDRCharacterMovementComponent::FaceVelocity(float DeltaTime)
{
	const FVector Flat(Velocity.X, Velocity.Y, 0.f);
	if (Flat.SizeSquared() < FMath::Square(50.f)) return;
	const FRotator Target = Flat.Rotation();
	const FRotator Current = UpdatedComponent->GetComponentRotation();
	const FRotator New = FMath::RInterpTo(Current, FRotator(0.f, Target.Yaw, 0.f), DeltaTime, 10.f);
	MoveUpdatedComponent(FVector::ZeroVector, New.Quaternion(), false);
}
