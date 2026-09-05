#include "DRCharacter.h"
#include "DRCharacterMovementComponent.h"
#include "DRAbilityManagerComponent.h"
#include "DRSpiritEnergyComponent.h"
#include "DimensionalRift.h"
#include "Camera/CameraComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "CableComponent.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "InputActionValue.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"

ADRCharacter::ADRCharacter(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer.SetDefaultSubobjectClass<UDRCharacterMovementComponent>(ACharacter::CharacterMovementComponentName))
{
	PrimaryActorTick.bCanEverTick = true;
	DRMovement = Cast<UDRCharacterMovementComponent>(GetCharacterMovement());

	bUseControllerRotationYaw = false;
	bUseControllerRotationPitch = false;
	bUseControllerRotationRoll = false;
	GetCapsuleComponent()->InitCapsuleSize(38.f, 92.f);

	CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
	CameraBoom->SetupAttachment(RootComponent);
	CameraBoom->TargetArmLength = 480.f;
	CameraBoom->SocketOffset = FVector(0.f, 60.f, 70.f);
	CameraBoom->bUsePawnControlRotation = true;
	CameraBoom->bEnableCameraLag = true;
	CameraBoom->CameraLagSpeed = 14.f;
	CameraBoom->bEnableCameraRotationLag = true;
	CameraBoom->CameraRotationLagSpeed = 18.f;

	FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
	FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
	FollowCamera->bUsePawnControlRotation = false;
	FollowCamera->FieldOfView = 80.f;

	AbilityManager = CreateDefaultSubobject<UDRAbilityManagerComponent>(TEXT("AbilityManager"));
	SpiritEnergy = CreateDefaultSubobject<UDRSpiritEnergyComponent>(TEXT("SpiritEnergy"));

	WebCable = CreateDefaultSubobject<UCableComponent>(TEXT("WebCable"));
	WebCable->SetupAttachment(GetMesh(), TEXT("hand_r"));
	WebCable->bAttachEnd = true;
	WebCable->CableLength = 50.f;
	WebCable->NumSegments = 10;
	WebCable->SolverIterations = 4;
	WebCable->CableWidth = 3.f;
	WebCable->SetVisibility(false);
}

void ADRCharacter::BeginPlay()
{
	Super::BeginPlay();
	Health = MaxHealth;

	if (APlayerController* PC = Cast<APlayerController>(GetController()))
	{
		if (ULocalPlayer* LP = PC->GetLocalPlayer())
		{
			if (UEnhancedInputLocalPlayerSubsystem* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(LP))
			{
				if (DefaultMappingContext) Subsystem->AddMappingContext(DefaultMappingContext, 0);
			}
		}
	}

	if (DRMovement)
	{
		DRMovement->OnSwingStarted.AddDynamic(this, &ADRCharacter::HandleSwingStarted);
		DRMovement->OnSwingEnded.AddDynamic(this, &ADRCharacter::HandleSwingEnded);
	}
}

void ADRCharacter::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (DRMovement && (DRMovement->IsSwinging() || DRMovement->IsZipping()) && WebCable)
	{
		// The cable's EndLocation is in its own component space.
		WebCable->EndLocation = WebCable->GetComponentTransform().InverseTransformPosition(DRMovement->GetSwingAnchor());
	}
}

// ---------------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------------

void ADRCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);
	UEnhancedInputComponent* EIC = Cast<UEnhancedInputComponent>(PlayerInputComponent);
	if (!EIC)
	{
		UE_LOG(LogDR, Error, TEXT("ADRCharacter needs the Enhanced Input component (Project Settings > Input > Default Classes)."));
		return;
	}

	if (MoveAction)  EIC->BindAction(MoveAction, ETriggerEvent::Triggered, this, &ADRCharacter::Move);
	if (LookAction)  EIC->BindAction(LookAction, ETriggerEvent::Triggered, this, &ADRCharacter::Look);
	if (JumpAction)
	{
		EIC->BindAction(JumpAction, ETriggerEvent::Started, this, &ADRCharacter::Jump);
		EIC->BindAction(JumpAction, ETriggerEvent::Completed, this, &ADRCharacter::StopJumping);
	}
	if (SwingAction)
	{
		EIC->BindAction(SwingAction, ETriggerEvent::Started, this, &ADRCharacter::SwingPressed);
		EIC->BindAction(SwingAction, ETriggerEvent::Completed, this, &ADRCharacter::SwingReleased);
	}
	if (ZipAction)   EIC->BindAction(ZipAction, ETriggerEvent::Started, this, &ADRCharacter::ZipPressed);
	if (ReelAction)
	{
		EIC->BindAction(ReelAction, ETriggerEvent::Started, this, &ADRCharacter::ReelPressed);
		EIC->BindAction(ReelAction, ETriggerEvent::Completed, this, &ADRCharacter::ReelReleased);
	}
	if (DodgeAction) EIC->BindAction(DodgeAction, ETriggerEvent::Started, this, &ADRCharacter::DodgePressed);

	// One action per loadout slot (Q / E / R / F, or the four face buttons with a modifier).
	for (int32 Slot = 0; Slot < FMath::Min(AbilityActions.Num(), UDRAbilityManagerComponent::MaxSlots); ++Slot)
	{
		if (AbilityActions[Slot])
		{
			EIC->BindAction(AbilityActions[Slot], ETriggerEvent::Started, this, &ADRCharacter::ActivateAbilitySlot, Slot);
		}
	}
}

void ADRCharacter::Move(const FInputActionValue& Value)
{
	const FVector2D Axis = Value.Get<FVector2D>();
	if (!Controller) return;
	const FRotator YawRot(0.f, Controller->GetControlRotation().Yaw, 0.f);
	const FVector Forward = FRotationMatrix(YawRot).GetUnitAxis(EAxis::X);
	const FVector Right = FRotationMatrix(YawRot).GetUnitAxis(EAxis::Y);
	AddMovementInput(Forward, Axis.Y);
	AddMovementInput(Right, Axis.X);
}

void ADRCharacter::Look(const FInputActionValue& Value)
{
	const FVector2D Axis = Value.Get<FVector2D>();
	AddControllerYawInput(Axis.X);
	AddControllerPitchInput(Axis.Y);
}

void ADRCharacter::SwingPressed()
{
	if (!DRMovement || DRMovement->IsSwinging()) return;
	if (!DRMovement->TryStartSwing())
	{
		UE_LOG(LogDR, Verbose, TEXT("No web anchor in reach."));
	}
}

void ADRCharacter::SwingReleased()
{
	// Hold-to-swing: letting go of the button lets go of the web, carrying momentum into the air.
	if (DRMovement) DRMovement->ReleaseSwing();
}

void ADRCharacter::ZipPressed()
{
	if (DRMovement) DRMovement->TryStartZip();
}

void ADRCharacter::ReelPressed()   { if (DRMovement) DRMovement->SetReelingIn(true); }
void ADRCharacter::ReelReleased()  { if (DRMovement) DRMovement->SetReelingIn(false); }

void ADRCharacter::ActivateAbilitySlot(int32 Slot)
{
	if (AbilityManager) AbilityManager->TryActivate(Slot);
}

// ---------------------------------------------------------------------------------
// Dodge & Spider-Sense
// ---------------------------------------------------------------------------------

void ADRCharacter::DodgePressed()
{
	const float Now = GetWorld()->GetTimeSeconds();
	if (Now < NextDodgeTime || !DRMovement) return;
	if (DRMovement->IsSwinging()) DRMovement->ReleaseSwing();

	FVector Dir = GetLastMovementInputVector();
	Dir.Z = 0.f;
	if (Dir.IsNearlyZero()) Dir = -GetActorForwardVector(); // neutral dodge = backstep
	Dir.Normalize();

	const bool bPerfect = bSpiderSenseActive;
	NextDodgeTime = Now + DodgeCooldown;
	DodgeInvulnerableUntil = Now + DodgeInvulnerableTime;
	LaunchCharacter(Dir * (DodgeDistance / FMath::Max(DodgeInvulnerableTime, 0.05f)), true, false);

	if (bPerfect) PerformPerfectDodge();
	BP_OnDodge(Dir, bPerfect);
}

