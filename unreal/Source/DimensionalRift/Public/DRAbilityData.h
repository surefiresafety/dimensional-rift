#pragma once
#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "DRTypes.h"
#include "DRAbilityData.generated.h"

class UAnimMontage;
class UNiagaraSystem;
class USoundBase;

UENUM(BlueprintType)
enum class EDRAbilityKind : uint8 { Attack, Buff, Debuff, Heal, Traversal };

/**
 * One technique (jutsu / cursed technique / web gadget). Designers author these as
 * Data Assets; the Ability Manager equips at most four of them at a time.
 *
 * Runtime behaviour lives in `PayloadClass` (an actor spawned at activation, usually a
 * Blueprint subclass of ADRTechniqueActor) so each technique's logic and VFX are self-contained.
 */
UCLASS(BlueprintType)
class DIMENSIONALRIFT_API UDRAbilityData : public UPrimaryDataAsset
{
	GENERATED_BODY()
public:
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Identity") FName AbilityId;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Identity") FText DisplayName;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Identity", meta = (MultiLine = true)) FText Description;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Identity") TObjectPtr<UTexture2D> Icon;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Identity") EDRAbilityOrigin Origin = EDRAbilityOrigin::Naruto;

	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Combat") EDRNature Nature = EDRNature::Physical;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Combat") EDRAbilityKind Kind = EDRAbilityKind::Attack;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Combat", meta = (ClampMin = 0)) float BasePower = 50.f;
	/** Spirit Energy cost. Every origin pays from the same pool. */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Combat", meta = (ClampMin = 0)) float SpiritCost = 10.f;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Combat", meta = (ClampMin = 0)) float Cooldown = 2.f;
	/** Ultimates (Domain Expansion, Rasenshuriken) lock movement and run a Sequencer cinematic. */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Combat") bool bIsUltimate = false;

	/** Actor spawned at activation. It owns the hitbox/projectile and the Niagara systems. */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Presentation") TSubclassOf<AActor> PayloadClass;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Presentation") TObjectPtr<UAnimMontage> CastMontage;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Presentation") TObjectPtr<UNiagaraSystem> CastVFX;
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Presentation") TObjectPtr<USoundBase> CastSound;
	/** Socket on the character mesh the payload/VFX is attached to (e.g. hand_r, spine_03). */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Presentation") FName SpawnSocket = TEXT("hand_r");

	virtual FPrimaryAssetId GetPrimaryAssetId() const override { return FPrimaryAssetId(TEXT("Ability"), AbilityId); }
};
