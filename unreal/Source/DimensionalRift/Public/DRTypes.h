#pragma once
#include "CoreMinimal.h"
#include "DRTypes.generated.h"

/** Chakra natures: the elemental weakness wheel. Physical and Cursed sit outside it (always neutral). */
UENUM(BlueprintType)
enum class EDRNature : uint8
{
	Physical  UMETA(DisplayName = "Physical"),
	Fire      UMETA(DisplayName = "Fire"),
	Wind      UMETA(DisplayName = "Wind"),
	Lightning UMETA(DisplayName = "Lightning"),
	Earth     UMETA(DisplayName = "Earth"),
	Water     UMETA(DisplayName = "Water"),
	Cursed    UMETA(DisplayName = "Cursed")
};

UENUM(BlueprintType)
enum class EDRAbilityOrigin : uint8
{
	Naruto, JJK, Marvel, CursedSpirit
};

/** Custom movement modes handled by UDRCharacterMovementComponent::PhysCustom. */
UENUM(BlueprintType)
enum EDRCustomMovementMode : int
{
	CMOVE_None  UMETA(Hidden),
	CMOVE_Swing UMETA(DisplayName = "Web Swing"),
	CMOVE_Zip   UMETA(DisplayName = "Web Zip")
};
