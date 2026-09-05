#include "DRAbilityManagerComponent.h"
#include "DRAbilityData.h"
#include "DRExtractable.h"
#include "DRSpiritEnergyComponent.h"
#include "DimensionalRift.h"
#include "GameFramework/Character.h"
#include "Components/SkeletalMeshComponent.h"
#include "Animation/AnimInstance.h"
#include "NiagaraFunctionLibrary.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"

UDRAbilityManagerComponent::UDRAbilityManagerComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
	Slots.SetNum(MaxSlots);
}

void UDRAbilityManagerComponent::BeginPlay()
{
	Super::BeginPlay();
	if (Slots.Num() != MaxSlots) Slots.SetNum(MaxSlots);
	SpiritEnergy = GetOwner()->FindComponentByClass<UDRSpiritEnergyComponent>();
	if (!SpiritEnergy)
	{
		UE_LOG(LogDR, Warning, TEXT("%s has an Ability Manager but no Spirit Energy component; techniques will be free."), *GetOwner()->GetName());
	}
	// Anything pre-equipped in the editor counts as learned.
	for (UDRAbilityData* A : Slots) if (A && !Learned.Contains(A)) Learned.Add(A);
	OnLoadoutChanged.Broadcast(Slots);
}

// ---- Loadout -------------------------------------------------------------------

bool UDRAbilityManagerComponent::Learn(UDRAbilityData* Ability)
{
	if (!Ability || Learned.Contains(Ability)) return false;
	Learned.Add(Ability);
	OnAbilityLearned.Broadcast(Ability);
	// Auto-equip while there is room, like picking up your first four moves.
	Equip(Ability, -1);
	return true;
}

bool UDRAbilityManagerComponent::Equip(UDRAbilityData* Ability, int32 Slot)
{
	if (!Ability || !Learned.Contains(Ability)) return false;
	if (Slots.Contains(Ability)) return true; // already active

	if (Slot < 0)
	{
		Slot = Slots.IndexOfByPredicate([](const UDRAbilityData* A) { return A == nullptr; });
		if (Slot == INDEX_NONE) return false; // The Rule of Four: loadout full, player must choose what to drop.
	}
	if (!Slots.IsValidIndex(Slot)) return false;

	Slots[Slot] = Ability;
	OnLoadoutChanged.Broadcast(Slots);
	return true;
}

bool UDRAbilityManagerComponent::Unequip(int32 Slot)
{
	if (!Slots.IsValidIndex(Slot) || !Slots[Slot]) return false;
	Slots[Slot] = nullptr;
	OnLoadoutChanged.Broadcast(Slots);
	return true;
}

void UDRAbilityManagerComponent::SwapSlots(int32 A, int32 B)
{
	if (!Slots.IsValidIndex(A) || !Slots.IsValidIndex(B) || A == B) return;
	Slots.Swap(A, B);
	OnLoadoutChanged.Broadcast(Slots);
}

UDRAbilityData* UDRAbilityManagerComponent::GetSlot(int32 Slot) const
{
	return Slots.IsValidIndex(Slot) ? Slots[Slot].Get() : nullptr;
}

int32 UDRAbilityManagerComponent::FindSlot(const UDRAbilityData* Ability) const
{
	return Slots.IndexOfByKey(Ability);
}

// ---- Extraction -----------------------------------------------------------------

UDRAbilityData* UDRAbilityManagerComponent::ExtractFrom(AActor* DefeatedEnemy)
{
	if (!IsValid(DefeatedEnemy) || !DefeatedEnemy->Implements<UDRExtractable>()) return nullptr;
	UDRAbilityData* Ability = IDRExtractable::Execute_GetExtractableAbility(DefeatedEnemy);
	if (!Ability || Learned.Contains(Ability)) return nullptr;
	Learn(Ability);
	UE_LOG(LogDR, Log, TEXT("Extracted %s from %s"), *Ability->DisplayName.ToString(), *DefeatedEnemy->GetName());
	return Ability;
}

