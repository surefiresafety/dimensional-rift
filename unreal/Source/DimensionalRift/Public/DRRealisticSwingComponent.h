#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "DRRealisticSwingComponent.generated.h"

class UCharacterMovementComponent;
class ACharacter;
class UCableComponent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FDRSwingAttached, FVector, Anchor, float, RestLength);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FDRSwingDetached, FVector, ReleaseVelocity);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FDRSwingFailed, FVector, AttemptedDirection);

/**
 * Physically grounded web swing.
 *
 * The stylised component (UDRCharacterMovementComponent, CMOVE_Swing) treats the rope as a
 * hard inequality constraint and cheats gravity upward so arcs stay readable. This one is the
 * photoreal counterpart and cheats nothing:
 *
 *   - Gravity is real: 9.80665 m/s^2, no scale. A 78 kg body on a 25 m line has a pendulum
 *     period of 2*pi*sqrt(L/g) ~= 10 s, so a half-arc is ~5 s. That is the honest number and
 *     it is slower than any Spider-Man game ships with. See "Tuning against reality" below.
 *   - The rope is a damped spring, not a rigid rod. Real webbing stretches under load, and
 *     the visible stretch-and-recoil at the bottom of the arc is most of what reads as
 *     "physical" to a viewer. Force is Hooke plus a damper, clamped so it can pull but never
 *     push (a rope goes slack, it does not hold you out).
 *   - Drag is quadratic: F = 0.5 * rho * v^2 * Cd * A, opposing velocity. At 30 m/s a
 *     0.65 m^2 frontal area in a skydiving tuck costs roughly 4 m/s^2 of deceleration, which
 *     is what stops a swing accelerating forever and gives terminal velocity for free.
 *   - Momentum is conserved across attach and release. Nothing is added on let-go; the
 *     launch you feel at the bottom of an arc is the tangential velocity you already had.
 *
 * Integration is semi-implicit Euler at a fixed substep (default 240 Hz) so a stiff rope does
 * not explode at low frame rates. All motion still goes through the character's
 * SafeMoveUpdatedComponent path, so collision, sliding and CMC networking keep working.
 *
 * Tuning against reality
 * ----------------------
 * Fully real is correct and boring. The two knobs that buy playability without breaking the
 * look are RopeReelForce (Spider-Man visibly hauls himself up the line, which is real work
 * and shortens the arc honestly) and PumpAcceleration (a body pumping a swing really does add
 * energy — a playground swing is the proof). Both are physical mechanisms, so raising them
 * keeps the motion legible as physics. Raising GravityScale above 1.0 does not; that is where
 * the stylised component lives.
 */
