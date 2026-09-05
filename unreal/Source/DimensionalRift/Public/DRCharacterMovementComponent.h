#pragma once
#include "CoreMinimal.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "DRTypes.h"
#include "DRCharacterMovementComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FDRSwingStarted, FVector, AnchorPoint);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FDRSwingEnded, FVector, ReleaseVelocity);

/**
 * Character movement with a physics-based web swing (CMOVE_Swing) and a web zip (CMOVE_Zip).
 *
 * The swing is a pendulum solved on the character's own velocity, not a PhysX constraint:
 * every tick we integrate gravity + player "pumping", then enforce the rope as an inequality
 * constraint (distance to anchor <= RopeLength) by killing outward radial velocity and
 * projecting the capsule back onto the sphere. Momentum is preserved through release, so a
 * well-timed let-go at the bottom of the arc throws the player forward and up.
 *
 * All motion goes through SafeMoveUpdatedComponent, so collisions, sliding and networking
 * (client prediction via FSavedMove) keep working like the stock modes.
 */
UCLASS()
class DIMENSIONALRIFT_API UDRCharacterMovementComponent : public UCharacterMovementComponent
{
	GENERATED_BODY()
public:
	UDRCharacterMovementComponent();

	// ---- Tuning (defaults feel like a 70 kg hero on 20-40 m ropes) --------------
	/** Furthest a web can reach when looking for an anchor. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 100)) float MaxRopeLength = 3500.f;
	/** Anchor must be at least this far above the character, or the swing feels like a zipline. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 0)) float MinAnchorHeight = 600.f;
	/** Cone of candidate directions searched above the camera forward vector (degrees of elevation). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing") FVector2D AnchorSearchElevation = FVector2D(25.f, 80.f);
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing") float AnchorSearchYawSpread = 35.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 1)) int32 AnchorSearchRays = 9;
	/** Trace channel that web anchors respond to (see DefaultEngine.ini: WebAnchor = GameTraceChannel1). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing") TEnumAsByte<ECollisionChannel> AnchorChannel = ECC_GameTraceChannel1;
	/** Also accept plain world geometry (buildings) as anchors when no tagged anchor is found. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing") bool bAllowWorldStaticAnchors = true;

	/** Extra acceleration from stick input along the arc, so the player can pump the swing. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 0)) float SwingPumpAcceleration = 1800.f;
	/** Gravity multiplier while swinging; >1 makes the arc snappier and more "Spider-Man". */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 0.1)) float SwingGravityScale = 1.6f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 100)) float MaxSwingSpeed = 4200.f;
	/** Reel-in speed (cm/s) while holding the crouch/reel input; shortens the rope for more speed. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 0)) float ReelInSpeed = 700.f;
	/** Air drag applied while swinging (fraction of velocity lost per second). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 0, ClampMax = 1)) float SwingDrag = 0.04f;
	/** Upward impulse added on release so releasing at the bottom of an arc lofts the player. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 0)) float ReleaseUpBoost = 450.f;
	/** Extra forward momentum multiplier on release (1 = pure conservation). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 0.5)) float ReleaseMomentumScale = 1.15f;
	/** Time after release during which a new swing is refused (prevents anchor spam). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Swing", meta = (ClampMin = 0)) float SwingCooldown = 0.15f;

	/** Web-Zip (Web-Pull's traversal twin): fly straight to the anchor. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Zip", meta = (ClampMin = 100)) float ZipSpeed = 3200.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Web Zip", meta = (ClampMin = 0)) float ZipArriveDistance = 120.f;

	UPROPERTY(BlueprintAssignable, Category = "Web Swing") FDRSwingStarted OnSwingStarted;
	UPROPERTY(BlueprintAssignable, Category = "Web Swing") FDRSwingEnded OnSwingEnded;

	// ---- API ------------------------------------------------------------------
	/** Search for an anchor from the camera view and start swinging. Returns false if nothing was in reach. */
	UFUNCTION(BlueprintCallable, Category = "Web Swing") bool TryStartSwing();
	/** Start swinging from an explicit anchor (scripted swings, Web-Swing HM gaps). */
	UFUNCTION(BlueprintCallable, Category = "Web Swing") void StartSwingAt(const FVector& Anchor);
	UFUNCTION(BlueprintCallable, Category = "Web Swing") void ReleaseSwing();
	UFUNCTION(BlueprintCallable, Category = "Web Swing") bool TryStartZip();
	UFUNCTION(BlueprintPure, Category = "Web Swing") bool IsSwinging() const { return MovementMode == MOVE_Custom && CustomMovementMode == CMOVE_Swing; }
	UFUNCTION(BlueprintPure, Category = "Web Swing") bool IsZipping() const { return MovementMode == MOVE_Custom && CustomMovementMode == CMOVE_Zip; }
	UFUNCTION(BlueprintPure, Category = "Web Swing") FVector GetSwingAnchor() const { return SwingAnchor; }
	UFUNCTION(BlueprintPure, Category = "Web Swing") float GetRopeLength() const { return RopeLength; }
	/** Hold to shorten the rope mid-swing. */
	UFUNCTION(BlueprintCallable, Category = "Web Swing") void SetReelingIn(bool bReel) { bReelingIn = bReel; }
	/** Finds the best anchor for the current view without starting a swing (for the HUD reticle). */
	UFUNCTION(BlueprintCallable, Category = "Web Swing") bool FindAnchor(FVector& OutAnchor) const;

	// ---- UCharacterMovementComponent ----------------------------------------------
	virtual void PhysCustom(float DeltaTime, int32 Iterations) override;
	virtual void OnMovementModeChanged(EMovementMode PreviousMovementMode, uint8 PreviousCustomMode) override;
	virtual float GetMaxSpeed() const override;
	virtual bool CanAttemptJump() const override;

protected:
	void PhysSwing(float DeltaTime, int32 Iterations);
	void PhysZip(float DeltaTime, int32 Iterations);
	void FaceVelocity(float DeltaTime);
	void EndCustomMove(EMovementMode NewMode);

private:
	FVector SwingAnchor = FVector::ZeroVector;
	float RopeLength = 0.f;
	bool bReelingIn = false;
	float LastReleaseTime = -100.f;
};
