/***********************************************************************/
/***********************************************************************/
/** Copyright © 2009-2014
/** Author : collective mind of the CDP
/***********************************************************************/

statemachine class W3PlayerWitcher extends CR4Player
{	
	//CRAFTING
	private saved var craftingSchematics				: array<name>; 					//known crafting schematics
	
	//ALCHEMY
	private saved var alchemyRecipes 					: array<name>; 					//known alchemy recipes	
	
	// SKILLS
	private 			var levelupAbilities	: array< name >;
	private 			var fastAttackCounter, heavyAttackCounter	: int;		//counter for light/heavy attacks. Currently not used but I leave it in case it will come back
	private				var isInFrenzy : bool;
	private				var hasRecentlyCountered : bool;
	private saved 		var cannotUseUndyingSkill : bool;						//if activation delay of Undying skill has finished or not
	
	// FOCUS MODE
	public				var canSwitchFocusModeTarget	: bool;
	protected			var switchFocusModeTargetAllowed : bool;
		default canSwitchFocusModeTarget = true;
		default switchFocusModeTargetAllowed = true;
	
	// SIGNS
	private editable	var signs						: array< SWitcherSign >;
	private	saved		var equippedSign				: ESignType;
	private				var currentlyCastSign			: ESignType; default currentlyCastSign = ST_None;
	private				var signOwner					: W3SignOwnerPlayer;
	private				var usedQuenInCombat			: bool;
	public				var yrdenEntities				: array<W3YrdenEntity>;
	
	default				equippedSign	= ST_Aard;
	
	//COMBAT MECHANICS
	//private				var combatStance				: EPlayerCombatStance;		
	private 			var bDispalyHeavyAttackIndicator 		: bool; //#B
	private 			var bDisplayHeavyAttackFirstLevelTimer 	: bool; //#B
	public	 			var specialAttackHeavyAllowed 			: bool;	

	default bIsCombatActionAllowed = true;	
	default bDispalyHeavyAttackIndicator = false; //#B	
	default bDisplayHeavyAttackFirstLevelTimer = true; //#B
	
	//INPUT
	
		default explorationInputContext = 'Exploration';
		default combatInputContext = 'Combat';
		default combatFistsInputContext = 'Combat';
		
	// COMPANION MODULE	
	private saved var companionNPCTag		: name;
	private saved var companionNPCTag2		: name;
	
	private saved var companionNPCIconPath	: string;
	private saved var companionNPCIconPath2	: string;	
		
	//ITEMS	
	private 	  saved	var itemSlots					: array<SItemUniqueId>;
	private 			var remainingBombThrowDelaySlot1	: float;
	private 			var remainingBombThrowDelaySlot2	: float;
	private 			var previouslyUsedBolt : SItemUniqueId;				//ID of previously used special bolt (before we entered water)
	
	default isThrowingItem = false;
	default remainingBombThrowDelaySlot1 = 0.f;
	default remainingBombThrowDelaySlot2 = 0.f;
	
	//----------------------------
	//SKILLS
	//----------------------------
	
	private 	  var tempLearnedSignSkills : array<SSimpleSkill>;		//list of skills temporarily added for the duration of 'All Out' skill (sword_s19)
	public	saved var autoLevel				: bool;						//temp flag for switching autoleveling for player
	
	//---------------------------------------------------------
	//POTIONS and TOXICITY
	//---------------------------------------------------------
	protected var skillBonusPotionEffect			: CBaseGameplayEffect;			//cached current bonus potion effect (for skill) - we can have only one
	
	//CHARACTER LEVELING AND DEVELOPMENT
	public saved 		var levelManager 				: W3LevelManager;

	//REPUTATION
	saved var reputationManager	: W3Reputation;
	
	//MEDALLION
	private editable	var medallionEntity			: CEntityTemplate;
	private				var medallionController		: W3MedallionController;
	
	//#B Radial Menu
	public 				var bShowRadialMenu	: bool;	

	private 			var _HoldBeforeOpenRadialMenuTime : float;
	
	default _HoldBeforeOpenRadialMenuTime = 0.5f;
	
	public var MappinToHighlight : array<SHighlightMappin>;
	
	//OTHER
	protected saved	var horseManagerHandle			: EntityHandle;		//handles horse stuff //#DynSave this is always dynamic and will never be saved, can't fix
	private var isInitialized : bool;
	
		default isInitialized = false;
	
	////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////
	
	
	////////////////////////////////////////////////////////////////////////////////
	//
	// INITIALIZATION
	//
	////////////////////////////////////////////////////////////////////////////////
	
	event OnSpawned( spawnData : SEntitySpawnData )
	{
		var i 				: int;
		var items 			: array<SItemUniqueId>;
		var items2 			: array<SItemUniqueId>;
		var horseTemplate 	: CEntityTemplate;
		var horseManager 	: W3HorseManager;
		
		AddAnimEventCallback( 'ActionBlend', 			'OnAnimEvent_ActionBlend' );
		AddAnimEventCallback('cast_begin',				'OnAnimEvent_Sign');
		AddAnimEventCallback('cast_throw',				'OnAnimEvent_Sign');
		AddAnimEventCallback('cast_end',				'OnAnimEvent_Sign');
		AddAnimEventCallback('cast_friendly_begin',		'OnAnimEvent_Sign');
		AddAnimEventCallback('cast_friendly_throw',		'OnAnimEvent_Sign');
		AddAnimEventCallback('axii_ready',				'OnAnimEvent_Sign');
		AddAnimEventCallback('axii_alternate_ready',	'OnAnimEvent_Sign');
		AddAnimEventCallback('yrden_draw_ready',		'OnAnimEvent_Sign');
		
		AddAnimEventCallback( 'ProjectileThrow',	'OnAnimEvent_Throwable'	);
		AddAnimEventCallback( 'OnWeaponReload',		'OnAnimEvent_Throwable'	);
		AddAnimEventCallback( 'ProjectileAttach',	'OnAnimEvent_Throwable' );			
		
		theTelemetry.Log( TE_HERO_SPAWNED );
		
		runewordInfusionType = ST_None;
				
		//  Ability manager recalculates resistances so we need to re-equip items first
		inv = GetInventory();			//inv is set in super

		// create and initialize sign owner
		signOwner = new W3SignOwnerPlayer in this;
		signOwner.Init( this );
		
		itemSlots.Resize( EnumGetMax('EEquipmentSlots')+1 );

		if(!spawnData.restored)
		{
			levelManager = new W3LevelManager in this;			
			levelManager.Initialize();
			
			//equip items mounted by default from character template
			inv.GetAllItems(items);
			for(i=0; i<items.Size(); i+=1)
			{
				if(inv.IsItemMounted(items[i]) && ( !inv.IsItemBody(items[i]) || inv.GetItemCategory(items[i]) == 'hair' ) )
					EquipItem(items[i]);
			}
			
			//Sets up default Geralt hair item
			//SetupStartingHair();
			
			// Add starting alchemy recipes
			AddAlchemyRecipe('Recipe for Swallow 1',true,true);
			AddAlchemyRecipe('Recipe for Cat 1',true,true);
			AddAlchemyRecipe('Recipe for White Honey 1',true,true);
			
			AddAlchemyRecipe('Recipe for Samum 1',true,true);
			AddAlchemyRecipe('Recipe for Grapeshot 1',true,true);
			
			AddAlchemyRecipe('Recipe for Specter Oil 1',true,true);
			AddAlchemyRecipe('Recipe for Necrophage Oil 1',true,true);
			AddAlchemyRecipe('Recipe for Alcohest 1',true,true);
			
			// CRAFTING ITEM SCHEMATICS
			AddStartingSchematics();			
		}
		else
		{
			AddTimer('DelayedOnItemMount', 0.1, true);
			
			//Check applied hair for any errors that might occur due to item manipulation via scripts
			CheckHairItem();
		}
		
		super.OnSpawned( spawnData );
		
		// New mutagen recipes, added here to work with old saves
		AddAlchemyRecipe('Recipe for Mutagen red',true,true);
		AddAlchemyRecipe('Recipe for Mutagen green',true,true);
		AddAlchemyRecipe('Recipe for Mutagen blue',true,true);
		AddAlchemyRecipe('Recipe for Greater mutagen red',true,true);
		AddAlchemyRecipe('Recipe for Greater mutagen green',true,true);
		AddAlchemyRecipe('Recipe for Greater mutagen blue',true,true);
		
		AddCraftingSchematic('Starting Armor Upgrade schematic 1',true,true);
				
		levelupAbilities.PushBack('Lvl1');
		levelupAbilities.PushBack('Lvl1');
		levelupAbilities.PushBack('Lvl2');
		levelupAbilities.PushBack('Lvl3');
		levelupAbilities.PushBack('Lvl4');
		levelupAbilities.PushBack('Lvl5');
		levelupAbilities.PushBack('Lvl6');
		levelupAbilities.PushBack('Lvl7');
		levelupAbilities.PushBack('Lvl8');
		levelupAbilities.PushBack('Lvl9');
		levelupAbilities.PushBack('Lvl10');
		levelupAbilities.PushBack('Lvl11');
		levelupAbilities.PushBack('Lvl12');
		levelupAbilities.PushBack('Lvl13');
		levelupAbilities.PushBack('Lvl14');
		levelupAbilities.PushBack('Lvl15');
		levelupAbilities.PushBack('Lvl16');
		levelupAbilities.PushBack('Lvl17');
		levelupAbilities.PushBack('Lvl18');
		levelupAbilities.PushBack('Lvl19');
		levelupAbilities.PushBack('Lvl20');
		levelupAbilities.PushBack('Lvl21');
		levelupAbilities.PushBack('Lvl22');
		levelupAbilities.PushBack('Lvl23');
		levelupAbilities.PushBack('Lvl24');
		levelupAbilities.PushBack('Lvl25');
		levelupAbilities.PushBack('Lvl26');
		levelupAbilities.PushBack('Lvl27');
		levelupAbilities.PushBack('Lvl28');
		levelupAbilities.PushBack('Lvl29');
		levelupAbilities.PushBack('Lvl30');
		levelupAbilities.PushBack('Lvl31');
		levelupAbilities.PushBack('Lvl32');
		levelupAbilities.PushBack('Lvl33');
		levelupAbilities.PushBack('Lvl34');
		levelupAbilities.PushBack('Lvl35');
		levelupAbilities.PushBack('Lvl36');
		levelupAbilities.PushBack('Lvl37');
		levelupAbilities.PushBack('Lvl38');
		levelupAbilities.PushBack('Lvl39');
		levelupAbilities.PushBack('Lvl40');
		levelupAbilities.PushBack('Lvl41');
		levelupAbilities.PushBack('Lvl42');
		levelupAbilities.PushBack('Lvl43');
		levelupAbilities.PushBack('Lvl44');
		levelupAbilities.PushBack('Lvl45');
		levelupAbilities.PushBack('Lvl46');
		levelupAbilities.PushBack('Lvl47');
		levelupAbilities.PushBack('Lvl48');
		levelupAbilities.PushBack('Lvl49');
		levelupAbilities.PushBack('Lvl50');
		levelupAbilities.PushBack('Lvl51');
		levelupAbilities.PushBack('Lvl52');
		levelupAbilities.PushBack('Lvl53');
		levelupAbilities.PushBack('Lvl54');
		levelupAbilities.PushBack('Lvl55');
		levelupAbilities.PushBack('Lvl56');
		levelupAbilities.PushBack('Lvl57');
		levelupAbilities.PushBack('Lvl58');
		levelupAbilities.PushBack('Lvl59');
		levelupAbilities.PushBack('Lvl60');
		levelupAbilities.PushBack('Lvl61');
		levelupAbilities.PushBack('Lvl62');
		levelupAbilities.PushBack('Lvl63');
		levelupAbilities.PushBack('Lvl64');
		levelupAbilities.PushBack('Lvl65');
		levelupAbilities.PushBack('Lvl66');
		levelupAbilities.PushBack('Lvl67');
		levelupAbilities.PushBack('Lvl68');
		levelupAbilities.PushBack('Lvl69');
		levelupAbilities.PushBack('Lvl70');
		levelupAbilities.PushBack('Lvl71');
		levelupAbilities.PushBack('Lvl72');
		levelupAbilities.PushBack('Lvl73');
		levelupAbilities.PushBack('Lvl74');
		levelupAbilities.PushBack('Lvl75');
		levelupAbilities.PushBack('Lvl76');
		levelupAbilities.PushBack('Lvl77');
		levelupAbilities.PushBack('Lvl78');
		levelupAbilities.PushBack('Lvl79');
		levelupAbilities.PushBack('Lvl80');
		levelupAbilities.PushBack('Lvl81');
		levelupAbilities.PushBack('Lvl82');
		levelupAbilities.PushBack('Lvl83');
		levelupAbilities.PushBack('Lvl84');
		levelupAbilities.PushBack('Lvl85');
		levelupAbilities.PushBack('Lvl86');
		levelupAbilities.PushBack('Lvl87');
		levelupAbilities.PushBack('Lvl88');
		levelupAbilities.PushBack('Lvl89');
		levelupAbilities.PushBack('Lvl90');
		levelupAbilities.PushBack('Lvl91');
		levelupAbilities.PushBack('Lvl92');
		levelupAbilities.PushBack('Lvl93');
		levelupAbilities.PushBack('Lvl94');
		levelupAbilities.PushBack('Lvl95');
		levelupAbilities.PushBack('Lvl96');
		levelupAbilities.PushBack('Lvl97');
		levelupAbilities.PushBack('Lvl98');
		levelupAbilities.PushBack('Lvl99');
		levelupAbilities.PushBack('Lvl100');
		
		// Revert ciri locks
		if( inputHandler )
		{
			inputHandler.BlockAllActions( 'being_ciri', false );
		}
		SetBehaviorVariable( 'test_ciri_replacer', 0.0f);
		
		if(!spawnData.restored)
		{
			//toxicity`
			abilityManager.GainStat(BCS_Toxicity, 0);		//to calculate current threshold			
		}		
		
		levelManager.PostInit(this, spawnData.restored);
		
		SetBIsCombatActionAllowed( true );		//PFTODO: should this get called when loading a game?
		SetBIsInputAllowed( true, 'OnSpawned' );				//PFTODO: should this get called when loading a game?
		
		//Reputation
		if ( !reputationManager )
		{
			reputationManager = new W3Reputation in this;
			reputationManager.Initialize();
		}
		
		theSound.SoundParameter( "focus_aim", 1.0f, 1.0f );
		theSound.SoundParameter( "focus_distance", 0.0f, 1.0f );
		
		//unlock skills for testing purposes
		//if(!theGame.IsFinalBuild() && !spawnData.restored )
		//	Debug_EquipTestingSkills(true);
			
		//cast sign
		currentlyCastSign = ST_None;
		
		//horse manager
		if(!spawnData.restored)
		{
			horseTemplate = (CEntityTemplate)LoadResource("horse_manager");
			horseManager = (W3HorseManager)theGame.CreateEntity(horseTemplate, GetWorldPosition(),,,,,PM_Persist);
			horseManager.CreateAttachment(this);
			horseManager.OnCreated();
			EntityHandleSet( horseManagerHandle, horseManager );
		}
		else
		{
			AddTimer('DelayedHorseUpdate', 0.01, true);
		}
		
		// HACK - removing Ciri abilities
		RemoveAbility('Ciri_CombatRegen');
		RemoveAbility('Ciri_Rage');
		RemoveAbility('CiriBlink');
		RemoveAbility('CiriCharge');
		RemoveAbility('Ciri_Q205');
		RemoveAbility('Ciri_Q305');
		RemoveAbility('Ciri_Q403');
		RemoveAbility('Ciri_Q111');
		RemoveAbility('Ciri_Q501');
		RemoveAbility('SkillCiri');
		
		if(spawnData.restored)
		{
			RestoreQuen(savedQuenHealth, savedQuenDuration);			
		}
		else
		{
			savedQuenHealth = 0.f;
			savedQuenDuration = 0.f;
		}
		
		if(spawnData.restored)
			ApplyPatchFixes();
		
		if(!newGamePlusInitialized && FactsQuerySum("NewGamePlus") > 0)
		{
			NewGamePlusInitialize();
		}
		
		if ( FactsQuerySum("NewGamePlus") > 0 )
		{
			NewGamePlusAdjustDLC1TemerianSet(inv);
			NewGamePlusAdjustDLC5NilfgardianSet(inv);
			NewGamePlusAdjustDLC10WolfSet(inv);
			NewGamePlusAdjustDLC14SkelligeSet(inv);
			if(horseManager)
			{
				NewGamePlusAdjustDLC1TemerianSet(horseManager.GetInventoryComponent());
				NewGamePlusAdjustDLC5NilfgardianSet(horseManager.GetInventoryComponent());
				NewGamePlusAdjustDLC10WolfSet(horseManager.GetInventoryComponent());
				NewGamePlusAdjustDLC14SkelligeSet(horseManager.GetInventoryComponent());
			}
		}
		
		//failsafe - sometimes whirl does not end properly and keeps stamina lock, cannot pinpoint why this happens
		ResumeStaminaRegen('WhirlSkill');
		
		if(HasAbility('Runeword 4 _Stats', true))
			StartVitalityRegen();
		
		isInitialized = true;
	}
	
	timer function DelayedHorseUpdate( dt : float, id : int )
	{
		var man : W3HorseManager;
		
		man = GetHorseManager();
		if(man)
		{
			if ( man.ApplyHorseUpdateOnSpawn() )
			{
				RemoveTimer( 'DelayedHorseUpdate' );
			}
		}
	}	
	
	event OnAbilityAdded( abilityName : name)
	{
		super.OnAbilityAdded(abilityName);
		
		if(HasAbility('Runeword 4 _Stats', true))
			StartVitalityRegen();
			
		if ( GetStat(BCS_Focus, true) >= GetStatMax(BCS_Focus) && abilityName == 'Runeword 8 _Stats' && !HasBuff(EET_Runeword8) )
		{
			AddEffectDefault(EET_Runeword8, this, "equipped item");
		}

	}
	
	private final function AddStartingSchematics()
	{
		AddCraftingSchematic('Starting Armor Upgrade schematic 1',	true,true);
		AddCraftingSchematic('Thread schematic',					true, true);
		AddCraftingSchematic('String schematic',					true, true);
		AddCraftingSchematic('Linen schematic',						true, true);
		AddCraftingSchematic('Silk schematic',						true, true);
		AddCraftingSchematic('Resin schematic',						true, true);
		AddCraftingSchematic('Blasting powder schematic',			true, true);
		AddCraftingSchematic('Haft schematic',						true, true);
		AddCraftingSchematic('Hardened timber schematic',			true, true);
		AddCraftingSchematic('Leather squares schematic',			true, true);
		AddCraftingSchematic('Leather schematic',					true, true);
		AddCraftingSchematic('Hardened leather schematic',			true, true);
		AddCraftingSchematic('Draconide leather schematic',			true, true);
		AddCraftingSchematic('Iron ingot schematic',				true, true);
		AddCraftingSchematic('Steel ingot schematic',				true, true);
		AddCraftingSchematic('Steel ingot schematic 1',				true, true);
		AddCraftingSchematic('Steel plate schematic',				true, true);
		AddCraftingSchematic('Dark iron ingot schematic',			true, true);
		AddCraftingSchematic('Dark steel ingot schematic',			true, true);
		AddCraftingSchematic('Dark steel ingot schematic 1',		true, true);
		AddCraftingSchematic('Dark steel plate schematic',			true, true);
		AddCraftingSchematic('Silver ore schematic',				true, true);
		AddCraftingSchematic('Silver ingot schematic',				true, true);
		AddCraftingSchematic('Silver ingot schematic 1',			true, true);
		AddCraftingSchematic('Silver plate schematic',				true, true);
		AddCraftingSchematic('Meteorite ingot schematic',			true, true);
		AddCraftingSchematic('Meteorite silver ingot schematic',	true, true);
		AddCraftingSchematic('Meteorite silver plate schematic',	true, true);
		AddCraftingSchematic('Glowing ingot schematic',				true, true);
		AddCraftingSchematic('Dwimeryte ore schematic',				true, true);
		AddCraftingSchematic('Dwimeryte ingot schematic',			true, true);
		AddCraftingSchematic('Dwimeryte ingot schematic 1',			true, true);
		AddCraftingSchematic('Dwimeryte plate schematic',			true, true);
	}
	
	private final function ApplyPatchFixes()
	{
		var cnt, transmutationCount, mutagenCount, i : int;
		var transmutationAbility : name;
		var pam : W3PlayerAbilityManager;
		var slotId : int;
		var offset : float;
		var buffs : array<CBaseGameplayEffect>;
		var mutagen : W3Mutagen_Effect;
		
		if(FactsQuerySum("ClearingPotionPassiveBonusFix") < 1)
		{
			pam = (W3PlayerAbilityManager)abilityManager;

			cnt = GetAbilityCount('sword_adrenalinegain') - pam.GetPathPointsSpent(ESP_Sword);
			if(cnt > 0)
				RemoveAbilityMultiple('sword_adrenalinegain', cnt);
				
			cnt = GetAbilityCount('magic_staminaregen') - pam.GetPathPointsSpent(ESP_Signs);
			if(cnt > 0)
				RemoveAbilityMultiple('magic_staminaregen', cnt);
				
			cnt = GetAbilityCount('alchemy_potionduration') - pam.GetPathPointsSpent(ESP_Alchemy);
			if(cnt > 0)
				RemoveAbilityMultiple('alchemy_potionduration', cnt);
		
			FactsAdd("ClearingPotionPassiveBonusFix");
		}
				
		//fix for mutagen syngergy bonus (alchemy skill 19) not removed properly when under influence of Dimeritium Bomb
		if(FactsQuerySum("DimeritiumSynergyFix") < 1)
		{
			slotId = GetSkillSlotID(S_Alchemy_s19);
			if(slotId != -1)
				UnequipSkill(S_Alchemy_s19);
				
			RemoveAbilityAll('greater_mutagen_color_green_synergy_bonus');
			RemoveAbilityAll('mutagen_color_green_synergy_bonus');
			RemoveAbilityAll('mutagen_color_lesser_green_synergy_bonus');
			
			RemoveAbilityAll('greater_mutagen_color_blue_synergy_bonus');
			RemoveAbilityAll('mutagen_color_blue_synergy_bonus');
			RemoveAbilityAll('mutagen_color_lesser_blue_synergy_bonus');
			
			RemoveAbilityAll('greater_mutagen_color_red_synergy_bonus');
			RemoveAbilityAll('mutagen_color_red_synergy_bonus');
			RemoveAbilityAll('mutagen_color_lesser_red_synergy_bonus');
			
			if(slotId != -1)
				EquipSkill(S_Alchemy_s19, slotId);
		
			FactsAdd("DimeritiumSynergyFix");
		}
		
		//tutorial for pinning recipes
		if(FactsQuerySum("DontShowRecipePinTut") < 1)
		{
			TutorialScript('alchemyRecipePin', '');
			TutorialScript('craftingRecipePin', '');
		}
		
		//potion reducing level requirement
		if(FactsQuerySum("LevelReqPotGiven") < 1)
		{
			FactsAdd("LevelReqPotGiven");
			inv.AddAnItem('Wolf Hour', 1, false, false, true);
		}
		
		//missing auto stamina regen buff
		if(!HasBuff(EET_AutoStaminaRegen))
		{
			AddEffectDefault(EET_AutoStaminaRegen, this, 'autobuff', false);
		}
		
		//wrongly implemented Transmutation skill AND
		//remaining offset toxicity after abilityManager object get corrupted and deleted
		buffs = GetBuffs();
		offset = 0;
		mutagenCount = 0;
		for(i=0; i<buffs.Size(); i+=1)
		{
			mutagen = (W3Mutagen_Effect)buffs[i];
			if(mutagen)
			{
				offset += mutagen.GetToxicityOffset();
				mutagenCount += 1;
			}
		}
		
		//fix offset
		if(offset != (GetStat(BCS_Toxicity) - GetStat(BCS_Toxicity, true)))
			SetToxicityOffset(offset);
			
		//fix Transmutation
		mutagenCount *= GetSkillLevel(S_Alchemy_s13);
		transmutationAbility = GetSkillAbilityName(S_Alchemy_s13);
		transmutationCount = GetAbilityCount(transmutationAbility);
		if(mutagenCount < transmutationCount)
		{
			RemoveAbilityMultiple(transmutationAbility, transmutationCount - mutagenCount);
		}
		else if(mutagenCount > transmutationCount)
		{
			AddAbilityMultiple(transmutationAbility, mutagenCount - transmutationCount);
		}
		
		//enchanting glossary tutorial
		if(theGame.GetDLCManager().IsEP1Available())
		{
			theGame.GetJournalManager().ActivateEntryByScriptTag('TutorialJournalEnchanting', JS_Active);
		}
	}
	
	public final function RestoreQuen(quenHealth : float, quenDuration : float) : bool
	{
		var restoredQuen 	: W3QuenEntity;
		
		if(quenHealth > 0.f && quenDuration >= 3.f)
		{
			restoredQuen = (W3QuenEntity)theGame.CreateEntity( signs[ST_Quen].template, GetWorldPosition(), GetWorldRotation() );
			restoredQuen.Init( signOwner, signs[ST_Quen].entity, true );
			restoredQuen.OnStarted();
			restoredQuen.OnThrowing();
			restoredQuen.OnEnded();
			restoredQuen.SetDataFromRestore(quenHealth, quenDuration);
			
			return true;
		}
		
		return false;
	}
	
	public function IsInitialized() : bool
	{
		return isInitialized;
	}
	
	private final function NewGamePlusInitialize()
	{
		var questItems : array<name>;
		var horseManager : W3HorseManager;
		var horseInventory : CInventoryComponent;
		var i, missingLevels, expDiff : int;
		
		//get horse inventory - that's where the stash is
		horseManager = (W3HorseManager)EntityHandleGet(horseManagerHandle);
		if(horseManager)
			horseInventory = horseManager.GetInventoryComponent();
		
		//set NG+ level to player level + few
		theGame.params.SetNewGamePlusLevel(GetLevel());
		
		//increase player level if below 30		
		if (theGame.GetDLCManager().IsDLCAvailable('ep1'))
			missingLevels = theGame.params.NEW_GAME_PLUS_EP1_MIN_LEVEL - GetLevel();
		else
			missingLevels = theGame.params.NEW_GAME_PLUS_MIN_LEVEL - GetLevel();
			
		for(i=0; i<missingLevels; i+=1)
		{
			//M.J. Divide XP by 2 since AddPoints() will multiply it by 2 as we are in NG+ mode.
			expDiff = levelManager.GetTotalExpForNextLevel() - levelManager.GetPointsTotal(EExperiencePoint);
			expDiff = CeilF( ((float)expDiff) / 2 );
			AddPoints(EExperiencePoint, expDiff, false);
		}
		
		//-- remove all quest items 1) and 2)
		
		//1) some non-quest items might dynamically have 'Quest' tag added so first we remove all items that 
		//currently have Quest tag
		inv.RemoveItemByTag('Quest', -1);
		horseInventory.RemoveItemByTag('Quest', -1);

		//2) some quest items might lose 'Quest' tag during the course of the game so we need to check their 
		//XML definitions rather than actual items in inventory
		questItems = theGame.GetDefinitionsManager().GetItemsWithTag('Quest');
		for(i=0; i<questItems.Size(); i+=1)
		{
			inv.RemoveItemByName(questItems[i], -1);
			horseInventory.RemoveItemByName(questItems[i], -1);
		}
		
		//3) some quest items don't have 'Quest' tag at all
		inv.RemoveItemByName('mq1002_artifact_3', -1);
		horseInventory.RemoveItemByName('mq1002_artifact_3', -1);
		
		//4) some quest items are regular items but become quest items at some point - Quests will mark them with proper tag
		inv.RemoveItemByTag('NotTransferableToNGP', -1);
		horseInventory.RemoveItemByTag('NotTransferableToNGP', -1);
		
		//remove notice board notices - they are not quest items
		inv.RemoveItemByTag('NoticeBoardNote', -1);
		horseInventory.RemoveItemByTag('NoticeBoardNote', -1);
		
		//remove active buffs
		RemoveAllNonAutoBuffs();
		
		//remove quest alchemy recipes
		RemoveAlchemyRecipe('Recipe for Trial Potion Kit');
		RemoveAlchemyRecipe('Recipe for Pops Antidote');
		RemoveAlchemyRecipe('Recipe for Czart Lure');
		RemoveAlchemyRecipe('q603_diarrhea_potion_recipe');
		
		//remove trophies
		inv.RemoveItemByTag('Trophy', -1);
		horseInventory.RemoveItemByTag('Trophy', -1);
		
		//remove usable items
		inv.RemoveItemByCategory('usable', -1);
		horseInventory.RemoveItemByCategory('usable', -1);
		
		//remove quest abilities
		RemoveAbility('StaminaTutorialProlog');
    	RemoveAbility('TutorialStaminaRegenHack');
    	RemoveAbility('area_novigrad');
    	RemoveAbility('NoRegenEffect');
    	RemoveAbility('HeavySwimmingStaminaDrain');
    	RemoveAbility('AirBoost');
    	RemoveAbility('area_nml');
    	RemoveAbility('area_skellige');
    	
    	//remove Gwent cards
    	inv.RemoveItemByTag('GwintCard', -1);
    	horseInventory.RemoveItemByTag('GwintCard', -1);
    	    	
    	
    	//remove readable items (maps, lore books etc - decision was to remove all)
    	inv.RemoveItemByTag('ReadableItem', -1);
    	horseInventory.RemoveItemByTag('ReadableItem', -1);
    	
    	//restore stats
    	abilityManager.RestoreStats();
    	
    	//unblock toxicity threshold
    	((W3PlayerAbilityManager)abilityManager).RemoveToxicityOffset(10000);
    	
    	//replenish alchemy items
    	GetInventory().SingletonItemsRefillAmmo();
    	
    	//remove crafting recipes
    	craftingSchematics.Clear();
    	AddStartingSchematics();

    	//add clearing potion
    	inv.AddAnItem('Clearing Potion', 1, true, false, false);
    	
    	//broken Ouroboros Mask
    	inv.RemoveItemByName('q203_broken_eyeofloki', -1);
    	horseInventory.RemoveItemByName('q203_broken_eyeofloki', -1);
    	//replace NG+ Witcher items with "base" variants
    	NewGamePlusReplaceViperSet(inv);
    	NewGamePlusReplaceViperSet(horseInventory);
    	NewGamePlusReplaceLynxSet(inv);
    	NewGamePlusReplaceLynxSet(horseInventory);
    	NewGamePlusReplaceGryphonSet(inv);
    	NewGamePlusReplaceGryphonSet(horseInventory);
    	NewGamePlusReplaceBearSet(inv);
    	NewGamePlusReplaceBearSet(horseInventory);
    	NewGamePlusReplaceEP1(inv);
    	NewGamePlusReplaceEP1(horseInventory);
    	
    	//remove action locks from previous playthrough
    	inputHandler.ClearLocksForNGP();
    	
    	//remove buff immunities & removed immunities from previous playthrough
    	buffImmunities.Clear();
    	buffRemovedImmunities.Clear();
    	
    	newGamePlusInitialized = true;
	}
		
	private final function NewGamePlusReplaceItem( item : name, new_item : name, out inv : CInventoryComponent)
	{
		var i, j 					: int;
		var ids, new_ids, enh_ids 	: array<SItemUniqueId>;
		var enh					 	: array<name>;
		var wasEquipped 			: bool;
		var wasEnchanted 			: bool;
		var enchantName				: name;
		
		if ( inv.HasItem( item ) )
		{
			ids = inv.GetItemsIds(item);
			for (i = 0; i < ids.Size(); i += 1)
			{
				inv.GetItemEnhancementItems(ids[i], enh);
				wasEnchanted = inv.IsItemEnchanted(ids[i]);
				if ( wasEnchanted ) 
					enchantName = inv.GetEnchantment(ids[i]);
				wasEquipped = IsItemEquipped( ids[i] );
				inv.RemoveItem(ids[i], 1);
				new_ids = inv.AddAnItem(new_item, 1, true, true, false);
				if ( wasEquipped )
				{
					EquipItem( new_ids[0] );
				}
				if ( wasEnchanted )
				{
					inv.EnchantItem(new_ids[0], enchantName, getEnchamtmentStatName(enchantName));
				}
				for (j = 0; j < enh.Size(); j += 1)
				{
					enh_ids = inv.AddAnItem(enh[j], 1, true, true, false);
					inv.EnhanceItemScript(new_ids[0], enh_ids[0]);
				}
			}
		}
	}
	
	private final function NewGamePlusAdjustDLCItem(item : name, mod : name, inv : CInventoryComponent)
	{
		var ids		: array<SItemUniqueId>;
		var i 		: int;
		
		if( inv.HasItem(item) )
		{
			ids = inv.GetItemsIds(item);
			for (i = 0; i < ids.Size(); i += 1)
			{
				if ( inv.GetItemModifierInt(ids[i], 'DoNotAdjustNGPDLC') <= 0 )
				{
					inv.AddItemBaseAbility(ids[i], mod);
					inv.SetItemModifierInt(ids[i], 'DoNotAdjustNGPDLC', 1);	
				}
			}
		}
		
	}
	
	private final function NewGamePlusAdjustDLC1TemerianSet(inv : CInventoryComponent) 
	{
		NewGamePlusAdjustDLCItem('NGP DLC1 Temerian Armor', 'NGP DLC Compatibility Chest Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP DLC1 Temerian Gloves', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP DLC1 Temerian Pants', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP DLC1 Temerian Boots', 'NGP DLC Compatibility Armor Mod', inv);
	}
	
	private final function NewGamePlusAdjustDLC5NilfgardianSet(inv : CInventoryComponent) 
	{
		NewGamePlusAdjustDLCItem('NGP DLC5 Nilfgaardian Armor', 'NGP DLC Compatibility Chest Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP DLC5 Nilfgaardian Gloves', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP DLC5 Nilfgaardian Pants', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP DLC5 Nilfgaardian Boots', 'NGP DLC Compatibility Armor Mod', inv);
	}
	
	private final function NewGamePlusAdjustDLC10WolfSet(inv : CInventoryComponent) 
	{
		NewGamePlusAdjustDLCItem('NGP Wolf Armor',   'NGP DLC Compatibility Chest Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Armor 1', 'NGP DLC Compatibility Chest Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Armor 2', 'NGP DLC Compatibility Chest Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Armor 3', 'NGP DLC Compatibility Chest Armor Mod', inv);
		
		NewGamePlusAdjustDLCItem('NGP Wolf Boots 1', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Boots 2', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Boots 3', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Boots 4', 'NGP DLC Compatibility Armor Mod', inv);
		
		NewGamePlusAdjustDLCItem('NGP Wolf Gloves 1', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Gloves 2', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Gloves 3', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Gloves 4', 'NGP DLC Compatibility Armor Mod', inv);
		
		NewGamePlusAdjustDLCItem('NGP Wolf Pants 1', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Pants 2', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Pants 3', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf Pants 4', 'NGP DLC Compatibility Armor Mod', inv);
		
		NewGamePlusAdjustDLCItem('NGP Wolf School steel sword',   'NGP Wolf Steel Sword Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf School steel sword 1', 'NGP Wolf Steel Sword Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf School steel sword 2', 'NGP Wolf Steel Sword Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf School steel sword 3', 'NGP Wolf Steel Sword Mod', inv);
		
		NewGamePlusAdjustDLCItem('NGP Wolf School silver sword',   'NGP Wolf Silver Sword Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf School silver sword 1', 'NGP Wolf Silver Sword Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf School silver sword 2', 'NGP Wolf Silver Sword Mod', inv);
		NewGamePlusAdjustDLCItem('NGP Wolf School silver sword 3', 'NGP Wolf Silver Sword Mod', inv);
	}
	
	private final function NewGamePlusAdjustDLC14SkelligeSet(inv : CInventoryComponent) 
	{
		NewGamePlusAdjustDLCItem('NGP DLC14 Skellige Armor', 'NGP DLC Compatibility Chest Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP DLC14 Skellige Gloves', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP DLC14 Skellige Pants', 'NGP DLC Compatibility Armor Mod', inv);
		NewGamePlusAdjustDLCItem('NGP DLC14 Skellige Boots', 'NGP DLC Compatibility Armor Mod', inv);
	}
	
	private final function NewGamePlusReplaceViperSet(out inv : CInventoryComponent)
	{
		NewGamePlusReplaceItem('Viper School steel sword', 'NGP Viper School steel sword', inv);
		
		NewGamePlusReplaceItem('Viper School silver sword', 'NGP Viper School silver sword', inv);
	}
	
	private final function NewGamePlusReplaceLynxSet(out inv : CInventoryComponent)
	{
		NewGamePlusReplaceItem('Lynx Armor', 'NGP Lynx Armor', inv);
		NewGamePlusReplaceItem('Lynx Armor 1', 'NGP Lynx Armor 1', inv);
		NewGamePlusReplaceItem('Lynx Armor 2', 'NGP Lynx Armor 2', inv);
		NewGamePlusReplaceItem('Lynx Armor 3', 'NGP Lynx Armor 3', inv);
		
		NewGamePlusReplaceItem('Lynx Gloves 1', 'NGP Lynx Gloves 1', inv);
		NewGamePlusReplaceItem('Lynx Gloves 2', 'NGP Lynx Gloves 2', inv);
		NewGamePlusReplaceItem('Lynx Gloves 3', 'NGP Lynx Gloves 3', inv);
		NewGamePlusReplaceItem('Lynx Gloves 4', 'NGP Lynx Gloves 4', inv);
		
		NewGamePlusReplaceItem('Lynx Pants 1', 'NGP Lynx Pants 1', inv);
		NewGamePlusReplaceItem('Lynx Pants 2', 'NGP Lynx Pants 2', inv);
		NewGamePlusReplaceItem('Lynx Pants 3', 'NGP Lynx Pants 3', inv);
		NewGamePlusReplaceItem('Lynx Pants 4', 'NGP Lynx Pants 4', inv);
		
		NewGamePlusReplaceItem('Lynx Boots 1', 'NGP Lynx Boots 1', inv);
		NewGamePlusReplaceItem('Lynx Boots 2', 'NGP Lynx Boots 2', inv);
		NewGamePlusReplaceItem('Lynx Boots 3', 'NGP Lynx Boots 3', inv);
		NewGamePlusReplaceItem('Lynx Boots 4', 'NGP Lynx Boots 4', inv);
		
		NewGamePlusReplaceItem('Lynx School steel sword', 'NGP Lynx School steel sword', inv);
		NewGamePlusReplaceItem('Lynx School steel sword 1', 'NGP Lynx School steel sword 1', inv);
		NewGamePlusReplaceItem('Lynx School steel sword 2', 'NGP Lynx School steel sword 2', inv);
		NewGamePlusReplaceItem('Lynx School steel sword 3', 'NGP Lynx School steel sword 3', inv);
		
		NewGamePlusReplaceItem('Lynx School silver sword', 'NGP Lynx School silver sword', inv);
		NewGamePlusReplaceItem('Lynx School silver sword 1', 'NGP Lynx School silver sword 1', inv);
		NewGamePlusReplaceItem('Lynx School silver sword 2', 'NGP Lynx School silver sword 2', inv);
		NewGamePlusReplaceItem('Lynx School silver sword 3', 'NGP Lynx School silver sword 3', inv);
	}
	
	private final function NewGamePlusReplaceGryphonSet(out inv : CInventoryComponent)
	{
		NewGamePlusReplaceItem('Gryphon Armor', 'NGP Gryphon Armor', inv);
		NewGamePlusReplaceItem('Gryphon Armor 1', 'NGP Gryphon Armor 1', inv);
		NewGamePlusReplaceItem('Gryphon Armor 2', 'NGP Gryphon Armor 2', inv);
		NewGamePlusReplaceItem('Gryphon Armor 3', 'NGP Gryphon Armor 3', inv);
		
		NewGamePlusReplaceItem('Gryphon Gloves 1', 'NGP Gryphon Gloves 1', inv);
		NewGamePlusReplaceItem('Gryphon Gloves 2', 'NGP Gryphon Gloves 2', inv);
		NewGamePlusReplaceItem('Gryphon Gloves 3', 'NGP Gryphon Gloves 3', inv);
		NewGamePlusReplaceItem('Gryphon Gloves 4', 'NGP Gryphon Gloves 4', inv);
		
		NewGamePlusReplaceItem('Gryphon Pants 1', 'NGP Gryphon Pants 1', inv);
		NewGamePlusReplaceItem('Gryphon Pants 2', 'NGP Gryphon Pants 2', inv);
		NewGamePlusReplaceItem('Gryphon Pants 3', 'NGP Gryphon Pants 3', inv);
		NewGamePlusReplaceItem('Gryphon Pants 4', 'NGP Gryphon Pants 4', inv);
		
		NewGamePlusReplaceItem('Gryphon Boots 1', 'NGP Gryphon Boots 1', inv);
		NewGamePlusReplaceItem('Gryphon Boots 2', 'NGP Gryphon Boots 2', inv);
		NewGamePlusReplaceItem('Gryphon Boots 3', 'NGP Gryphon Boots 3', inv);
		NewGamePlusReplaceItem('Gryphon Boots 4', 'NGP Gryphon Boots 4', inv);
		
		NewGamePlusReplaceItem('Gryphon School steel sword', 'NGP Gryphon School steel sword', inv);
		NewGamePlusReplaceItem('Gryphon School steel sword 1', 'NGP Gryphon School steel sword 1', inv);
		NewGamePlusReplaceItem('Gryphon School steel sword 2', 'NGP Gryphon School steel sword 2', inv);
		NewGamePlusReplaceItem('Gryphon School steel sword 3', 'NGP Gryphon School steel sword 3', inv);
		
		NewGamePlusReplaceItem('Gryphon School silver sword', 'NGP Gryphon School silver sword', inv);
		NewGamePlusReplaceItem('Gryphon School silver sword 1', 'NGP Gryphon School silver sword 1', inv);
		NewGamePlusReplaceItem('Gryphon School silver sword 2', 'NGP Gryphon School silver sword 2', inv);
		NewGamePlusReplaceItem('Gryphon School silver sword 3', 'NGP Gryphon School silver sword 3', inv);
	}
	
	private final function NewGamePlusReplaceBearSet(out inv : CInventoryComponent)
	{
		NewGamePlusReplaceItem('Bear Armor', 'NGP Bear Armor', inv);
		NewGamePlusReplaceItem('Bear Armor 1', 'NGP Bear Armor 1', inv);
		NewGamePlusReplaceItem('Bear Armor 2', 'NGP Bear Armor 2', inv);
		NewGamePlusReplaceItem('Bear Armor 3', 'NGP Bear Armor 3', inv);
		
		NewGamePlusReplaceItem('Bear Gloves 1', 'NGP Bear Gloves 1', inv);
		NewGamePlusReplaceItem('Bear Gloves 2', 'NGP Bear Gloves 2', inv);
		NewGamePlusReplaceItem('Bear Gloves 3', 'NGP Bear Gloves 3', inv);
		NewGamePlusReplaceItem('Bear Gloves 4', 'NGP Bear Gloves 4', inv);
		
		NewGamePlusReplaceItem('Bear Pants 1', 'NGP Bear Pants 1', inv);
		NewGamePlusReplaceItem('Bear Pants 2', 'NGP Bear Pants 2', inv);
		NewGamePlusReplaceItem('Bear Pants 3', 'NGP Bear Pants 3', inv);
		NewGamePlusReplaceItem('Bear Pants 4', 'NGP Bear Pants 4', inv);
		
		NewGamePlusReplaceItem('Bear Boots 1', 'NGP Bear Boots 1', inv);
		NewGamePlusReplaceItem('Bear Boots 2', 'NGP Bear Boots 2', inv);
		NewGamePlusReplaceItem('Bear Boots 3', 'NGP Bear Boots 3', inv);
		NewGamePlusReplaceItem('Bear Boots 4', 'NGP Bear Boots 4', inv);
		
		NewGamePlusReplaceItem('Bear School steel sword', 'NGP Bear School steel sword', inv);
		NewGamePlusReplaceItem('Bear School steel sword 1', 'NGP Bear School steel sword 1', inv);
		NewGamePlusReplaceItem('Bear School steel sword 2', 'NGP Bear School steel sword 2', inv);
		NewGamePlusReplaceItem('Bear School steel sword 3', 'NGP Bear School steel sword 3', inv);
		
		NewGamePlusReplaceItem('Bear School silver sword', 'NGP Bear School silver sword', inv);
		NewGamePlusReplaceItem('Bear School silver sword 1', 'NGP Bear School silver sword 1', inv);
		NewGamePlusReplaceItem('Bear School silver sword 2', 'NGP Bear School silver sword 2', inv);
		NewGamePlusReplaceItem('Bear School silver sword 3', 'NGP Bear School silver sword 3', inv);
	}
		
	private final function NewGamePlusReplaceEP1(out inv : CInventoryComponent)
	{	
		NewGamePlusReplaceItem('Ofir Armor', 'NGP Ofir Armor', inv);
		NewGamePlusReplaceItem('Ofir Sabre 2', 'NGP Ofir Sabre 2', inv);
		
		NewGamePlusReplaceItem('Crafted Burning Rose Armor', 'NGP Crafted Burning Rose Armor', inv);
		NewGamePlusReplaceItem('Crafted Burning Rose Gloves', 'NGP Crafted Burning Rose Gloves', inv);
		NewGamePlusReplaceItem('Crafted Burning Rose Sword', 'NGP Crafted Burning Rose Sword', inv);
		
		NewGamePlusReplaceItem('Crafted Ofir Armor', 'NGP Crafted Ofir Armor', inv);
		NewGamePlusReplaceItem('Crafted Ofir Boots', 'NGP Crafted Ofir Boots', inv);
		NewGamePlusReplaceItem('Crafted Ofir Gloves', 'NGP Crafted Ofir Gloves', inv);
		NewGamePlusReplaceItem('Crafted Ofir Pants', 'NGP Crafted Ofir Pants', inv);
		NewGamePlusReplaceItem('Crafted Ofir Steel Sword', 'NGP Crafted Ofir Steel Sword', inv);
		
		NewGamePlusReplaceItem('EP1 Crafted Witcher Silver Sword', 'NGP EP1 Crafted Witcher Silver Sword', inv);
		NewGamePlusReplaceItem('Olgierd Sabre', 'NGP Olgierd Sabre', inv);
		
		NewGamePlusReplaceItem('EP1 Witcher Armor', 'NGP EP1 Witcher Armor', inv);
		NewGamePlusReplaceItem('EP1 Witcher Boots', 'NGP EP1 Witcher Boots', inv);
		NewGamePlusReplaceItem('EP1 Witcher Gloves', 'NGP EP1 Witcher Gloves', inv);
		NewGamePlusReplaceItem('EP1 Witcher Pants', 'NGP EP1 Witcher Pants', inv);
		NewGamePlusReplaceItem('EP1 Viper School steel sword', 'NGP EP1 Viper School steel sword', inv);
		NewGamePlusReplaceItem('EP1 Viper School silver sword', 'NGP EP1 Viper School silver sword', inv);
	}
	
	timer function BroadcastRain( deltaTime : float, id : int )
	{
		var rainStrength : float = 0;
		rainStrength = GetRainStrength();
		if( rainStrength > 0.5 )
		{
			theGame.GetBehTreeReactionManager().CreateReactionEventIfPossible( thePlayer, 'RainAction', 2.0f , 50.0f, -1.f, -1, true); //reactionSystemOld
			LogReactionSystem( "'RainAction' was sent by Player - single broadcast - distance: 50.0" ); 
		}
	}
	
	function InitializeParryType()
	{
		var i, j : int;
		
		parryTypeTable.Resize( EnumGetMax('EAttackSwingType')+1 );
		for( i = 0; i < EnumGetMax('EAttackSwingType')+1; i += 1 )
		{
			parryTypeTable[i].Resize( EnumGetMax('EAttackSwingDirection')+1 );
		}
		parryTypeTable[AST_Horizontal][ASD_UpDown] = PT_None;
		parryTypeTable[AST_Horizontal][ASD_DownUp] = PT_None;
		parryTypeTable[AST_Horizontal][ASD_LeftRight] = PT_Left;
		parryTypeTable[AST_Horizontal][ASD_RightLeft] = PT_Right;
		parryTypeTable[AST_Vertical][ASD_UpDown] = PT_Up;
		parryTypeTable[AST_Vertical][ASD_DownUp] = PT_Down;
		parryTypeTable[AST_Vertical][ASD_LeftRight] = PT_None;
		parryTypeTable[AST_Vertical][ASD_RightLeft] = PT_None;
		parryTypeTable[AST_DiagonalUp][ASD_UpDown] = PT_None;
		parryTypeTable[AST_DiagonalUp][ASD_DownUp] = PT_None;
		parryTypeTable[AST_DiagonalUp][ASD_LeftRight] = PT_UpLeft;
		parryTypeTable[AST_DiagonalUp][ASD_RightLeft] = PT_RightUp;
		parryTypeTable[AST_DiagonalDown][ASD_UpDown] = PT_None;
		parryTypeTable[AST_DiagonalDown][ASD_DownUp] = PT_None;
		parryTypeTable[AST_DiagonalDown][ASD_LeftRight] = PT_LeftDown;
		parryTypeTable[AST_DiagonalDown][ASD_RightLeft] = PT_DownRight;
		parryTypeTable[AST_Jab][ASD_UpDown] = PT_Jab;
		parryTypeTable[AST_Jab][ASD_DownUp] = PT_Jab;
		parryTypeTable[AST_Jab][ASD_LeftRight] = PT_Jab;
		parryTypeTable[AST_Jab][ASD_RightLeft] = PT_Jab;	
	}
	
	////////////////////////////////////////////////////////////////////////////////
	//
	// DEATH
	//
	////////////////////////////////////////////////////////////////////////////////
	event OnDeath( damageAction : W3DamageAction )
	{
		var items 		: array< SItemUniqueId >;
		var i, size 	: int;	
		var slot		: EEquipmentSlots;
		var holdSlot	: name;
	
		super.OnDeath( damageAction );
	
		items = GetHeldItems();
				
		if( rangedWeapon && rangedWeapon.GetCurrentStateName() != 'State_WeaponWait')
		{
			OnRangedForceHolster( true, true, true );		
			rangedWeapon.ClearDeployedEntity(true);
		}
		
		size = items.Size();
		
		if ( size > 0 )
		{
			for ( i = 0; i < size; i += 1 )
			{
				if ( this.inv.IsIdValid( items[i] ) && !( this.inv.IsItemCrossbow( items[i] ) ) )
				{
					holdSlot = this.inv.GetItemHoldSlot( items[i] );				
				
					if (  holdSlot == 'l_weapon' && this.IsHoldingItemInLHand() )
					{
						this.OnUseSelectedItem( true );
					}			
			
					DropItemFromSlot( holdSlot, false );
					
					if ( holdSlot == 'r_weapon' )
					{
						slot = this.GetItemSlot( items[i] );
						if ( UnequipItemFromSlot( slot ) )
							Log( "Unequip" );
					}
				}
			}
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	// Input Section
	//
	//////////////////////////////////////////////////////////////////////////////////////////
	
	function HandleMovement( deltaTime : float )
	{
		super.HandleMovement( deltaTime );
		
		rawCameraHeading = theCamera.GetCameraHeading();
	}
		
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	// SETTERS & GETTERS
	//
	//////////////////////////////////////////////////////////////////////////////////////////
	
	function ToggleSpecialAttackHeavyAllowed( toggle : bool)
	{
		specialAttackHeavyAllowed = toggle;
	}
	
	function GetReputationManager() : W3Reputation
	{
		return reputationManager;
	}
			
	function OnRadialMenuItemChoose( selectedItem : string ) //#B
	{
		var iSlotId : int;
		
		if ( selectedItem != "Slot3" )
		{
			if ( rangedWeapon && rangedWeapon.GetCurrentStateName() != 'State_WeaponWait' )
				OnRangedForceHolster( true, false );
		}
		
		
		switch(selectedItem)
		{
			/*case "Silver":
				if(IsItemEquippedByCategoryName('silversword'))
				{
					OnEquipMeleeWeapon( PW_Silver, false, true );
				}
				break;
			case "Steel":
				if(IsItemEquippedByCategoryName('steelsword'))
				{
					OnEquipMeleeWeapon( PW_Steel, false, true );
				}
				break;	*/
			case "Meditation":
				theGame.RequestMenuWithBackground( 'MeditationClockMenu', 'CommonMenu' );
				break;			
			case "Slot1":
				SelectQuickslotItem(EES_Petard1);
				break;			
			case "Slot2":
				SelectQuickslotItem(EES_Petard2);
				break;			
			case "Slot3":
				SelectQuickslotItem(EES_RangedWeapon);
				break;
			case "Slot4":
				SelectQuickslotItem(EES_Quickslot1); 
				break;
			case "Slot5": 
				SelectQuickslotItem(EES_Quickslot2);
				break;
			default:
				SetEquippedSign(SignStringToEnum( selectedItem ));
				FactsRemove("SignToggled");
				break;
		}
	}
	
	function ToggleNextItem()
	{
		var quickSlotItems : array< EEquipmentSlots >;
		var currentSelectedItem : SItemUniqueId;
		var item : SItemUniqueId;
		var i : int;
		
		for( i = EES_Quickslot2; i > EES_Petard1 - 1; i -= 1 )
		{
			GetItemEquippedOnSlot( i, item );
			if( inv.IsIdValid( item ) )
			{
				quickSlotItems.PushBack( i );
			}
		}
		if( !quickSlotItems.Size() )
		{
			return;
		}
		
		currentSelectedItem = GetSelectedItemId();
		
		if( inv.IsIdValid( currentSelectedItem ) )
		{
			for( i = 0; i < quickSlotItems.Size(); i += 1 )
			{
				GetItemEquippedOnSlot( quickSlotItems[i], item );
				if( currentSelectedItem == item )
				{
					if( i == quickSlotItems.Size() - 1 )
					{
						SelectQuickslotItem( quickSlotItems[ 0 ] );
					}
					else
					{
						SelectQuickslotItem( quickSlotItems[ i + 1 ] );
					}
					return;
				}
			}
		}
		else // just pick first valid
		{
			SelectQuickslotItem( quickSlotItems[ 0 ] );
		}
	}
		
	// SIGNS
	function SetEquippedSign( signType : ESignType )
	{
		if(!IsSignBlocked(signType))
		{
			equippedSign = signType;
			FactsSet("CurrentlySelectedSign", equippedSign);
		}
	}
	
	function GetEquippedSign() : ESignType
	{
		return equippedSign;
	}
	
	function GetCurrentlyCastSign() : ESignType
	{
		return currentlyCastSign;
	}
	
	function SetCurrentlyCastSign( type : ESignType, entity : W3SignEntity )
	{
		currentlyCastSign = type;
		
		if( type != ST_None )
		{
			signs[currentlyCastSign].entity = entity;
		}
	}
	
	function GetCurrentSignEntity() : W3SignEntity
	{
		if(currentlyCastSign == ST_None)
			return NULL;
			
		return signs[currentlyCastSign].entity;
	}
	
	public function GetSignEntity(type : ESignType) : W3SignEntity
	{
		if(type == ST_None)
			return NULL;
			
		return signs[type].entity;
	}
	
	public function GetSignTemplate(type : ESignType) : CEntityTemplate
	{
		if(type == ST_None)
			return NULL;
			
		return signs[type].template;
	}
	
	public function IsCurrentSignChanneled() : bool
	{
		if( currentlyCastSign != ST_None && signs[currentlyCastSign].entity)
			return signs[currentlyCastSign].entity.OnCheckChanneling();
		
		return false;
	}
	
	function IsCastingSign() : bool
	{
		return currentlyCastSign != ST_None;
	}
	
	// Called from code
	protected function IsInCombatActionCameraRotationEnabled() : bool
	{
		if( IsInCombatAction() && ( GetCombatAction() == EBAT_EMPTY || GetCombatAction() == EBAT_Parry ) )
		{
			return true;
		}
		
		return !bIsInCombatAction;
	}
	
	function SetHoldBeforeOpenRadialMenuTime ( time : float )
	{
		_HoldBeforeOpenRadialMenuTime = time;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	// @Repair Kits
	//
	//////////////////////////////////////////////////////////////////////////////////////////
	
	public function RepairItem (  rapairKitId : SItemUniqueId, usedOnItem : SItemUniqueId )
	{
		var itemMaxDurablity 		: float;
		var itemCurrDurablity 		: float;
		var baseRepairValue		  	: float;
		var reapirValue				: float;
		var itemAttribute			: SAbilityAttributeValue;
		
		itemMaxDurablity = inv.GetItemMaxDurability(usedOnItem);
		itemCurrDurablity = inv.GetItemDurability(usedOnItem);
		itemAttribute = inv.GetItemAttributeValue ( rapairKitId, 'repairValue' );
		
		if ( inv.IsItemAnyArmor ( usedOnItem )|| inv.IsItemWeapon( usedOnItem ) )
		{			
			
			baseRepairValue = itemMaxDurablity * itemAttribute.valueMultiplicative;					
			reapirValue = MinF( itemCurrDurablity + baseRepairValue, itemMaxDurablity );
			
			inv.SetItemDurabilityScript ( usedOnItem, MinF ( reapirValue, itemMaxDurablity ));
		}
		
		inv.RemoveItem ( rapairKitId, 1 );
		
	}
	public function HasRepairAbleGearEquiped ( ) : bool
	{
		var curEquipedItem : SItemUniqueId;
		
		return ( GetItemEquippedOnSlot(EES_Armor, curEquipedItem) || GetItemEquippedOnSlot(EES_Boots, curEquipedItem) || GetItemEquippedOnSlot(EES_Pants, curEquipedItem) || GetItemEquippedOnSlot(EES_Gloves, curEquipedItem)) == true;
	}
	public function HasRepairAbleWaponEquiped () : bool
	{
		var curEquipedItem : SItemUniqueId;
		
		return ( GetItemEquippedOnSlot(EES_SilverSword, curEquipedItem) || GetItemEquippedOnSlot(EES_SteelSword, curEquipedItem) ) == true;
	}
	public function IsItemRepairAble ( item : SItemUniqueId ) : bool
	{
		return inv.GetItemDurabilityRatio(item) <= 0.99999f;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	// @Oils
	//
	//////////////////////////////////////////////////////////////////////////////////////////
		
	//Returns oil item name (oil item can no longer exist in inventory) of oil applied to given sword (Steel if steel==true, Silver otherwise)
	public function GetOilAppliedOnSword(steel : bool) : name
	{
		var hasItem : bool;
		var sword   : SItemUniqueId;
		
		if(steel)
			hasItem = GetItemEquippedOnSlot(EES_SteelSword, sword);
		else
			hasItem = GetItemEquippedOnSlot(EES_SilverSword, sword);
			
		if(!hasItem)
			return '';	//no sword
		
		return inv.GetSwordOil(sword);
	}
	
	// Returns true if given sword type is upgraded with given oil
	public function IsEquippedSwordUpgradedWithOil(steel : bool, optional oilName : name) : bool
	{
		var sword : SItemUniqueId;
		var i, minAbs, maxAbs : int;
		var hasItem : bool;
		var abilities, swordAbilities : array<name>;
		var dm : CDefinitionsManagerAccessor;
		var weights : array<float>;
	
		if(steel)
			hasItem = GetItemEquippedOnSlot(EES_SteelSword, sword);
		else
			hasItem = GetItemEquippedOnSlot(EES_SilverSword, sword);
				
		if(hasItem)	
		{
			inv.GetItemAbilities(sword, swordAbilities);
			dm = theGame.GetDefinitionsManager();
			
			if(IsNameValid(oilName))
			{				
				dm.GetItemAbilitiesWithWeights(oilName, true, abilities, weights, minAbs, maxAbs);
								
				for(i=0; i<abilities.Size(); i+=1)
				{
					if(dm.AbilityHasTag(abilities[i], theGame.params.OIL_ABILITY_TAG))
					{
						if(swordAbilities.Contains(abilities[i]))
						{
							//there is an oil ability with oil tag that the sword has - that's enough
							return true;
						}					
					}
				}
			}
			else
			{
				//checking for any oil
				for(i=0; i<swordAbilities.Size(); i+=1)
				{
					if(dm.AbilityHasTag(swordAbilities[i], theGame.params.OIL_ABILITY_TAG))
						return true;
				}
			}
		}
		
		//if here then there is no oil ability from given oil on the sword
		return false;
	}
	
	//applies oil on given player item - adds oil bonus ability to item abilities
	public function ApplyOil( oilId : SItemUniqueId, usedOnItem : SItemUniqueId )
	{
		var oilAbilities : array<name>;
		var i : int;
		var ammo, ammoBonus : float;
		var dm : CDefinitionsManagerAccessor;
		var swordEquipped : bool;
		var tutStateOil : W3TutorialManagerUIHandlerStateOils;
		var sword : CWitcherSword;
				
		if(!CanApplyOilOnItem(oilId, usedOnItem))
			return;
				
		dm = theGame.GetDefinitionsManager();
		inv.GetItemAbilitiesWithTag(oilId, theGame.params.OIL_ABILITY_TAG, oilAbilities);
		swordEquipped = IsItemEquipped(usedOnItem);
		
		//remove previous oil
		RemoveItemOil(usedOnItem);

		//add new oil
		for(i=0; i<oilAbilities.Size(); i+=1)
		{
			inv.AddItemCraftedAbility(usedOnItem, oilAbilities[i]);
				
			//When oil is equipped it adds its abilities to player. Since item is equipped it has already done that so we need to do it manually.
			if(swordEquipped)
			{
				AddAbility(oilAbilities[i]);
			}
		}

			if(swordEquipped)
			{
				sword = (CWitcherSword) inv.GetItemEntityUnsafe(usedOnItem);
				sword.ApplyOil( inv );
			}
				
		//set charges
		//ammo = GetCurrentOilAmmo ( oilId );
		ammo = CalculateAttributeValue(inv.GetItemAttributeValue(oilId, 'ammo'));
		if(CanUseSkill(S_Alchemy_s06))
		{
			ammoBonus = CalculateAttributeValue(GetSkillAttributeValue(S_Alchemy_s06, 'ammo_bonus', false, false));
			ammo *= 1 + ammoBonus * GetSkillLevel(S_Alchemy_s06);
		}
		inv.SetItemModifierInt(usedOnItem, 'oil_charges', RoundMath(ammo));
		inv.SetItemModifierInt(usedOnItem, 'oil_max_charges', RoundMath(ammo));
				
		LogOils("Added oil <<" + inv.GetItemName(oilId) + ">> to <<" + inv.GetItemName(usedOnItem) + ">>");
		
		//fundamentals first achievement
		SetFailedFundamentalsFirstAchievementCondition(true);
				
		//oils equip tutorial
		if(ShouldProcessTutorial('TutorialOilCanEquip3'))
		{
			tutStateOil = (W3TutorialManagerUIHandlerStateOils)theGame.GetTutorialSystem().uiHandler.GetCurrentState();
			if(tutStateOil)
			{
				tutStateOil.OnOilApplied();
			}
		}
		
		theGame.GetGlobalEventsManager().OnScriptedEvent( SEC_OnOilApplied );
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	// Damage
	//
	//////////////////////////////////////////////////////////////////////////////////////////
	
	//FIXME this is foobar - sign tests should be moved to actor or entity. This will be usefull when npc will have signs or sign-like spells.
	function ReduceDamage(out damageData : W3DamageAction)
	{
		var actorAttacker : CActor;
		var quen : W3QuenEntity;
		var attackRange : CAIAttackRange;
		var attackerMovementAdjustor : CMovementAdjustor;
		var dist, distToAttacker, actionHeading, attackerHeading : float;
		var attackName : name;
		var useQuenForBleeding : bool;
		
		super.ReduceDamage(damageData);
		
		//HACK for bleeding and quen - since bleeding does direct damage it's not considered in super
		//but we want quen to reduce it
		quen = (W3QuenEntity)signs[ST_Quen].entity;
		useQuenForBleeding = false;
		if(quen && !damageData.DealsAnyDamage() && ((W3Effect_Bleeding)damageData.causer) && damageData.GetDamageValue(theGame.params.DAMAGE_NAME_DIRECT) > 0.f)
			useQuenForBleeding = true;
		
		//damage prevented in super
		if(!useQuenForBleeding && !damageData.DealsAnyDamage())
			return;	
		
		actorAttacker = (CActor)damageData.attacker;
		
		//dodging
		if(actorAttacker && IsCurrentlyDodging() && damageData.CanBeDodged())
		{
			//check if we're dodging straight on attacker or +/- 30 degrees off. If so then the damage will not be prevented
			//if(	( AbsF(AngleDistance(GetCombatActionHeading(), actorAttacker.GetHeading())) < 150 ) && ( !actorAttacker.GetIgnoreImmortalDodge() ) )
			actionHeading = evadeHeading;
			attackerHeading = actorAttacker.GetHeading();
			dist = AngleDistance(actionHeading, attackerHeading);
			distToAttacker = VecDistance(this.GetWorldPosition(),damageData.attacker.GetWorldPosition());
			attackName = actorAttacker.GetLastAttackRangeName();
			attackRange = theGame.GetAttackRangeForEntity( actorAttacker, attackName );
			attackerMovementAdjustor = actorAttacker.GetMovingAgentComponent().GetMovementAdjustor();
			if( ( AbsF(dist) < 150 && attackName != 'stomp' && attackName != 'anchor_special_far' && attackName != 'anchor_far' ) 
				|| ( ( attackName == 'stomp' || attackName == 'anchor_special_far' || attackName == 'anchor_far' ) 
					&& distToAttacker > attackRange.rangeMax * 0.75 ) )
			{
				if ( theGame.CanLog() )
				{
					LogDMHits("W3PlayerWitcher.ReduceDamage: Attack dodged by player - no damage done", damageData);
				}
				damageData.SetAllProcessedDamageAs(0);
				damageData.SetWasDodged();
			}
			// S_sword_s9 - decrease damage while dodging
			else if (!(damageData.IsActionEnvironment() || damageData.IsDoTDamage()) && CanUseSkill(S_Sword_s09))
			{
				damageData.processedDmg.vitalityDamage *= 1 - ( CalculateAttributeValue(GetSkillAttributeValue(S_Sword_s09, 'damage_reduction', false, true)) * GetSkillLevel(S_Sword_s09) );
				if ( theGame.CanLog() )
				{
					LogDMHits("W3PlayerWitcher.ReduceDamage: skill S_Sword_s09 reduced damage while dodging", damageData );
				}
			}
		}
		
		//damage reduction from signs
		if(quen && damageData.GetBuffSourceName() != "FallingDamage")
		{
			if ( theGame.CanLog() )
			{		
				LogDMHits("W3PlayerWitcher.ReduceDamage: Processing Quen sign damage reduction...", damageData);
			}
			quen.OnTargetHit( damageData );
		}	
	}
	
	timer function UndyingSkillCooldown(dt : float, id : int)
	{
		cannotUseUndyingSkill = false;
	}
	
	event OnTakeDamage( action : W3DamageAction)
	{
		var currVitality, hpTriggerTreshold : float;
		var healingFactor : float;
		var abilityName : name;
		var abilityCount, maxStack, itemDurability : float;
		var addAbility : bool;
		var min, max : SAbilityAttributeValue;
		var mutagenQuen : W3SignEntity;
		var equipped : array<SItemUniqueId>;
		var i : int;
	
		currVitality = GetStat(BCS_Vitality);
		
		//death preventing effects
		if(action.processedDmg.vitalityDamage >= currVitality)
		{
			//skill that prevents fatal damage & removes battle trance and focus points
			if(!cannotUseUndyingSkill && FloorF(GetStat(BCS_Focus)) >= 1 && CanUseSkill(S_Sword_s18) && HasBuff(EET_BattleTrance))
			{
				healingFactor = CalculateAttributeValue( GetSkillAttributeValue(S_Sword_s18, 'healing_factor', false, true) );
				healingFactor *= GetStatMax(BCS_Vitality);
				healingFactor *= GetStat(BCS_Focus);
				healingFactor *= 1 + CalculateAttributeValue( GetSkillAttributeValue(S_Sword_s18, 'healing_bonus', false, true) ) * (GetSkillLevel(S_Sword_s18) - 1);
				ForceSetStat(BCS_Vitality, GetStatMax(BCS_Vitality));
				action.processedDmg.vitalityDamage = GetStatMax(BCS_Vitality) - healingFactor;
				DrainFocus(GetStat(BCS_Focus));
				RemoveBuff(EET_BattleTrance);
				cannotUseUndyingSkill = true;
				AddTimer('UndyingSkillCooldown', CalculateAttributeValue( GetSkillAttributeValue(S_Sword_s18, 'trigger_delay', false, true) ), false, , , true);
			}
			else
			{
				//"Reinforced" special item ability. When fatal blows comes, item takes all damage on itself (durability) and prevents death.
				equipped = GetEquippedItems();
				
				for(i=0; i<equipped.Size(); i+=1)
				{
					if ( !inv.IsIdValid( equipped[i] ) )
					{
						continue;
					}
					itemDurability = inv.GetItemDurability(equipped[i]);
					if(inv.ItemHasAbility(equipped[i], 'MA_Reinforced') && itemDurability > 0)
					{
						//break item
						inv.SetItemDurabilityScript(equipped[i], MaxF(0, itemDurability - action.processedDmg.vitalityDamage) );
						
						//prevent damage
						action.processedDmg.vitalityDamage = 0;
						ForceSetStat(BCS_Vitality, 1);
						
						break;
					}
				}
			}
		}
		
		//mutagen 10, 15
		if(action.DealsAnyDamage() && !((W3Effect_Toxicity)action.causer) )
		{
			if(HasBuff(EET_Mutagen10))
				RemoveAbilityAll( GetBuff(EET_Mutagen10).GetAbilityName() );
			
			if(HasBuff(EET_Mutagen15))
				RemoveAbilityAll( GetBuff(EET_Mutagen15).GetAbilityName() );
		}
				
		//mutagen 19
		if(HasBuff(EET_Mutagen19))
		{
			theGame.GetDefinitionsManager().GetAbilityAttributeValue(GetBuff(EET_Mutagen19).GetAbilityName(), 'max_hp_perc_trigger', min, max);
			hpTriggerTreshold = GetStatMax(BCS_Vitality) * CalculateAttributeValue(GetAttributeRandomizedValue(min, max));
			
			if(action.GetDamageDealt() >= hpTriggerTreshold)
			{
				mutagenQuen = (W3SignEntity)theGame.CreateEntity( signs[ST_Quen].template, GetWorldPosition(), GetWorldRotation() );
				mutagenQuen.Init( signOwner, signs[ST_Quen].entity, true );
				mutagenQuen.OnStarted();
				mutagenQuen.OnThrowing();
				mutagenQuen.OnEnded();
			}
		}
		
		//mutagen 27
		if(action.DealsAnyDamage() && !action.IsDoTDamage() && HasBuff(EET_Mutagen27))
		{
			abilityName = GetBuff(EET_Mutagen27).GetAbilityName();
			abilityCount = GetAbilityCount(abilityName);
			
			if(abilityCount == 0)
			{
				addAbility = true;
			}
			else
			{
				theGame.GetDefinitionsManager().GetAbilityAttributeValue(abilityName, 'mutagen27_max_stack', min, max);
				maxStack = CalculateAttributeValue(GetAttributeRandomizedValue(min, max));
				
				if(maxStack >= 0)
				{
					addAbility = (abilityCount < maxStack);
				}
				else
				{
					addAbility = true;
				}
			}
			
			if(addAbility)
			{
				AddAbility(abilityName, true);
			}
		}

		return super.OnTakeDamage(action);
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	// @Combat
	//
	//////////////////////////////////////////////////////////////////////////////////////////
	
	event OnStartFistfightMinigame()
	{
		super.OnStartFistfightMinigame();
		effectManager.RemoveAllPotionEffects();
	}
	
	event OnEndFistfightMinigame()
	{
		super.OnEndFistfightMinigame();
	}
	
	//crit hit chance 0-1
	public function GetCriticalHitChance(isHeavyAttack : bool, target : CActor, victimMonsterCategory : EMonsterCategory) : float
	{
		var ret : float;
		var thunder : W3Potion_Thunderbolt;
		
		ret = super.GetCriticalHitChance(isHeavyAttack, target, victimMonsterCategory);
		
		//Perk_05 bonus
		//if(!isHeavyAttack)
		//{
		//	ret += CalculateAttributeValue(GetAttributeValue('critical_hit_chance_fast_style'));
		//}
		
		thunder = (W3Potion_Thunderbolt)GetBuff(EET_Thunderbolt);
		if(thunder && thunder.GetBuffLevel() == 3 && GetCurWeather() == EWE_Storm)
		{
			ret += 1.0f;
		}
			
		return ret;
	}
	
	//gets damage bonus for critical hit
	public function GetCriticalHitDamageBonus(weaponId : SItemUniqueId, victimMonsterCategory : EMonsterCategory, isStrikeAtBack : bool) : SAbilityAttributeValue
	{
		var min, max, bonus, null, oilBonus : SAbilityAttributeValue;
		var mutagen : CBaseGameplayEffect;
		var vsAttributeName : name;
		
		bonus = super.GetCriticalHitDamageBonus(weaponId, victimMonsterCategory, isStrikeAtBack);
		
		//alchemy oil criticical damage skill bonus
		if(inv.ItemHasOilApplied(weaponId) && GetStat(BCS_Focus) >= 3 && CanUseSkill(S_Alchemy_s07))
		{
			vsAttributeName = MonsterCategoryToCriticalDamageBonus(victimMonsterCategory);
			oilBonus = inv.GetItemAttributeValue(weaponId, vsAttributeName);
			if(oilBonus != null)	//has proper oil type
			{
				bonus += GetSkillAttributeValue(S_Alchemy_s07, theGame.params.CRITICAL_HIT_DAMAGE_BONUS, false, true);
			}
		}
		
		// Mutagen 11 - back strike bonus
		if (isStrikeAtBack && HasBuff(EET_Mutagen11))
		{
			mutagen = GetBuff(EET_Mutagen11);
			theGame.GetDefinitionsManager().GetAbilityAttributeValue(mutagen.GetAbilityName(), 'damageIncrease', min, max);
			bonus += GetAttributeRandomizedValue(min, max);
		}
			
		return bonus;		
	}
	
	public function ProcessLockTarget( optional newLockTarget : CActor, optional checkLeftStickHeading : bool ) : bool
	{
		var newLockTargetFound	: bool;
	
		newLockTargetFound = super.ProcessLockTarget(newLockTarget, checkLeftStickHeading);
		
		if(GetCurrentlyCastSign() == ST_Axii)
		{
			((W3AxiiEntity)GetCurrentSignEntity()).OnDisplayTargetChange(newLockTarget);
		}
		
		return newLockTargetFound;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	// @Combat Actions
	//
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/*script*/ event OnPocessActionPost(action : W3DamageAction)
	{
		var attackAction : W3Action_Attack;
		var rendLoad : float;
		var value : SAbilityAttributeValue;
		var actorVictim : CActor;
		var weaponId : SItemUniqueId;
		var usesSteel, usesSilver, usesVitality, usesEssence : bool;
		var abs : array<name>;
		var i : int;
		var dm : CDefinitionsManagerAccessor;
		var items : array<SItemUniqueId>;
		var weaponEnt : CEntity;
		
		super.OnPocessActionPost(action);
		
		attackAction = (W3Action_Attack)action;
		actorVictim = (CActor)action.victim;
		if(attackAction)
		{
			if(attackAction.IsActionMelee())
			{
				//Rend aka special attack heavy
				if(SkillNameToEnum(attackAction.GetAttackTypeName()) == S_Sword_s02)
				{
					rendLoad = GetSpecialAttackTimeRatio();
					
					//consumed focus is lesser of two: current focus and (rend time held * max focus)
					rendLoad = MinF(rendLoad * GetStatMax(BCS_Focus), GetStat(BCS_Focus));
					
					//used points are treated as INTs
					rendLoad = FloorF(rendLoad);					
					DrainFocus(rendLoad);
					
					OnSpecialAttackHeavyActionProcess();
				}
				else if(actorVictim && IsRequiredAttitudeBetween(this, actorVictim, true))
				{
					//focus gain on hit - rend gives none	
					// M.J Each attack gives the same number of adrenaline
					value = GetAttributeValue('focus_gain');
					
					if( FactsQuerySum("debug_fact_focus_boy") > 0 )
					{
						Debug_FocusBoyFocusGain();
					}
					
					//bonus from skill
					if ( CanUseSkill(S_Sword_s20) )
					{
						value += GetSkillAttributeValue(S_Sword_s20, 'focus_gain', false, true) * GetSkillLevel(S_Sword_s20);
					}
					
					GainStat(BCS_Focus, 0.1f * (1 + CalculateAttributeValue(value)) );
				}
				
				//tutorial - using wrong sword type. Display only when hitting hostiles (even if you can hit neutrals / friendlies)				
				weaponId = attackAction.GetWeaponId();
				if(actorVictim && (ShouldProcessTutorial('TutorialWrongSwordSteel') || ShouldProcessTutorial('TutorialWrongSwordSilver')) && GetAttitudeBetween(actorVictim, this) == AIA_Hostile)
				{
					usesSteel = inv.IsItemSteelSwordUsableByPlayer(weaponId);
					usesSilver = inv.IsItemSilverSwordUsableByPlayer(weaponId);
					usesVitality = actorVictim.UsesVitality();
					usesEssence = actorVictim.UsesEssence();
					
					if(usesSilver && usesVitality)
					{
						FactsAdd('tut_wrong_sword_silver',1);
					}
					else if(usesSteel && usesEssence)
					{
						FactsAdd('tut_wrong_sword_steel',1);
					}
					else if(FactsQuerySum('tut_wrong_sword_steel') && usesSilver && usesEssence)
					{
						FactsAdd('tut_proper_sword_silver',1);
						FactsRemove('tut_wrong_sword_steel');
					}
					else if(FactsQuerySum('tut_wrong_sword_silver') && usesSteel && usesVitality)
					{
						FactsAdd('tut_proper_sword_steel',1);
						FactsRemove('tut_wrong_sword_silver');
					}
				}
				
				//runeword infusing sword with sign power
				if(!action.WasDodged() && HasAbility('Runeword 1 _Stats', true))
				{
					if(runewordInfusionType == ST_Axii)
					{
						actorVictim.SoundEvent('sign_axii_release');
					}
					else if(runewordInfusionType == ST_Igni)
					{
						actorVictim.SoundEvent('sign_igni_charge_begin');
					}
					else if(runewordInfusionType == ST_Quen)
					{
						value = GetAttributeValue('runeword1_quen_heal');
						Heal( action.GetDamageDealt() * value.valueMultiplicative );
						PlayEffectSingle('drain_energy_caretaker_shovel');
					}
					else if(runewordInfusionType == ST_Yrden)
					{
						actorVictim.SoundEvent('sign_yrden_shock_activate');
					}
					runewordInfusionType = ST_None;
					
					//stop fx
					items = inv.GetHeldWeapons();
					weaponEnt = inv.GetItemEntityUnsafe(items[0]);
					weaponEnt.StopEffect('runeword_aard');
					weaponEnt.StopEffect('runeword_axii');
					weaponEnt.StopEffect('runeword_igni');
					weaponEnt.StopEffect('runeword_quen');
					weaponEnt.StopEffect('runeword_yrden');
				}
				
				//light / heavy attacks tutorial
				if(ShouldProcessTutorial('TutorialLightAttacks') || ShouldProcessTutorial('TutorialHeavyAttacks'))
				{
					if(IsLightAttack(attackAction.GetAttackName()))
					{
						theGame.GetTutorialSystem().IncreaseGeraltsLightAttacksCount(action.victim.GetTags());
					}
					else if(IsHeavyAttack(attackAction.GetAttackName()))
					{
						theGame.GetTutorialSystem().IncreaseGeraltsHeavyAttacksCount(action.victim.GetTags());
					}
				}
			}
			else if(attackAction.IsActionRanged())
			{
				//bolt focus gain (if has skill)
				if(CanUseSkill(S_Sword_s15))
				{				
					value = GetSkillAttributeValue(S_Sword_s15, 'focus_gain', false, true) * GetSkillLevel(S_Sword_s15) ;
					GainStat(BCS_Focus, CalculateAttributeValue(value) );
				}
				
				//skill: critical crossbow hit disables 1 random enemy skill
				if(CanUseSkill(S_Sword_s12) && attackAction.IsCriticalHit() && actorVictim)
				{
					//get non-blocked abilities of victim
					abs = actorVictim.GetAbilities(false);
					dm = theGame.GetDefinitionsManager();
					for(i=abs.Size()-1; i>=0; i-=1)
					{
						if(!dm.AbilityHasTag(abs[i], theGame.params.TAG_MONSTER_SKILL) || actorVictim.IsAbilityBlocked(abs[i]))
						{
							abs.EraseFast(i);
						}
					}
					
					//if there is any non-blocked ability - pick random and block it
					if(abs.Size() > 0)
					{
						value = GetSkillAttributeValue(S_Sword_s12, 'duration', true, true) * GetSkillLevel(S_Sword_s12);
						actorVictim.BlockAbility(abs[ RandRange(abs.Size()) ], true, CalculateAttributeValue(value));
					}
				}
			}
		}
		
		//perk generating adrenaline on bomb non-DoT damage
		if(CanUseSkill(S_Perk_18) && ((W3Petard)action.causer) && action.DealsAnyDamage() && !action.IsDoTDamage())
		{
			value = GetSkillAttributeValue(S_Perk_18, 'focus_gain', false, true);
			GainStat(BCS_Focus, CalculateAttributeValue(value));
		}		
	}
	
	//mutagen 14 - attack power bonus
	timer function Mutagen14Timer(dt : float, id : int)
	{
		var abilityName : name;
		var abilityCount, maxStack : float;
		var min, max : SAbilityAttributeValue;
		var addAbility : bool;
		
		abilityName = GetBuff(EET_Mutagen14).GetAbilityName();
		abilityCount = GetAbilityCount(abilityName);
		
		if(abilityCount == 0)
		{
			addAbility = true;
		}
		else
		{
			theGame.GetDefinitionsManager().GetAbilityAttributeValue(abilityName, 'mutagen14_max_stack', min, max);
			maxStack = CalculateAttributeValue(GetAttributeRandomizedValue(min, max));
			
			if(maxStack >= 0)
			{
				addAbility = (abilityCount < maxStack);
			}
			else
			{
				addAbility = true;
			}
		}
		
		if(addAbility)
		{
			AddAbility(abilityName, true);
		}
		else
		{
			//max stack reached
			RemoveTimer('Mutagen14Timer');
		}
	}
	
	public final function FailFundamentalsFirstAchievementCondition()
	{
		SetFailedFundamentalsFirstAchievementCondition(true);
	}
		
	public final function SetUsedQuenInCombat()
	{
		usedQuenInCombat = true;
	}
	
	public final function UsedQuenInCombat() : bool
	{
		return usedQuenInCombat;
	}
	
	event OnCombatStart()
	{
		var quenEntity, glyphQuen : W3QuenEntity;
		var focus, stamina : float;
		
		super.OnCombatStart();
		
		if ( IsInCombatActionFriendly() )
		{
			SetBIsCombatActionAllowed(true);
			SetBIsInputAllowed(true, 'OnCombatActionStart' );
		}
		
		//mutagen 14 - attack power bonus
		if(HasBuff(EET_Mutagen14))
		{
			AddTimer('Mutagen14Timer', 2, true);
		}
		
		//mutagen 15 - attack power bonus
		if(HasBuff(EET_Mutagen15))
		{
			AddAbility(GetBuff(EET_Mutagen15).GetAbilityName(), false);
		}
		
		//check if quen is currently on		
		quenEntity = (W3QuenEntity)signs[ST_Quen].entity;		
		
		//if has some quen
		if(quenEntity)
		{
			usedQuenInCombat = quenEntity.IsAnyQuenActive();
		}
		else
		{
			usedQuenInCombat = false;
		}
		
		if(usedQuenInCombat || HasPotionBuff() || IsEquippedSwordUpgradedWithOil(true) || IsEquippedSwordUpgradedWithOil(false))
		{
			SetFailedFundamentalsFirstAchievementCondition(true);
		}
		else
		{
			if(IsAnyItemEquippedOnSlot(EES_PotionMutagen1) || IsAnyItemEquippedOnSlot(EES_PotionMutagen2) || IsAnyItemEquippedOnSlot(EES_PotionMutagen3) || IsAnyItemEquippedOnSlot(EES_PotionMutagen4))
				SetFailedFundamentalsFirstAchievementCondition(true);
			else
				SetFailedFundamentalsFirstAchievementCondition(false);
		}
		
		if(CanUseSkill(S_Sword_s20) && IsThreatened())
		{
			focus = GetStat(BCS_Focus);
			if(focus < 1)
			{
				GainStat(BCS_Focus, 1 - focus);
			}
		}

		if ( HasAbility('Glyphword 17 _Stats', true) && RandF() < CalculateAttributeValue(GetAttributeValue('quen_apply_chance')) )
		{
			stamina = GetStat(BCS_Stamina);
			glyphQuen = (W3QuenEntity)theGame.CreateEntity( signs[ST_Quen].template, GetWorldPosition(), GetWorldRotation() );
			glyphQuen.Init( signOwner, signs[ST_Quen].entity, true );
			glyphQuen.OnStarted();
			glyphQuen.OnThrowing();
			glyphQuen.OnEnded();
			ForceSetStat(BCS_Stamina, stamina);
		}
		
		//abort meditation
		MeditationForceAbort(true);
	}
	
	//called when combat finishes
	event OnCombatFinished()
	{
		var mut17 : W3Mutagen17_Effect;
		
		super.OnCombatFinished();
		
		//mutagen 10 disable
		if(HasBuff(EET_Mutagen10))
		{
			RemoveAbilityAll( GetBuff(EET_Mutagen10).GetAbilityName() );
		}
		
		//mutagen 14 disable
		if(HasBuff(EET_Mutagen14))
		{
			RemoveAbilityAll( GetBuff(EET_Mutagen14).GetAbilityName() );
		}
		
		//mutagen 15 disable
		if(HasBuff(EET_Mutagen15))
		{
			RemoveAbilityAll( GetBuff(EET_Mutagen15).GetAbilityName() );
		}
		
		//mutagen 17 disable
		if(HasBuff(EET_Mutagen17))
		{
			mut17 = (W3Mutagen17_Effect)GetBuff(EET_Mutagen17);
			mut17.ClearBoost();
		}
		
		//mutagen 18 disable
		if(HasBuff(EET_Mutagen18))
		{
			RemoveAbilityAll( GetBuff(EET_Mutagen18).GetAbilityName() );
		}
		
		//mutagen 22 disable
		if(HasBuff(EET_Mutagen22))
		{
			RemoveAbilityAll( GetBuff(EET_Mutagen22).GetAbilityName() );
		}
		
		//mutagen 27 disable
		if(HasBuff(EET_Mutagen27))
		{
			RemoveAbilityAll( GetBuff(EET_Mutagen27).GetAbilityName() );
		}
		
		//adrenaline drain
		if(GetStat(BCS_Focus) > 0)
		{
			AddTimer('DelayedAdrenalineDrain', theGame.params.ADRENALINE_DRAIN_AFTER_COMBAT_DELAY, , , , true);
		}
		
		//Removing overheal bonus
		thePlayer.abilityManager.ResetOverhealBonus();
		
		usedQuenInCombat = false;		
		
		theGame.GetGamerProfile().ResetStat(ES_FinesseKills);
		
		LogChannel( 'OnCombatFinished', "OnCombatFinished: DelayedSheathSword timer added" ); 
		if ( ShouldAutoSheathSwordInstantly() )
			AddTimer( 'DelayedSheathSword', 0.5f );
		else
			AddTimer( 'DelayedSheathSword', 2.f );
			
		OnBlockAllCombatTickets( false ); // failsafe for killing opponents with debug keys
		
		//'discharge' Runeword 1 infusion
		runewordInfusionType = ST_None;
		
		/*if ( !this.IsThreatened() )
		{
			if ( this.IsInCombatAction() )
				this.PushCombatActionOnBuffer(EBAT_Sheathe_Sword,BS_Pressed);
			else
				OnEquipMeleeWeapon( PW_None, false );
		}*/
	}
	
	timer function DelayedAdrenalineDrain(dt : float, id : int)
	{
		if ( !HasBuff(EET_Runeword8) )
			AddEffectDefault(EET_AdrenalineDrain, this, "after_combat_adrenaline_drain");
	}
	
	//performs an attack (mechanics wise) on given target and using given attack data
	protected function Attack( hitTarget : CGameplayEntity, animData : CPreAttackEventData, weaponId : SItemUniqueId, parried : bool, countered : bool, parriedBy : array<CActor>, attackAnimationName : name, hitTime : float, weaponEntity : CItemEntity)
	{
		var mutagen17 : W3Mutagen17_Effect;
		
		super.Attack(hitTarget, animData, weaponId, parried, countered, parriedBy, attackAnimationName, hitTime, weaponEntity);
		
		if( (CActor)hitTarget && HasBuff(EET_Mutagen17) )
		{
			mutagen17 = (W3Mutagen17_Effect)GetBuff(EET_Mutagen17);
			if(mutagen17.HasBoost())
			{
				mutagen17.ClearBoost();
			}
		}
	}
	
	public final timer function SpecialAttackLightSustainCost(dt : float, id : int)
	{
		var focusPerSec, cost, delay : float;
		var reduction : SAbilityAttributeValue;
		var skillLevel : int;
		
		if(abilityManager && abilityManager.IsInitialized() && IsAlive())
		{
			PauseStaminaRegen('WhirlSkill');
			
			if(GetStat(BCS_Stamina) > 0)
			{
				cost = GetStaminaActionCost(ESAT_Ability, GetSkillAbilityName(S_Sword_s01), dt);
				delay = GetStaminaActionDelay(ESAT_Ability, GetSkillAbilityName(S_Sword_s01), dt);
				skillLevel = GetSkillLevel(S_Sword_s01);
				
				if(skillLevel > 1)
				{
					reduction = GetSkillAttributeValue(S_Sword_s01, 'cost_reduction', false, true) * (skillLevel - 1);
					cost = MaxF(0, cost * (1 - reduction.valueMultiplicative) - reduction.valueAdditive);
				}
				
				DrainStamina(ESAT_FixedValue, cost, delay, GetSkillAbilityName(S_Sword_s01));
			}
			else				
			{				
				GetSkillAttributeValue(S_Sword_s01, 'focus_cost_per_sec', false, true);
				focusPerSec = GetWhirlFocusCostPerSec();
				DrainFocus(focusPerSec * dt);
			}
		}
		
		if(GetStat(BCS_Stamina) <= 0 && GetStat(BCS_Focus) <= 0)
		{
			OnPerformSpecialAttack(true, false);
		}
	}
	
	public final function GetWhirlFocusCostPerSec() : float
	{
		var ability : SAbilityAttributeValue;
		var val : float;
		var skillLevel : int;
		
		ability = GetSkillAttributeValue(S_Sword_s01, 'focus_cost_per_sec_initial', false, false);
		skillLevel = GetSkillLevel(S_Sword_s01);
		
		if(skillLevel > 1)
			ability -= GetSkillAttributeValue(S_Sword_s01, 'cost_reduction', false, false) * (skillLevel-1);
			
		val = CalculateAttributeValue(ability);
		
		return val;
	}
	
	public final timer function SpecialAttackHeavySustainCost(dt : float, id : int)
	{
		var focusHighlight, ratio : float;
		var hud : CR4ScriptedHud;
		var hudWolfHeadModule : CR4HudModuleWolfHead;		

		//drain stamina
		DrainStamina(ESAT_Ability, 0, 0, GetSkillAbilityName(S_Sword_s02), dt);

		//abort if out of stamina
		if(GetStat(BCS_Stamina) <= 0)
			OnPerformSpecialAttack(false, false);
			
		//update 'held' ratio
		ratio = EngineTimeToFloat(theGame.GetEngineTime() - specialHeavyStartEngineTime) / specialHeavyChargeDuration;
		
		//rounding and blend-out errors
		if(ratio > 0.95)
			ratio = 1;
			
		SetSpecialAttackTimeRatio(ratio);
		
		//calculate focus point cost and highlight 'to be used' focus points on HUD
		focusHighlight = ratio * GetStatMax(BCS_Focus);
		focusHighlight = MinF(focusHighlight, GetStat(BCS_Focus));
		focusHighlight = FloorF(focusHighlight);
		
		hud = (CR4ScriptedHud)theGame.GetHud();
		if ( hud )
		{
			hudWolfHeadModule = (CR4HudModuleWolfHead)hud.GetHudModule( "WolfHeadModule" );
			if ( hudWolfHeadModule )
			{
				hudWolfHeadModule.LockFocusPoints((int)focusHighlight);
			}		
		}
	}
	
	public function OnSpecialAttackHeavyActionProcess()
	{
		var hud : CR4ScriptedHud;
		var hudWolfHeadModule : CR4HudModuleWolfHead;
		
		super.OnSpecialAttackHeavyActionProcess();

		hud = (CR4ScriptedHud)theGame.GetHud();
		if ( hud )
		{
			hudWolfHeadModule = (CR4HudModuleWolfHead)hud.GetHudModule( "WolfHeadModule" );
			if ( hudWolfHeadModule )
			{
				hudWolfHeadModule.ResetFocusPoints();
			}		
		}
	}
	
	timer function IsSpecialLightAttackInputHeld ( time : float, id : int )
	{
		var hasResource : bool;
		
		if ( GetCurrentStateName() == 'CombatSteel' || GetCurrentStateName() == 'CombatSilver' )
		{
			if ( GetBIsCombatActionAllowed() && inputHandler.IsActionAllowed(EIAB_SwordAttack))
			{
				if(GetStat(BCS_Stamina) > 0)
				{
					hasResource = true;
				}
				else
				{
					hasResource = (GetStat(BCS_Focus) >= GetWhirlFocusCostPerSec() * time);					
				}
				
				if(hasResource)
				{
					SetupCombatAction( EBAT_SpecialAttack_Light, BS_Pressed );
					RemoveTimer('IsSpecialLightAttackInputHeld');
				}
				else if(!playedSpecialAttackMissingResourceSound)
				{
					IndicateTooLowAdrenaline();
					playedSpecialAttackMissingResourceSound = true;
				}
			}			
		}
		else
		{
			RemoveTimer('IsSpecialLightAttackInputHeld');
		}
	}	
	
	timer function IsSpecialHeavyAttackInputHeld ( time : float, id : int )
	{		
		var cost : float;
		
		if ( GetCurrentStateName() == 'CombatSteel' || GetCurrentStateName() == 'CombatSilver' )
		{
			cost = CalculateAttributeValue(GetSkillAttributeValue(S_Sword_s02, 'stamina_cost_per_sec', false, false));
			
			if( GetBIsCombatActionAllowed() && inputHandler.IsActionAllowed(EIAB_SwordAttack))
			{
				if(GetStat(BCS_Stamina) >= cost)
				{
					SetupCombatAction( EBAT_SpecialAttack_Heavy, BS_Pressed );
					RemoveTimer('IsSpecialHeavyAttackInputHeld');
				}
				else if(!playedSpecialAttackMissingResourceSound)
				{
					IndicateTooLowAdrenaline();
					playedSpecialAttackMissingResourceSound = true;
				}
			}
		}
		else
		{
			RemoveTimer('IsSpecialHeavyAttackInputHeld');
		}
	}
	
	public function EvadePressed( bufferAction : EBufferActionType )
	{
		var cat : float;
		
		if( (bufferAction == EBAT_Dodge && IsActionAllowed(EIAB_Dodge)) || (bufferAction == EBAT_Roll && IsActionAllowed(EIAB_Roll)) )
		{
			//tutorial - even if input is not allowed - we might get caught with slowmo during previous dodge - so dodge is not allowed then
			if(bufferAction != EBAT_Roll && ShouldProcessTutorial('TutorialDodge'))
			{
				FactsAdd("tut_in_dodge", 1, 2);
				
				if(FactsQuerySum("tut_fight_use_slomo") > 0)
				{
					theGame.RemoveTimeScale( theGame.GetTimescaleSource(ETS_TutorialFight) );
					FactsRemove("tut_fight_slomo_ON");
				}
			}				
			else if(bufferAction == EBAT_Roll && ShouldProcessTutorial('TutorialRoll'))
			{
				FactsAdd("tut_in_roll", 1, 2);
				
				if(FactsQuerySum("tut_fight_use_slomo") > 0)
				{
					theGame.RemoveTimeScale( theGame.GetTimescaleSource(ETS_TutorialFight) );
					FactsRemove("tut_fight_slomo_ON");
				}
			}
				
			if ( GetBIsInputAllowed() )
			{			
				if ( GetBIsCombatActionAllowed() )
				{
					CriticalEffectAnimationInterrupted("Dodge 2");
					PushCombatActionOnBuffer( bufferAction, BS_Released );
					ProcessCombatActionBuffer();
				}					
				else if ( IsInCombatAction() && GetBehaviorVariable( 'combatActionType' ) == (int)CAT_Attack )
				{
					if ( CanPlayHitAnim() && IsThreatened() )
					{
						CriticalEffectAnimationInterrupted("Dodge 1");
						PushCombatActionOnBuffer( bufferAction, BS_Released );
						ProcessCombatActionBuffer();							
					}
					else
						PushCombatActionOnBuffer( bufferAction, BS_Released );
				}
				
				else if ( !( IsCurrentSignChanneled() ) )
				{
					//bIsRollAllowed = true;
					PushCombatActionOnBuffer( bufferAction, BS_Released );
				}
			}
			else
			{
				if ( IsInCombatAction() && GetBehaviorVariable( 'combatActionType' ) == (int)CAT_Attack )
				{
					if ( CanPlayHitAnim() && IsThreatened() )
					{
						CriticalEffectAnimationInterrupted("Dodge 3");
						PushCombatActionOnBuffer( bufferAction, BS_Released );
						ProcessCombatActionBuffer();							
					}
					else
						PushCombatActionOnBuffer( bufferAction, BS_Released );
				}
				LogChannel( 'InputNotAllowed', "InputNotAllowed" );
			}
		}
		else
		{
			DisplayActionDisallowedHudMessage(EIAB_Dodge);
		}
	}
		
	//All input mechanics are in here
	public function ProcessCombatActionBuffer() : bool
	{
		var action	 			: EBufferActionType			= this.BufferCombatAction;
		var stage	 			: EButtonStage 				= this.BufferButtonStage;		
		var throwStage			: EThrowStage;		
		var actionResult 		: bool = true;
		
		
		if( isInFinisher )
		{
			return false;
		}
		
		if ( action != EBAT_SpecialAttack_Heavy )
			specialAttackCamera = false;			
		
		//call super
		if(super.ProcessCombatActionBuffer())
			return true;		//... and quit if processed	
			
		switch ( action )
		{			
			case EBAT_CastSign :
			{
				switch ( stage )
				{
					case BS_Pressed : 
					{
//						if ( GetInvalidUniqueId() == inv.GetItemFromSlot( 'l_weapon' ) )
//						{
//							if ( ( !rangedWeapon || !( rangedWeapon.PerformedDraw() || rangedWeapon.GetCurrentStateName() != 'State_WeaponWait' ) )
//								&& !currentlyUsingItem )
	//						if ( !currentlyUsingItem )
	//						{
								actionResult = this.CastSign();
								LogChannel('SignDebug', "CastSign()");
	//						}
//						}
					} break;
					
					default : 
					{
						actionResult = false;
					} break;
				}
			} break;
			
			case EBAT_SpecialAttack_Light :
			{
				switch ( stage )
				{
					case BS_Pressed :
					{
						//AddTemporarySkills();
						actionResult = this.OnPerformSpecialAttack( true, true );
					} break;
					
					case BS_Released :
					{						
						actionResult = this.OnPerformSpecialAttack( true, false );
					} break;
					
					default :
					{
						actionResult = false;
					} break;
				}
			} break;

			case EBAT_SpecialAttack_Heavy :
			{
				switch ( stage )
				{
					case BS_Pressed :
					{
						//AddTemporarySkills();
						actionResult = this.OnPerformSpecialAttack( false, true );
					} break;
					
					case BS_Released :
					{
						actionResult = this.OnPerformSpecialAttack( false, false );
					} break;
					
					default :
					{
						actionResult = false;
					} break;
				}
			} break;
			
			default:
				return false;	//not processed
		}
		
		//if here then buffer got processed
		this.CleanCombatActionBuffer();
		
		if (actionResult)
		{
			SetCombatAction( action ) ;
		}
		
		return true;
	}
		
	/*
		These declarations are needed here only to call event with the same name inside combat state (there's no other way to call it!).
	*/	
	event OnPerformSpecialAttack( isLightAttack : bool, enableAttack : bool ){}	
	
	event OnPlayerTickTimer( deltaTime : float )
	{
		super.OnPlayerTickTimer( deltaTime );
		
		if ( !IsInCombat() )
		{
			fastAttackCounter = 0;
			heavyAttackCounter = 0;
		}		
	}
	
	//////////////////
	// @attacks
	//////////////////
	
	protected function PrepareAttackAction( hitTarget : CGameplayEntity, animData : CPreAttackEventData, weaponId : SItemUniqueId, parried : bool, countered : bool, parriedBy : array<CActor>, attackAnimationName : name, hitTime : float, weaponEntity : CItemEntity, out attackAction : W3Action_Attack) : bool
	{
		var ret : bool;
		var skill : ESkill;
	
		ret = super.PrepareAttackAction(hitTarget, animData, weaponId, parried, countered, parriedBy, attackAnimationName, hitTime, weaponEntity, attackAction);
		
		if(!ret)
			return false;
		
		//Skill bonuses
		if(attackAction.IsActionMelee())
		{			
			skill = SkillNameToEnum( attackAction.GetAttackTypeName() );
			if( skill != S_SUndefined && CanUseSkill(skill))
			{
				if(IsLightAttack(animData.attackName))
					fastAttackCounter += 1;
				else
					fastAttackCounter = 0;
				
				if(IsHeavyAttack(animData.attackName))
					heavyAttackCounter += 1;
				else
					heavyAttackCounter = 0;				
			}		
		}
		
		AddTimer('FastAttackCounterDecay',5.0);
		AddTimer('HeavyAttackCounterDecay',5.0);
		
		return true;
	}
	
	protected function TestParryAndCounter(data : CPreAttackEventData, weaponId : SItemUniqueId, out parried : bool, out countered : bool) : array<CActor>
	{
		//rend cannot be parried
		if(SkillNameToEnum(attackActionName) == S_Sword_s02)
			data.Can_Parry_Attack = false;
			
		return super.TestParryAndCounter(data, weaponId, parried, countered);
	}
		
	private timer function FastAttackCounterDecay(delta : float, id : int)
	{
		fastAttackCounter = 0;
	}
	
	private timer function HeavyAttackCounterDecay(delta : float, id : int)
	{
		heavyAttackCounter = 0;
	}
		
	//---------------------------------------------- @CRAFTING --------------------------------------------------------	
	public function GetCraftingSchematicsNames() : array<name>		{return craftingSchematics;}
	
	public function RemoveAllCraftingSchematics()
	{
		craftingSchematics.Clear();
	}
	
	/**
		Adds new schematic to the book. Returns true if the schematic was added, false if it's already in the book.
	*/
	function AddCraftingSchematic( nam : name, optional isSilent : bool, optional skipTutorialUpdate : bool ) : bool
	{
		var i : int;
		
		if(!skipTutorialUpdate && ShouldProcessTutorial('TutorialCraftingGotRecipe'))
		{
			FactsAdd("tut_received_schematic");
		}
		
		for(i=0; i<craftingSchematics.Size(); i+=1)
		{
			if(craftingSchematics[i] == nam)
				return false;
			
			//found a place to insert
			if(StrCmp(craftingSchematics[i],nam) > 0)
			{
				craftingSchematics.Insert(i,nam);
				AddCraftingHudNotification( nam, isSilent );
				theGame.GetGlobalEventsManager().OnScriptedEvent( SEC_CraftingSchematics );
				return true;
			}			
		}	

		//if here then either the array is empty or 'nam' should be inserted at the end
		craftingSchematics.PushBack(nam);
		AddCraftingHudNotification( nam, isSilent );
		theGame.GetGlobalEventsManager().OnScriptedEvent( SEC_CraftingSchematics );
		return true;	
	}
	
	function AddCraftingHudNotification( nam : name, isSilent : bool )
	{
		var hud : CR4ScriptedHud;
		if( !isSilent )
		{
			hud = (CR4ScriptedHud)theGame.GetHud();
			if( hud )
			{
				hud.OnCraftingSchematicUpdate( nam );
			}
		}
	}	
	
	function AddAlchemyHudNotification( nam : name, isSilent : bool )
	{
		var hud : CR4ScriptedHud;
		if( !isSilent )
		{
			hud = (CR4ScriptedHud)theGame.GetHud();
			if( hud )
			{
				hud.OnAlchemySchematicUpdate( nam );
			}
		}
	}
	
	////////////////////////////////////////////////////////////////////////////////
	//
	// @Alchemy
	//
	////////////////////////////////////////////////////////////////////////////////
	
	public function GetAlchemyRecipes() : array<name>
	{
		return alchemyRecipes;
	}
		
	public function CanLearnAlchemyRecipe(recipeName : name) : bool
	{
		var dm : CDefinitionsManagerAccessor;
		var recipeNode : SCustomNode;
		var i, tmpInt : int;
		var tmpName : name;
	
		dm = theGame.GetDefinitionsManager();
		if ( dm.GetSubNodeByAttributeValueAsCName( recipeNode, 'alchemy_recipes', 'name_name', recipeName ) )
		{
			return true;
			/*
			unused perk 8
			if(dm.GetCustomNodeAttributeValueInt( recipeNode, 'level', tmpInt))
			{
				if(tmpInt >= 3)
				{
					return CanUseSkill(S_Perk_08);
				}
				else
				{
					return true;
				}
			}
			else
			{
				return true;
			}
			*/
		}
		
		return false;
	}
	
	private final function RemoveAlchemyRecipe(recipeName : name)
	{
		alchemyRecipes.Remove(recipeName);
	}
	
	private final function RemoveAllAlchemyRecipes()
	{
		alchemyRecipes.Clear();
	}

	/**
		Adds new recipe to the book. Returns true if the recipe was added, false if it's already in the book.
	*/
	function AddAlchemyRecipe(nam : name, optional isSilent : bool, optional skipTutorialUpdate : bool) : bool
	{
		var i, potions, bombs : int;
		var found : bool;
		var m_alchemyManager : W3AlchemyManager;
		var recipe : SAlchemyRecipe;
		var knownBombTypes : array<string>;
		var strRecipeName, recipeNameWithoutLevel : string;
		
		if(!IsAlchemyRecipe(nam))
			return false;
		
		found = false;
		for(i=0; i<alchemyRecipes.Size(); i+=1)
		{
			if(alchemyRecipes[i] == nam)
				return false;
			
			//found a place to insert
			if(StrCmp(alchemyRecipes[i],nam) > 0)
			{
				alchemyRecipes.Insert(i,nam);
				found = true;
				AddAlchemyHudNotification(nam,isSilent);
				break;
			}			
		}	

		if(!found)
		{
			alchemyRecipes.PushBack(nam);
			AddAlchemyHudNotification(nam,isSilent);
		}
		
		m_alchemyManager = new W3AlchemyManager in this;
		m_alchemyManager.Init(alchemyRecipes);
		m_alchemyManager.GetRecipe(nam, recipe);
			
		//skill toxicity increase
		if(CanUseSkill(S_Alchemy_s18))
		{
			if ((recipe.cookedItemType != EACIT_Bolt) && (recipe.cookedItemType != EACIT_Undefined) && (recipe.level <= GetSkillLevel(S_Alchemy_s18)))
				AddAbility(SkillEnumToName(S_Alchemy_s18), true);
			
		}
		
		//achievement for learning - need to do a full pass due to desync between RC and patch versions
		potions = 0;
		bombs = 0;
		for(i=0; i<alchemyRecipes.Size(); i+=1)
		{
			m_alchemyManager.GetRecipe(alchemyRecipes[i], recipe);
			
			//potions are not unique
			if(recipe.cookedItemType == EACIT_Potion || recipe.cookedItemType == EACIT_MutagenPotion || recipe.cookedItemType == EACIT_Alcohol || recipe.cookedItemType == EACIT_Quest)
			{
				potions += 1;
			}
			//bombs are unique
			else if(recipe.cookedItemType == EACIT_Bomb)
			{
				strRecipeName = NameToString(alchemyRecipes[i]);
				recipeNameWithoutLevel = StrLeft(strRecipeName, StrLen(strRecipeName)-2);
				if(!knownBombTypes.Contains(recipeNameWithoutLevel))
				{
					bombs += 1;
					knownBombTypes.PushBack(recipeNameWithoutLevel);
				}
			}
		}		
		theGame.GetGamerProfile().SetStat(ES_KnownPotionRecipes, potions);
		theGame.GetGamerProfile().SetStat(ES_KnownBombRecipes, bombs);
		theGame.GetGlobalEventsManager().OnScriptedEvent( SEC_AlchemyRecipe );
				
		return true;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	// Combat Actions GUI Mediator //#B
	// 
	//////////////////////////////////////////////////////////////////////////////////////////
	
	public function GetDisplayHeavyAttackIndicator() : bool
	{
		return bDispalyHeavyAttackIndicator;
	}

	public function SetDisplayHeavyAttackIndicator( val : bool ) 
	{
		bDispalyHeavyAttackIndicator = val;
	}

	public function GetDisplayHeavyAttackFirstLevelTimer() : bool
	{
		return bDisplayHeavyAttackFirstLevelTimer;
	}

	public function SetDisplayHeavyAttackFirstLevelTimer( val : bool ) 
	{
		bDisplayHeavyAttackFirstLevelTimer = val;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	// Witcher's Throw Item Mechanics
	// 
	//////////////////////////////////////////////////////////////////////////////////////////

	public function SelectQuickslotItem( slot : EEquipmentSlots )
	{
		var item : SItemUniqueId;
	
		GetItemEquippedOnSlot(slot, item);
		selectedItemId = item;			//invalid if no item
	}	
	
	/////////////////////////////////////////////////////////////////////////////////
	//
	//	MEDALLION
	//
	/////////////////////////////////////////////////////////////////////////////////
	
	public function GetMedallion() : W3MedallionController
	{
		if ( !medallionController )
		{
			medallionController = new W3MedallionController in this;
		}
		return medallionController;
	}
	
	// Medallion highlighted objects
	public final function HighlightObjects(range : float, optional highlightTime : float )
	{
		var ents : array<CGameplayEntity>;
		var i : int;

		FindGameplayEntitiesInSphere(ents, GetWorldPosition(), range, 100, 'HighlightedByMedalionFX', FLAG_ExcludePlayer);

		if(highlightTime == 0)
			highlightTime = 30;
		
		for(i=0; i<ents.Size(); i+=1)
		{
			if(!ents[i].IsHighlighted())
			{
				ents[i].SetHighlighted( true );
				ents[i].PlayEffectSingle( 'medalion_detection_fx' );
				ents[i].AddTimer( 'MedallionEffectOff', highlightTime );
			}
		}
	}
	
	// highlighted enemies
	public final function HighlightEnemies(range : float, optional highlightTime : float )
	{
		var ents : array<CGameplayEntity>;
		var i : int;
		var catComponent : CGameplayEffectsComponent;

		FindGameplayEntitiesInSphere(ents, GetWorldPosition(), range, 100, , FLAG_ExcludePlayer + FLAG_OnlyAliveActors);

		if(highlightTime == 0)
			highlightTime = 5;
		
		for(i=0; i<ents.Size(); i+=1)
		{
			if(IsRequiredAttitudeBetween(this, ents[i], true))
			{
				catComponent = GetGameplayEffectsComponent(ents[i]);
				if(catComponent)
				{
					catComponent.SetGameplayEffectFlag(EGEF_CatViewHiglight, true);
					ents[i].AddTimer( 'EnemyHighlightOff', highlightTime );
				}
			}
		}
	}	
	
	function SpawnMedallionEntity()
	{
		var rot					: EulerAngles;
		var spawnedMedallion	: CEntity;
				
		spawnedMedallion = theGame.GetEntityByTag( 'new_Witcher_medallion_FX' ); 
		
		if ( !spawnedMedallion )
			theGame.CreateEntity( medallionEntity, GetWorldPosition(), rot, true, false );
	}
	
	/////////////////////////////////////////////////////////////////////////////////
	//
	//	COMBAT FOCUS
	//
	/////////////////////////////////////////////////////////////////////////////////
	
	// Yes! Empty space!
	
	public final function InterruptCombatFocusMode()
	{
		if( this.GetCurrentStateName() == 'CombatFocusMode_SelectSpot' )
		{	
			SetCanPlayHitAnim( true );
			PopState();
		}
	}
	
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////  @EQUIPMENT @SLOTS @ITEMS   ////////////////////////////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	private saved var selectedPotionSlotUpper, selectedPotionSlotLower : EEquipmentSlots;
	private var potionDoubleTapTimerRunning, potionDoubleTapSlotIsUpper : bool;
		default selectedPotionSlotUpper = EES_Potion1;
		default selectedPotionSlotLower = EES_Potion2;
		default potionDoubleTapTimerRunning = false;
	
	public final function SetPotionDoubleTapRunning(b : bool, optional isUpperSlot : bool)
	{
		if(b)
		{
			AddTimer('PotionDoubleTap', 0.3);
		}
		else
		{
			RemoveTimer('PotionDoubleTap');
		}
		
		potionDoubleTapTimerRunning = b;
		potionDoubleTapSlotIsUpper = isUpperSlot;
	}
	
	public final function IsPotionDoubleTapRunning() : bool
	{
		return potionDoubleTapTimerRunning;
	}
	
	timer function PotionDoubleTap(dt : float, id : int)
	{
		potionDoubleTapTimerRunning = false;
		OnPotionDrinkInput(potionDoubleTapSlotIsUpper);
	}
	
	public final function OnPotionDrinkInput(fromUpperSlot : bool)
	{
		var slot : EEquipmentSlots;
		
		if(fromUpperSlot)
			slot = GetSelectedPotionSlotUpper();
		else
			slot = GetSelectedPotionSlotLower();
			
		DrinkPotionFromSlot(slot);
	}
	
	public final function OnPotionDrinkKeyboardsInput(slot : EEquipmentSlots)
	{
		DrinkPotionFromSlot(slot);
	}
	
	private function DrinkPotionFromSlot(slot : EEquipmentSlots):void
	{
		var item : SItemUniqueId;		
		var hud : CR4ScriptedHud;
		var module : CR4HudModuleItemInfo;
		
		GetItemEquippedOnSlot(slot, item);
		if(inv.ItemHasTag(item, 'Edibles'))
		{
			ConsumeItem( item );
		}
		else
		{			
			if (ToxicityLowEnoughToDrinkPotion(slot))
			{
				DrinkPreparedPotion(slot);
			}
			else
			{
				SendToxicityTooHighMessage();
			}
		}
		
		hud = (CR4ScriptedHud)theGame.GetHud(); 
		if ( hud ) 
		{ 
			module = (CR4HudModuleItemInfo)hud.GetHudModule("ItemInfoModule");
			if( module )
			{
				module.ForceShowElement();
			}
		}
	}
	
	private function SendToxicityTooHighMessage()
	{
		var messageText : string;
		var language : string;
		var audioLanguage : string;
		
		if (GetHudMessagesSize() < 2)
		{
			messageText = GetLocStringByKeyExt("menu_cannot_perform_action_now") + " " + GetLocStringByKeyExt("panel_common_statistics_tooltip_current_toxicity");
			
			theGame.GetGameLanguageName(audioLanguage,language);
			if (language == "AR")
			{
				messageText += (int)(abilityManager.GetStat(BCS_Toxicity, false)) + " / " +  (int)(abilityManager.GetStatMax(BCS_Toxicity)) + " :";
			}
			else
			{
				messageText += ": " + (int)(abilityManager.GetStat(BCS_Toxicity, false)) + " / " +  (int)(abilityManager.GetStatMax(BCS_Toxicity));
			}
			
			DisplayHudMessage(messageText);
		}
		theSound.SoundEvent("gui_global_denied");
	}
	
	public final function GetSelectedPotionSlotUpper() : EEquipmentSlots
	{
		return selectedPotionSlotUpper;
	}
	
	public final function GetSelectedPotionSlotLower() : EEquipmentSlots
	{
		return selectedPotionSlotLower;
	}
	
	//Flips selected potion between two slots (upper or lower). Returns true if flip actually occured.
	public final function FlipSelectedPotion(isUpperSlot : bool) : bool
	{
		if(isUpperSlot)
		{
			if(selectedPotionSlotUpper == EES_Potion1 && IsAnyItemEquippedOnSlot(EES_Potion3))
			{
				selectedPotionSlotUpper = EES_Potion3;
				return true;
			}
			else if(selectedPotionSlotUpper == EES_Potion3 && IsAnyItemEquippedOnSlot(EES_Potion1))
			{
				selectedPotionSlotUpper = EES_Potion1;
				return true;
			}
		}
		else
		{
			if(selectedPotionSlotLower == EES_Potion2 && IsAnyItemEquippedOnSlot(EES_Potion4))
			{
				selectedPotionSlotLower = EES_Potion4;
				return true;
			}
			else if(selectedPotionSlotLower == EES_Potion4 && IsAnyItemEquippedOnSlot(EES_Potion2))
			{
				selectedPotionSlotLower = EES_Potion2;
				return true;
			}
		}
		
		return false;
	}
	
	public final function AddBombThrowDelay(bombId : SItemUniqueId)
	{
		var slot : EEquipmentSlots;
		
		slot = GetItemSlot(bombId);
		
		if(slot == EES_Unused)
			return;
			
		if(slot == EES_Petard1 || slot == EES_Quickslot1)
		{
			remainingBombThrowDelaySlot1 = theGame.params.BOMB_THROW_DELAY;
			AddTimer('BombDelay1', 0.1, true);
		}
		else if(slot == EES_Petard2 || slot == EES_Quickslot2)
		{
			remainingBombThrowDelaySlot2 = theGame.params.BOMB_THROW_DELAY;
			AddTimer('BombDelay2', 0.1, true);
		}
	}
	
	public final function GetBombDelay(slot : EEquipmentSlots) : float
	{
		if(slot == EES_Petard1 || slot == EES_Quickslot1)
			return remainingBombThrowDelaySlot1;
		else if(slot == EES_Petard2 || slot == EES_Quickslot2)
			return remainingBombThrowDelaySlot2;
			
		return 0;
	}
	
	timer function BombDelay1(dt : float, id : int)
	{
		remainingBombThrowDelaySlot1 -= dt;
		
		if(remainingBombThrowDelaySlot1 <= 0)
			RemoveTimer('BombDelay1');
	}
	
	timer function BombDelay2(dt : float, id : int)
	{
		remainingBombThrowDelaySlot2 -= dt;
		
		if(remainingBombThrowDelaySlot2 <= 0)
			RemoveTimer('BombDelay2');
	}
	
	public function ResetCharacterDev()
	{
		//char dev mutagens
		UnequipItemFromSlot(EES_SkillMutagen1);
		UnequipItemFromSlot(EES_SkillMutagen2);
		UnequipItemFromSlot(EES_SkillMutagen3);
		UnequipItemFromSlot(EES_SkillMutagen4);
		
		Debug_ClearCharacterDevelopment();
		levelManager.ResetCharacterDev();	
	}
	
	public function ConsumeItem( itemId : SItemUniqueId ) : bool
	{
		var itemName : name;
		var removedItem, willRemoveItem : bool;
		var edibles : array<SItemUniqueId>;
		var toSlot : EEquipmentSlots;
		var i : int;
		var equippedNewEdible : bool;
		
		itemName = inv.GetItemName( itemId );
		
		if (itemName == 'q111_imlerith_acorn' ) // MEGA HACK STARTS
		{
			AddPoints(ESkillPoint, 2, true);
			removedItem = inv.RemoveItem( itemId, 1 );
			theGame.GetGuiManager().ShowNotification( GetLocStringByKeyExt("panel_character_popup_title_buy_skill") + "<br>" + GetLocStringByKeyExt("panel_character_availablepoints") + " +2");
			theSound.SoundEvent("gui_character_buy_skill"); // #J Not sure if best sound, but its better than no sound
		} 
		else if ( itemName == 'Clearing Potion' ) 
		{
			ResetCharacterDev();
			removedItem = inv.RemoveItem( itemId, 1 );
			theGame.GetGuiManager().ShowNotification( GetLocStringByKeyExt("panel_character_popup_character_cleared") );
			theSound.SoundEvent("gui_character_synergy_effect"); // #J Not sure if best sound, but its better than no sound
		}
		else if(itemName == 'Wolf Hour')
		{
			removedItem = inv.RemoveItem( itemId, 1 );
			theSound.SoundEvent("gui_character_synergy_effect"); // #J Not sure if best sound, but its better than no sound
			AddEffectDefault(EET_WolfHour, thePlayer, 'wolf hour');
		}
		else
		{
			willRemoveItem = inv.GetItemQuantity(itemId) == 1 && !inv.ItemHasTag(itemId, 'InfiniteUse');
			
			if(willRemoveItem)
				toSlot = GetItemSlot(itemId);
				
			removedItem = super.ConsumeItem(itemId);
			
			if(willRemoveItem && removedItem)
			{
				edibles = inv.GetItemsByTag('Edibles');
				equippedNewEdible = false;
				
				//look for non-alcohol
				for(i=0; i<edibles.Size(); i+=1)
				{
					if(!IsItemEquipped(edibles[i]) && !inv.ItemHasTag(edibles[i], 'Alcohol') && inv.GetItemName(edibles[i]) != 'Clearing Potion' && inv.GetItemName(edibles[i]) != 'Wolf Hour')
					{
						EquipItemInGivenSlot(edibles[i], toSlot, true, false);
						equippedNewEdible = true;
						break;
					}
				}
				
				//take alco if only has alco
				if(!equippedNewEdible)
				{
					for(i=0; i<edibles.Size(); i+=1)
					{
						if(!IsItemEquipped(edibles[i]) && inv.GetItemName(edibles[i]) != 'Clearing Potion' && inv.GetItemName(edibles[i]) != 'Wolf Hour')
						{
							EquipItemInGivenSlot(edibles[i], toSlot, true, false);
							break;
						}
					}
				}
			}
		}
		
		return removedItem;
	}
	
	//returns item ID (or empty if none) of item that can be used to refill alchemical items in meditation
	public final function GetAlcoholForAlchemicalItemsRefill() : SItemUniqueId
	{
		var alcos : array<SItemUniqueId>;
		var id : SItemUniqueId;
		var i, price, minPrice : int;
		
		alcos = inv.GetItemsByTag(theGame.params.TAG_ALCHEMY_REFILL_ALCO);
		
		if(alcos.Size() > 0)
		{
			if(inv.ItemHasTag(alcos[0], theGame.params.TAG_INFINITE_USE))
				return alcos[0];
				
			minPrice = inv.GetItemPrice(alcos[0]);
			price = minPrice;
			id = alcos[0];
			
			for(i=1; i<alcos.Size(); i+=1)
			{
				if(inv.ItemHasTag(alcos[i], theGame.params.TAG_INFINITE_USE))
					return alcos[i];
				
				price = inv.GetItemPrice(alcos[i]);
				
				if(price < minPrice)
				{
					minPrice = price;
					id = alcos[i];
				}
			}
			
			return id;
		}
		
		return GetInvalidUniqueId();
	}
	
	public final function ClearPreviouslyUsedBolt()
	{
		previouslyUsedBolt = GetInvalidUniqueId();
	}
	
	//adds and equips infinite bolts of proper type
	public final function AddAndEquipInfiniteBolt(optional forceBodkin : bool, optional forceHarpoon : bool)
	{
		var bolt, bodkins, harpoons : array<SItemUniqueId>;
		var boltItemName : name;
		var i : int;
		
		//failsafe - remove any infinite bolts if they're in inventory for some reason
		bodkins = inv.GetItemsByName('Bodkin Bolt');
		harpoons = inv.GetItemsByName('Harpoon Bolt');
		
		for(i=bodkins.Size()-1; i>=0; i-=1)
			inv.RemoveItem(bodkins[i], inv.GetItemQuantity(bodkins[i]) );
			
		for(i=harpoons.Size()-1; i>=0; i-=1)
			inv.RemoveItem(harpoons[i], inv.GetItemQuantity(harpoons[i]) );
			
		//Check which bolt is needed.
		//Note: all three checks for swimming are NOT guaranteed to work, hence optional force flags
		if(!forceBodkin && (forceHarpoon || GetCurrentStateName() == 'Swimming' || IsSwimming() || IsDiving()) )
		{
			boltItemName = 'Harpoon Bolt';
		}
		else
		{
			boltItemName = 'Bodkin Bolt';
		}
		
		//select previous special ammo
		if(boltItemName == 'Bodkin Bolt' && inv.IsIdValid(previouslyUsedBolt))
		{
			bolt.PushBack(previouslyUsedBolt);
		}
		else
		{
			//add bolt
			bolt = inv.AddAnItem(boltItemName, 1, true, true);
			
			//if harpoon then we store previously used special bolt if any to restore once we leave water
			if(boltItemName == 'Harpoon Bolt')
			{
				GetItemEquippedOnSlot(EES_Bolt, previouslyUsedBolt);
			}
		}
		
		EquipItem(bolt[0], EES_Bolt);
	}
	
	//called when item is added to players inventory through ANY means
	event OnItemGiven(data : SItemChangedData)
	{
		var m_guiManager 	: CR4GuiManager;
		
		super.OnItemGiven(data);
		
		//player object may not exist at this point. As much as impossible that sounds - it does happen (as a result inv is not set)
		if(!inv)
			inv = GetInventory();
		
		//update encumbrance
		if(inv.IsItemEncumbranceItem(data.ids[0]))
			UpdateEncumbrance();
		
		m_guiManager = theGame.GetGuiManager();
		if(m_guiManager)
			m_guiManager.RegisterNewItem(data.ids[0]);	
	}
		
	//checks progress towards FullyArmed achievement and gives it if applicable
	public final function CheckForFullyArmedAchievement()
	{
		if( HasAllItemsFromSet(theGame.params.ITEM_SET_TAG_BEAR) || HasAllItemsFromSet(theGame.params.ITEM_SET_TAG_GRYPHON) || 
			HasAllItemsFromSet(theGame.params.ITEM_SET_TAG_LYNX) || HasAllItemsFromSet(theGame.params.ITEM_SET_TAG_WOLF)
		)
		{
			theGame.GetGamerProfile().AddAchievement(EA_FullyArmed);
		}
	}
	
	//checks if player has all items from witcher set with given tag equipped
	public final function HasAllItemsFromSet(setItemTag : name) : bool
	{
		var item : SItemUniqueId;
		
		if(!GetItemEquippedOnSlot(EES_SteelSword, item) || !inv.ItemHasTag(item, setItemTag))
			return false;
		
		if(!GetItemEquippedOnSlot(EES_SilverSword, item) || !inv.ItemHasTag(item, setItemTag))
			return false;
			
		if(!GetItemEquippedOnSlot(EES_Boots, item) || !inv.ItemHasTag(item, setItemTag))
			return false;
			
		if(!GetItemEquippedOnSlot(EES_Pants, item) || !inv.ItemHasTag(item, setItemTag))
			return false;
			
		if(!GetItemEquippedOnSlot(EES_Gloves, item) || !inv.ItemHasTag(item, setItemTag))
			return false;
			
		if(!GetItemEquippedOnSlot(EES_Armor, item) || !inv.ItemHasTag(item, setItemTag))
			return false;
			
		//hack for some sets having also a crossbow
		if(setItemTag == theGame.params.ITEM_SET_TAG_BEAR || setItemTag == theGame.params.ITEM_SET_TAG_LYNX)
		{
			if(!GetItemEquippedOnSlot(EES_RangedWeapon, item) || !inv.ItemHasTag(item, setItemTag))
				return false;
		}

		return true;
	}
	
	/* few nice checks are in here so I leave it for the time being
	private function CanPlaceMobileCampfire(out position : Vector) : bool
	{
		var colPos, normal, headPosition : Vector;
		var world : CWorld;
		var test : float;
	
		position = Vector(0, 0, 0);
		
		//check if is allowed to place it at all
		if(GetCurrentStateName() != 'Exploration' || isOnBoat || IsInInterior() || IsInSettlement())
			return false;
			
		//ground test
		position = GetWorldPosition() + VecNormalize(GetHeadingVector()) * 0.5;
		world = theGame.GetWorld();
		
		if(!world.StaticTrace(position + Vector(0,0,1), position - Vector(0,0,0.5), colPos, normal))
			return false;	//void cannot place
			
		position = colPos;	//snapped to ground position
		
		//underwater
		test = world.GetWaterLevel(position, true);
		
		if(position.Z <= world.GetWaterLevel(position, true))
			return false;
		
		//not navigable area - cannot reach so most likely no place
		if(!world.NavigationCircleTest(position, 0.4))
			return false;
			
		//actor occupies that spot - cannot place
		if(!theGame.TestNoCreaturesOnLocation(position, 0.4, this))
			return false;
			
		//behind wall - line of sight check
		headPosition = GetBoneWorldPosition('head');
		if(world.StaticTrace(headPosition, position, colPos, normal ) )
		{
			//small deviation is fine
			if(VecDistance(colPos, position) > 0.1)			
				return false;
		}
			
		return true;
	}
	*/
	
	//returns total armor
	public function GetTotalArmor() : SAbilityAttributeValue
	{
		var armor : SAbilityAttributeValue;
		var armorItem : SItemUniqueId;
		
		armor = super.GetTotalArmor();
		
		if(GetItemEquippedOnSlot(EES_Armor, armorItem))
		{
			//subtract base item armor
			armor -= inv.GetItemAttributeValue(armorItem, theGame.params.ARMOR_VALUE_NAME);
			
			//add real armor
			armor += inv.GetItemArmorTotal(armorItem);			
		}
		
		if(GetItemEquippedOnSlot(EES_Pants, armorItem))
		{
			//subtract base item armor
			armor -= inv.GetItemAttributeValue(armorItem, theGame.params.ARMOR_VALUE_NAME);
			
			//add real armor
			armor += inv.GetItemArmorTotal(armorItem);			
		}
			
		if(GetItemEquippedOnSlot(EES_Boots, armorItem))
		{
			//subtract base item armor
			armor -= inv.GetItemAttributeValue(armorItem, theGame.params.ARMOR_VALUE_NAME);
			
			//add real armor
			armor += inv.GetItemArmorTotal(armorItem);			
		}
			
		if(GetItemEquippedOnSlot(EES_Gloves, armorItem))
		{
			//subtract base item armor
			armor -= inv.GetItemAttributeValue(armorItem, theGame.params.ARMOR_VALUE_NAME);
			
			//add real armor
			armor += inv.GetItemArmorTotal(armorItem);			
		}
			
		return armor;
	}
	
	//Picks random armor item and reduces its durability.
	//Returns slot of the item that got reduced or EES_InvalidSlot if nothing reduced 
	public function ReduceArmorDurability() : EEquipmentSlots
	{
		var r, sum : int;
		var slot : EEquipmentSlots;
		var id : SItemUniqueId;
		var prevDurMult, currDurMult, ratio : float;
	
		//pick item slot
		sum = theGame.params.DURABILITY_ARMOR_CHEST_WEIGHT;
		sum += theGame.params.DURABILITY_ARMOR_PANTS_WEIGHT;
		sum += theGame.params.DURABILITY_ARMOR_GLOVES_WEIGHT;
		sum += theGame.params.DURABILITY_ARMOR_BOOTS_WEIGHT;
		sum += theGame.params.DURABILITY_ARMOR_MISS_WEIGHT;
		
		r = RandRange(sum);
		
		if(r < theGame.params.DURABILITY_ARMOR_CHEST_WEIGHT)
			slot = EES_Armor;
		else if (r < theGame.params.DURABILITY_ARMOR_CHEST_WEIGHT + theGame.params.DURABILITY_ARMOR_PANTS_WEIGHT)
			slot = EES_Pants;
		else if (r < theGame.params.DURABILITY_ARMOR_CHEST_WEIGHT + theGame.params.DURABILITY_ARMOR_PANTS_WEIGHT + theGame.params.DURABILITY_ARMOR_GLOVES_WEIGHT)
			slot = EES_Gloves;
		else if (r < theGame.params.DURABILITY_ARMOR_CHEST_WEIGHT + theGame.params.DURABILITY_ARMOR_PANTS_WEIGHT + theGame.params.DURABILITY_ARMOR_GLOVES_WEIGHT + theGame.params.DURABILITY_ARMOR_BOOTS_WEIGHT)
			slot = EES_Boots;
		else
			return EES_InvalidSlot;					//theGame.params.DURABILITY_ARMOR_MISS_WEIGHT
		
		GetItemEquippedOnSlot(slot, id);				
		ratio = inv.GetItemDurabilityRatio(id);		//ratio before reduction
		if(inv.ReduceItemDurability(id))			//auto-handles invalid id and no defined durability
		{
			prevDurMult = theGame.params.GetDurabilityMultiplier(ratio, false);
			
			ratio = inv.GetItemDurabilityRatio(id);
			currDurMult = theGame.params.GetDurabilityMultiplier(ratio, false);
			
			if(currDurMult != prevDurMult)
			{
				//if durability threshold changed then recalc resists
				
				//currently affects only armor
				//((W3PlayerAbilityManager)abilityManager).RecalcItemResistDurability(slot, id);
			}
				
			return slot;
		}
		
		return EES_InvalidSlot;
	}
	
	//returns true if item was dismantled
	public function DismantleItem(dismantledItem : SItemUniqueId, toolItem : SItemUniqueId) : bool
	{
		var parts : array<SItemParts>;
		var i : int;
		
		if(!inv.IsItemDismantleKit(toolItem))
			return false;
		
		parts = inv.GetItemRecyclingParts(dismantledItem);
		
		if(parts.Size() <= 0)
			return false;
			
		for(i=0; i<parts.Size(); i+=1)
			inv.AddAnItem(parts[i].itemName, parts[i].quantity, true, false);
			
		inv.RemoveItem(toolItem);
		inv.RemoveItem(dismantledItem);
		return true;
	}
	
	//gets item from given slot to out param *item*, returns true if the ID is valid
	public function GetItemEquippedOnSlot(slot : EEquipmentSlots, out item : SItemUniqueId) : bool
	{
		if(slot == EES_InvalidSlot || slot < 0 || slot > EnumGetMax('EEquipmentSlots'))
			return false;
		
		item = itemSlots[slot];
		
		return inv.IsIdValid(item);
	}
	
	//returns slot on which this item is equipped or invalid if this item is not equipped or player does not have it
	public function GetItemSlotByItemName(itemName : name) : EEquipmentSlots
	{
		var ids : array<SItemUniqueId>;
		var i : int;
		var slot : EEquipmentSlots;
		
		ids = inv.GetItemsByName(itemName);
		for(i=0; i<ids.Size(); i+=1)
		{
			slot = GetItemSlot(ids[i]);
			if(slot != EES_InvalidSlot)
				return slot;
		}
		
		return EES_InvalidSlot;
	}
	
	//returns slot on which this item is equipped or invalid if this item is not equipped or item id is invalid
	public function GetItemSlot(item : SItemUniqueId) : EEquipmentSlots
	{
		var i : int;
		
		if(!inv.IsIdValid(item))
			return EES_InvalidSlot;
			
		for(i=0; i<itemSlots.Size(); i+=1)
			if(itemSlots[i] == item)
				return i;
		
		return EES_InvalidSlot;
	}
	
	public function GetEquippedItems() : array<SItemUniqueId>
	{
		return itemSlots;
	}
	
	public function IsItemEquipped(item : SItemUniqueId) : bool
	{
		if(!inv.IsIdValid(item))
			return false;
			
		return itemSlots.Contains(item);
	}
	
	//returns true if any item is equipped on given slot
	public function IsAnyItemEquippedOnSlot(slot : EEquipmentSlots) : bool
	{
		if(slot == EES_InvalidSlot || slot < 0 || slot > EnumGetMax('EEquipmentSlots'))
			return false;
			
		return inv.IsIdValid(itemSlots[slot]);
	}
	
	//returns next free quickslot or EES_InvalidSlot if all are occupied
	public function GetFreeQuickslot() : EEquipmentSlots
	{
		if(!inv.IsIdValid(itemSlots[EES_Quickslot1]))		return EES_Quickslot1;
		if(!inv.IsIdValid(itemSlots[EES_Quickslot2]))		return EES_Quickslot2;
		/*if(!inv.IsIdValid(itemSlots[EES_Quickslot3]))		return EES_Quickslot3;
		if(!inv.IsIdValid(itemSlots[EES_Quickslot4]))		return EES_Quickslot4;
		if(!inv.IsIdValid(itemSlots[EES_Quickslot5]))		return EES_Quickslot5;*/
		
		return EES_InvalidSlot;
	}
	
	// Used by things like cut scenes which may mount things independently
	event OnEquipItemRequested(item : SItemUniqueId, ignoreMount : bool)
	{
		var slot : EEquipmentSlots;
		
		if(inv.IsIdValid(item))
		{
			slot = inv.GetSlotForItemId(item);
				
			if (slot != EES_InvalidSlot)
			{
				//#J [WARNING] might want to eventually add a parameter for toHand, currently ignoreMount is always false so it doesn't matter 
				//(trying to fix P0 quickly so covering hypothetical uses that may never come to be seems like waste of time)
				EquipItemInGivenSlot(item, slot, ignoreMount);
			}
		}
	} 
	
	event OnUnequipItemRequested(item : SItemUniqueId)
	{
		UnequipItem(item);
	}
	
	/*
		Equips given item. If you don't provide the slot it will find appropriate one and equip there. 
		If it's a multiple slot group (e.g. quickslots or potion slots) it will try to find next free slot. If it cannot then the default slot
		will be used.
		
		If toHand is set then given item will be made *held*, that is it's entity will be put in witcher hands.
		
		Returns true if item was successfully equipped.
	*/
	public function EquipItem(item : SItemUniqueId, optional slot : EEquipmentSlots, optional toHand : bool) : bool
	{
		if(!inv.IsIdValid(item))
			return false;
			
		if(slot == EES_InvalidSlot)
		{
			slot = inv.GetSlotForItemId(item);
			
			if(slot == EES_InvalidSlot)
				return false;
		}
		
		return EquipItemInGivenSlot(item, slot, false, toHand);
	}
	
	protected function ShouldMount(slot : EEquipmentSlots, item : SItemUniqueId, category : name):bool
	{
		//AK: don't mount potion mutagens in inventory	
		//PB: don't mount usable items (will be mounted on use)
		return !IsSlotPotionMutagen(slot) && category != 'usable' && category != 'potion' && category != 'petard' && !inv.ItemHasTag(item, 'PlayerUnwearable');
	}
		
	protected function ShouldMountItemWithName( itemName: name ): bool
	{
		var slot : EEquipmentSlots;
		var items : array<SItemUniqueId>;
		var category : name;
		var i : int;
		
		items = inv.GetItemsByName( itemName );
		
		category = inv.GetItemCategory( items[0] );
		
		slot = GetItemSlot( items[0] );
		
		return ShouldMount( slot, items[0], category );
	}	
	
	public function GetMountableItems( out items : array< SItemUniqueId > )
	{
		var i : int;
		var mountable : bool;
		var mountableItems : array< SItemUniqueId >;
		var slot : EEquipmentSlots;
		var category : name;
		var item: SItemUniqueId;
		
		for ( i = 0; i < items.Size(); i += 1 )
		{
			item = items[i];
		
			category = inv.GetItemCategory( item );
		
			slot = GetItemSlot( item );
		
			mountable = ShouldMount( slot, item, category );
		
			if ( mountable )
			{
				mountableItems.PushBack( items[ i ] );
			}
		}
		items = mountableItems;
	}
	
	public final function SwapEquippedItems(slot1 : EEquipmentSlots, slot2 : EEquipmentSlots)
	{
		var temp : SItemUniqueId;
		var pam : W3PlayerAbilityManager;
		
		temp = itemSlots[slot1];
		itemSlots[slot1] = itemSlots[slot2];
		itemSlots[slot2] = temp;
		
		if(IsSlotSkillMutagen(slot1))
		{
			pam = (W3PlayerAbilityManager)abilityManager;
			if(pam)
				pam.OnSwappedMutagensPost(itemSlots[slot1], itemSlots[slot2]);
		}
	}
	
	public function EquipItemInGivenSlot(item : SItemUniqueId, slot : EEquipmentSlots, ignoreMounting : bool, optional toHand : bool) : bool
	{			
		var i, groupID : int;
		var fistsID : array<SItemUniqueId>;
		var pam : W3PlayerAbilityManager;
		var isSkillMutagen : bool;		
		var armorEntity : CItemEntity;
		var armorMeshComponent : CComponent;
		var armorSoundIdentification : name;
		var category : name;
		var prevSkillColor : ESkillColor;
		var containedAbilities : array<name>;
		var dm : CDefinitionsManagerAccessor;
		var armorType : EArmorType;
		var otherMask, previousItemInSlot : SItemUniqueId;
		var tutStatePot : W3TutorialManagerUIHandlerStatePotions;
		var tutStateFood : W3TutorialManagerUIHandlerStateFood;
		var tutStateSecondPotionEquip : W3TutorialManagerUIHandlerStateSecondPotionEquip;
		var boltItem : SItemUniqueId;
		
		if(!inv.IsIdValid(item))
		{
			LogAssert(false, "W3PlayerWitcher.EquipItemInGivenSlot: invalid item");
			return false;
		}
		if(slot == EES_InvalidSlot || slot == EES_HorseBlinders || slot == EES_HorseSaddle || slot == EES_HorseBag || slot == EES_HorseTrophy)
		{
			LogAssert(false, "W3PlayerWitcher.EquipItem: Cannot equip item <<" + inv.GetItemName(item) + ">> - provided slot <<" + slot + ">> is invalid");
			return false;
		}
		if(itemSlots[slot] == item)
		{
			return true;
		}	
		
		if(!HasRequiredLevelToEquipItem(item))
		{
			//player does not meet level requirement
			return false;
		}
		
		if(inv.ItemHasTag(item, 'PhantomWeapon') && !GetPhantomWeaponMgr())
		{
			InitPhantomWeaponMgr();
		}
		
		//swapping items - just reassign in slots, don't do any logic
		previousItemInSlot = itemSlots[slot];
		if(/*inv.IsIdValid(previousItemInSlot) &&*/ IsItemEquipped(item)) // #Y potions and bombs can be swapped with empty item
		{
			SwapEquippedItems(slot, GetItemSlot(item));
			return true;
		}
		
		//skill mutagens
		isSkillMutagen = IsSlotSkillMutagen(slot);
		if(isSkillMutagen)
		{
			pam = (W3PlayerAbilityManager)abilityManager;
			if(!pam.IsSkillMutagenSlotUnlocked(slot))
			{
				return false;
			}
		}
		
		//unequip previous item if slot is occupied
		if(inv.IsIdValid(previousItemInSlot))
		{			
			if(!UnequipItemFromSlot(slot, true))
			{
				LogAssert(false, "W3PlayerWitcher.EquipItem: Cannot equip item <<" + inv.GetItemName(item) + ">> !!");
				return false;
			}
		}
		
		//if it's a mask unequip other equipped mask
		if(inv.IsItemMask(item))
		{
			if(slot == EES_Quickslot1)
				GetItemEquippedOnSlot(EES_Quickslot2, otherMask);
			else
				GetItemEquippedOnSlot(EES_Quickslot1, otherMask);
				
			if(inv.IsItemMask(otherMask))
				UnequipItem(otherMask);
		}
		
		if(isSkillMutagen)
		{
			groupID = pam.GetSkillGroupIdOfMutagenSlot(slot);
			prevSkillColor = pam.GetSkillGroupColor(groupID);
		}
		
		itemSlots[slot] = item;
		
		category = inv.GetItemCategory( item );
	
		//potion mutagens
		if( !ignoreMounting && ShouldMount(slot, item, category) )
		{
			// force mounting mutagen skills (so that other mutagen skills won't be unmounted)
			inv.MountItem( item, toHand, IsSlotSkillMutagen( slot ) );
		}		
		
		theTelemetry.LogWithLabelAndValue( TE_INV_ITEM_EQUIPPED, inv.GetItemName(item), slot );
				
		if(slot == EES_RangedWeapon)
		{			
			rangedWeapon = ( Crossbow )( inv.GetItemEntityUnsafe(item) );
			if(!rangedWeapon)
				AddTimer('DelayedOnItemMount', 0.1, true);
			
			if ( IsSwimming() || IsDiving() )
			{
				GetItemEquippedOnSlot(EES_Bolt, boltItem);
				
				if(inv.IsIdValid(boltItem))
				{
					if ( !inv.ItemHasTag(boltItem, 'UnderwaterAmmo' ))
					{
						AddAndEquipInfiniteBolt(false, true);
					}
				}
				else if(!IsAnyItemEquippedOnSlot(EES_Bolt))
				{
					AddAndEquipInfiniteBolt(false, true);
				}
			}
			//default ammo
			else if(!IsAnyItemEquippedOnSlot(EES_Bolt))
				AddAndEquipInfiniteBolt();
		}
		else if(slot == EES_Bolt)
		{
			if(rangedWeapon)
			{	if ( !IsSwimming() || !IsDiving() )
				{
					rangedWeapon.OnReplaceAmmo();
					rangedWeapon.OnWeaponReload();
				}
				else
				{
					DisplayHudMessage(GetLocStringByKeyExt( "menu_cannot_perform_action_now" ));
				}
			}
		}		
		//skill mutagen
		else if(isSkillMutagen)
		{			
			pam.OnSkillMutagenEquipped(item, slot, prevSkillColor);
			LogSkillColors("Mutagen <<" + inv.GetItemName(item) + ">> equipped to slot <<" + slot + ">>");
			LogSkillColors("Group bonus color is now <<" + pam.GetSkillGroupColor(groupID) + ">>");
			LogSkillColors("");
		}
		else if(slot == EES_Gloves && HasWeaponDrawn(false))
		{
			PlayRuneword4FX(PW_Steel);
			PlayRuneword4FX(PW_Silver);
		}

		//fist fight bonus ability
		if(inv.ItemHasAbility(item, 'MA_HtH'))
		{
			inv.GetItemContainedAbilities(item, containedAbilities);
			fistsID = inv.GetItemsByName('fists');
			dm = theGame.GetDefinitionsManager();
			for(i=0; i<containedAbilities.Size(); i+=1)
			{
				if(dm.AbilityHasTag(containedAbilities[i], 'MA_HtH'))
				{					
					inv.AddItemCraftedAbility(fistsID[0], containedAbilities[i], true);
				}
			}
		}		
		
		//perk armor bonuses
		if(inv.IsItemAnyArmor(item))
		{
			armorType = inv.GetArmorType(item);
			pam = (W3PlayerAbilityManager)abilityManager;
			
			if(armorType == EAT_Light)
			{
				if(CanUseSkill(S_Perk_05))
					pam.UpdatePerkArmorBonus(S_Perk_05, true);
			}
			else if(armorType == EAT_Medium)
			{
				if(CanUseSkill(S_Perk_06))
					pam.UpdatePerkArmorBonus(S_Perk_06, true);
			}
			else if(armorType == EAT_Heavy)
			{
				if(CanUseSkill(S_Perk_07))
					pam.UpdatePerkArmorBonus(S_Perk_07, true);
			}
		}
		
		// report global event
		theGame.GetGlobalEventsManager().OnScriptedEvent( SEC_OnItemEquipped );
	
		//potion equip tutorial	
		if(ShouldProcessTutorial('TutorialPotionCanEquip3'))
		{
			if(IsSlotPotionSlot(slot))
			{
				tutStatePot = (W3TutorialManagerUIHandlerStatePotions)theGame.GetTutorialSystem().uiHandler.GetCurrentState();
				if(tutStatePot)
				{
					tutStatePot.OnPotionEquipped(inv.GetItemName(item));
				}
				
				tutStateSecondPotionEquip = (W3TutorialManagerUIHandlerStateSecondPotionEquip)theGame.GetTutorialSystem().uiHandler.GetCurrentState();
				if(tutStateSecondPotionEquip)
				{
					tutStateSecondPotionEquip.OnPotionEquipped(inv.GetItemName(item));
				}
				
			}
		}
		//food equip tutorial	
		if(ShouldProcessTutorial('TutorialFoodSelectTab'))
		{
			if( IsSlotPotionSlot(slot) && inv.IsItemFood(item))
			{
				tutStateFood = (W3TutorialManagerUIHandlerStateFood)theGame.GetTutorialSystem().uiHandler.GetCurrentState();
				if(tutStateFood)
				{
					tutStateFood.OnFoodEquipped();
				}
			}
		}
		
		//achievement for any fully equipped witcher set
		if(inv.IsItemSetItem(item))
		{
			CheckForFullyArmedAchievement();	
		}
		
		return true;
	}

	private function CheckHairItem()
	{
		var ids : array<SItemUniqueId>;
		var i   : int;
		var itemName : name;
		var hairApplied : bool;
		
		ids = inv.GetItemsByCategory('hair');
		
		for(i=0; i<ids.Size(); i+= 1)
		{
			itemName = inv.GetItemName( ids[i] );
			
			if( itemName != 'Preview Hair' )
			{
				if( hairApplied == false )
				{
					inv.MountItem( ids[i], false );
					hairApplied = true;
				}
				else
				{
					inv.RemoveItem( ids[i], 1 );
				}
				
			}
		}
		
		if( hairApplied == false )
		{
			ids = inv.AddAnItem('Half With Tail Hairstyle', 1, true, false);
			inv.MountItem( ids[0], false );
		}
		
	}

	//Tries to set crossbow object untill it succeeds
	timer function DelayedOnItemMount( dt : float, id : int )
	{
		var crossbowID : SItemUniqueId;
		var invent : CInventoryComponent;
		
		invent = GetInventory();
		if(!invent)
			return;	//inventory component not streamed yet
		
		//get crossbow ID
		GetItemEquippedOnSlot(EES_RangedWeapon, crossbowID);
				
		if(invent.IsIdValid(crossbowID))
		{
			//if has crossbow, get object
			rangedWeapon = ( Crossbow )(invent.GetItemEntityUnsafe(crossbowID) );
			
			if(rangedWeapon)
			{
				//if succeeded finish, else will loop again
				RemoveTimer('DelayedOnItemMount');
			}
		}
		else
		{
			//if no crossbow then nothing to set - abort
			RemoveTimer('DelayedOnItemMount');
		}
	}

	public function GetHeldItems() : array<SItemUniqueId>
	{
		var items : array<SItemUniqueId>;
		var item : SItemUniqueId;
	
		if( inv.GetItemEquippedOnSlot(EES_SilverSword, item) && inv.IsItemHeld(item))
			items.PushBack(item);
			
		if( inv.GetItemEquippedOnSlot(EES_SteelSword, item) && inv.IsItemHeld(item))
			items.PushBack(item);

		if( inv.GetItemEquippedOnSlot(EES_RangedWeapon, item) && inv.IsItemHeld(item))
			items.PushBack(item);

		if( inv.GetItemEquippedOnSlot(EES_Quickslot1, item) && inv.IsItemHeld(item))
			items.PushBack(item);

		if( inv.GetItemEquippedOnSlot(EES_Quickslot2, item) && inv.IsItemHeld(item))
			items.PushBack(item);

		if( inv.GetItemEquippedOnSlot(EES_Petard1, item) && inv.IsItemHeld(item))
			items.PushBack(item);

		if( inv.GetItemEquippedOnSlot(EES_Petard2, item) && inv.IsItemHeld(item))
			items.PushBack(item);

		return items;			
	}
	
	/*
		Unequips item from given slot. Returns true if item was successfully removed.
	*/
	public function UnequipItemFromSlot(slot : EEquipmentSlots, optional reequipped : bool) : bool
	{
		var item, bolts : SItemUniqueId;
		var items : array<SItemUniqueId>;
		var retBool : bool;
		var fistsID, bolt : array<SItemUniqueId>;
		var i, groupID : int;
		var pam : W3PlayerAbilityManager;
		var prevSkillColor : ESkillColor;
		var containedAbilities : array<name>;
		var dm : CDefinitionsManagerAccessor;
		var armorType : EArmorType;
		var isSwimming : bool;
		var hud 				: CR4ScriptedHud;
		var damagedItemModule 	: CR4HudModuleDamagedItems;
		
		if(slot == EES_InvalidSlot || slot < 0 || slot > EnumGetMax('EEquipmentSlots') || !inv.IsIdValid(itemSlots[slot]))
			return false;
			
		//remove mutagen potion effect
		if(IsSlotSkillMutagen(slot))
		{
			//get current color bonus
			pam = (W3PlayerAbilityManager)abilityManager;
			groupID = pam.GetSkillGroupIdOfMutagenSlot(slot);
			prevSkillColor = pam.GetSkillGroupColor(groupID);
		}
			
		item = itemSlots[slot];
		itemSlots[slot] = GetInvalidUniqueId();
		
		// unequiping swords
		if(inv.ItemHasTag( item, 'PhantomWeapon' ) && GetPhantomWeaponMgr())
		{
			DestroyPhantomWeaponMgr();
		}
		
		//manage crosssbow and bolts under water
		
		//unequipping crossbow
		if(slot == EES_RangedWeapon)
		{
			
			this.OnRangedForceHolster( true, true );
			rangedWeapon.ClearDeployedEntity(true);
			rangedWeapon = NULL;
		
			//if has equipped some infinite bolts, remove them
			if(GetItemEquippedOnSlot(EES_Bolt, bolts))
			{
				if(inv.ItemHasTag(bolts, theGame.params.TAG_INFINITE_AMMO))
				{
					inv.RemoveItem(bolts, inv.GetItemQuantity(bolts) );
				}
			}
		}
		else if(IsSlotSkillMutagen(slot))
		{			
			pam.OnSkillMutagenUnequipped(item, slot, prevSkillColor);
			LogSkillColors("Mutagen <<" + inv.GetItemName(item) + ">> unequipped from slot <<" + slot + ">>");
			LogSkillColors("Group bonus color is now <<" + pam.GetSkillGroupColor(groupID) + ">>");
			LogSkillColors("");
		}
		
		//usable items
		if(currentlyEquipedItem == item)
		{
			currentlyEquipedItem = GetInvalidUniqueId();
			RaiseEvent('ForcedUsableItemUnequip');
		}
		if(currentlyEquipedItemL == item)
		{
			if ( currentlyUsedItemL )
			{
				currentlyUsedItemL.OnHidden( this );
			}
			HideUsableItem ( true );
		}
				
		//unmount if mountable item
		if( !IsSlotPotionMutagen(slot) )
		{
			GetInventory().UnmountItem(item, true);
		}
		
		retBool = true;
				
		//unequipping bolts
		if(IsAnyItemEquippedOnSlot(EES_RangedWeapon) && slot == EES_Bolt)
		{			
			if(inv.ItemHasTag(item, theGame.params.TAG_INFINITE_AMMO))
			{
				//unequipping infinite ammo bolts
				inv.RemoveItem(item, inv.GetItemQuantityByName( inv.GetItemName(item) ) );
			}
			else if (!reequipped)
			{
				//unequipping finite ammo bolts
				AddAndEquipInfiniteBolt();
			}
		}
		
		//if weapon was held in hand then update the character pose / combat state
		if(slot == EES_SilverSword  || slot == EES_SteelSword)
		{
			OnEquipMeleeWeapon(PW_None, true);
		}
		
		if( /*IsSlotQuickslot(slot) || */ GetSelectedItemId() == item )
		{
			ClearSelectedItemId();
		}
		
		if(inv.IsItemBody(item))
		{
			retBool = true;
		}		
		
		if(retBool && !reequipped)
		{
			theTelemetry.LogWithLabelAndValue( TE_INV_ITEM_UNEQUIPPED, inv.GetItemName(item), slot );
			
			//remove enhanced item buffs
			if(slot == EES_SteelSword && !IsAnyItemEquippedOnSlot(EES_SilverSword))
			{
				RemoveBuff(EET_EnhancedWeapon);
			}
			else if(slot == EES_SilverSword && !IsAnyItemEquippedOnSlot(EES_SteelSword))
			{
				RemoveBuff(EET_EnhancedWeapon);
			}
			else if(inv.IsItemAnyArmor(item))
			{
				if( !IsAnyItemEquippedOnSlot(EES_Armor) && !IsAnyItemEquippedOnSlot(EES_Gloves) && !IsAnyItemEquippedOnSlot(EES_Boots) && !IsAnyItemEquippedOnSlot(EES_Pants))
					RemoveBuff(EET_EnhancedArmor);
			}
		}
		
		//fist fight bonus ability
		if(inv.ItemHasAbility(item, 'MA_HtH'))
		{
			inv.GetItemContainedAbilities(item, containedAbilities);
			fistsID = inv.GetItemsByName('fists');
			dm = theGame.GetDefinitionsManager();
			for(i=0; i<containedAbilities.Size(); i+=1)
			{
				if(dm.AbilityHasTag(containedAbilities[i], 'MA_HtH'))
				{
					inv.RemoveItemCraftedAbility(fistsID[0], containedAbilities[i]);
				}
			}
		}
		
		//perk armor bonuses
		if(inv.IsItemAnyArmor(item))
		{
			armorType = inv.GetArmorType(item);
			pam = (W3PlayerAbilityManager)abilityManager;
			
			if(armorType == EAT_Light || GetCharacterStats().HasAbility('Glyphword 2 _Stats', true))
			{
				if(CanUseSkill(S_Perk_05))
					pam.UpdatePerkArmorBonus(S_Perk_05, false);
			}
			if(armorType == EAT_Medium || GetCharacterStats().HasAbility('Glyphword 3 _Stats', true))
			{
				if(CanUseSkill(S_Perk_06))
					pam.UpdatePerkArmorBonus(S_Perk_06, false);
			}
			if(armorType == EAT_Heavy || GetCharacterStats().HasAbility('Glyphword 4 _Stats', true))
			{
				if(CanUseSkill(S_Perk_07))
					pam.UpdatePerkArmorBonus(S_Perk_07, false);
			}
		}
		
		if( slot == EES_Gloves )
		{
			thePlayer.DestroyEffect('runeword_4');
		}
		
		// Update broken item indicator
		hud = (CR4ScriptedHud)theGame.GetHud();
		damagedItemModule = hud.GetDamagedItemModule();		
		damagedItemModule.OnItemUnequippedFromSlot( slot );		
		
		// report global event
		theGame.GetGlobalEventsManager().OnScriptedEvent( SEC_OnItemEquipped );
		
		return retBool;
	}
		
	public function UnequipItem(item : SItemUniqueId) : bool
	{
		if(!inv.IsIdValid(item))
			return false;
		
		return UnequipItemFromSlot( itemSlots.FindFirst(item) );
	}
	
	public function DropItem( item : SItemUniqueId, quantity : int ) : bool
	{
		if(!inv.IsIdValid(item))
			return false;
		if(IsItemEquipped(item))
			return UnequipItem(item);
		
		return true;
	}	
	
	//Returns true if there is at least one item with given name or category equipped (others with same name might be unequipped)
	public function IsItemEquippedByName(itemName : name) : bool
	{
		var i : int;
	
		for(i=0; i<itemSlots.Size(); i+=1)
			if(inv.GetItemName(itemSlots[i]) == itemName)
				return true;

		return false;
	}

	//Returns true if there is at least one item of given category equipped (others with same name might be unequipped)
	public function IsItemEquippedByCategoryName(categoryName : name) : bool
	{
		var i : int;
	
		for(i=0; i<itemSlots.Size(); i+=1)
			if(inv.GetItemCategory(itemSlots[i]) == categoryName)
				return true;
				
		return false;
	}
	
	public function GetMaxRunEncumbrance(out usesHorseBonus : bool) : float
	{
		var value : float;
		
		value = CalculateAttributeValue(GetHorseManager().GetHorseAttributeValue('encumbrance', false));
		usesHorseBonus = (value > 0);
		value += CalculateAttributeValue( GetAttributeValue('encumbrance') );
		
		return value;
	}
		
	public function GetEncumbrance() : float
	{
		var i: int;
		var encumbrance : float;
		var items : array<SItemUniqueId>;
		var inve : CInventoryComponent;
	
		inve = GetInventory();			//called before geralt is spawned -> inv == NULL
		inve.GetAllItems(items);

		for(i=0; i<items.Size(); i+=1)
		{
			if( inv.IsItemEncumbranceItem( items[i] ) )
			{
				encumbrance += inve.GetItemEncumbrance( items[i] );
				//LogPotions("Item: " + inve.GetItemName( items[i] ) + " with Weight: " + inve.GetItemWeight( items[i] ) + " adds Encumberance: " + inve.GetItemEncumbrance(items[i]) + ".");
			}
		}		
		return encumbrance;
	}
	
	//optimize me!
	public function UpdateEncumbrance()
	{
		var temp : bool;
		
		//we add bonus 1 point because UI shows this as int rather than float, so having 150.9 / 150 is shown as 150/150
		//so from player's perspective you should not be overburdened
		if ( GetEncumbrance() >= (GetMaxRunEncumbrance(temp) + 1) )
		{
			if( !HasBuff(EET_OverEncumbered) )
			{
				AddEffectDefault(EET_OverEncumbered, NULL, "OverEncumbered");
			}
		}
		else if(HasBuff(EET_OverEncumbered))
		{
			RemoveAllBuffsOfType(EET_OverEncumbered);
		}
	}
	
	public final function GetSkillGroupIDFromIndex(idx : int) : int
	{
		var pam : W3PlayerAbilityManager;
		
		pam = (W3PlayerAbilityManager)abilityManager;
		if(pam && pam.IsInitialized())
			return pam.GetSkillGroupIDFromIndex(idx);
			
		return -1;
	}
	
	public final function GetSkillGroupColor(groupID : int) : ESkillColor
	{
		var pam : W3PlayerAbilityManager;
		
		pam = (W3PlayerAbilityManager)abilityManager;
		if(pam && pam.IsInitialized())
			return pam.GetSkillGroupColor(groupID);
			
		return SC_None;
	}
	
	public final function GetSkillGroupsCount() : int
	{
		var pam : W3PlayerAbilityManager;
		
		pam = (W3PlayerAbilityManager)abilityManager;
		if(pam && pam.IsInitialized())
			return pam.GetSkillGroupsCount();
			
		return 0;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	//
	// Witcher's Signs
	// 
	////////////////////////////////////////////////////////////////////////////////////////// 
	
	//returns next (left or right) sign type in cycle
	function CycleSelectSign( bIsCyclingLeft : bool ) : ESignType
	{
		var signOrder : array<ESignType>;
		var i : int;
		
		signOrder.PushBack( ST_Yrden );
		signOrder.PushBack( ST_Quen );
		signOrder.PushBack( ST_Igni );
		signOrder.PushBack( ST_Axii );
		signOrder.PushBack( ST_Aard );
			
		for( i = 0; i < signOrder.Size(); i += 1 )
			if( signOrder[i] == equippedSign )
				break;
		
		if(bIsCyclingLeft)
			return signOrder[ (4 + i) % 5 ];	//5+i-1
		else
			return signOrder[ (6 + i) % 5 ];
	}
	
	function ToggleNextSign()
	{
		SetEquippedSign(CycleSelectSign( false ));
		FactsAdd("SignToggled", 1, 1);
	}
	
	function TogglePreviousSign()
	{
		SetEquippedSign(CycleSelectSign( true ));
		FactsAdd("SignToggled", 1, 1);
	}
	
	function ProcessSignEvent( eventName : name ) : bool
	{
		if( currentlyCastSign != ST_None && signs[currentlyCastSign].entity)
		{
			return signs[currentlyCastSign].entity.OnProcessSignEvent( eventName );
		}
		
		return false;
	}
	
	var findActorTargetTimeStamp : float;
	var pcModeChanneledSignTimeStamp	: float;
	event OnProcessCastingOrientation( isContinueCasting : bool )
	{
		var customOrientationTarget : EOrientationTarget;
		var checkHeading 			: float;
		var rotHeading 				: float;
		var playerToHeadingDist 	: float;
		var slideTargetActor		: CActor;
		var newLockTarget			: CActor;
		
		var enableNoTargetOrientation	: bool;
		
		var currTime : float;
		
		enableNoTargetOrientation = true;
		if ( GetDisplayTarget() && this.IsDisplayTargetTargetable() )// && theInput.LastUsedGamepad() )// && ( GetPlayerCombatStance() == PCS_AlertNear || GetPlayerCombatStance() == PCS_Guarded ) ) 
		{		
			enableNoTargetOrientation = false;
			if ( theInput.GetActionValue( 'CastSignHold' ) > 0 || this.IsCurrentSignChanneled() )
			{
				if ( IsPCModeEnabled() )
				{
					if ( EngineTimeToFloat( theGame.GetEngineTime() ) >  pcModeChanneledSignTimeStamp + 1.f )
						enableNoTargetOrientation = true;
				}
				else
				{
					if ( GetCurrentlyCastSign() == ST_Igni || GetCurrentlyCastSign() == ST_Axii )
					{
						slideTargetActor = (CActor)GetDisplayTarget();
						if ( slideTargetActor 
							&& ( !slideTargetActor.GetGameplayVisibility() || !CanBeTargetedIfSwimming( slideTargetActor ) || !slideTargetActor.IsAlive() ) )
						{
							SetSlideTarget( NULL );
							if ( ProcessLockTarget() )
								slideTargetActor = (CActor)slideTarget;
						}				
					
						if ( !slideTargetActor )
						{
							LockToTarget( false );
							enableNoTargetOrientation = true;
						}
						else if ( IsThreat( slideTargetActor ) || GetCurrentlyCastSign() == ST_Axii )
							LockToTarget( true );
						else
						{
							LockToTarget( false );
							enableNoTargetOrientation = true;
						}
					}
				}
			}

			if ( !enableNoTargetOrientation )
			{			
				customOrientationTarget = OT_Actor;
			}
		}
		
		if ( enableNoTargetOrientation )
		{
			if ( GetPlayerCombatStance() == PCS_AlertNear && theInput.GetActionValue( 'CastSignHold' ) > 0 )
			{
				if ( GetDisplayTarget() && !slideTargetActor )
				{
					currTime = EngineTimeToFloat( theGame.GetEngineTime() );
					if ( currTime > findActorTargetTimeStamp + 1.5f )
					{
						findActorTargetTimeStamp = currTime;
						
						newLockTarget = GetScreenSpaceLockTarget( GetDisplayTarget(), 180.f, 1.f, 0.f, true );
						
						if ( newLockTarget && IsThreat( newLockTarget ) && IsCombatMusicEnabled() )
						{
							SetTarget( newLockTarget, true );
							SetMoveTargetChangeAllowed( true );
							SetMoveTarget( newLockTarget );
							SetMoveTargetChangeAllowed( false );
							SetSlideTarget( newLockTarget );							
						}	
					}
				}
				else
					ProcessLockTarget();
			}
			
			if ( wasBRAxisPushed )
				customOrientationTarget = OT_CameraOffset;
			else
			{
				if ( !lastAxisInputIsMovement || theInput.LastUsedPCInput() )
					customOrientationTarget = OT_CameraOffset;
				else if ( theInput.GetActionValue( 'CastSignHold' ) > 0 )
				{
					if ( GetOrientationTarget() == OT_CameraOffset )
						customOrientationTarget = OT_CameraOffset;
					else if ( GetPlayerCombatStance() == PCS_AlertNear || GetPlayerCombatStance() == PCS_Guarded ) 
						customOrientationTarget = OT_CameraOffset;
					else
						customOrientationTarget = OT_Player;	
				}
				else
					customOrientationTarget = OT_CustomHeading;
			}			
		}		
		
		if ( GetCurrentlyCastSign() == ST_Quen )
		{
			if ( theInput.LastUsedPCInput() )
			{
				customOrientationTarget = OT_Camera;
			}
			else if ( IsCurrentSignChanneled() )
			{
				if ( bLAxisReleased )
					customOrientationTarget = OT_Player;
				else
					customOrientationTarget = OT_Camera;
			}
			else 
				customOrientationTarget = OT_Player;
		}	
		
		if ( GetCurrentlyCastSign() == ST_Axii && IsCurrentSignChanneled() )
		{	
			if ( slideTarget && (CActor)slideTarget )
			{
				checkHeading = VecHeading( slideTarget.GetWorldPosition() - this.GetWorldPosition() );
				rotHeading = checkHeading;
				playerToHeadingDist = AngleDistance( GetHeading(), checkHeading );
				
				if ( playerToHeadingDist > 45 )
					SetCustomRotation( 'ChanneledSignAxii', rotHeading, 0.0, 0.5, false );
				else if ( playerToHeadingDist < -45 )
					SetCustomRotation( 'ChanneledSignAxii', rotHeading, 0.0, 0.5, false );					
			}
			else
			{
				checkHeading = VecHeading( theCamera.GetCameraDirection() );
				rotHeading = GetHeading();
				playerToHeadingDist = AngleDistance( GetHeading(), checkHeading );
				
				if ( playerToHeadingDist > 45 )
					SetCustomRotation( 'ChanneledSignAxii', rotHeading - 22.5, 0.0, 0.5, false );
				else if ( playerToHeadingDist < -45 )
					SetCustomRotation( 'ChanneledSignAxii', rotHeading + 22.5, 0.0, 0.5, false );				
			}
		}		
			
		if ( IsActorLockedToTarget() )
			customOrientationTarget = OT_Actor;
		
		AddCustomOrientationTarget( customOrientationTarget, 'Signs' );
		
		if ( customOrientationTarget == OT_CustomHeading )
			SetOrientationTargetCustomHeading( GetCombatActionHeading(), 'Signs' );			
	}
	
	event OnRaiseSignEvent()
	{
		var newTarget : CActor;
	
		if ( ( !IsCombatMusicEnabled() && !CanAttackWhenNotInCombat( EBAT_CastSign, false, newTarget ) ) || ( IsOnBoat() && !IsCombatMusicEnabled() ) )
		{		
			if ( CastSignFriendly() )
				return true;
		}
		else
		{
			RaiseEvent('CombatActionFriendlyEnd');
			SetBehaviorVariable( 'SignNum', (int)equippedSign );
			SetBehaviorVariable( 'combatActionType', (int)CAT_CastSign );

			if ( IsPCModeEnabled() )
				pcModeChanneledSignTimeStamp = EngineTimeToFloat( theGame.GetEngineTime() );
		
			if( RaiseForceEvent('CombatAction') )
			{
				OnCombatActionStart();
				findActorTargetTimeStamp = EngineTimeToFloat( theGame.GetEngineTime() );
				theTelemetry.LogWithValueStr(TE_FIGHT_PLAYER_USE_SIGN, SignEnumToString( equippedSign ));
				return true;
			}
		}
		
		return false;
	}
	
	function CastSignFriendly() : bool
	{
		var actor : CActor;
	
		SetBehaviorVariable( 'combatActionTypeForOverlay', (int)CAT_CastSign );			
		if ( RaiseCombatActionFriendlyEvent() )
		{
			/*if ( bLAxisReleased && slideTarget )
			{
				actor = (CActor)slideTarget;
				if ( actor )
					SetCustomRotation( 'Sign', VecHeading( actor.GetWorldPosition() - GetWorldPosition() ), 0.0f, 0.3f, false );	
			}*/			
			return true;
		}	
		
		return false;
	}
	
	function CastSign() : bool
	{
		var equippedSignStr : string;
		var newSignEnt : W3SignEntity;
		var spawnPos : Vector;
		var slotMatrix : Matrix;
		var target : CActor;
		
		if ( IsInAir() )
		{
			return false;
		}
		
		AddTemporarySkills();
		
		//OnProcessCastingOrientation( false );
		
		if(equippedSign == ST_Aard)
		{
			CalcEntitySlotMatrix('l_weapon', slotMatrix);
			spawnPos = MatrixGetTranslation(slotMatrix);
		}
		else
		{
			spawnPos = GetWorldPosition();
		}
		
		if( equippedSign == ST_Aard || equippedSign == ST_Igni )
		{
			target = GetTarget();
			if(target)
				target.SignalGameplayEvent( 'DodgeSign' );
		}
		
		newSignEnt = (W3SignEntity)theGame.CreateEntity( signs[equippedSign].template, spawnPos, GetWorldRotation() );
		return newSignEnt.Init( signOwner, signs[equippedSign].entity );
	}
	
	//if we throw hold while casting sign then the input gets ingored (cleared from combat action buffer when cast sign stop is processed)
	private function HAX_SignToThrowItemRestore()
	{
		var action : SInputAction;
		
		action.value = theInput.GetActionValue('ThrowItemHold');
		action.lastFrameValue = 0;
		
		if(IsPressed(action) && CanSetupCombatAction_Throw())
		{
			if(inv.IsItemBomb(selectedItemId))
			{
				BombThrowStart();
			}
			else
			{
				UsableItemStart();
			}
			
			SetThrowHold( true );
		}
	}
	
	event OnCFMCameraZoomFail(){}
		
	////////////////////////////////////////////////////////////////////////////////

	public final function GetDrunkMutagens() : array<CBaseGameplayEffect>
	{
		return effectManager.GetDrunkMutagens();
	}
	
	public final function GetPotionBuffs() : array<CBaseGameplayEffect>
	{
		return effectManager.GetPotionBuffs();
	}
	
	public final function RecalcPotionsDurations()
	{
		var i : int;
		var buffs : array<CBaseGameplayEffect>;
		
		buffs = GetPotionBuffs();
		for(i=0; i<buffs.Size(); i+=1)
		{
			buffs[i].RecalcPotionDuration();
		}
	}

	public function StartFrenzy()
	{
		var ratio, duration : float;
		var skillLevel : int;
	
		isInFrenzy = true;
		skillLevel = GetSkillLevel(S_Alchemy_s16);
		ratio = 0.48f - skillLevel * CalculateAttributeValue(GetSkillAttributeValue(S_Alchemy_s16, 'slowdown_ratio', false, true));
		duration = skillLevel * CalculateAttributeValue(GetSkillAttributeValue(S_Alchemy_s16, 'slowdown_duration', false, true));
	
		theGame.SetTimeScale(ratio, theGame.GetTimescaleSource(ETS_SkillFrenzy), theGame.GetTimescalePriority(ETS_SkillFrenzy) );
		AddTimer('SkillFrenzyFinish', duration * ratio, , , , true);
	}
	
	timer function SkillFrenzyFinish(dt : float, optional id : int)
	{		
		theGame.RemoveTimeScale( theGame.GetTimescaleSource(ETS_SkillFrenzy) );
		isInFrenzy = false;
	}
	
	public function GetToxicityDamageThreshold() : float
	{
		var ret : float;
		
		ret = theGame.params.TOXICITY_DAMAGE_THRESHOLD;
		
		if(CanUseSkill(S_Alchemy_s01))
			ret += CalculateAttributeValue(GetSkillAttributeValue(S_Alchemy_s01, 'threshold', false, true)) * GetSkillLevel(S_Alchemy_s01);
		
		return ret;
	}
	
	/*
	private function DrinkMutagenPotion(id : SItemUniqueId, slot : EEquipmentSlots) : bool
	{
		var toxicityOffset, toxicitySum : float;
		var ret : EEffectInteract;
		var mutagen : SDrunkMutagen;
		var mutagenParams : SCustomEffectParams;		
		var buffs : array<SEffectInfo>;
		//var tutState : W3TutorialManagerUIHandlerStatePreparationMutagens; disabled, might be added in patch
		var result : bool;
			
		if(!IsSlotMutagen(slot)) 
			return false;
		
		toxicityOffset = CalculateAttributeValue(inv.GetItemAttributeValue(id,'toxicity_offset'));
	
		// check what toxicity would be if we drink mutagen, don't allow it to be too high.
		toxicitySum = abilityManager.GetStat(BCS_Toxicity) + (toxicityOffset - GetMutagenToxicityOffset(slot)) * abilityManager.GetStatMax(BCS_Toxicity);
		if( toxicitySum > abilityManager.GetStatMax(BCS_Toxicity) )
			return false;			

		//buff type
		inv.GetItemBuffs(id, buffs);
				
		//apply mutagen effect
		mutagenParams.effectType = buffs[0].effectType;
		mutagenParams.creator = this;
		mutagenParams.sourceName = "mutagen";
		mutagenParams.duration = -1;
		mutagenParams.customAbilityName = buffs[0].effectAbilityName;
		ret = AddEffectCustom(mutagenParams);
		
		//post-application - if successfull
		if(ret == EI_Pass || ret == EI_Override || ret == EI_Cumulate)
		{			
			PlayEffect('use_potion');
			
			itemSlots[slot] = id;	//'equip mutagen'
			
			mutagen.mutagenName = GetInventory().GetItemName( id );
			mutagen.effectType = buffs[0].effectType;
			mutagen.slot = slot;
			mutagen.toxicityOffset = toxicityOffset;
			
			drunkMutagens.PushBack( mutagen );
			
			AddToxicityOffset(toxicityOffset);
			
			result = true;
		}
		else
		{
			result = false;
		}
		
		/ * disabled, might be added in patch
		//tutorial
		if(ShouldProcessTutorial('TutorialMutagenPotion'))
		{
			tutState = (W3TutorialManagerUIHandlerStatePreparationMutagens)theGame.GetTutorialSystem().uiHandler.GetCurrentState();
			if(tutState)
			{
				tutState.OnMutagenEquipped();
			}
		}
		* /
		
		//trial of grasses achievement
		theGame.GetGamerProfile().CheckTrialOfGrasses();
		
		//fundamentals first achievement
		SetFailedFundamentalsFirstAchievementCondition(true);
		
		// report global event
		theGame.GetGlobalEventsManager().OnScriptedEvent( SEC_OnItemEquipped );
		
		return result;
	}
	*/
	
	public final function AddToxicityOffset( val : float)
	{
		((W3PlayerAbilityManager)abilityManager).AddToxicityOffset(val);		
	}
	
	public final function SetToxicityOffset( val : float)
	{
		((W3PlayerAbilityManager)abilityManager).SetToxicityOffset(val);
	}
	
	public final function RemoveToxicityOffset( val : float)
	{
		((W3PlayerAbilityManager)abilityManager).RemoveToxicityOffset(val);		
	}
	
	//calculates final duration of potion (with all skill bonuses)
	public final function CalculatePotionDuration(item : SItemUniqueId, isMutagenPotion : bool, optional itemName : name) : float
	{
		var duration, skillPassiveMod, mutagenSkillMod : float;
		var val, min, max : SAbilityAttributeValue;
		
		//base potion duration
		if(inv.IsIdValid(item))
		{
			duration = CalculateAttributeValue(inv.GetItemAttributeValue(item, 'duration'));			
		}
		else
		{
			theGame.GetDefinitionsManager().GetItemAttributeValueNoRandom(itemName, true, 'duration', min, max);
			duration = CalculateAttributeValue(GetAttributeRandomizedValue(min, max));
		}
			
		skillPassiveMod = CalculateAttributeValue(GetAttributeValue('potion_duration'));
		
		if(isMutagenPotion && CanUseSkill(S_Alchemy_s14))
		{
			val = GetSkillAttributeValue(S_Alchemy_s14, 'duration', false, true);
			mutagenSkillMod = val.valueMultiplicative * GetSkillLevel(S_Alchemy_s14);
		}
		
		duration = duration * (1 + skillPassiveMod + mutagenSkillMod);
		
		return duration;
	}
	
	public function ToxicityLowEnoughToDrinkPotion( slotid : EEquipmentSlots, optional itemId : SItemUniqueId ) : bool
	{
		var item : SItemUniqueId;
		var maxTox : float;
		var potionToxicity : float;
		var toxicityOffset : float;
		var effectType : EEffectType;
		var customAbilityName : name;
		
		if(itemId != GetInvalidUniqueId())
			item = itemId; 
		else 
			item = itemSlots[slotid];
		
		inv.GetPotionItemBuffData(item, effectType, customAbilityName);
		maxTox = abilityManager.GetStatMax(BCS_Toxicity);
		potionToxicity = CalculateAttributeValue(inv.GetItemAttributeValue(item, 'toxicity'));
		toxicityOffset = CalculateAttributeValue(inv.GetItemAttributeValue(item, 'toxicity_offset'));
		
		if(effectType != EET_WhiteHoney)
		{
			if(abilityManager.GetStat(BCS_Toxicity, false) + potionToxicity + toxicityOffset > maxTox )
			{
				return false;
			}
		}
		
		return true;
	}
	
	public function DrinkPreparedPotion( slotid : EEquipmentSlots, optional itemId : SItemUniqueId )
	{	
		var i, ind : int;
		var toxicityOffset, adrenaline : float;
		var potionToxicity, duration, hpGainValue, maxTox : float;
		var randomPotions : array<EEffectType>;
		var effectType : EEffectType;
		var customAbilityName, factId : name;
		var ret : EEffectInteract;
		var atts : array<name>;
		var effectsOld, effectsNew : array<CBaseGameplayEffect>;
		var factPotionParams : W3Potion_Fact_Params;
		var potParams : W3PotionParams;
		var mutagenParams : W3MutagenBuffCustomParams;		
		var item : SItemUniqueId;
		var params, potionParams : SCustomEffectParams;
		var costReduction : SAbilityAttributeValue;
		
		//normally use slot BUT you can also drink any potion directly from inventory panel without equipping - in that case we override it by custom itemID		
		if(itemId != GetInvalidUniqueId())
			item = itemId; 
		else 
			item = itemSlots[slotid];
		
		//invalid item
		if(!inv.IsIdValid(item))
			return;
			
		//potion has no ammo left
		if( inv.SingletonItemGetAmmo(item) == 0 )
			return;
		
		//get toxicity costs
		inv.GetPotionItemBuffData(item, effectType, customAbilityName);
		maxTox = abilityManager.GetStatMax(BCS_Toxicity);
		potionToxicity = CalculateAttributeValue(inv.GetItemAttributeValue(item, 'toxicity'));
		toxicityOffset = CalculateAttributeValue(inv.GetItemAttributeValue(item, 'toxicity_offset'));
		
		//check for perk which decrases toxicity cost by consuming adrenaline
		if(CanUseSkill(S_Perk_13))
		{
			costReduction = GetSkillAttributeValue(S_Perk_13, 'cost_reduction', false, true);
			adrenaline = FloorF(GetStat(BCS_Focus));
			costReduction = costReduction * adrenaline;
			potionToxicity = (potionToxicity - costReduction.valueBase) * (1 - costReduction.valueMultiplicative) - costReduction.valueAdditive;
			potionToxicity = MaxF(0.f, potionToxicity);
		}
		
		//check toxicity but White Honey can always be drunk
		if(effectType != EET_WhiteHoney)
		{
			if(abilityManager.GetStat(BCS_Toxicity, false) + potionToxicity + toxicityOffset > maxTox )
				return;
		}
		
		//buff info
		customAbilityName = '';
		inv.GetPotionItemBuffData(item, effectType, customAbilityName);
				
		//custom params - fact name
		if(effectType == EET_Fact)
		{
			inv.GetItemAttributes(item, atts);
			
			for(i=0; i<atts.Size(); i+=1)
			{
				if(StrBeginsWith(NameToString(atts[i]), "fact_"))
				{
					factId = atts[i];
					break;
				}
			}
			
			factPotionParams = new W3Potion_Fact_Params in theGame;
			factPotionParams.factName = factId;
			factPotionParams.potionItemName = inv.GetItemName(item);
			
			potionParams.buffSpecificParams = factPotionParams;
		}
		//custom params for mutagens
		else if(inv.ItemHasTag( item, 'Mutagen' ))
		{
			mutagenParams = new W3MutagenBuffCustomParams in theGame;
			mutagenParams.toxicityOffset = toxicityOffset;
			mutagenParams.potionItemName = inv.GetItemName(item);
			
			potionParams.buffSpecificParams = mutagenParams;
		}
		//custom params for potions
		else
		{
			potParams = new W3PotionParams in theGame;
			potParams.potionItemName = inv.GetItemName(item);
			
			potionParams.buffSpecificParams = potParams;
		}
	
		//set duration
		duration = CalculatePotionDuration(item, inv.ItemHasTag( item, 'Mutagen' ));		

		//apply potion
		potionParams.effectType = effectType;
		potionParams.creator = this;
		potionParams.sourceName = "drank_potion";
		potionParams.duration = duration;
		potionParams.customAbilityName = customAbilityName;
		ret = AddEffectCustom(potionParams);

		//clear custom params
		if(factPotionParams)
			delete factPotionParams;
			
		if(mutagenParams)
			delete mutagenParams;
			
		//use up ammo
		inv.SingletonItemRemoveAmmo(item);
		
		//post-application - if successfull
		if(ret == EI_Pass || ret == EI_Override || ret == EI_Cumulate)
		{
			abilityManager.GainStat(BCS_Toxicity, potionToxicity );
			
			//adrenaline perk
			if(CanUseSkill(S_Perk_13))
			{
				abilityManager.DrainFocus(adrenaline);
			}
			
			if (!IsEffectActive('invisible'))
			{
				PlayEffect('use_potion');
			}
			
			if ( inv.ItemHasTag( item, 'Mutagen' ) )
			{
				//trial of grasses achievement
				theGame.GetGamerProfile().CheckTrialOfGrasses();
				
				//fundamentals first achievement
				SetFailedFundamentalsFirstAchievementCondition(true);
			}
			
			//heal
			if(CanUseSkill(S_Alchemy_s02))
			{
				hpGainValue = ClampF(GetStatMax(BCS_Vitality) * CalculateAttributeValue(GetSkillAttributeValue(S_Alchemy_s02, 'vitality_gain_perc', false, true)) * GetSkillLevel(S_Alchemy_s02), 0, GetStatMax(BCS_Vitality));
				GainStat(BCS_Vitality, hpGainValue);
			}
			//bonus random potion
			if(CanUseSkill(S_Alchemy_s04) && !skillBonusPotionEffect && (RandF() < CalculateAttributeValue(GetSkillAttributeValue(S_Alchemy_s04, 'apply_chance', false, true)) * GetSkillLevel(S_Alchemy_s04)))
			{
				//list of potions to pick from
				randomPotions.PushBack(EET_BlackBlood);
				randomPotions.PushBack(EET_Blizzard);
				//Chicken no cat start
				//randomPotions.PushBack(EET_Cat);
				//Chicken no cat end
				randomPotions.PushBack(EET_FullMoon);
				randomPotions.PushBack(EET_GoldenOriole);
				randomPotions.PushBack(EET_KillerWhale);
				randomPotions.PushBack(EET_MariborForest);
				randomPotions.PushBack(EET_PetriPhiltre);
				randomPotions.PushBack(EET_Swallow);
				randomPotions.PushBack(EET_TawnyOwl);
				randomPotions.PushBack(EET_Thunderbolt);
				randomPotions.PushBack(EET_WhiteRaffardDecoction);
				
				//exclude current potion
				randomPotions.Remove(effectType);
				ind = RandRange(randomPotions.Size());

				duration = BonusPotionGetDurationFromXML(randomPotions[ind]);
				
				if(duration > 0)
				{
					effectsOld = GetCurrentEffects();
										
					params.effectType = randomPotions[ind];
					params.creator = this;
					params.sourceName = SkillEnumToName(S_Alchemy_s04);
					params.duration = duration;
					ret = AddEffectCustom(params);
					
					
					if(ret != EI_Undefined && ret != EI_Deny)
					{
						effectsNew = GetCurrentEffects();
						
						ind = -1;
						for(i=0; i<effectsNew.Size(); i+=1)
						{
							if(!effectsOld.Contains(effectsNew[i]))
							{
								ind = i;
								break;
							}
						}
						
						if(ind > -1)
						{
							skillBonusPotionEffect = effectsNew[ind];
						}
					}
				}		
			}
			
			theGame.GetGamerProfile().SetStat(ES_ActivePotions, effectManager.GetPotionBuffsCount());
		}
		
		theTelemetry.LogWithLabel(TE_ELIXIR_USED, inv.GetItemName(item));
		
		if(ShouldProcessTutorial('TutorialPotionAmmo'))
		{
			FactsAdd("tut_used_potion");
		}
		
		SetFailedFundamentalsFirstAchievementCondition(true);
	}
	
	// Caches recipes' data from XML for given recipes
	private function BonusPotionGetDurationFromXML(type : EEffectType) : float
	{
		var dm : CDefinitionsManagerAccessor;
		var main, ingredients : SCustomNode;
		var tmpName, typeName, itemName : name;
		var abs : array<name>;
		var min, max : SAbilityAttributeValue;
		var tmpInt : int;
		var temp 								: array<float>;
		var i, temp2, temp3 : int;
						
		dm = theGame.GetDefinitionsManager();
		main = dm.GetCustomDefinition('alchemy_recipes');
		typeName = EffectTypeToName(type);
		
		//get potion item name
		for(i=0; i<main.subNodes.Size(); i+=1)
		{
			if(dm.GetCustomNodeAttributeValueName(main.subNodes[i], 'type_name', tmpName))
			{
				//proper potion definition...
				if(tmpName == typeName)
				{
					if(dm.GetCustomNodeAttributeValueInt(main.subNodes[i], 'level', tmpInt))
					{
						//of level 1...
						if(tmpInt == 1)
						{
							if(dm.GetCustomNodeAttributeValueName(main.subNodes[i], 'cookedItem_name', itemName))
							{
								//got valid item id
								if(IsNameValid(itemName))
								{
									break;
								}
							}
						}
					}
				}
			}
		}
		
		if(!IsNameValid(itemName))
			return 0;
		
		//get duration from item's ability's definition
		dm.GetItemAbilitiesWithWeights(itemName, true, abs, temp, temp2, temp3);
		dm.GetAbilitiesAttributeValue(abs, 'duration', min, max);						
		return CalculateAttributeValue(GetAttributeRandomizedValue(min, max));
	}
	
	public function ClearSkillBonusPotionEffect()
	{
		skillBonusPotionEffect = NULL;
	}
	
	public function GetSkillBonusPotionEffect() : CBaseGameplayEffect
	{
		return skillBonusPotionEffect;
	}
	
	////////////////////////////////////////////////////////////////////////////////
	//
	// @Buffs
	//
	////////////////////////////////////////////////////////////////////////////////
	
	public final function HasRunewordActive(abilityName : name) : bool
	{
		var item : SItemUniqueId;
		var hasRuneword : bool;
		
		if(GetItemEquippedOnSlot(EES_SteelSword, item))
		{
			hasRuneword = inv.ItemHasAbility(item, abilityName);				
		}
		
		if(!hasRuneword)
		{
			if(GetItemEquippedOnSlot(EES_SilverSword, item))
			{
				hasRuneword = inv.ItemHasAbility(item, abilityName);
			}
		}
		
		return hasRuneword;
	}
	
	public final function GetShrineBuffs() : array<CBaseGameplayEffect>
	{
		var null : array<CBaseGameplayEffect>;
		
		if(effectManager && effectManager.IsReady())
			return effectManager.GetShrineBuffs();
			
		return null;
	}
	
	public final function AddRepairObjectBuff(armor : bool, weapon : bool) : bool
	{
		var added : bool;
		
		added = false;
		
		if(weapon && (IsAnyItemEquippedOnSlot(EES_SilverSword) || IsAnyItemEquippedOnSlot(EES_SteelSword)) )
		{
			AddEffectDefault(EET_EnhancedWeapon, this, "repair_object", false);
			added = true;
		}
		
		if(armor && (IsAnyItemEquippedOnSlot(EES_Armor) || IsAnyItemEquippedOnSlot(EES_Gloves) || IsAnyItemEquippedOnSlot(EES_Boots) || IsAnyItemEquippedOnSlot(EES_Pants)) )
		{
			AddEffectDefault(EET_EnhancedArmor, this, "repair_object", false);
			added = true;
		}
		
		return added;
	}
	
	/*
		Called when new critical effect has started
		This will interrupt current critical state
		
		returns true if the effect got fired properly
	*/
	public function StartCSAnim(buff : CBaseGameplayEffect) : bool
	{
		//if has quen and gets DOT - abort DOT's anim
		if(IsAnyQuenActive() && (W3CriticalDOTEffect)buff)
			return false;
			
		return super.StartCSAnim(buff);
	}
	
	public function GetPotionBuffLevel(effectType : EEffectType) : int
	{
		if(effectManager && effectManager.IsReady())
			return effectManager.GetPotionBuffLevel(effectType);
			
		return 0;
	}	

	////////////////////////////////////////////////////////////////////////////////
	//
	// @Stats
	//
	////////////////////////////////////////////////////////////////////////////////
	
	event OnLevelGained(currentLevel : int, show : bool)
	{
		var hud : CR4ScriptedHud;
		hud = (CR4ScriptedHud)theGame.GetHud();
		
		if(abilityManager && abilityManager.IsInitialized())
		{
			((W3PlayerAbilityManager)abilityManager).OnLevelGained(currentLevel);
		}
		
		if ( theGame.GetDifficultyMode() != EDM_Hardcore ) 
		{
			Heal(GetStatMax(BCS_Vitality));
		} 
	
		//achievement
		if(currentLevel >= 35)
		{
			theGame.GetGamerProfile().AddAchievement(EA_Immortal);
		}
	
		if ( hud && currentLevel < 70 )
		{
			hud.OnLevelUpUpdate(currentLevel, show);
		}
		
		theGame.RequestAutoSave( "level gained", false );
	}
	
	public function GetSignStats(skill : ESkill, out damageType : name, out damageVal : float, out spellPower : SAbilityAttributeValue)
	{
		var i, size : int;
		var dm : CDefinitionsManagerAccessor;
		var attrs : array<name>;
	
		spellPower = GetPowerStatValue(CPS_SpellPower);
		
		dm = theGame.GetDefinitionsManager();
		dm.GetAbilityAttributes(GetSkillAbilityName(skill), attrs);
		size = attrs.Size();
		
		for( i = 0; i < size; i += 1 )
		{
			if( IsDamageTypeNameValid(attrs[i]) )
			{
				damageVal = CalculateAttributeValue(GetSkillAttributeValue(skill, attrs[i], false, true));
				damageType = attrs[i];
				break;
			}
		}
	}
		
	//used by Ignore Pain skill to change max vitality based on dynamically calculated value (cannot use abilities to do that)
	public function SetIgnorePainMaxVitality(val : float)
	{
		if(abilityManager && abilityManager.IsInitialized())
			abilityManager.SetStatPointMax(BCS_Vitality, val);
	}
	
	event OnAnimEvent_ActionBlend( animEventName : name, animEventType : EAnimationEventType, animInfo : SAnimationEventAnimInfo )
	{
		if ( animEventType == AET_DurationStart && !disableActionBlend )
		{
			if ( this.IsCastingSign() )
				ProcessSignEvent( 'cast_end' );
			//MSTODO:
			//SetMoveTarget( FindNearestTarget() );	
			FindMoveTarget();
			SetCanPlayHitAnim( true );
			this.SetBIsCombatActionAllowed( true );
			
			if ( this.GetFinisherVictim() && this.GetFinisherVictim().HasAbility( 'ForceFinisher' ) )
			{
				this.GetFinisherVictim().SignalGameplayEvent( 'Finisher' );
			}
			else if (this.BufferCombatAction != EBAT_EMPTY )
			{
				//if ( !( this.BufferCombatAction == EBAT_CastSign ) )//&& inv.IsItemCrossbow( inv.GetItemFromSlot( 'l_weapon' ) ) ) )
				//LogChannel('combatActionAllowed',"BufferCombatAction != EBAT_EMPTY");
					
					if ( !IsCombatMusicEnabled() )
					{
						SetCombatActionHeading( ProcessCombatActionHeading( this.BufferCombatAction ) ); 
						FindTarget();
						UpdateDisplayTarget( true );
					}
			
					if ( AllowAttack( GetTarget(), this.BufferCombatAction ) )
						this.ProcessCombatActionBuffer();
			}
			else
			{
				//stamina pause should happen just for a brief moment
				ResumeEffects(EET_AutoStaminaRegen, 'InsideCombatAction');
				
				//if sign button is held we should cast sign to have better responsiveness
				/*if (  theInput.GetActionValue( 'CastSignHold' ) > 0.f ) //GetCombatAction() != EBAT_CastSign &&
				{
					this.PushCombatActionOnBuffer( EBAT_CastSign, BS_Pressed);
					this.ProcessCombatActionBuffer();
				}*/
			}
		}
		else if ( disableActionBlend )
		{
			disableActionBlend = false;
		}
	}
	
	
	event OnAnimEvent_Sign( animEventName : name, animEventType : EAnimationEventType, animInfo : SAnimationEventAnimInfo )
	{
		if( animEventType == AET_Tick )
		{
			ProcessSignEvent( animEventName );
		}
	}
	
	event OnAnimEvent_Throwable( animEventName : name, animEventType : EAnimationEventType, animInfo : SAnimationEventAnimInfo )
	{
		var thrownEntity		: CThrowable;	
		
		thrownEntity = (CThrowable)EntityHandleGet( thrownEntityHandle );
			
		if ( inv.IsItemCrossbow( inv.GetItemFromSlot('l_weapon') ) &&  rangedWeapon.OnProcessThrowEvent( animEventName ) )
		{		
			return true;
		}
		else if( thrownEntity && IsThrowingItem() && thrownEntity.OnProcessThrowEvent( animEventName ) )
		{
			return true;
		}	
	}	
	
	public function IsInCombatAction_SpecialAttack() : bool
	{
		if ( IsInCombatAction() && ( GetCombatAction() == EBAT_SpecialAttack_Light || GetCombatAction() == EBAT_SpecialAttack_Heavy ) )
			return true;
		else
			return false;
	}
	
	protected function WhenCombatActionIsFinished()
	{
		super.WhenCombatActionIsFinished();
		RemoveTimer( 'ProcessAttackTimer' );
		RemoveTimer( 'AttackTimerEnd' );
		CastSignAbort();
		specialAttackCamera = false;	
		this.OnPerformSpecialAttack( true, false );
	}
	
	event OnCombatActionEnd()
	{
		this.CleanCombatActionBuffer();		
		super.OnCombatActionEnd();
		
		RemoveTemporarySkills();
	}
	
	event OnCombatActionFriendlyEnd()
	{
		if ( IsCastingSign() )
		{
			SetBehaviorVariable( 'IsCastingSign', 0 );
			SetCurrentlyCastSign( ST_None, NULL );
			LogChannel( 'ST_None', "ST_None" );					
		}

		super.OnCombatActionFriendlyEnd();
	}
	
	//--------------------------------- RADIAL MENU #B --------------------------------------
	
	timer function OpenRadialMenu( time: float, id : int )
	{
		//_gfxFuncShowRadialMenu(FlashArgBool(true));
		if( GetBIsCombatActionAllowed() && !IsUITakeInput() )
		{
			bShowRadialMenu = true;
		}
		//LogChannel('RADIAL',"OpenRadialMenu timer");
		this.RemoveTimer('OpenRadialMenu');
	}
	
	public function OnAddRadialMenuOpenTimer(  )
	{
		//LogChannel('RADIAL',"OnAddRadialMenuOpenTimer");
		//if( GetBIsCombatActionAllowed() )
		//{
		    // fix to make radial menu delay independent of current time scale
		    // if it's required in other places as well, changes in timer would be more appropriate
			this.AddTimer('OpenRadialMenu', _HoldBeforeOpenRadialMenuTime * theGame.GetTimeScale() );
		//}
	}

	public function SetShowRadialMenuOpenFlag( bSet : bool  )
	{
		//LogChannel('RADIAL',"OnAddRadialMenuOpenTimer bSet "+bSet);
		bShowRadialMenu = bSet;
	}
	
	public function OnRemoveRadialMenuOpenTimer()
	{
		//LogChannel('RADIAL',"OnRemoveRadialMenuOpenTimer");
		this.RemoveTimer('OpenRadialMenu');
	}
	
	public function ResetRadialMenuOpenTimer()
	{
		//LogChannel('RADIAL',"ResetRadialMenuOpenTimer");
		this.RemoveTimer('OpenRadialMenu');
		if( GetBIsCombatActionAllowed() )
		{
		    // fix to make radial menu delay independent of current time scale
		    // if it's required in other places as well, changes in timer would be more appropriate
			AddTimer('OpenRadialMenu', _HoldBeforeOpenRadialMenuTime * theGame.GetTimeScale() );
		}
	}

	//--------------------------------- Companion Module #B --------------------------------------
	
	timer function ResendCompanionDisplayName(dt : float, id : int)
	{
		var hud : CR4ScriptedHud;
		var companionModule : CR4HudModuleCompanion;
		
		hud = (CR4ScriptedHud)theGame.GetHud();
		if( hud )
		{
			companionModule = (CR4HudModuleCompanion)hud.GetHudModule("CompanionModule");
			if( companionModule )
			{
				companionModule.ResendDisplayName();
			}
		}
	}

	timer function ResendCompanionDisplayNameSecond(dt : float, id : int)
	{
		var hud : CR4ScriptedHud;
		var companionModule : CR4HudModuleCompanion;
		
		hud = (CR4ScriptedHud)theGame.GetHud();
		if( hud )
		{
			companionModule = (CR4HudModuleCompanion)hud.GetHudModule("CompanionModule");
			if( companionModule )
			{
				companionModule.ResendDisplayNameSecond();
			}
		}
	}
	
	public function RemoveCompanionDisplayNameTimer()
	{
		this.RemoveTimer('ResendCompanionDisplayName');
	}
		
	public function RemoveCompanionDisplayNameTimerSecond()
	{
		this.RemoveTimer('ResendCompanionDisplayNameSecond');
	}
	
		
	public function GetCompanionNPCTag() : name
	{
		return companionNPCTag;
	}

	public function SetCompanionNPCTag( value : name )
	{
		companionNPCTag = value;
	}	

	public function GetCompanionNPCTag2() : name
	{
		return companionNPCTag2;
	}

	public function SetCompanionNPCTag2( value : name )
	{
		companionNPCTag2 = value;
	}

	public function GetCompanionNPCIconPath() : string
	{
		return companionNPCIconPath;
	}

	public function SetCompanionNPCIconPath( value : string )
	{
		companionNPCIconPath = value;
	}

	public function GetCompanionNPCIconPath2() : string
	{
		return companionNPCIconPath2;
	}

	public function SetCompanionNPCIconPath2( value : string )
	{
		companionNPCIconPath2 = value;
	}
	
	//-------------------------------------- OTHER ---------------------------------------------

	public function ReactToBeingHit(damageAction : W3DamageAction, optional buffNotApplied : bool) : bool
	{
		var chance : float;
		var procQuen : W3SignEntity;
		
		if(!damageAction.IsDoTDamage() && damageAction.DealsAnyDamage())
		{
			if(inv.IsItemBomb(selectedItemId))
			{
				BombThrowAbort();
			}
			else
			{
				//usable item and crossbow
				ThrowingAbort();
			}			
		}		
		
		//special item with chance to apply quen when hit with projectile
		if(damageAction.IsActionRanged())
		{
			chance = CalculateAttributeValue(GetAttributeValue('quen_chance_on_projectile'));
			if(chance > 0)
			{
				chance = ClampF(chance, 0, 1);
				
				if(RandF() < chance)
				{
					procQuen = (W3SignEntity)theGame.CreateEntity(signs[ST_Quen].template, GetWorldPosition(), GetWorldRotation() );
					procQuen.Init(signOwner, signs[ST_Quen].entity, true );
					procQuen.OnStarted();
					procQuen.OnThrowing();
					procQuen.OnEnded();
				}
			}
		}
		
		//abort meditation unless it's toxicity damage
		if( !((W3Effect_Toxicity)damageAction.causer) )
			MeditationForceAbort(true);
		
		//if in whirlwind, skip hit animations
		if(IsDoingSpecialAttack(false))
			damageAction.SetHitAnimationPlayType(EAHA_ForceNo);
		
		return super.ReactToBeingHit(damageAction, buffNotApplied);
	}
	
	protected function ShouldPauseHealthRegenOnHit() : bool
	{
		//level 3 swallow prevents regen pause
		if( (HasBuff(EET_Swallow) && GetPotionBuffLevel(EET_Swallow) >= 3) || HasBuff(EET_Runeword8) )
			return false;
			
		return true;
	}
		
	public function SetMappinToHighlight( mappinName : name, mappinState : bool )
	{
		var mappinDef : SHighlightMappin;
		mappinDef.MappinName = mappinName;
		mappinDef.MappinState = mappinState;
		MappinToHighlight.PushBack(mappinDef);
	}	

	public function ClearMappinToHighlight()
	{
		MappinToHighlight.Clear();
	}
	
	public function CastSignAbort()
	{
		if( currentlyCastSign != ST_None && signs[currentlyCastSign].entity)
		{
			signs[currentlyCastSign].entity.OnSignAborted();
		}
		
		//HAX_SignToThrowItemRestore();
	}
	
	event OnBlockingSceneStarted( scene: CStoryScene )
	{
		var med : W3PlayerWitcherStateMeditationWaiting;
				
		//abort meditation if meditating
		med = (W3PlayerWitcherStateMeditationWaiting)GetCurrentState();
		if(med)
		{
			med.StopRequested(true);
		}
		
		//super has to be called as last since it changes player state
		super.OnBlockingSceneStarted( scene );
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////    ---===  @HORSE  ===---    ////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	public function GetHorseManager() : W3HorseManager
	{
		return (W3HorseManager)EntityHandleGet( horseManagerHandle );
	}
	
	//Provide item id from HORSE'S INVENTORY. Returns false if failed.
	public function HorseEquipItem(horsesItemId : SItemUniqueId) : bool
	{
		var man : W3HorseManager;
		
		man = GetHorseManager();
		if(man)
			return man.EquipItem(horsesItemId) != GetInvalidUniqueId();
			
		return false;
	}
	
	//Returns false if failed
	public function HorseUnequipItem(slot : EEquipmentSlots) : bool
	{
		var man : W3HorseManager;
		
		man = GetHorseManager();
		if(man)
			return man.UnequipItem(slot) != GetInvalidUniqueId();
			
		return false;
	}
	
	//returns removed amount
	public final function HorseRemoveItemByName(itemName : name, quantity : int)
	{
		var man : W3HorseManager;
		
		man = GetHorseManager();
		if(man)
			man.HorseRemoveItemByName(itemName, quantity);
	}
	
	//returns removed amount
	public final function HorseRemoveItemByCategory(itemCategory : name, quantity : int)
	{
		var man : W3HorseManager;
		
		man = GetHorseManager();
		if(man)
			man.HorseRemoveItemByCategory(itemCategory, quantity);
	}
	
	//returns removed amount
	public final function HorseRemoveItemByTag(itemTag : name, quantity : int)
	{
		var man : W3HorseManager;
		
		man = GetHorseManager();
		if(man)
			man.HorseRemoveItemByTag(itemTag, quantity);
	}
	
	public function GetAssociatedInventory() : CInventoryComponent
	{
		var man : W3HorseManager;
		
		man = GetHorseManager();
		if(man)
			return man.GetInventoryComponent();
			
		return NULL;
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////    ---===  @TUTORIAL  ===---    /////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	public final function TutorialMutagensUnequipPlayerSkills() : array<STutorialSavedSkill>
	{
		var pam : W3PlayerAbilityManager;
		
		pam = (W3PlayerAbilityManager)abilityManager;
		return pam.TutorialMutagensUnequipPlayerSkills();
	}
	
	public final function TutorialMutagensEquipOneGoodSkill()
	{
		var pam : W3PlayerAbilityManager;
		
		pam = (W3PlayerAbilityManager)abilityManager;
		pam.TutorialMutagensEquipOneGoodSkill();
	}
	
	public final function TutorialMutagensEquipOneGoodOneBadSkill()
	{
		var pam : W3PlayerAbilityManager;
		
		pam = (W3PlayerAbilityManager)abilityManager;
		if(pam)
			pam.TutorialMutagensEquipOneGoodOneBadSkill();
	}
	
	public final function TutorialMutagensEquipThreeGoodSkills()
	{
		var pam : W3PlayerAbilityManager;
		
		pam = (W3PlayerAbilityManager)abilityManager;
		if(pam)
			pam.TutorialMutagensEquipThreeGoodSkills();
	}
	
	public final function TutorialMutagensCleanupTempSkills(savedEquippedSkills : array<STutorialSavedSkill>)
	{
		var pam : W3PlayerAbilityManager;
		
		pam = (W3PlayerAbilityManager)abilityManager;
		return pam.TutorialMutagensCleanupTempSkills(savedEquippedSkills);
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////    ---===  @STATS  ===---    ////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	public function GetOffenseStatsList() : SPlayerOffenseStats
	{
		var playerOffenseStats:SPlayerOffenseStats;
		var steelDmg, silverDmg, elementalSteel, elementalSilver : float;
		var steelCritChance, steelCritDmg : float;
		var silverCritChance, silverCritDmg : float;
		var attackPower	: SAbilityAttributeValue;
		var fastCritChance, fastCritDmg : float;
		var strongCritChance, strongCritDmg : float;
		var fastAP, strongAP : SAbilityAttributeValue;
		var item, crossbow : SItemUniqueId;
		var value : SAbilityAttributeValue;
		var mutagen : CBaseGameplayEffect;
		var thunder : W3Potion_Thunderbolt;
		
		if(!abilityManager || !abilityManager.IsInitialized())
			return playerOffenseStats;
		
		if (CanUseSkill(S_Sword_s21))
			fastAP += GetSkillAttributeValue(S_Sword_s21, PowerStatEnumToName(CPS_AttackPower), false, true) * GetSkillLevel(S_Sword_s21); 
		if (CanUseSkill(S_Perk_05))
		{
			fastAP += GetAttributeValue('attack_power_fast_style');
			fastCritDmg += CalculateAttributeValue(GetAttributeValue('critical_hit_chance_fast_style'));
			strongCritDmg += CalculateAttributeValue(GetAttributeValue('critical_hit_chance_fast_style'));
		}
		if (CanUseSkill(S_Sword_s04))
			strongAP += GetSkillAttributeValue(S_Sword_s04, PowerStatEnumToName(CPS_AttackPower), false, true) * GetSkillLevel(S_Sword_s04);
		if (CanUseSkill(S_Perk_07))
			strongAP +=	GetAttributeValue('attack_power_heavy_style');
			
		if (CanUseSkill(S_Sword_s17)) 
		{
			fastCritChance += CalculateAttributeValue(GetSkillAttributeValue(S_Sword_s17, theGame.params.CRITICAL_HIT_CHANCE, false, true)) * GetSkillLevel(S_Sword_s17);
			fastCritDmg += CalculateAttributeValue(GetSkillAttributeValue(S_Sword_s17, theGame.params.CRITICAL_HIT_DAMAGE_BONUS, false, true)) * GetSkillLevel(S_Sword_s17);
		}
		
		if (CanUseSkill(S_Sword_s08)) 
		{
			strongCritChance += CalculateAttributeValue(GetSkillAttributeValue(S_Sword_s08, theGame.params.CRITICAL_HIT_CHANCE, false, true)) * GetSkillLevel(S_Sword_s08);
			strongCritDmg += CalculateAttributeValue(GetSkillAttributeValue(S_Sword_s08, theGame.params.CRITICAL_HIT_DAMAGE_BONUS, false, true)) * GetSkillLevel(S_Sword_s08);
		}
		
		if ( HasBuff(EET_Mutagen05) && (GetStat(BCS_Vitality) == GetStatMax(BCS_Vitality)) )
		{
			attackPower += GetAttributeValue('damageIncrease');
		}
		
		steelCritChance += CalculateAttributeValue(GetAttributeValue(theGame.params.CRITICAL_HIT_CHANCE));
		silverCritChance += CalculateAttributeValue(GetAttributeValue(theGame.params.CRITICAL_HIT_CHANCE));
		steelCritDmg += CalculateAttributeValue(GetAttributeValue(theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
		silverCritDmg += CalculateAttributeValue(GetAttributeValue(theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
		attackPower += GetPowerStatValue(CPS_AttackPower);
		
		if (GetItemEquippedOnSlot(EES_SteelSword, item))
		{
			steelDmg = GetTotalWeaponDamage(item, theGame.params.DAMAGE_NAME_SLASHING, GetInvalidUniqueId());
			steelDmg += GetTotalWeaponDamage(item, theGame.params.DAMAGE_NAME_PIERCING, GetInvalidUniqueId());
			steelDmg += GetTotalWeaponDamage(item, theGame.params.DAMAGE_NAME_BLUDGEONING, GetInvalidUniqueId());
			elementalSteel = CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.DAMAGE_NAME_FIRE));
			elementalSteel += CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.DAMAGE_NAME_FROST)); 
			if ( GetInventory().IsItemHeld(item) )
			{
				steelCritChance -= CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_CHANCE));
				silverCritChance -= CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_CHANCE));
				steelCritDmg -= CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
				silverCritDmg -= CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
			}
			steelCritChance += CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_CHANCE));
			steelCritDmg += CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
			
			thunder = (W3Potion_Thunderbolt)GetBuff(EET_Thunderbolt);
			if(thunder && thunder.GetBuffLevel() == 3 && GetCurWeather() == EWE_Storm)
			{
				steelCritChance += 1.0f;
			}
		}
		else
		{
			steelDmg += 0;
			steelCritChance += 0;
			steelCritDmg +=0;
		}
		
		if (GetItemEquippedOnSlot(EES_SilverSword, item))
		{
			silverDmg = GetTotalWeaponDamage(item, theGame.params.DAMAGE_NAME_SILVER, GetInvalidUniqueId());
			elementalSilver = CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.DAMAGE_NAME_FIRE));
			elementalSilver += CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.DAMAGE_NAME_FROST));
			if ( GetInventory().IsItemHeld(item) )
			{
				steelCritChance -= CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_CHANCE));
				silverCritChance -= CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_CHANCE));
				steelCritDmg -= CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
				silverCritDmg -= CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
			}
			silverCritChance += CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_CHANCE));
			silverCritDmg += CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
			
			thunder = (W3Potion_Thunderbolt)GetBuff(EET_Thunderbolt);
			if(thunder && thunder.GetBuffLevel() == 3 && GetCurWeather() == EWE_Storm)
			{
				silverCritChance += 1.0f;
			}
		}
		else
		{
			silverDmg += 0;
			silverCritChance += 0;
			silverCritDmg +=0;
		}
		
		if ( HasAbility('Runeword 4 _Stats', true) )
		{
			steelDmg += steelDmg * (abilityManager.GetOverhealBonus() / GetStatMax(BCS_Vitality));
			silverDmg += silverDmg * (abilityManager.GetOverhealBonus() / GetStatMax(BCS_Vitality));
		}
		
		fastAP += attackPower;
		strongAP += attackPower;
		
		playerOffenseStats.steelFastCritChance = (steelCritChance + fastCritChance) * 100;
		playerOffenseStats.steelFastCritDmg = steelCritDmg + fastCritDmg;
		if ( steelDmg != 0 )
		{
			playerOffenseStats.steelFastDmg = (steelDmg + fastAP.valueBase) * fastAP.valueMultiplicative + fastAP.valueAdditive + elementalSteel;
			playerOffenseStats.steelFastCritDmg = (steelDmg + fastAP.valueBase) * (fastAP.valueMultiplicative + playerOffenseStats.steelFastCritDmg) + fastAP.valueAdditive + elementalSteel;
		}
		else
		{
			playerOffenseStats.steelFastDmg = 0;
			playerOffenseStats.steelFastCritDmg = 0;
		}
		playerOffenseStats.steelFastDPS = (playerOffenseStats.steelFastDmg * (100 - playerOffenseStats.steelFastCritChance) + playerOffenseStats.steelFastCritDmg * playerOffenseStats.steelFastCritChance) / 100;
		playerOffenseStats.steelFastDPS = playerOffenseStats.steelFastDPS / 0.6;
		//playerOffenseStats.steelFastCritDmg *= 100;
		
		playerOffenseStats.steelStrongCritChance = (steelCritChance + strongCritChance) * 100;
		playerOffenseStats.steelStrongCritDmg = steelCritDmg + strongCritDmg;
		if ( steelDmg != 0 )
		{
			playerOffenseStats.steelStrongDmg = (steelDmg + strongAP.valueBase) * strongAP.valueMultiplicative + strongAP.valueAdditive + elementalSteel;
			playerOffenseStats.steelStrongDmg *= 1.833f;
			playerOffenseStats.steelStrongCritDmg = (steelDmg + strongAP.valueBase) * (strongAP.valueMultiplicative + playerOffenseStats.steelStrongCritDmg) + strongAP.valueAdditive + elementalSteel;
			playerOffenseStats.steelStrongCritDmg *= 1.833f;		}
		else
		{
			playerOffenseStats.steelStrongDmg = 0;
			playerOffenseStats.steelStrongCritDmg = 0;
		}
		playerOffenseStats.steelStrongDPS = (playerOffenseStats.steelStrongDmg * (100 - playerOffenseStats.steelStrongCritChance) + playerOffenseStats.steelStrongCritDmg * playerOffenseStats.steelStrongCritChance) / 100;
		playerOffenseStats.steelStrongDPS = playerOffenseStats.steelStrongDPS / 1.1;
		//playerOffenseStats.steelStrongCritDmg *= 100;
	
		
		playerOffenseStats.silverFastCritChance = (silverCritChance + fastCritChance) * 100;
		playerOffenseStats.silverFastCritDmg = silverCritDmg + fastCritDmg;
		if ( silverDmg != 0 )
		{
			playerOffenseStats.silverFastDmg = (silverDmg + fastAP.valueBase) * fastAP.valueMultiplicative + fastAP.valueAdditive + elementalSilver;
			playerOffenseStats.silverFastCritDmg = (silverDmg + fastAP.valueBase) * (fastAP.valueMultiplicative + playerOffenseStats.silverFastCritDmg) + fastAP.valueAdditive + elementalSilver;	
		}
		else
		{
			playerOffenseStats.silverFastDmg = 0;
			playerOffenseStats.silverFastCritDmg = 0;	
		}
		playerOffenseStats.silverFastDPS = (playerOffenseStats.silverFastDmg * (100 - playerOffenseStats.silverFastCritChance) + playerOffenseStats.silverFastCritDmg * playerOffenseStats.silverFastCritChance) / 100;
		playerOffenseStats.silverFastDPS = playerOffenseStats.silverFastDPS / 0.6;
		//playerOffenseStats.silverFastCritDmg *= 100;
		
		playerOffenseStats.silverStrongCritChance = (silverCritChance + strongCritChance) * 100;
		playerOffenseStats.silverStrongCritDmg = silverCritDmg + strongCritDmg;		
		if ( silverDmg != 0 )
		{
			playerOffenseStats.silverStrongDmg = (silverDmg + strongAP.valueBase) * strongAP.valueMultiplicative + strongAP.valueAdditive + elementalSilver;
			playerOffenseStats.silverStrongDmg *= 1.833f;
			playerOffenseStats.silverStrongCritDmg = (silverDmg + strongAP.valueBase) * (strongAP.valueMultiplicative + playerOffenseStats.silverStrongCritDmg) + strongAP.valueAdditive + elementalSilver;
			playerOffenseStats.silverStrongCritDmg *= 1.833f;
		}
		else
		{
			playerOffenseStats.silverStrongDmg = 0;
			playerOffenseStats.silverStrongCritDmg = 0;
		}
		playerOffenseStats.silverStrongDPS = (playerOffenseStats.silverStrongDmg * (100 - playerOffenseStats.silverStrongCritChance) + playerOffenseStats.silverStrongCritDmg * playerOffenseStats.silverStrongCritChance) / 100;
		playerOffenseStats.silverStrongDPS = playerOffenseStats.silverStrongDPS / 1.1;
		//playerOffenseStats.silverStrongCritDmg *= 100;
		
		playerOffenseStats.crossbowCritChance = CalculateAttributeValue(GetAttributeValue(theGame.params.CRITICAL_HIT_CHANCE));
		if (CanUseSkill(S_Sword_s07))
			playerOffenseStats.crossbowCritChance += CalculateAttributeValue(GetSkillAttributeValue(S_Sword_s07, theGame.params.CRITICAL_HIT_CHANCE, false, true)) * GetSkillLevel(S_Sword_s07);
			
		// Bolt stats
		playerOffenseStats.crossbowSteelDmgType = theGame.params.DAMAGE_NAME_PIERCING;
		if (GetItemEquippedOnSlot(EES_Bolt, item))
		{
			//GetItemEquippedOnSlot(EES_RangedWeapon, crossbow);
			
			steelDmg = CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.DAMAGE_NAME_FIRE));
			if(steelDmg > 0)
			{
				playerOffenseStats.crossbowSteelDmg = steelDmg;
				
				playerOffenseStats.crossbowSteelDmgType = theGame.params.DAMAGE_NAME_FIRE;
				playerOffenseStats.crossbowSilverDmg = steelDmg;
			}
			else
			{
				playerOffenseStats.crossbowSilverDmg = CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.DAMAGE_NAME_SILVER));
				
				steelDmg = CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.DAMAGE_NAME_PIERCING));
				if(steelDmg > 0)
				{
					playerOffenseStats.crossbowSteelDmg = steelDmg;
					playerOffenseStats.crossbowSteelDmgType = theGame.params.DAMAGE_NAME_PIERCING;
				}
				else
				{
					playerOffenseStats.crossbowSteelDmg = CalculateAttributeValue(GetInventory().GetItemAttributeValue(item, theGame.params.DAMAGE_NAME_BLUDGEONING));
					playerOffenseStats.crossbowSteelDmgType = theGame.params.DAMAGE_NAME_BLUDGEONING;
				}
			}
		}
		// Crossbow
		if (GetItemEquippedOnSlot(EES_RangedWeapon, item))
		{
			attackPower += GetInventory().GetItemAttributeValue(item, PowerStatEnumToName(CPS_AttackPower));
			if(CanUseSkill(S_Perk_02))
			{				
				attackPower += GetSkillAttributeValue(S_Perk_02, PowerStatEnumToName(CPS_AttackPower), false, true);
			}
			playerOffenseStats.crossbowSteelDmg = (playerOffenseStats.crossbowSteelDmg + attackPower.valueBase) * attackPower.valueMultiplicative + attackPower.valueAdditive;
			playerOffenseStats.crossbowSilverDmg = (playerOffenseStats.crossbowSilverDmg + attackPower.valueBase) * attackPower.valueMultiplicative + attackPower.valueAdditive;
		}
		else
		{
			playerOffenseStats.crossbowSteelDmg = 0;
			playerOffenseStats.crossbowSilverDmg = 0;
			playerOffenseStats.crossbowSteelDmgType = theGame.params.DAMAGE_NAME_PIERCING;
		}
		
		return playerOffenseStats;
	}
	
	public function GetTotalWeaponDamage(weaponId : SItemUniqueId, damageTypeName : name, crossbowId : SItemUniqueId) : float
	{
		var damage, durRatio, durMod : float;
		var repairObjectBonus : SAbilityAttributeValue;
		
		durMod = 0;
		damage = super.GetTotalWeaponDamage(weaponId, damageTypeName, crossbowId);
		
		//durability & repair bonus only affects physical damage
		if(IsPhysicalResistStat(GetResistForDamage(damageTypeName, false)))
		{
			repairObjectBonus = inv.GetItemAttributeValue(weaponId, theGame.params.REPAIR_OBJECT_BONUS);
			durRatio = -1;
			
			if(inv.IsIdValid(crossbowId) && inv.HasItemDurability(crossbowId))
			{
				durRatio = inv.GetItemDurabilityRatio(crossbowId);
			}
			else if(inv.IsIdValid(weaponId) && inv.HasItemDurability(weaponId))
			{
				durRatio = inv.GetItemDurabilityRatio(weaponId);
			}
			
			//if has durability at all
			if(durRatio >= 0)
				durMod = theGame.params.GetDurabilityMultiplier(durRatio, true);
			else
				durMod = 1;
		}
		
		return damage * (durMod + repairObjectBonus.valueMultiplicative);
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////    ---===  @SKILLS  ===---    ///////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	public final function GetSkillPathType(skill : ESkill) : ESkillPath
	{
		if(abilityManager && abilityManager.IsInitialized())
			return ((W3PlayerAbilityManager)abilityManager).GetSkillPathType(skill);
			
		return ESP_NotSet;
	}
	
	public function GetSkillLevel(s : ESkill) : int
	{
		if(abilityManager && abilityManager.IsInitialized())
			return ((W3PlayerAbilityManager)abilityManager).GetSkillLevel(s);
			
		return -1;
	}
	
	public function GetBoughtSkillLevel(s : ESkill) : int
	{
		if(abilityManager && abilityManager.IsInitialized())
			return ((W3PlayerAbilityManager)abilityManager).GetBoughtSkillLevel(s);
			
		return -1;
	}
	
	//used mostly for dialog choice options
	public function GetAxiiLevel() : int
	{
		var level : int;
		
		level = 1;
		
		if(CanUseSkill(S_Magic_s17)) level += GetSkillLevel(S_Magic_s17);
			
		return Clamp(level, 1, 4);
	}
	
	public function IsInFrenzy() : bool
	{
		return isInFrenzy;
	}
	
	public function HasRecentlyCountered() : bool
	{
		return hasRecentlyCountered;
	}
	
	public function SetRecentlyCountered(counter : bool)
	{
		hasRecentlyCountered = counter;
	}
	
	timer function CheckBlockedSkills(dt : float, id : int)
	{
		var nextCallTime : float;
		
		nextCallTime = ((W3PlayerAbilityManager)abilityManager).CheckBlockedSkills(dt);
		if(nextCallTime != -1)
			AddTimer('CheckBlockedSkills', nextCallTime, , , , true);
	}
		
	//removes temporarily gained skills
	public function RemoveTemporarySkills()
	{
		var i : int;
		var pam : W3PlayerAbilityManager;
	
		if(tempLearnedSignSkills.Size() > 0)
		{
			pam = (W3PlayerAbilityManager)abilityManager;
			for(i=0; i<tempLearnedSignSkills.Size(); i+=1)
			{
				pam.RemoveTemporarySkill(tempLearnedSignSkills[i]);
			}
			
			tempLearnedSignSkills.Clear();
			RemoveAbilityAll(SkillEnumToName(S_Sword_s19));			
		}
	}
	
	public function RemoveTemporarySkill(skill : SSimpleSkill) : bool
	{
		var pam : W3PlayerAbilityManager;
		
		pam = (W3PlayerAbilityManager)abilityManager;
		if(pam && pam.IsInitialized())
			return pam.RemoveTemporarySkill(skill);
			
		return false;
	}
	
	//add temporarily all skills for 'All Out' skill
	private function AddTemporarySkills()
	{
		if(CanUseSkill(S_Sword_s19) && GetStat(BCS_Focus) >= 3)
		{
			tempLearnedSignSkills = ((W3PlayerAbilityManager)abilityManager).AddTempNonAlchemySkills();						
			DrainFocus(GetStat(BCS_Focus));
			AddAbilityMultiple(SkillEnumToName(S_Sword_s19), GetSkillLevel(S_Sword_s19));			
		}
	}

	/*
	public function GetSkillLinkColorVertical(skill : ESkill, out color : ESkillColor, out isJoker : bool)
	{
		if(abilityManager && abilityManager.IsInitialized())
			((W3PlayerAbilityManager)abilityManager).GetSkillLinkColorVertical(skill, color, isJoker);
	}
	
	public function GetSkillLinkColorLeft(skill : ESkill, out color : ESkillColor, out isJoker : bool)
	{
		if(abilityManager && abilityManager.IsInitialized())
			((W3PlayerAbilityManager)abilityManager).GetSkillLinkColorLeft(skill, color, isJoker);
	}
	
	public function GetSkillLinkColorRight(skill : ESkill, out color : ESkillColor, out isJoker : bool)
	{
		if(abilityManager && abilityManager.IsInitialized())
			((W3PlayerAbilityManager)abilityManager).GetSkillLinkColorRight(skill, color, isJoker);
	}*/
	
	public function HasAlternateQuen() : bool
	{
		var quenEntity : W3QuenEntity;
		
		quenEntity = (W3QuenEntity)GetCurrentSignEntity();
		if(quenEntity)
		{
			return quenEntity.IsAlternateCast();
		}
		
		return false;
	}
	
	///////////////////////////////////////////////////////////////////////
	//////////////////  @LEVELING @EXPERIENCE  ////////////////////////////
	///////////////////////////////////////////////////////////////////////
	
	public function AddPoints(type : ESpendablePointType, amount : int, show : bool)
	{
		levelManager.AddPoints(type, amount, show);
	}
	
	public function GetLevel() : int											{return levelManager.GetLevel();}
	public function GetTotalExpForNextLevel() : int								{return levelManager.GetTotalExpForNextLevel();}	
	public function GetPointsTotal(type : ESpendablePointType) : int 			{return levelManager.GetPointsTotal(type);}
	public function IsAutoLeveling() : bool										{return autoLevel;}
	public function SetAutoLeveling( b : bool )									{autoLevel = b;}
	
	public function GetMissingExpForNextLevel() : int
	{
		return Max(0, GetTotalExpForNextLevel() - GetPointsTotal(EExperiencePoint));
	}
	
	////////////////////////////////////////////////////////////////////////////
	////////////////////  @SIGNS  //////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////
	private saved var runewordInfusionType : ESignType;
	default runewordInfusionType = ST_None;
	
	public final function GetRunewordInfusionType() : ESignType
	{
		return runewordInfusionType;
	}

	public function OnSignCastPerformed(signType : ESignType, isAlternate : bool)
	{
		var items : array<SItemUniqueId>;
		var weaponEnt : CEntity;
		var fxName : name;
		
		super.OnSignCastPerformed(signType, isAlternate);
		
		if(HasAbility('Runeword 1 _Stats', true) && GetStat(BCS_Focus) >= 1.0f)
		{
			DrainFocus(1.0f);
			runewordInfusionType = signType;
			items = inv.GetHeldWeapons();
			weaponEnt = inv.GetItemEntityUnsafe(items[0]);
			
			//clear previous infusion fx
			weaponEnt.StopEffect('runeword_aard');
			weaponEnt.StopEffect('runeword_axii');
			weaponEnt.StopEffect('runeword_igni');
			weaponEnt.StopEffect('runeword_quen');
			weaponEnt.StopEffect('runeword_yrden');
					
			//show current fx
			if(signType == ST_Aard)
				fxName = 'runeword_aard';
			else if(signType == ST_Axii)
				fxName = 'runeword_axii';
			else if(signType == ST_Igni)
				fxName = 'runeword_igni';
			else if(signType == ST_Quen)
				fxName = 'runeword_quen';
			else if(signType == ST_Yrden)
				fxName = 'runeword_yrden';
				
			weaponEnt.PlayEffect(fxName);
		}
	}
	
	public saved var savedQuenHealth, savedQuenDuration : float;
	//this is insane! but there's no event on saving game
	timer function HACK_QuenSaveStatus(dt : float, id : int)
	{
		var quenEntity : W3QuenEntity;
		
		quenEntity = (W3QuenEntity)signs[ST_Quen].entity;
		savedQuenHealth = quenEntity.GetShieldHealth();
		savedQuenDuration = quenEntity.GetShieldRemainingDuration();
	}
	
	timer function DelayedRestoreQuen(dt : float, id : int)
	{
		RestoreQuen(savedQuenHealth, savedQuenDuration);
	}
	
	public final function OnBasicQuenFinishing()
	{
		RemoveTimer('HACK_QuenSaveStatus');
		savedQuenHealth = 0.f;
		savedQuenDuration = 0.f;
	}
	
	public final function IsAnyQuenActive() : bool
	{
		var quen : W3QuenEntity;
		
		quen = (W3QuenEntity)GetSignEntity(ST_Quen);
		if(quen)
			return quen.IsAnyQuenActive();
			
		return false;
	}
	
	public final function IsQuenActive(alternateMode : bool) : bool
	{
		if(IsAnyQuenActive() && GetSignEntity(ST_Quen).IsAlternateCast() == alternateMode)
			return true;
			
		return false;
	}
	
	public function FinishQuen(skipVisuals : bool)
	{
		var quen : W3QuenEntity;
		
		quen = (W3QuenEntity)GetSignEntity(ST_Quen);
		if(quen)
			quen.ForceFinishQuen(skipVisuals);
	}
	
	//returns value of spell power to be used by this sign (including power bonuses)
	public function GetTotalSignSpellPower(signSkill : ESkill) : SAbilityAttributeValue
	{
		var sp : SAbilityAttributeValue;
		var penalty : SAbilityAttributeValue;
		var penaltyReduction : float;
		var penaltyReductionLevel : int; 
		
		//character SP + spell specific skills
		sp = GetSkillAttributeValue(signSkill, PowerStatEnumToName(CPS_SpellPower), true, true);
		
		//skill custom
		if ( signSkill == S_Magic_s01 )
		{
			//wave leveling penalty reduction
			penaltyReductionLevel = GetSkillLevel(S_Magic_s01) + 1;
			if(penaltyReductionLevel > 0)
			{
				penaltyReduction = 1 - penaltyReductionLevel * CalculateAttributeValue(GetSkillAttributeValue(S_Magic_s01, 'spell_power_penalty_reduction', true, true));
				penalty = GetSkillAttributeValue(S_Magic_s01, PowerStatEnumToName(CPS_SpellPower), false, false);
				sp += penalty * penaltyReduction;	//add amount equal to penalty reduction (since full penalty is already applied)
			}
		}
		
		//magic item abilities
		if(signSkill == S_Magic_1 || signSkill == S_Magic_s01)
		{
			sp += GetAttributeValue('spell_power_aard');
		}
		else if(signSkill == S_Magic_2 || signSkill == S_Magic_s02)
		{
			sp += GetAttributeValue('spell_power_igni');
		}
		else if(signSkill == S_Magic_3 || signSkill == S_Magic_s03)
		{
			sp += GetAttributeValue('spell_power_yrden');
		}
		else if(signSkill == S_Magic_4 || signSkill == S_Magic_s04)
		{
			sp += GetAttributeValue('spell_power_quen');
		}
		else if(signSkill == S_Magic_5 || signSkill == S_Magic_s05)
		{
			sp += GetAttributeValue('spell_power_axii');
		}
		
		return sp;
	}
	
	////////////////////////////////////////////////////////////////////////////
	/////////////////////////  @GWENT  /////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////
	
	public final function GetGwentCardIndex( cardName : name ) : int
	{
		var dm : CDefinitionsManagerAccessor;
		
		dm = theGame.GetDefinitionsManager();
		
		if(dm.ItemHasTag( cardName , 'GwintCardLeader' )) //Checks for Gwent cards factions
		{
			return theGame.GetGwintManager().GwentLeadersNametoInt( cardName );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardNrkd' ))
		{
			return theGame.GetGwintManager().GwentNrkdNameToInt( cardName );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardNlfg' ))
		{
			return theGame.GetGwintManager().GwentNlfgNameToInt( cardName );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardSctl' ))
		{
			return theGame.GetGwintManager().GwentSctlNameToInt( cardName );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardMstr' ))
		{
			return theGame.GetGwintManager().GwentMstrNameToInt( cardName );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardNeutral' ))
		{
			return theGame.GetGwintManager().GwentNeutralNameToInt( cardName );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardSpcl' ))
		{
			return theGame.GetGwintManager().GwentSpecialNameToInt( cardName );
		}
		
		return -1;
	}
	
	public final function AddGwentCard(cardName : name, amount : int) : bool
	{
		var dm : CDefinitionsManagerAccessor;
		var cardIndex, i : int;
		var tut : STutorialMessage;
		
		//getting new gwent card tutorial - cannot be done in quest as there is no way to send signal
		//to that phase if player activated it before patch
		if(FactsQuerySum("q001_nightmare_ended") > 0 && ShouldProcessTutorial('TutorialGwentDeckBuilder2'))
		{
			tut.type = ETMT_Hint;
			tut.tutorialScriptTag = 'TutorialGwentDeckBuilder2';
			tut.journalEntryName = 'TutorialGwentDeckBuilder2';
			tut.hintPositionType = ETHPT_DefaultGlobal;
			tut.markAsSeenOnShow = true;
			tut.hintDurationType = ETHDT_Long;

			theGame.GetTutorialSystem().DisplayTutorial(tut);
		}
		
		dm = theGame.GetDefinitionsManager();
		
		cardIndex = GetGwentCardIndex(cardName);
		
		if (cardIndex != -1)
		{
			FactsAdd("Gwint_Card_Looted");
			
			for(i = 0; i < amount; i += 1)
			{
				theGame.GetGwintManager().AddCardToCollection( cardIndex );
			}
		}
		
		if( dm.ItemHasTag( cardName, 'GwentTournament' ) )
		{
			if ( dm.ItemHasTag( cardName, 'GT1' ) )
			{
				FactsAdd( "GwentTournament", 1 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT2' ) )
			{
				FactsAdd( "GwentTournament", 2 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT3' ) )
			{
				FactsAdd( "GwentTournament", 3 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT4' ) )
			{
				FactsAdd( "GwentTournament", 4 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT5' ) )
			{
				FactsAdd( "GwentTournament", 5 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT6' ) )
			{
				FactsAdd( "GwentTournament", 6 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT7' ) )
			{
				FactsAdd( "GwentTournament", 7 );
			}
			
			CheckGwentTournamentDeck();
		}
		else
		{
			return false;
		}
		
		return true;
	}
	
	
	public final function RemoveGwentCard(cardName : name, amount : int) : bool
	{
		var dm : CDefinitionsManagerAccessor;
		var cardIndex, i : int;
		
		dm = theGame.GetDefinitionsManager();
		
		if(dm.ItemHasTag( cardName , 'GwintCardLeader' )) //Checks for Gwent cards factions
		{
			cardIndex = theGame.GetGwintManager().GwentLeadersNametoInt( cardName );
			for(i=0; i<amount; i+=1)
				theGame.GetGwintManager().RemoveCardFromCollection( cardIndex );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardNrkd' ))
		{
			cardIndex = theGame.GetGwintManager().GwentNrkdNameToInt( cardName );
			for(i=0; i<amount; i+=1)
				theGame.GetGwintManager().RemoveCardFromCollection( cardIndex );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardNlfg' ))
		{
			cardIndex = theGame.GetGwintManager().GwentNlfgNameToInt( cardName );
			for(i=0; i<amount; i+=1)
				theGame.GetGwintManager().RemoveCardFromCollection( cardIndex );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardSctl' ))
		{
			cardIndex = theGame.GetGwintManager().GwentSctlNameToInt( cardName );
			for(i=0; i<amount; i+=1)
				theGame.GetGwintManager().RemoveCardFromCollection( cardIndex );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardMstr' ))
		{
			cardIndex = theGame.GetGwintManager().GwentMstrNameToInt( cardName );
			for(i=0; i<amount; i+=1)
				theGame.GetGwintManager().RemoveCardFromCollection( cardIndex );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardNeutral' ))
		{
			cardIndex = theGame.GetGwintManager().GwentNeutralNameToInt( cardName );
			for(i=0; i<amount; i+=1)
				theGame.GetGwintManager().RemoveCardFromCollection( cardIndex );
		}
		else if(dm.ItemHasTag( cardName , 'GwintCardSpcl' ))
		{
			cardIndex = theGame.GetGwintManager().GwentSpecialNameToInt( cardName );
			for(i=0; i<amount; i+=1)
				theGame.GetGwintManager().RemoveCardFromCollection( cardIndex );
		}
		
		if( dm.ItemHasTag( cardName, 'GwentTournament' ) )
		{
			if ( dm.ItemHasTag( cardName, 'GT1' ) )
			{
				FactsSubstract( "GwentTournament", 1 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT2' ) )
			{
				FactsSubstract( "GwentTournament", 2 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT3' ) )
			{
				FactsSubstract( "GwentTournament", 3 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT4' ) )
			{
				FactsSubstract( "GwentTournament", 4 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT5' ) )
			{
				FactsSubstract( "GwentTournament", 5 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT6' ) )
			{
				FactsSubstract( "GwentTournament", 6 );
			}
			
			else if ( dm.ItemHasTag( cardName, 'GT7' ) )
			{
				FactsSubstract( "GwentTournament", 7 );
			}
			
			CheckGwentTournamentDeck();
		}
		
		else
		{
			return false;
		}
		
		return true;
	}
	
	function CheckGwentTournamentDeck()
	{
		var gwentPower			: int;
		var neededGwentPower	: int;
		var checkBreakpoint		: int;
		
		neededGwentPower = 70;
		
		checkBreakpoint = neededGwentPower/5;
		gwentPower = FactsQuerySum( "GwentTournament" );
		
		if ( gwentPower >= neededGwentPower )
		{
			FactsAdd( "HasGwentTournamentDeck", 1 );
		}
		else
		{
			if( FactsDoesExist( "HasGwentTournamentDeck" ) )
			{
				FactsRemove( "HasGwentTournamentDeck" );
			}
			
			if ( gwentPower >= checkBreakpoint )
			{
				FactsAdd( "GwentTournamentObjective1", 1 );
			}
			else if ( FactsDoesExist( "GwentTournamentObjective1" ) )
			{
				FactsRemove( "GwentTournamentObjective1" );
			}
			
			if ( gwentPower >= checkBreakpoint*2 )
			{
				FactsAdd( "GwentTournamentObjective2", 1 );
			}
			else if ( FactsDoesExist( "GwentTournamentObjective2" ) )
			{
				FactsRemove( "GwentTournamentObjective2" );
			}
			
			if ( gwentPower >= checkBreakpoint*3 )
			{
				FactsAdd( "GwentTournamentObjective3", 1 );
			}
			else if ( FactsDoesExist( "GwentTournamentObjective3" ) )
			{
				FactsRemove( "GwentTournamentObjective3" );
			}
			
			if ( gwentPower >= checkBreakpoint*4 )
			{
				FactsAdd( "GwentTournamentObjective4", 1 );
			}
			else if ( FactsDoesExist( "GwentTournamentObjective4" ) )
			{
				FactsRemove( "GwentTournamentObjective4" );
			}
		}
	}
	
	
	////////////////////////////////////////////////////////////////////////////
	////////////////////  @MEDITATION  /////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////
	
	public function SimulateBuffTimePassing(simulatedTime : float)
	{
		super.SimulateBuffTimePassing(simulatedTime);
		
		FinishQuen(true);
	}
	
	//Can player kneel and enter meditation mode. Does NOT check for 'waiting' mechanics
	public function CanMeditate() : bool
	{
		var currentStateName : name;
		
		currentStateName = GetCurrentStateName();
		
		//cannot play kneel animation
		if(currentStateName == 'Exploration' && !CanPerformPlayerAction())
			return false;
		
		//not in exloration or meditation
		if(GetCurrentStateName() != 'Exploration' && GetCurrentStateName() != 'Meditation' && GetCurrentStateName() != 'MeditationWaiting')
			return false;
			
		//not in vehicles
		if(GetUsedVehicle())
			return false;
			
		//not if in water
		return CanMeditateHere();
	}
	
	//If the 'waiting' mechanic is available
	public final function CanMeditateWait(optional skipMeditationStateCheck : bool) : bool
	{
		var currState : name;
		
		currState = GetCurrentStateName();
		
		//if not meditating then cannot meditate wait. Also hack for exploration - if game time is paused by menus we might not have had
		//enough time to enter meditation state, and are frozen inbetween
		if(!skipMeditationStateCheck && currState != 'Meditation')
			return false;
			
		//if time stopped cannot meditate as time does not flow at all
		if(theGame.IsGameTimePaused())
			return false;
			
		if(!IsActionAllowed( EIAB_MeditationWaiting ))
			return false;
			
		return true;
	}

	//Is current position ok for kneeling to meditate
	public final function CanMeditateHere() : bool
	{
		var pos	: Vector;
		
		pos = GetWorldPosition();
		if(pos.Z <= theGame.GetWorld().GetWaterLevel(pos, true) && IsInShallowWater())
			return false;
		
		if(IsThreatened())
			return false;
		
		return true;
	}
	
	//Makes player kneel and enter meditation. Does not WAIT any time yet
	public function Meditate()
	{
		var medState 			: W3PlayerWitcherStateMeditation;
	
		if (!CanMeditate() || GetCurrentStateName() == 'Meditation' || GetCurrentStateName() == 'MeditationWaiting')
			return;
	
		GotoState('Meditation');
		medState = (W3PlayerWitcherStateMeditation)GetState('Meditation');		
		medState.SetMeditationPointHeading(GetHeading());
	}
	
	//healhs health, restores alchemy items
	public final function MeditationRestoring(simulatedTime : float)
	{
		//health
		if ( theGame.GetDifficultyMode() != EDM_Hard && theGame.GetDifficultyMode() != EDM_Hardcore ) 
		{
			Heal(GetStatMax(BCS_Vitality));
		}
		
		// toxicity
		abilityManager.DrainToxicity( abilityManager.GetStat( BCS_Toxicity ) );
		abilityManager.DrainFocus( abilityManager.GetStat( BCS_Focus ) );
		
		//items
		inv.SingletonItemsRefillAmmo();
		
		//potions
		SimulateBuffTimePassing(simulatedTime);
	}
	
	var clockMenu : CR4MeditationClockMenu;
	
	public function MeditationClockStart(m : CR4MeditationClockMenu)
	{
		clockMenu = m;
		AddTimer('UpdateClockTime',0.1,true);
	}
	
	public function MeditationClockStop()
	{
		clockMenu = NULL;
		RemoveTimer('UpdateClockTime');
	}
	
	public timer function UpdateClockTime(dt : float, id : int)
	{
		if(clockMenu)
			clockMenu.UpdateCurrentHours();
		else
			RemoveTimer('UpdateClockTime');
	}
	
	private var waitTimeHour : int;
	public function SetWaitTargetHour(t : int)
	{
		waitTimeHour = t;
	}
	public function GetWaitTargetHour() : int
	{
		return waitTimeHour;
	}
	
	public function MeditationForceAbort(forceCloseUI : bool)
	{
		var waitt : W3PlayerWitcherStateMeditationWaiting;
		var medd : W3PlayerWitcherStateMeditation;
		var currentStateName : name;
		
		currentStateName = GetCurrentStateName();
		
		if(currentStateName == 'MeditationWaiting')
		{
			waitt = (W3PlayerWitcherStateMeditationWaiting)GetCurrentState();
			if(waitt)
			{
				waitt.StopRequested(forceCloseUI);
			}
		}
		else if(currentStateName == 'Meditation')
		{
			medd = (W3PlayerWitcherStateMeditation)GetCurrentState();
			if(medd)
			{
				medd.StopRequested(forceCloseUI);
			}
		}
		
		//because UI handles meditation differently right now, we no longer enter Meditation when entering panel and 
		//when waiting the game is not running (no ticks)
		if(forceCloseUI && theGame.GetGuiManager().IsAnyMenu())
		{
			theGame.GetGuiManager().GetRootMenu().CloseMenu();
			DisplayActionDisallowedHudMessage(EIAB_MeditationWaiting, false, false, true, false);
		}
	}
	
	public function Runeword10Triggerred()
	{
		var min, max : SAbilityAttributeValue; 
		
		theGame.GetDefinitionsManager().GetAbilityAttributeValue( 'Runeword 10 _Stats', 'stamina', min, max );
		GainStat(BCS_Stamina, min.valueMultiplicative * GetStatMax(BCS_Stamina));
		PlayEffect('runeword_10_stamina');
	}
	
	public function Runeword12Triggerred()
	{
		var min, max : SAbilityAttributeValue;
		
		theGame.GetDefinitionsManager().GetAbilityAttributeValue( 'Runeword 12 _Stats', 'focus', min, max );
		GainStat(BCS_Focus, RandRangeF(max.valueAdditive, min.valueAdditive));
		PlayEffect('runeword_20_adrenaline');	//fx has typo in name
	}
	
	var runeword10TriggerredOnFinisher, runeword12TriggerredOnFinisher : bool;
	
	event OnFinisherStart()
	{
		super.OnFinisherStart();
		
		runeword10TriggerredOnFinisher = false;
		runeword12TriggerredOnFinisher = false;
	}
	
	////////////////////////////////////////////////////////////////////////////
	////////////////////  @DEBUG  //////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////
	
	public function CheatResurrect()
	{
		super.CheatResurrect();
		theGame.ReleaseNoSaveLock(theGame.deathSaveLockId);
		theInput.RestoreContext( 'Exploration', true );	
	}
	
	//testing skills equip
	public function Debug_EquipTestingSkills(equip : bool, force : bool)
	{
		var skills : array<ESkill>;
		var i, slot : int;
		
		//make pam believe it's level 36 so it unlocks skill slots
		((W3PlayerAbilityManager)abilityManager).OnLevelGained(36);
		
		skills.PushBack(S_Magic_s01);
		skills.PushBack(S_Magic_s02);
		skills.PushBack(S_Magic_s03);
		skills.PushBack(S_Magic_s04);
		skills.PushBack(S_Magic_s05);
		skills.PushBack(S_Sword_s01);
		skills.PushBack(S_Sword_s02);
		
		//equip special skills
		if(equip)
		{
			for(i=0; i<skills.Size(); i+=1)
			{
				if(!force && IsSkillEquipped(skills[i]))
					continue;
					
				//add skill
				if(GetSkillLevel(skills[i]) == 0)
					AddSkill(skills[i]);
				
				//find free slot
				if(force)
					slot = i+1;		//slots are numbered 1+ not 0+
				else
					slot = GetFreeSkillSlot();
				
				//equip
				EquipSkill(skills[i], slot);
			}
		}
		else
		{
			for(i=0; i<skills.Size(); i+=1)
			{
				UnequipSkill(GetSkillSlotID(skills[i]));
			}
		}
	}
	
	public function Debug_ClearCharacterDevelopment(optional keepInv : bool)
	{
		var template : CEntityTemplate;
		var entity : CEntity;
		var invTesting : CInventoryComponent;
		var i : int;
		var items : array<SItemUniqueId>;
		var abs : array<name>;
		var totalExp : int;
		var currentLevel : int;
		var totalSkillPoints : int;
		var skillPointDifference : int;
		
		inv.GetAllItems(items);
		for(i=0; i<items.Size(); i+=1)
		{
			if(inv.ItemHasTag(items[i], 'MutagenIngredient'))	
				UnequipItem(items[i]);
		}
		
		//remove old abilities
		abs = GetAbilities(false);
		for(i=0; i<abs.Size(); i+=1)
			RemoveAbility(abs[i]);
			
		//get default abilities and add them
		abs.Clear();
		GetCharacterStatsParam(abs);		
		for(i=0; i<abs.Size(); i+=1)
			AddAbility(abs[i]);
					
		// Triangle save character data before clearing
		totalExp = levelManager.GetPointsTotal(EExperiencePoint);
		currentLevel = levelManager.GetLevel();
		totalSkillPoints = levelManager.GetPointsTotal(ESkillPoint);
		
		//leveling
		delete levelManager;
		levelManager = new W3LevelManager in this;			
		levelManager.Initialize();
		levelManager.PostInit(this, false);		

		// Triangle re-level and re-point
		levelManager.AddPoints(EExperiencePoint, totalExp, true, true);
		/* Note that the following doesn't account for all edge cases wrt custom leveling and places of power.
		 * example: if you are level 8 with 12 total skill points (8 from level, 4 from PoP) and you switch to a mod that gives 2 points per level,
		 * you'll have 16 after cleardevelop instead of 20 like you should. You lose the PoP skill points. Will fix this later
		 */
		if ( theGame.GetInGameConfigWrapper().IsGroupVisible('SCOptionLB') )		
				skillPointDifference = totalSkillPoints - (levelManager.GetPointsTotal(ESkillPoint)/StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('SCOptionLB', 'SPG')));
			else
				skillPointDifference = totalSkillPoints - levelManager.GetPointsTotal(ESkillPoint);

		if (skillPointDifference > 0)
		{
			levelManager.AddPoints(ESkillPoint, skillPointDifference, true);
		}
						
		//skills, perks etc., exp, buffs
		delete abilityManager;
		//AddAbility('GeraltSkills_Testing');
		SetAbilityManager();		//defined in inheriting classes but must be called before setting any other managers - sets skills and stats
		abilityManager.Init(this, GetCharacterStats(), false, theGame.GetDifficultyMode());
		
		delete effectManager;
		SetEffectManager();
		
		abilityManager.PostInit();						//called after other managers are ready	
	}
	
	final function Debug_HAX_UnlockSkillSlot(slotIndex : int) : bool
	{
		if(abilityManager && abilityManager.IsInitialized())
			return ((W3PlayerAbilityManager)abilityManager).Debug_HAX_UnlockSkillSlot(slotIndex);
			
		return false;
	}
	
	
	public function GetLevelupAbility( id : int) : name
	{
		return levelupAbilities[ id ];
	}
	
	
	public function CanSprint( speed : float ) : bool
	{
		if( !super.CanSprint( speed ) )
		{
			return false;
		}		
		if( rangedWeapon && rangedWeapon.GetCurrentStateName() != 'State_WeaponWait' )
		{
			if ( this.GetPlayerCombatStance() ==  PCS_AlertNear )
			{
				if ( IsSprintActionPressed() )
					OnRangedForceHolster( true, false );
			}
			else
				return false;
		}
		if( GetCurrentStateName() != 'Swimming' && GetStat(BCS_Stamina) <= 0 )
		{
			SetSprintActionPressed(false,true);
			return false;
		}
		
		return true;
	}
	
	// Purpose of this command is ONLY to allow to continue testing on saves with broken horse manager
	// DO NOT USE IT OTHERWISE
	public function RestoreHorseManager() : bool
	{
		var horseTemplate 	: CEntityTemplate;
		var horseManager 	: W3HorseManager;	
		
		if ( GetHorseManager() )
		{
			return false;
		}
		
		horseTemplate = (CEntityTemplate)LoadResource("horse_manager");
		horseManager = (W3HorseManager)theGame.CreateEntity(horseTemplate, GetWorldPosition(),,,,,PM_Persist);
		horseManager.CreateAttachment(this);
		horseManager.OnCreated();
		EntityHandleSet( horseManagerHandle, horseManager );	
		
		return true;
	}
	
	//private saved var blockedSigns : array<ESignType>;
	
	/*public final function BlockSignSelection(signType : ESignType, block : bool)
	{
		if(block && !blockedSigns.Contains(signType))
			blockedSigns.PushBack(signType);
		else if(!block)
			blockedSigns.Remove(signType);
	}*/
	
	/*public final function GetBlockedSigns () : array<ESignType>
	{
		return blockedSigns;
	}*/
	
	public final function IsSignBlocked(signType : ESignType) : bool
	{
		switch( signType )
		{
			case ST_Aard :
				return IsRadialSlotBlocked ( 'Aard');
				break;
			case ST_Axii :
				return IsRadialSlotBlocked ( 'Axii');
				break;
			case ST_Igni :
				return IsRadialSlotBlocked ( 'Igni');
				break;
			case ST_Quen :
				return IsRadialSlotBlocked ( 'Quen');
				break;
			case ST_Yrden :
				return IsRadialSlotBlocked ( 'Yrden');
				break;
			default:
				break;
		}
		return false;
		//return blockedSigns.Contains(signType);
	}
	
	public final function AddAnItemWithAutogenLevelAndQuality(itemName : name, desiredLevel : int, minQuality : int, optional equipItem : bool)
	{
		var itemLevel, quality : int;
		var ids : array<SItemUniqueId>;
		var attemptCounter : int;
		
		itemLevel = 0;
		quality = 0;
		attemptCounter = 0;
		while(itemLevel != desiredLevel || quality < minQuality)
		{
			attemptCounter += 1;
			ids.Clear();
			ids = inv.AddAnItem(itemName, 1, true);
			itemLevel = inv.GetItemLevel(ids[0]);
			quality = RoundMath(CalculateAttributeValue(inv.GetItemAttributeValue(ids[0], 'quality')));
			
			//if not doable at all
			if(attemptCounter >= 1000)
				break;
			
			if(itemLevel != desiredLevel || quality < minQuality)
				inv.RemoveItem(ids[0]);
		}
		
		if(equipItem)
			EquipItem(ids[0]);
	}
	
	public final function AddAnItemWithAutogenLevel(itemName : name, desiredLevel : int)
	{
		var itemLevel : int;
		var ids : array<SItemUniqueId>;
		var attemptCounter : int;

		itemLevel = 0;
		while(itemLevel != desiredLevel)
		{
			attemptCounter += 1;
			ids.Clear();
			ids = inv.AddAnItem(itemName, 1, true);
			itemLevel = inv.GetItemLevel(ids[0]);
			
			//if not doable at all
			if(attemptCounter >= 1000)
				break;
				
			if(itemLevel != desiredLevel)
				inv.RemoveItem(ids[0]);
		}
	}
	
	public final function AddAnItemWithMinQuality(itemName : name, minQuality : int, optional equip : bool)
	{
		var quality : int;
		var ids : array<SItemUniqueId>;
		var attemptCounter : int;

		quality = 0;
		while(quality < minQuality)
		{
			attemptCounter += 1;
			ids.Clear();
			ids = inv.AddAnItem(itemName, 1, true);
			quality = RoundMath(CalculateAttributeValue(inv.GetItemAttributeValue(ids[0], 'quality')));
			
			//if not doable at all
			if(attemptCounter >= 1000)
				break;
				
			if(quality < minQuality)
				inv.RemoveItem(ids[0]);
		}
		
		if(equip)
			EquipItem(ids[0]);
	}
	
	public final function StandaloneEp1_1()
	{
		var i, inc, quantityLow, randLow, quantityMedium, randMedium, quantityHigh, randHigh, startingMoney : int;
		var pam : W3PlayerAbilityManager;
		var ids : array<SItemUniqueId>;
		var STARTING_LEVEL : int;
		
		FactsAdd("StandAloneEP1", 1);
		
		//clear inventory
		inv.RemoveAllItems();
		
		//add required quest items
		inv.AddAnItem('Illusion Medallion', 1, true, true, false);
		inv.AddAnItem('q103_safe_conduct', 1, true, true, false);
		
		//remove all achievements
		theGame.GetGamerProfile().ClearAllAchievementsForEP1();
		
		//set level
		STARTING_LEVEL = 32;
		inc = STARTING_LEVEL - GetLevel();
		for(i=0; i<inc; i+=1)
		{
			levelManager.AddPoints(EExperiencePoint, levelManager.GetTotalExpForNextLevel() - levelManager.GetPointsTotal(EExperiencePoint), false);
		}
		
		//release all skillpoints
		levelManager.ResetCharacterDev();
		pam = (W3PlayerAbilityManager)abilityManager;
		if(pam)
		{
			pam.ResetCharacterDev();
		}
		levelManager.SetFreeSkillPoints(levelManager.GetLevel() - 1 + 11);	//+1 for q111 quest reward, +10 because balancing
		
		//mutagen ings
		inv.AddAnItem('Mutagen red', 4);
		inv.AddAnItem('Mutagen green', 4);
		inv.AddAnItem('Mutagen blue', 4);
		inv.AddAnItem('Lesser mutagen red', 2);
		inv.AddAnItem('Lesser mutagen green', 2);
		inv.AddAnItem('Lesser mutagen blue', 2);
		inv.AddAnItem('Greater mutagen green', 1);
		inv.AddAnItem('Greater mutagen blue', 2);
		
		//money
		startingMoney = 20000;
		if(GetMoney() > startingMoney)
		{
			RemoveMoney(GetMoney() - startingMoney);
		}
		else
		{
			AddMoney( 20000 - GetMoney() );
		}
		
		//armor
		/*
		inv.AddAnItem('Light armor 01r');
		inv.AddAnItem('Boots 04');
		inv.AddAnItem('Gloves 04');
		inv.AddAnItem('Pants 04');
		
		AddAnItemWithMinQuality('Medium armor 05r', 3, true);
		AddAnItemWithMinQuality('Boots 032', 3, true);
		AddAnItemWithMinQuality('Heavy gloves 02', 3, true);
		AddAnItemWithMinQuality('Pants 03', 3, true);
		
		inv.AddAnItem('Heavy armor 05r');
		inv.AddAnItem('Heavy boots 08');
		inv.AddAnItem('Heavy gloves 04');
		inv.AddAnItem('Heavy pants 04');
		
		//swords
		AddAnItemWithMinQuality('Gnomish sword 2', 3, true);
		AddAnItemWithMinQuality('Azurewrath', 3, true);
		*/
		
		//armor
		ids.Clear();
		ids = inv.AddAnItem('EP1 Standalone Starting Armor');
		EquipItem(ids[0]);
		ids.Clear();
		ids = inv.AddAnItem('EP1 Standalone Starting Boots');
		EquipItem(ids[0]);
		ids.Clear();
		ids = inv.AddAnItem('EP1 Standalone Starting Gloves');
		EquipItem(ids[0]);
		ids.Clear();
		ids = inv.AddAnItem('EP1 Standalone Starting Pants');
		EquipItem(ids[0]);
		
		//swords
		ids.Clear();
		ids = inv.AddAnItem('EP1 Standalone Starting Steel Sword');
		EquipItem(ids[0]);
		ids.Clear();
		ids = inv.AddAnItem('EP1 Standalone Starting Silver Sword');
		EquipItem(ids[0]);
		
		//torch
		inv.AddAnItem('Torch', 1, true, true, false);
		
		//crafting ingredients
		quantityLow = 1;
		randLow = 3;
		quantityMedium = 4;
		randMedium = 4;
		quantityHigh = 8;
		randHigh = 6;
		
		inv.AddAnItem('Alghoul bone marrow',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Amethyst dust',quantityLow+RandRange(randLow));
		inv.AddAnItem('Arachas eyes',quantityLow+RandRange(randLow));
		inv.AddAnItem('Arachas venom',quantityLow+RandRange(randLow));
		inv.AddAnItem('Basilisk hide',quantityLow+RandRange(randLow));
		inv.AddAnItem('Basilisk venom',quantityLow+RandRange(randLow));
		inv.AddAnItem('Bear pelt',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Berserker pelt',quantityLow+RandRange(randLow));
		inv.AddAnItem('Coal',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Cotton',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Dark iron ingot',quantityLow+RandRange(randLow));
		inv.AddAnItem('Dark iron ore',quantityLow+RandRange(randLow));
		inv.AddAnItem('Deer hide',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Diamond dust',quantityLow+RandRange(randLow));
		inv.AddAnItem('Draconide leather',quantityLow+RandRange(randLow));
		inv.AddAnItem('Drowned dead tongue',quantityLow+RandRange(randLow));
		inv.AddAnItem('Drowner brain',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Dwimeryte ingot',quantityLow+RandRange(randLow));
		inv.AddAnItem('Dwimeryte ore',quantityLow+RandRange(randLow));
		inv.AddAnItem('Emerald dust',quantityLow+RandRange(randLow));
		inv.AddAnItem('Endriag chitin plates',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Endriag embryo',quantityLow+RandRange(randLow));
		inv.AddAnItem('Ghoul blood',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Goat hide',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Hag teeth',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Hardened leather',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Hardened timber',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Harpy feathers',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Horse hide',quantityLow+RandRange(randLow));
		inv.AddAnItem('Iron ore',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Leather straps',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Leather',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Linen',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Meteorite ingot',quantityLow+RandRange(randLow));
		inv.AddAnItem('Meteorite ore',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Necrophage skin',quantityLow+RandRange(randLow));
		inv.AddAnItem('Nekker blood',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Nekker heart',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Oil',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Phosphorescent crystal',quantityLow+RandRange(randLow));
		inv.AddAnItem('Pig hide',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Pure silver',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Rabbit pelt',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Rotfiend blood',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Sapphire dust',quantityLow+RandRange(randLow));
		inv.AddAnItem('Silk',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Silver ingot',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Silver ore',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Specter dust',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Steel ingot',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Steel plate',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('String',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Thread',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Timber',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Twine',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Venom extract',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Water essence',quantityMedium+RandRange(randMedium));
		inv.AddAnItem('Wolf liver',quantityHigh+RandRange(randHigh));
		inv.AddAnItem('Wolf pelt',quantityMedium+RandRange(randMedium));
		
		inv.AddAnItem('Alcohest', 5);
		inv.AddAnItem('Dwarven spirit', 5);
	
		//crossbow, bolts
		ids.Clear();
		ids = inv.AddAnItem('Crossbow 5');
		EquipItem(ids[0]);
		ids.Clear();
		ids = inv.AddAnItem('Blunt Bolt', 100);
		EquipItem(ids[0]);
		inv.AddAnItem('Broadhead Bolt', 100);
		inv.AddAnItem('Split Bolt', 100);
		
		//remove recipes
		RemoveAllAlchemyRecipes();
		RemoveAllCraftingSchematics();
		
		//recipes - potions
		//AddAlchemyRecipe('Recipe for Black Blood 1');
		//AddAlchemyRecipe('Recipe for Blizzard 1');
		AddAlchemyRecipe('Recipe for Cat 1');
		//AddAlchemyRecipe('Recipe for Full Moon 1');
		//AddAlchemyRecipe('Recipe for Golden Oriole 1');
		//AddAlchemyRecipe('Recipe for Killer Whale 1');
		AddAlchemyRecipe('Recipe for Maribor Forest 1');
		AddAlchemyRecipe('Recipe for Petris Philtre 1');
		AddAlchemyRecipe('Recipe for Swallow 1');
		AddAlchemyRecipe('Recipe for Tawny Owl 1');
		//AddAlchemyRecipe('Recipe for Thunderbolt 1');
		AddAlchemyRecipe('Recipe for White Gull 1');
		AddAlchemyRecipe('Recipe for White Honey 1');
		AddAlchemyRecipe('Recipe for White Raffards Decoction 1');
		/*
		AddAlchemyRecipe('Recipe for Black Blood 2');
		AddAlchemyRecipe('Recipe for Blizzard 2');
		AddAlchemyRecipe('Recipe for Cat 2');
		AddAlchemyRecipe('Recipe for Full Moon 2');
		AddAlchemyRecipe('Recipe for Golden Oriole 2');
		AddAlchemyRecipe('Recipe for Killer Whale 2');
		AddAlchemyRecipe('Recipe for Maribor Forest 2');
		AddAlchemyRecipe('Recipe for Petris Philtre 2');
		AddAlchemyRecipe('Recipe for Swallow 2');
		AddAlchemyRecipe('Recipe for Tawny Owl 2');
		AddAlchemyRecipe('Recipe for Thunderbolt 2');
		AddAlchemyRecipe('Recipe for White Gull 2');
		AddAlchemyRecipe('Recipe for White Honey 2');
		AddAlchemyRecipe('Recipe for White Raffards Decoction 2');	
		*/
		
		//recipes - oils
		AddAlchemyRecipe('Recipe for Beast Oil 1');
		AddAlchemyRecipe('Recipe for Cursed Oil 1');
		AddAlchemyRecipe('Recipe for Hanged Man Venom 1');
		AddAlchemyRecipe('Recipe for Hybrid Oil 1');
		AddAlchemyRecipe('Recipe for Insectoid Oil 1');
		AddAlchemyRecipe('Recipe for Magicals Oil 1');
		AddAlchemyRecipe('Recipe for Necrophage Oil 1');
		AddAlchemyRecipe('Recipe for Specter Oil 1');
		AddAlchemyRecipe('Recipe for Vampire Oil 1');
		AddAlchemyRecipe('Recipe for Draconide Oil 1');
		AddAlchemyRecipe('Recipe for Ogre Oil 1');
		AddAlchemyRecipe('Recipe for Relic Oil 1');
		AddAlchemyRecipe('Recipe for Beast Oil 2');
		AddAlchemyRecipe('Recipe for Cursed Oil 2');
		AddAlchemyRecipe('Recipe for Hanged Man Venom 2');
		AddAlchemyRecipe('Recipe for Hybrid Oil 2');
		AddAlchemyRecipe('Recipe for Insectoid Oil 2');
		AddAlchemyRecipe('Recipe for Magicals Oil 2');
		AddAlchemyRecipe('Recipe for Necrophage Oil 2');
		AddAlchemyRecipe('Recipe for Specter Oil 2');
		AddAlchemyRecipe('Recipe for Vampire Oil 2');
		AddAlchemyRecipe('Recipe for Draconide Oil 2');
		AddAlchemyRecipe('Recipe for Ogre Oil 2');
		AddAlchemyRecipe('Recipe for Relic Oil 2');
		
		//recipes - bombs
		AddAlchemyRecipe('Recipe for Dancing Star 1');
		//AddAlchemyRecipe('Recipe for Devils Puffball 1');
		AddAlchemyRecipe('Recipe for Dwimeritum Bomb 1');
		//AddAlchemyRecipe('Recipe for Dragons Dream 1');
		AddAlchemyRecipe('Recipe for Grapeshot 1');
		AddAlchemyRecipe('Recipe for Samum 1');
		//AddAlchemyRecipe('Recipe for Silver Dust Bomb 1');
		AddAlchemyRecipe('Recipe for White Frost 1');
		/*
		AddAlchemyRecipe('Recipe for Dancing Star 2');
		AddAlchemyRecipe('Recipe for Devils Puffball 2');
		AddAlchemyRecipe('Recipe for Dwimeritum Bomb 2');
		AddAlchemyRecipe('Recipe for Dragons Dream 2');
		AddAlchemyRecipe('Recipe for Grapeshot 2');
		AddAlchemyRecipe('Recipe for Samum 2');
		AddAlchemyRecipe('Recipe for Silver Dust Bomb 2');
		AddAlchemyRecipe('Recipe for White Frost 2');
		*/
		
		//recipes - alcohol
		AddAlchemyRecipe('Recipe for Dwarven spirit 1');
		AddAlchemyRecipe('Recipe for Alcohest 1');
		AddAlchemyRecipe('Recipe for White Gull 1');
		
		//crafting recipes
		AddStartingSchematics();
		
		//cooked alchemy items
		ids.Clear();
		ids = inv.AddAnItem('Swallow 2');
		EquipItem(ids[0]);
		ids.Clear();
		ids = inv.AddAnItem('Thunderbolt 2');
		EquipItem(ids[0]);
		ids.Clear();
		ids = inv.AddAnItem('Tawny Owl 2');
		EquipItem(ids[0]);
		ids.Clear();
		
		ids = inv.AddAnItem('Grapeshot 2');
		EquipItem(ids[0]);
		ids.Clear();
		ids = inv.AddAnItem('Samum 2');
		EquipItem(ids[0]);
		
		inv.AddAnItem('Dwimeritum Bomb 1');
		inv.AddAnItem('Dragons Dream 1');
		inv.AddAnItem('Silver Dust Bomb 1');
		inv.AddAnItem('White Frost 2');
		inv.AddAnItem('Devils Puffball 2');
		inv.AddAnItem('Dancing Star 2');
		inv.AddAnItem('Beast Oil 1');
		inv.AddAnItem('Cursed Oil 1');
		inv.AddAnItem('Hanged Man Venom 2');
		inv.AddAnItem('Hybrid Oil 1');
		inv.AddAnItem('Insectoid Oil 1');
		inv.AddAnItem('Magicals Oil 1');
		inv.AddAnItem('Necrophage Oil 2');
		inv.AddAnItem('Specter Oil 1');
		inv.AddAnItem('Vampire Oil 1');
		inv.AddAnItem('Draconide Oil 1');
		inv.AddAnItem('Relic Oil 1');
		inv.AddAnItem('Black Blood 1');
		inv.AddAnItem('Blizzard 1');
		inv.AddAnItem('Cat 2');
		inv.AddAnItem('Full Moon 1');
		inv.AddAnItem('Maribor Forest 1');
		inv.AddAnItem('Petris Philtre 1');
		inv.AddAnItem('White Gull 1', 3);
		inv.AddAnItem('White Honey 2');
		inv.AddAnItem('White Raffards Decoction 1');
		
		//mutagen decoctions
		inv.AddAnItem('Mutagen 17');	//forktail
		inv.AddAnItem('Mutagen 19');	//wraith
		inv.AddAnItem('Mutagen 27');	//griphon
		inv.AddAnItem('Mutagen 26');	//leshen
		
		//repair kits
		inv.AddAnItem('weapon_repair_kit_1', 5);
		inv.AddAnItem('weapon_repair_kit_2', 3);
		inv.AddAnItem('armor_repair_kit_1', 5);
		inv.AddAnItem('armor_repair_kit_2', 3);
		
		//runes
		quantityMedium = 2;
		quantityLow = 1;
		inv.AddAnItem('Rune stribog lesser', quantityMedium);
		inv.AddAnItem('Rune stribog', quantityLow);
		inv.AddAnItem('Rune dazhbog lesser', quantityMedium);
		inv.AddAnItem('Rune dazhbog', quantityLow);
		inv.AddAnItem('Rune devana lesser', quantityMedium);
		inv.AddAnItem('Rune devana', quantityLow);
		inv.AddAnItem('Rune zoria lesser', quantityMedium);
		inv.AddAnItem('Rune zoria', quantityLow);
		inv.AddAnItem('Rune morana lesser', quantityMedium);
		inv.AddAnItem('Rune morana', quantityLow);
		inv.AddAnItem('Rune triglav lesser', quantityMedium);
		inv.AddAnItem('Rune triglav', quantityLow);
		inv.AddAnItem('Rune svarog lesser', quantityMedium);
		inv.AddAnItem('Rune svarog', quantityLow);
		inv.AddAnItem('Rune veles lesser', quantityMedium);
		inv.AddAnItem('Rune veles', quantityLow);
		inv.AddAnItem('Rune perun lesser', quantityMedium);
		inv.AddAnItem('Rune perun', quantityLow);
		inv.AddAnItem('Rune elemental lesser', quantityMedium);
		inv.AddAnItem('Rune elemental', quantityLow);
		
		inv.AddAnItem('Glyph aard lesser', quantityMedium);
		inv.AddAnItem('Glyph aard', quantityLow);
		inv.AddAnItem('Glyph axii lesser', quantityMedium);
		inv.AddAnItem('Glyph axii', quantityLow);
		inv.AddAnItem('Glyph igni lesser', quantityMedium);
		inv.AddAnItem('Glyph igni', quantityLow);
		inv.AddAnItem('Glyph quen lesser', quantityMedium);
		inv.AddAnItem('Glyph quen', quantityLow);
		inv.AddAnItem('Glyph yrden lesser', quantityMedium);
		inv.AddAnItem('Glyph yrden', quantityLow);
		
		//memory exhaust error
		StandaloneEp1_2();
	}
	
	public final function StandaloneEp1_2()
	{
		var horseId : SItemUniqueId;
		var ids : array<SItemUniqueId>;
		var ents : array< CJournalBase >;
		var i : int;
		var manager : CWitcherJournalManager;
		
		//food
		inv.AddAnItem( 'Cows milk', 20 );
		ids.Clear();
		ids = inv.AddAnItem( 'Dumpling', 44 );
		EquipItem(ids[0]);
		
		//clearing potion
		inv.AddAnItem('Clearing Potion', 2, true, false, false);
		
		//horse gear
		GetHorseManager().RemoveAllItems();
		
		ids.Clear();
		ids = inv.AddAnItem('Horse Bag 2');
		horseId = GetHorseManager().MoveItemToHorse(ids[0]);
		GetHorseManager().EquipItem(horseId);
		
		ids.Clear();
		ids = inv.AddAnItem('Horse Blinder 2');
		horseId = GetHorseManager().MoveItemToHorse(ids[0]);
		GetHorseManager().EquipItem(horseId);
		
		ids.Clear();
		ids = inv.AddAnItem('Horse Saddle 2');
		horseId = GetHorseManager().MoveItemToHorse(ids[0]);
		GetHorseManager().EquipItem(horseId);
		
		manager = theGame.GetJournalManager();

		//delete journal entries - bestiary
		manager.GetActivatedOfType( 'CJournalCreature', ents );
		for(i=0; i<ents.Size(); i+=1)
		{
			manager.ActivateEntry(ents[i], JS_Inactive, false, true);
		}
		
		//delete journal entries - characters
		ents.Clear();
		manager.GetActivatedOfType( 'CJournalCharacter', ents );
		for(i=0; i<ents.Size(); i+=1)
		{
			manager.ActivateEntry(ents[i], JS_Inactive, false, true);
		}
		
		//delete journal entries - quest
		ents.Clear();
		manager.GetActivatedOfType( 'CJournalQuest', ents );
		for(i=0; i<ents.Size(); i+=1)
		{
			//don't disable EP1 quest
			if( StrStartsWith(ents[i].baseName, "q60"))
				continue;
				
			manager.ActivateEntry(ents[i], JS_Inactive, false, true);
		}
		
		//tutorial entries activate		
		manager.ActivateEntryByScriptTag('TutorialAard', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialAdrenaline', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialAxii', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialAxiiDialog', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialCamera', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialCamera_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialCiriBlink', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialCiriCharge', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialCiriStamina', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialCounter', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialDialogClose', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialFallingRoll', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialFocus', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialFocusClues', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialFocusClues', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialHorseRoad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialHorseSpeed0', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialHorseSpeed0_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialHorseSpeed1', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialHorseSpeed2', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialHorseSummon', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialHorseSummon_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialIgni', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalAlternateSings', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalBoatDamage', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalBoatMount', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalBuffs', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalCharDevLeveling', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalCharDevSkills', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalCrafting', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalCrossbow', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalDialogGwint', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalDialogShop', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalDive', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalDodge', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalDodge_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalDrawWeapon', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalDrawWeapon_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalDurability', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalExplorations', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalExplorations_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalFastTravel', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalFocusRedObjects', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalGasClouds', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalHeavyAttacks', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalHorse', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalHorseStamina', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalJump', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalLightAttacks', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalLightAttacks_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalMeditation', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalMeditation_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalMonsterThreatLevels', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalMovement', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalMovement_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalMutagenIngredient', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalMutagenPotion', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalOils', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalPetards', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalPotions', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalPotions_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalQuestArea', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalRadial', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalRifts', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalRun', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalShopDescription', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalSignCast', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalSignCast_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalSpecialAttacks', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJournalStaminaExploration', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialJumpHang', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialLadder', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialLadderMove', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialLadderMove_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialObjectiveSwitching', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialOxygen', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialParry', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialPOIUncovered', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialQuen', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialRoll', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialRoll_pad', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialSpeedPairing', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialSprint', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialStaminaSigns', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialStealing', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialSwimmingSpeed', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialTimedChoiceDialog', JS_Active);
		manager.ActivateEntryByScriptTag('TutorialYrden', JS_Active);
		
		//disable quest blocks with tutorials
		FactsAdd('kill_base_tutorials');
		
		//disable already queued tutorials
		theGame.GetTutorialSystem().RemoveAllQueuedTutorials();
		
		//enable start of standalone mode tutorial
		FactsAdd('standalone_ep1');
		FactsRemove("StandAloneEP1");
		
		theGame.GetJournalManager().ForceUntrackingQuestForEP1Savegame();
	}
		function Debug_FocusBoyFocusGain()
	{
		var focusGain : float;
		focusGain = FactsQuerySum("debug_fact_focus_boy") ;
		GainStat(BCS_Focus, focusGain );
	}
}
	
exec function fuqfep1()
{
	theGame.GetJournalManager().ForceUntrackingQuestForEP1Savegame();
}

///////////////////////////////////////////////////////////////////////
// HACKS! DO NOT USE THIS!!! IF IT IS REAAALY NEEDED ASK BEFORE USING!!!! - MAREK
///////////////////////////////////////////////////////////////////////

function GetWitcherPlayer() : W3PlayerWitcher
{
	return (W3PlayerWitcher)thePlayer;
}
