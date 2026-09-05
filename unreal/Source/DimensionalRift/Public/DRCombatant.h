#pragma once
#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "DRTypes.h"
#include "DRCombatant.generated.h"

UINTERFACE(BlueprintType)
class UDRCombatant : public UInterface { GENERATED_BODY() };

/** Anything that can be hit by a technique: player, enemies, destructibles. */
class DIMENSIONALRIFT_API IDRCombatant
{
	GENERATED_BODY()
public:
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "DR|Combat")
	EDRNature GetNature() const;

	/** Return true to negate the hit entirely (i-frames, Spider-Sense perfect dodge, Shadow Clone decoy). */
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "DR|Combat")
	bool IsInvulnerable() const;

	/** Called after damage is applied so the receiver can play hit reacts / flash / hit-stop. */
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "DR|Combat")
	void OnTechniqueHit(float Damage, EDRNature Nature, float Multiplier, AActor* Instigator);
};
