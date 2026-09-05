#pragma once
#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "DRSpiritEnergyComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FDRSpiritEnergyChanged, float, Current, float, Max);

/** The unified mana bar. Ninjutsu, Cursed Techniques and web gadgets all spend from here. */
UCLASS(ClassGroup = (DR), meta = (BlueprintSpawnableComponent))
class DIMENSIONALRIFT_API UDRSpiritEnergyComponent : public UActorComponent
{
	GENERATED_BODY()
public:
	UDRSpiritEnergyComponent();

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Spirit Energy", meta = (ClampMin = 1)) float MaxEnergy = 100.f;
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Spirit Energy") float CurrentEnergy = 100.f;
	/** Passive regen per second while out of combat. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Spirit Energy", meta = (ClampMin = 0)) float RegenPerSecond = 4.f;
	/** Seconds after spending before regen resumes. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Spirit Energy", meta = (ClampMin = 0)) float RegenDelay = 2.5f;

	UPROPERTY(BlueprintAssignable, Category = "Spirit Energy") FDRSpiritEnergyChanged OnChanged;

	UFUNCTION(BlueprintPure, Category = "Spirit Energy") bool CanAfford(float Cost) const { return CurrentEnergy >= Cost; }
	UFUNCTION(BlueprintCallable, Category = "Spirit Energy") bool TrySpend(float Cost);
	UFUNCTION(BlueprintCallable, Category = "Spirit Energy") void Restore(float Amount);
	UFUNCTION(BlueprintCallable, Category = "Spirit Energy") void SetMax(float NewMax, bool bRefill);

	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
	float RegenBlockedUntil = 0.f;
};