void ADRCharacter::WarnIncomingAttack(AActor* Attacker, float TimeToImpact)
{
	if (bSpiderSenseActive || Health <= 0.f) return;
	PendingAttacker = Attacker;
	bSpiderSenseActive = true;

	// The world slows; the player does not.
	UGameplayStatics::SetGlobalTimeDilation(this, SpiderSenseTimeDilation);
	CustomTimeDilation = 1.f / SpiderSenseTimeDilation;

	// Timers run on dilated world time, so scale the window back to (roughly) real seconds.
	const float Window = FMath::Min(SpiderSenseWindow, FMath::Max(TimeToImpact, 0.1f)) * SpiderSenseTimeDilation;
	GetWorld()->GetTimerManager().SetTimer(SpiderSenseTimer, this, &ADRCharacter::CloseSpiderSenseWindow, Window, false);
	OnSpiderSenseWindowOpened.Broadcast();
}

void ADRCharacter::CloseSpiderSenseWindow()
{
	if (!bSpiderSenseActive) return;
	bSpiderSenseActive = false;
	GetWorld()->GetTimerManager().ClearTimer(SpiderSenseTimer);
	UGameplayStatics::SetGlobalTimeDilation(this, 1.f);
	CustomTimeDilation = 1.f;
}

void ADRCharacter::PerformPerfectDodge()
{
	AActor* Attacker = PendingAttacker;
	CloseSpiderSenseWindow();
	PerfectDodgeGraceUntil = GetWorld()->GetTimeSeconds() + PerfectDodgeGrace;
	if (SpiritEnergy) SpiritEnergy->Restore(10.f); // reward reading the attack
	OnPerfectDodge.Broadcast(Attacker);
	PendingAttacker = nullptr;
}

bool ADRCharacter::IsInPerfectDodgeGrace() const
{
	return GetWorld()->GetTimeSeconds() < PerfectDodgeGraceUntil;
}

// ---------------------------------------------------------------------------------
// Combat
// ---------------------------------------------------------------------------------

bool ADRCharacter::IsInvulnerable_Implementation() const
{
	const float Now = GetWorld()->GetTimeSeconds();
	return Now < DodgeInvulnerableUntil || Now < PerfectDodgeGraceUntil;
}

float ADRCharacter::TakeDamage(float Damage, const FDamageEvent& DamageEvent, AController* EventInstigator, AActor* DamageCauser)
{
	if (Health <= 0.f || IsInvulnerable_Implementation()) return 0.f;
	const float Applied = Super::TakeDamage(Damage, DamageEvent, EventInstigator, DamageCauser);
	Health = FMath::Max(0.f, Health - Applied);
	if (Health <= 0.f)
	{
		CloseSpiderSenseWindow();
		if (AbilityManager) AbilityManager->SetBlocked(true);
		if (DRMovement) { DRMovement->ReleaseSwing(); DRMovement->DisableMovement(); }
		BP_OnDeath();
	}
	return Applied;
}

void ADRCharacter::OnTechniqueHit_Implementation(float Damage, EDRNature HitNature, float Multiplier, AActor* Instigator)
{
	// Hit reacts, damage numbers and the "It's super effective" flash are Blueprint/UMG territory;
	// this hook just exists so enemies and the player share one entry point.
	UE_LOG(LogDR, Verbose, TEXT("%s hit for %.0f (x%.1f)"), *GetName(), Damage, Multiplier);
}

void ADRCharacter::HandleSwingStarted(FVector Anchor)
{
	if (WebCable) WebCable->SetVisibility(true);
}

void ADRCharacter::HandleSwingEnded(FVector ReleaseVelocity)
{
	if (WebCable) WebCable->SetVisibility(false);
}