UCLASS(ClassGroup = (DimensionalRift), meta = (BlueprintSpawnableComponent))
class DIMENSIONALRIFT_API UDRRealisticSwingComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UDRRealisticSwingComponent();

	// ---------------------------------------------------------------- Physical constants
	/** Body mass in kg. Drives how much the reel and pump forces actually move you. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Body", meta = (ClampMin = 30.f, ClampMax = 200.f))
	float BodyMassKg = 78.f;

	/** Frontal area in m^2. ~0.65 tucked, ~1.2 spread-eagle. Drive it from the animation pose. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Body", meta = (ClampMin = 0.1f, ClampMax = 2.5f))
	float FrontalAreaM2 = 0.65f;

	/** Drag coefficient. 0.7 is a reasonable human in a suit; 1.0-1.3 is a flat plate. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Body", meta = (ClampMin = 0.f, ClampMax = 2.f))
	float DragCoefficient = 0.7f;

	/** Air density kg/m^3. 1.225 at sea level; drop it for a high-altitude level. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Body", meta = (ClampMin = 0.f))
	float AirDensity = 1.225f;

	// ---------------------------------------------------------------- Rope
	/** Spring stiffness in N/m. 8000 gives ~10 cm of sag under a 78 kg load; lower is springier. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Rope", meta = (ClampMin = 100.f))
	float RopeStiffness = 8000.f;

	/** Damping in N*s/m. Near-critical for the mass and stiffness above; too low and it wobbles. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Rope", meta = (ClampMin = 0.f))
	float RopeDamping = 900.f;

	/** Hard ceiling on stretch as a fraction of rest length. Beyond this the rope goes rigid. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Rope", meta = (ClampMin = 0.f, ClampMax = 0.5f))
	float MaxStretchRatio = 0.08f;

	/** Newtons available to haul yourself up the line. This is real work, so it is honest. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Rope", meta = (ClampMin = 0.f))
	float RopeReelForce = 1400.f;

	/** Shortest the rope may be reeled to, in cm. Stops you hugging the anchor. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Rope", meta = (ClampMin = 100.f))
	float MinRestLength = 400.f;

	/** Longest a line may be fired, in cm. 4000 = 40 m, about a ten-storey reach. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Rope", meta = (ClampMin = 500.f))
	float MaxRopeLength = 4000.f;

	// ---------------------------------------------------------------- Player input authority
	/** Acceleration a pumping body can add along its travel direction, in cm/s^2. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Control", meta = (ClampMin = 0.f))
	float PumpAcceleration = 900.f;

	/** Sideways steer authority while on the line, cm/s^2. Small: you are on a rope. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Control", meta = (ClampMin = 0.f))
	float SteerAcceleration = 500.f;

	/** Fixed physics substep in seconds. 1/240 keeps a stiff rope stable at 30 fps. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Solver", meta = (ClampMin = 0.001f, ClampMax = 0.02f))
	float SubstepSeconds = 1.f / 240.f;

	/** Never run more than this many substeps in one frame, so a hitch cannot spiral. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Solver", meta = (ClampMin = 1, ClampMax = 64))
	int32 MaxSubstepsPerFrame = 24;

	// ---------------------------------------------------------------- Anchor search
	/** Anchors must sit at least this far above the character or the swing reads as a zipline. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Anchor", meta = (ClampMin = 0.f))
	float MinAnchorHeight = 700.f;

	/** Elevation band above the aim direction that the fan of traces sweeps, in degrees. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Anchor")
	FVector2D SearchElevationDegrees = FVector2D(20.f, 70.f);

	/** Half-angle of the yaw fan, in degrees. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Anchor")
	float SearchYawHalfAngle = 30.f;

	/** Traces fired per attempt. 12 is plenty against Nanite geometry. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Anchor", meta = (ClampMin = 1, ClampMax = 64))
	int32 SearchRayCount = 12;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Swing|Anchor")
	TEnumAsByte<ECollisionChannel> AnchorChannel = ECC_Visibility;

	// ---------------------------------------------------------------- Events
	UPROPERTY(BlueprintAssignable, Category = "Swing") FDRSwingAttached OnSwingAttached;
	UPROPERTY(BlueprintAssignable, Category = "Swing") FDRSwingDetached OnSwingDetached;
	UPROPERTY(BlueprintAssignable, Category = "Swing") FDRSwingFailed   OnSwingFailed;

	// ---------------------------------------------------------------- API
	/** Fire a line along AimDirection. Returns false and broadcasts OnSwingFailed if nothing holds. */
	UFUNCTION(BlueprintCallable, Category = "Swing")
	bool TryAttach(const FVector& AimDirection);

	/** Let go. Velocity is untouched: whatever you had is what you keep. */
	UFUNCTION(BlueprintCallable, Category = "Swing")
	void Detach();

	/** Per-frame input while attached. Forward pumps, Right steers, ReelAxis > 0 hauls in. */
	UFUNCTION(BlueprintCallable, Category = "Swing")
	void SetSwingInput(float Forward, float Right, float ReelAxis);

	UFUNCTION(BlueprintPure, Category = "Swing") bool IsAttached() const { return bAttached; }
	UFUNCTION(BlueprintPure, Category = "Swing") FVector GetAnchor() const { return Anchor; }
	UFUNCTION(BlueprintPure, Category = "Swing") float GetRestLength() const { return RestLength; }

	/** Current rope tension in newtons. Drive cable thickness, anchor creak and camera shake from this. */
	UFUNCTION(BlueprintPure, Category = "Swing") float GetTensionNewtons() const { return LastTensionN; }

	/** 0 at rest length, 1 at MaxStretchRatio. Drives the web material's stretch response. */
	UFUNCTION(BlueprintPure, Category = "Swing") float GetStretchAlpha() const { return LastStretchAlpha; }

	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

protected:
	virtual void BeginPlay() override;

private:
	void Substep(float Dt);
	bool FindAnchor(const FVector& AimDirection, FVector& OutAnchor) const;

	UPROPERTY(Transient) TObjectPtr<ACharacter> OwnerCharacter;
	UPROPERTY(Transient) TObjectPtr<UCharacterMovementComponent> Movement;

	bool bAttached = false;
	FVector Anchor = FVector::ZeroVector;
	float RestLength = 0.f;
	float Accumulator = 0.f;

	float InputForward = 0.f;
	float InputRight = 0.f;
	float InputReel = 0.f;

	float LastTensionN = 0.f;
	float LastStretchAlpha = 0.f;
};
