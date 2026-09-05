#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "DRCombatant.h"
#include "DRTypes.h"
#include "DRCharacter.generated.h"

class UCameraComponent;
class USpringArmComponent;
class UInputMappingContext;
class UInputAction;
class UDRCharacterMovementComponent;
class UDRAbilityManagerComponent;
class UDRSpiritEnergyComponent;
class UCableComponent;
struct FInputActionValue;

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FDRSpiderSenseWindowOpened);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FDRPerfectDodge, AActor*, Attacker);

/**
 * The Rift Walker. Third-person action character with:
 *  - Enhanced Input (move / look / jump / swing / dodge / four ability slots)
 *  - UDRCharacterMovementComponent for the physics web swing
 *  - UDRAbilityManagerComponent (Rule of Four) + UDRSpiritEnergyComponent (unified mana)
 *  - Spider-Sense: enemies call WarnIncomingAttack(); a dodge inside the window is a Perfect Dodge
 *    with full i-frames, a slow-mo beat and a counter window.
 */
UCLASS()
class DIMENSIONALRIFT_API ADRCharacter : public ACharacter, public IDRCombatant
{
	GENERATED_BODY()
public:
	ADRCharacter(const FObjectInitializer& ObjectInitializer);

	// ---- Components -------------------------------------------------------------
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components") TObjectPtr<USpringArmComponent> CameraBoom;
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components") TObjectPtr<UCameraComponent> FollowCamera;
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components") TObjectPtr<UDRAbilityManagerComponent> AbilityManager;
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components") TObjectPtr<UDRSpiritEnergyComponent> SpiritEnergy;
	/** Visible web line; attached to the hand socket, its end is moved to the anchor while swinging. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components") TObjectPtr<UCableComponent> WebCable;

	// ---- Input (assign in the Blueprint child) -----------------------------------
	UPROPERTY(EditDefaultsOnly, Category = "Input") TObjectPtr<UInputMappingContext> DefaultMappingContext;
	UPROPERTY(EditDefaultsOnly, Category = "Input") TObjectPtr<UInputAction> MoveAction;
	UPROPERTY(EditDefaultsOnly, Category = "Input") TObjectPtr<UInputAction> LookAction;
	UPROPERTY(EditDefaultsOnly, Category = "Input") TObjectPtr<UInputAction> JumpAction;
	UPROPERTY(EditDefaultsOnly, Category = "Input") TObjectPtr<UInputAction> SwingAction;
	UPROPERTY(EditDefaultsOnly, Category = "Input") TObjectPtr<UInputAction> ZipAction;
	UPROPERTY(EditDefaultsOnly, Category = "Input") TObjectPtr<UInputAction> DodgeAction;
	UPROPERTY(EditDefaultsOnly, Category = "Input") TObjectPtr<UInputAction> ReelAction;
	/** Exactly four: one per loadout slot. */
	UPROPERTY(EditDefaultsOnly, Category = "Input") TArray<TObjectPtr<UInputAction>> AbilityActions;

	// ---- Combat ------------------------------------------------------------------
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Combat") EDRNature Nature = EDRNature::Physical;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Combat", meta = (ClampMin = 1)) float MaxHealth = 500.f;
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Combat") float Health = 500.f;

	// ---- Dodge / Spider-Sense ----------------------------------------------------
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Dodge", meta = (ClampMin = 0)) float DodgeDistance = 450.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Dodge", meta = (ClampMin = 0)) float DodgeInvulnerableTime = 0.25f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Dodge", meta = (ClampMin = 0)) float DodgeCooldown = 0.6f;
	/** How long the Spider-Sense window stays open once an attack is telegraphed. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Spider-Sense", meta = (ClampMin = 0)) float SpiderSenseWindow = 0.45f;
	/** Global time dilation during the window (the player is exempt). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Spider-Sense", meta = (ClampMin = 0.05, ClampMax = 1)) float SpiderSenseTimeDilation = 0.35f;
	/** Invulnerability + counter window granted by a Perfect Dodge. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Spider-Sense", meta = (ClampMin = 0)) float PerfectDodgeGrace = 1.2f;

	UPROPERTY(BlueprintAssignable, Category = "Spider-Sense") FDRSpiderSenseWindowOpened OnSpiderSenseWindowOpened;
	UPROPERTY(BlueprintAssignable, Category = "Spider-Sense") FDRPerfectDodge OnPerfectDodge;

	/** Enemies call this when they commit to an attack that will land in `TimeToImpact` seconds. */
	UFUNCTION(BlueprintCallable, Category = "Spider-Sense") void WarnIncomingAttack(AActor* Attacker, float TimeToImpact);
	UFUNCTION(BlueprintPure, Category = "Spider-Sense") bool IsSpiderSenseActive() const { return bSpiderSenseActive; }
	UFUNCTION(BlueprintPure, Category = "Spider-Sense") bool IsInPerfectDodgeGrace() const;

	// ---- IDRCombatant --------------------------------------------------------------
	virtual EDRNature GetNature_Implementation() const override { return Nature; }
	virtual bool IsInvulnerable_Implementation() const override;
	virtual void OnTechniqueHit_Implementation(float Damage, EDRNature HitNature, float Multiplier, AActor* Instigator) override;

	UFUNCTION(BlueprintPure, Category = "Movement") UDRCharacterMovementComponent* GetDRMovement() const { return DRMovement; }

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
	virtual float TakeDamage(float Damage, const FDamageEvent& DamageEvent, AController* EventInstigator, AActor* DamageCauser) override;

	void Move(const FInputActionValue& Value);
	void Look(const FInputActionValue& Value);
	void SwingPressed();
	void SwingReleased();
	void ZipPressed();
	void ReelPressed();
	void ReelReleased();
	void DodgePressed();
	void ActivateAbilitySlot(int32 Slot);

	UFUNCTION() void HandleSwingStarted(FVector Anchor);
	UFUNCTION() void HandleSwingEnded(FVector ReleaseVelocity);

	void CloseSpiderSenseWindow();
	void PerformPerfectDodge();

	/** Blueprint hooks for animation & VFX. */
	UFUNCTION(BlueprintImplementableEvent, Category = "Dodge") void BP_OnDodge(FVector Direction, bool bPerfect);
	UFUNCTION(BlueprintImplementableEvent, Category = "Combat") void BP_OnDeath();

private:
	UPROPERTY(Transient) TObjectPtr<UDRCharacterMovementComponent> DRMovement;
	UPROPERTY(Transient) TObjectPtr<AActor> PendingAttacker;

	bool bSpiderSenseActive = false;
	float DodgeInvulnerableUntil = 0.f;
	float PerfectDodgeGraceUntil = 0.f;
	float NextDodgeTime = 0.f;
	FTimerHandle SpiderSenseTimer;
};
