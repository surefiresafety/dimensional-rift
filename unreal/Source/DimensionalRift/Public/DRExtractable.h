#pragma once
#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "DRExtractable.generated.h"

class UDRAbilityData;

UINTERFACE(BlueprintType)
class UDRExtractable : public UInterface { GENERATED_BODY() };

/** Enemies that surrender a technique when defeated (the Copy System). */
class DIMENSIONALRIFT_API IDRExtractable
{
	GENERATED_BODY()
public:
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "DR|Copy")
	UDRAbilityData* GetExtractableAbility() const;
};