// ---- Activation -----------------------------------------------------------------

float UDRAbilityManagerComponent::GetCooldownRemaining(int32 Slot) const
{
	UDRAbilityData* Ability = GetSlot(Slot);
	if (!Ability) return 0.f;
	const float* End = CooldownEndTime.Find(Ability);
	return End ? FMath::Max(0.f, *End - GetWorld()->GetTimeSeconds()) : 0.f;
}

EDRActivateResult UDRAbilityManagerComponent::TryActivate(int32 Slot)
{
	UDRAbilityData* Ability = GetSlot(Slot);
	EDRActivateResult Result = EDRActivateResult::Activated;

	if (!Ability)                                                   Result = EDRActivateResult::EmptySlot;
	else if (bActivationBlocked || bCasting)                        Result = EDRActivateResult::Blocked;
	else if (GetCooldownRemaining(Slot) > 0.f)                      Result = EDRActivateResult::OnCooldown;
	else if (SpiritEnergy && !SpiritEnergy->CanAfford(Ability->SpiritCost)) Result = EDRActivateResult::NotEnoughSpiritEnergy;

	if (Result != EDRActivateResult::Activated)
	{
		BP_OnActivateFailed(Slot, Result);
		return Result;
	}

	if (SpiritEnergy) SpiritEnergy->TrySpend(Ability->SpiritCost);
	CooldownEndTime.Add(Ability, GetWorld()->GetTimeSeconds() + Ability->Cooldown);
	SpawnPayload(Ability, Slot);
	OnAbilityActivated.Broadcast(Ability, Slot);
	return Result;
}

void UDRAbilityManagerComponent::SpawnPayload(UDRAbilityData* Ability, int32 Slot)
{
	AActor* Owner = GetOwner();
	ACharacter* Character = Cast<ACharacter>(Owner);
	USkeletalMeshComponent* Mesh = Character ? Character->GetMesh() : nullptr;

	const FTransform SpawnTM = (Mesh && Mesh->DoesSocketExist(Ability->SpawnSocket))
		? Mesh->GetSocketTransform(Ability->SpawnSocket)
		: Owner->GetActorTransform();

	// Cast animation gates re-activation until its notify (or the montage end) calls EndCast().
	float CastLock = 0.f;
	if (Ability->CastMontage && Mesh && Mesh->GetAnimInstance())
	{
		CastLock = Mesh->GetAnimInstance()->Montage_Play(Ability->CastMontage);
	}
	if (CastLock > 0.f)
	{
		bCasting = true;
		GetWorld()->GetTimerManager().SetTimer(CastTimer, this, &UDRAbilityManagerComponent::EndCast, CastLock, false);
	}

	if (Ability->CastVFX)
	{
		if (Mesh) UNiagaraFunctionLibrary::SpawnSystemAttached(Ability->CastVFX, Mesh, Ability->SpawnSocket, FVector::ZeroVector, FRotator::ZeroRotator, EAttachLocation::SnapToTarget, true);
		else      UNiagaraFunctionLibrary::SpawnSystemAtLocation(this, Ability->CastVFX, SpawnTM.GetLocation());
	}
	if (Ability->CastSound) UGameplayStatics::PlaySoundAtLocation(this, Ability->CastSound, SpawnTM.GetLocation());

	if (Ability->PayloadClass)
	{
		FActorSpawnParameters Params;
		Params.Owner = Owner;
		Params.Instigator = Cast<APawn>(Owner);
		Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
		// Payloads face where the character faces (aim assist / camera aim can override in BP).
		FTransform TM(Owner->GetActorRotation(), SpawnTM.GetLocation());
		GetWorld()->SpawnActor<AActor>(Ability->PayloadClass, TM, Params);
	}
}

void UDRAbilityManagerComponent::EndCast()
{
	bCasting = false;
	GetWorld()->GetTimerManager().ClearTimer(CastTimer);
}
