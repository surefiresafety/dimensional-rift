#include "DRSpiritEnergyComponent.h"

UDRSpiritEnergyComponent::UDRSpiritEnergyComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
}

bool UDRSpiritEnergyComponent::TrySpend(float Cost)
{
	if (Cost < 0.f || CurrentEnergy < Cost) return false;
	CurrentEnergy -= Cost;
	RegenBlockedUntil = GetWorld()->GetTimeSeconds() + RegenDelay;
	OnChanged.Broadcast(CurrentEnergy, MaxEnergy);
	return true;
}

void UDRSpiritEnergyComponent::Restore(float Amount)
{
	if (Amount <= 0.f) return;
	CurrentEnergy = FMath::Min(MaxEnergy, CurrentEnergy + Amount);
	OnChanged.Broadcast(CurrentEnergy, MaxEnergy);
}

void UDRSpiritEnergyComponent::SetMax(float NewMax, bool bRefill)
{
	MaxEnergy = FMath::Max(1.f, NewMax);
	CurrentEnergy = bRefill ? MaxEnergy : FMath::Min(CurrentEnergy, MaxEnergy);
	OnChanged.Broadcast(CurrentEnergy, MaxEnergy);
}

void UDRSpiritEnergyComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
	if (RegenPerSecond <= 0.f || CurrentEnergy >= MaxEnergy) return;
	if (GetWorld()->GetTimeSeconds() < RegenBlockedUntil) return;
	Restore(RegenPerSecond * DeltaTime);
}
