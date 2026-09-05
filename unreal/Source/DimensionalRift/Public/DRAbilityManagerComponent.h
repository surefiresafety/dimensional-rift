#pragma once
#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "DRAbilityManagerComponent.generated.h"

class UDRAbilityData;
class UDRSpiritEnergyComponent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FDRLoadoutChanged, const TArray<UDRAbilityData*>&, Slots);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FDRAbilityLearned, UDRAbilityData*, Ability);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FDRAbilityActivated, UDRAbilityData*, Ability, int32, Slot);

UENUM(BlueprintType)
enum class EDRActivateResult : uint8
{
	Activated, EmptySlot, OnCooldown, NotEnoughSpiritEnergy, Blocked
};

/**
 * The Copy System.
 *  - `Learned`  : every technique the player has extracted (unbounded).
 *  - `Slots`    : the four active techniques (The Rule of Four). Fixed size; nullptr = empty.
 *  - ExtractFrom(): call when an enemy dies; pulls its IDRExtractable technique.
 *  - TryActivate(): spends Spirit Energy, starts the cooldown and spawns the payload.
 *
 * Deliberately independent of GAS so it drops into any character. If you migrate to the
 * Gameplay Ability System later, keep this as the loadout/extraction layer and have
 * TryActivate() call ASC->TryActivateAbilityByClass instead of SpawnPayload().
 */
UCLASS(ClassGroup = (DR), meta = (BlueprintSpawnableComponent))
class DIMENSIONALRIFT_API UDRAbilityManagerComponent : public UActorComponent
{
	GENERATED_BODY()
public:
	static constexpr int32 MaxSlots = 4;

	UDRAbilityManagerComponent();

	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Copy System") TArray<TObjectPtr<UDRAbilityData>> Learned;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Copy System") TArray<TObjectPtr<UDRAbilityData>> Slots;

	UPROPERTY(BlueprintAssignable, Category = "Copy System") FDRLoadoutChanged OnLoadoutChanged;
	UPROPERTY(BlueprintAssignable, Category = "Copy System") FDRAbilityLearned OnAbilityLearned;
	UPROPERTY(BlueprintAssignable, Category = "Copy System") FDRAbilityActivated OnAbilityActivated;

	// --- Loadout -------------------------------------------------------------
	UFUNCTION(BlueprintCallable, Category = "Copy System") bool Learn(UDRAbilityData* Ability);
	/** Equip into `Slot` (0-3). -1 = first empty slot; fails if the loadout is full. */
	UFUNCTION(BlueprintCallable, Category = "Copy System") bool Equip(UDRAbilityData* Ability, int32 Slot = -1);
	UFUNCTION(BlueprintCallable, Category = "Copy System") bool Unequip(int32 Slot);
	UFUNCTION(BlueprintCallable, Category = "Copy System") void SwapSlots(int32 A, int32 B);
	UFUNCTION(BlueprintPure, Category = "Copy System") UDRAbilityData* GetSlot(int32 Slot) const;
	UFUNCTION(BlueprintPure, Category = "Copy System") int32 FindSlot(const UDRAbilityData* Ability) const;
	UFUNCTION(BlueprintPure, Category = "Copy System") bool HasLearned(const UDRAbilityData* Ability) const { return Learned.Contains(Ability); }

	// --- Extraction (the "catch") -----------------------------------------------
	/** Extract the defeated actor's technique. Returns the ability learned, or nullptr if none / already known. */
	UFUNCTION(BlueprintCallable, Category = "Copy System") UDRAbilityData* ExtractFrom(AActor* DefeatedEnemy);

	// --- Activation --------------------------------------------------------------
	UFUNCTION(BlueprintCallable, Category = "Copy System") EDRActivateResult TryActivate(int32 Slot);
	UFUNCTION(BlueprintPure, Category = "Copy System") float GetCooldownRemaining(int32 Slot) const;
	UFUNCTION(BlueprintPure, Category = "Copy System") bool IsCasting() const { return bCasting; }
	/** Called by the cast montage's AnimNotify (or a timer) when the cast can be interrupted again. */
	UFUNCTION(BlueprintCallable, Category = "Copy System") void EndCast();
	/** External lockouts: stunned, rooted in webs, mid-ultimate. */
	UFUNCTION(BlueprintCallable, Category = "Copy System") void SetBlocked(bool bBlocked) { bActivationBlocked = bBlocked; }

protected:
	virtual void BeginPlay() override;

	/** Spawns the payload actor at the socket and plays montage/VFX/SFX. Override for GAS. */
	virtual void SpawnPayload(UDRAbilityData* Ability, int32 Slot);

	UFUNCTION(BlueprintImplementableEvent, Category = "Copy System", meta = (DisplayName = "On Activate Failed"))
	void BP_OnActivateFailed(int32 Slot, EDRActivateResult Reason);

private:
	UPROPERTY(Transient) TObjectPtr<UDRSpiritEnergyComponent> SpiritEnergy;
	TMap<TObjectPtr<UDRAbilityData>, float> CooldownEndTime;
	bool bCasting = false;
	bool bActivationBlocked = false;
	FTimerHandle CastTimer;
};
