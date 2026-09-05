using UnrealBuildTool;

public class DimensionalRift : ModuleRules
{
	public DimensionalRift(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		PublicDependencyModuleNames.AddRange(new string[]
		{
			"Core", "CoreUObject", "Engine", "InputCore",
			"EnhancedInput",      // player input
			"Niagara",            // technique VFX
			"CableComponent",     // visible web line while swinging
			"GameplayTags",       // status/immunity tags
			"UMG"
		});

		PrivateDependencyModuleNames.AddRange(new string[] { "Slate", "SlateCore" });

		PublicIncludePaths.Add(ModuleDirectory + "/Public");
		PrivateIncludePaths.Add(ModuleDirectory + "/Private");
	}
}
