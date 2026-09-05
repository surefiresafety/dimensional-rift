#include "DRCombatStatics.h"
#include "DRCombatant.h"
#include "DRAbilityData.h"
#include "DimensionalRift.h"
#include "Kismet/GameplayStatics.h"

EDRNature UDRCombatStatics::Beats(EDRNature Attack)
{
	switch (Attack)
	{
	case EDRNature::Fire:      return EDRNature::Wind;
	case EDRNature::Wind:      return EDRNature::Lightning;
	case EDRNature::Lightning: return EDRNature::Earth;
	case EDRNature::Earth:     return EDRNature::Water;
	case EDRNature::Water:     return EDRNature::Fire;
	default:                   return EDRNature::Physical; // off the wheel
	}
}

float UDRCombatStatics::GetEffectiveness(EDRNature Attack, EDRNature Defend)
{
	const bool bAttackOnWheel = Attack != EDRNature::Physical && Attack != EDRNature::Cursed;
	const bool bDefendOnWheel = Defend != EDRNature::Physical && Defend != EDRNature::Cursed;
	if (!bAttackOnWheel || !bDefendOnWheel) return 1.f;
	if (Beats(Attack) == Defend) return SuperEffective;
	if (Beats(Defend) == Attack) return NotVeryEffective;
	return 1.f;
}

float UDRCombatStatics::ApplyTechniqueDamage(AActor* Target, float BaseDamage, EDRNature Nature, AActor* Instigator, const UDRAbilityData* Source)
{
	if (!IsValid(Target) || BaseDamage <= 0.f) return 0.f;

	float Multiplier = 1.f;
	if (Target->Implements<UDRCombatant>())
	{
		if (IDRCombatant::Execute_IsInvulnerable(Target))
		{
			UE_LOG(LogDR, Verbose, TEXT("%s negated %s"), *Target->GetName(), Source ? *Source->DisplayName.ToString() : TEXT("hit"));
			return 0.f;
		}
		Multiplier = GetEffectiveness(Nature, IDRCombatant::Execute_GetNature(Target));
	}

	const float Damage = BaseDamage * Multiplier;
	AController* InstigatorController = Instigator ? Instigator->GetInstigatorController() : nullptr;
	UGameplayStatics::ApplyDamage(Target, Damage, InstigatorController, Instigator, nullptr);

	if (Target->Implements<UDRCombatant>())
	{
		IDRCombatant::Execute_OnTechniqueHit(Target, Damage, Nature, Multiplier, Instigator);
	}
	return Damage;
}
