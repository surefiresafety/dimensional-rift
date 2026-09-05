#pragma once
#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "DRTypes.h"
#include "DRCombatStatics.generated.h"

class UDRAbilityData;

/**
 * Elemental weakness math shared by every technique, projectile and hitbox.
 * Fire > Wind > Lightning > Earth > Water > Fire. Weakness = 2x, resistance = 0.5x.
 */
UCLASS()
class DIMENSIONALRIFT_API UDRCombatStatics : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()
public:
	static constexpr float SuperEffective = 2.f;
	static constexpr float NotVeryEffective = 0.5f;

	/** The nature that `Attack` beats, or Physical if it is not on the wheel. */
	UFUNCTION(BlueprintPure, Category = "DR|Combat")
	static EDRNature Beats(EDRNature Attack);

	/** 2.0 on a weakness, 0.5 on a resistance, 1.0 otherwise. */
	UFUNCTION(BlueprintPure, Category = "DR|Combat")
	static float GetEffectiveness(EDRNature Attack, EDRNature Defend);

	/**
	 * Applies technique damage to `Target`, reading its nature through IDRCombatant and
	 * multiplying by the weakness wheel. Returns the damage actually applied.
	 */
	UFUNCTION(BlueprintCallable, Category = "DR|Combat", meta = (DefaultToSelf = "Instigator"))
	static float ApplyTechniqueDamage(AActor* Target, float BaseDamage, EDRNature Nature, AActor* Instigator, const UDRAbilityData* Source = nullptr);
};
