/***********************************************************************/
/** Player skills are divided into trees/groups (sword, alchemy, signs).
/** Each skill tree has its ring levels (reflecting the rings in GUI, where
/** the innermost ring is the highest one). In order to learn a skill of 
/** Nth level you must know at least one skill on the (N-1)th level (you
/** can always learn ring 1 skills). The lowest ring level is 1.
/** Some skills have a ring level of -1 -> this means that this is a skill
/** that is learned automatically without spending skill points (e.g. some 
/** mastery skill).
/**
/** Skills are grouped in skill definitions. A definition holds information 
/** about which skills are available, to which trees and rings they belong
/** etc. Basically if you would like to make several character classes then
/** each of them would use a different skill definition (e.g. mage, warrior).
/** Each definition can make it's own skill placement so for example skill A
/** might be a sword tree ring 2 skill in warriors definition and a combat
/** tree ring 5 skill in rogue definition.
/** This manager loads whole definition and caches it - that's all the skill
/** data you need for this player object.
/**
/** This can be used in multiplayer, addons or for replacers.
/***********************************************************************/
/** Copyright © 2012-2014
/** Author : Tomek Kozera
/**			 Bartosz Bigaj
/***********************************************************************/
/** Modified by Elys ( 13 Oct 2015) for AllSkillsActive v0.7
/***********************************************************************/
/**
/***********************************************************************/
/** Modified by Dazedy (18 Oct 2015) for Better Combat Evolved
/***********************************************************************/

class W3PlayerAbilityManager extends W3AbilityManager
{
	private   saved var skills : array<SSkill>;									//all skills in all skill trees
	
	private   saved var resistStatsItems : array<array<SResistanceValue>>;		//holds cached resist stats from items
	private   saved var toxicityOffset : float;									//mutagens, locked percent of max toxicity
	private 		var pathPointsSpent : array<int>;							//amount of skillpoints spent in each skill path
	private   saved var skillSlots : array<SSkillSlot>;							//skill slots for skills chosen by player	
	protected saved var skillAbilities : array<name>;							//cached list of non-blocked non-GlobalPassive skill abilities
	private 		var totalSkillSlotsCount, orgTotalSkillSlotsCount : int;								//amount of skill slots
	private 		var tempSkills : array<ESkill>;								//list of temporarily added skills
	private   saved var mutagenSlots : array<SMutagenSlot>;						//list of mutagen slots
	private			var temporaryTutorialSkills : array<STutorialTemporarySkill>;	//temp skills added for duration of mutagens tutorial in character panel
	private   saved var ep1SkillsInitialized : bool;
	private   saved var ep2SkillsInitialized : bool;
	
	private const var LINK_BONUS_BLUE, LINK_BONUS_GREEN, LINK_BONUS_RED : name;	//ability added on link color match
	
		default LINK_BONUS_BLUE = 'SkillLinkBonus_Blue';
		default LINK_BONUS_GREEN = 'SkillLinkBonus_Green';
		default LINK_BONUS_RED = 'SkillLinkBonus_Red';
		
		default ep1SkillsInitialized = false;
		default ep2SkillsInitialized = false;
	
	public final function Init(ownr : CActor, cStats : CCharacterStats, isFromLoad : bool, diff : EDifficultyMode) : bool
	{
		var skillDefs : array<name>;
		var i : int;
		
		isInitialized = false;	
		
		if(!ownr)
		{
			LogAssert(false, "W3PlayerAbilityManager.Init: owner is NULL!!!!");
			return false;
		}
		else if(!( (CPlayer)ownr ))
		{
			LogAssert(false, "W3PlayerAbilityManager.Init: trying to create for non-player object!! Aborting!!");
			return false;
		}
		
		//array init
		resistStatsItems.Resize(EnumGetMax('EEquipmentSlots')+1);
		pathPointsSpent.Resize(EnumGetMax('ESkillPath')+1);
		
		//add default player character ability
		ownr.AddAbility(theGame.params.GLOBAL_PLAYER_ABILITY);
		
		if(!super.Init(ownr,cStats, isFromLoad, diff))
			return false;
			
		LogChannel('CHR', "Init W3PlayerAbilityManager "+isFromLoad);		
		
		// init skills
		if(!isFromLoad)
		{
			InitSkillSlots();
	
			//set skill definitions
			skillDefs = charStats.GetAbilitiesWithTag('SkillDefinitionName');		
			LogAssert(skillDefs.Size()>0, "W3PlayerAbilityManager.Init: actor <<" + owner + ">> has no skills!!");
			
			for(i=0; i<skillDefs.Size(); i+=1)
				CacheSkills(skillDefs[i], skills);
				
			LoadMutagenSlotsDataFromXML();
			
			//add initial skills
			InitSkills();
			
			PrecacheModifierSkills();
		}
		else
		{
			tempSkills.Clear();
			temporaryTutorialSkills.Clear();
			
			if ( !ep1SkillsInitialized && theGame.GetDLCManager().IsEP1Available() )
			{				
				ep1SkillsInitialized = FixMissingSkills();
			}
			if ( !ep2SkillsInitialized && theGame.GetDLCManager().IsEP2Available() )
			{
				ep2SkillsInitialized = FixMissingSkills();
			}			
		}
		
		isInitialized = true;
		// Elys start //

		orgTotalSkillSlotsCount = 12;

		for(i=0; i<skills.Size(); i+=1)
		{
			if( MustEquipSkill(skills[i].skillType) )
				ForceEquipSkill(skills[i].skillType);
		}
		// Elys end //

		return true;	
	}
	
	private function FixMissingSkills() : bool
	{
		var i : int;
		var newSkills : array<SSkill>;
		var skillDefs : array<name>;
		var fixedSomething : bool;
		
		skillDefs = charStats.GetAbilitiesWithTag('SkillDefinitionName');		
		LogAssert(skillDefs.Size()>0, "W3PlayerAbilityManager.Init: actor <<" + owner + ">> has no skills!!");
		fixedSomething = false;
		
		for( i = 0; i < skillDefs.Size(); i+=1 )
			CacheSkills(skillDefs[i], newSkills);	

		for(i=0; i<newSkills.Size(); i+=1)
		{
			//completely new skill
			if(i >= skills.Size())
			{
				skills.PushBack( newSkills[i] );
				fixedSomething = true;
				continue;
			}
	
			//missing skill in the middle of array
			if(skills[i].skillType == S_SUndefined && newSkills[i].skillType != S_SUndefined)
			{
				skills[i] = newSkills[i];
				fixedSomething = true;
			}
		}
		
		return fixedSomething;
	}
	
	public function OnOwnerRevived()
	{
		var i : int;
		
		super.OnOwnerRevived();
		
		if(owner == GetWitcherPlayer())
			GetWitcherPlayer().RemoveTemporarySkills();
	}
	
	private final function PrecacheModifierSkills()
	{
		var i, j : int;
		var dm : CDefinitionsManagerAccessor;
		var skill : SSkill;
		var skillIT : int;
		
		dm = theGame.GetDefinitionsManager();
		if( !dm )
		{
			return;
		}
		
		for( skillIT = 0; skillIT < skills.Size(); skillIT += 1 )
		{
			//skill = skills[ skillIT ];
			
			for( i = 0; i < skills.Size(); i += 1 )
			{
				if( i != skillIT )
				{
					for( j = 0; j < skills[ skillIT ].modifierTags.Size(); j += 1)
					{
						//if skill has modifier tag
						if( dm.AbilityHasTag( skills[ i ].abilityName, skills[ skillIT ].modifierTags[ j ] ) )
						{
							skills[ skillIT ].precachedModifierSkills.PushBack( i );
						}
					}
				}
			}
		}
	}
	
	// Called after Init() when other managers are initialized (since effect manager is and must be initialized after ability manager)
	public final function PostInit()
	{		
		var i, playerLevel : int;
	
		if(CanUseSkill(S_Sword_5))
			AddPassiveSkillBuff(S_Sword_5);
			
		//fill skill slot availability
		if( (W3PlayerWitcher)owner )
		{
			playerLevel = ((W3PlayerWitcher)owner).GetLevel();
			for(i=0; i<skillSlots.Size(); i+=1)
			{
				skillSlots[i].unlocked = ( playerLevel >= skillSlots[i].unlockedOnLevel);
			}
		}
	}
	
	public final function GetPlayerSkills() : array<SSkill> //#B
	{
		return skills;
	}
	
	public final function AddTempNonAlchemySkills() : array<SSimpleSkill>
	{
		var i, cnt, j : int;
		var ret : array<SSimpleSkill>;
		var temp : SSimpleSkill;
	
		tempSkills.Clear();
	
		for(i=0; i<skills.Size(); i+=1)
		{
			if(skills[i].skillPath == ESP_Signs && skills[i].level < skills[i].maxLevel)
			{
				temp.skillType = skills[i].skillType;
				temp.level = skills[i].level;
				ret.PushBack(temp);
				
				tempSkills.PushBack(skills[i].skillType);
				
				cnt = skills[i].maxLevel - skills[i].level;
				for(j=0; j<cnt; j+=1)
					AddSkill(skills[i].skillType, true);
			}
		}
		
		return ret;
	}

	public final function GetPlayerSkill(type : ESkill) : SSkill //#B
	{
		return skills[type];
	}
	
	// Adds a passive skill Buff from given skill
	private final function AddPassiveSkillBuff(skill : ESkill)
	{
		if(skill == S_Sword_5 && GetStat(BCS_Focus) >= 1)
			owner.AddEffectDefault(EET_BattleTrance, owner, "BattleTranceSkill");
	}

	private final function ReloadAcquiredSkills(out acquiredSkills : array<SRestoredSkill>)
	{
		var i, j : int;
		
		for(j=acquiredSkills.Size()-1; j>=0; j-=1)		
		{
			for(i=0; i<skills.Size(); i+=1)
			{
				if(skills[i].skillType == acquiredSkills[j].skillType)
				{
					skills[i].level = acquiredSkills[j].level;
					skills[i].isNew = acquiredSkills[j].isNew;
					skills[i].remainingBlockedTime = acquiredSkills[j].remainingBlockedTime;
					
					if(!skills[i].isCoreSkill)
						pathPointsSpent[skills[i].skillPath] = pathPointsSpent[skills[i].skillPath] + 1;
					
					acquiredSkills.Erase(j);
					
					break;
				}
			}
		}
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////    ---===  @EVENTS  ===---    ////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		
	// Called when Focus Stat current value has changed
	protected final function OnFocusChanged()
	{
		var points : float;
		var buff : W3Effect_Toxicity;
		
		points = GetStat(BCS_Focus);
		
		if(points < 1 && owner.HasBuff(EET_BattleTrance))
		{
			owner.RemoveBuff(EET_BattleTrance);
		}
		else if(points >= 1 && !owner.HasBuff(EET_BattleTrance))
		{
			if(CanUseSkill(S_Sword_5))
				owner.AddEffectDefault(EET_BattleTrance, owner, "BattleTranceSkill");
		}
		
		if ( points >= owner.GetStatMax(BCS_Focus) && owner.HasAbility('Runeword 8 _Stats', true) && !owner.HasBuff(EET_Runeword8) )
		{
			owner.AddEffectDefault(EET_Runeword8, owner, "max focus");
		}
	}
	
	// Called when Vitality Stat current value has changed
	protected final function OnVitalityChanged()
	{
		var vitPerc : float;
		
		vitPerc = GetStatPercents(BCS_Vitality);		
		
		if(vitPerc < theGame.params.LOW_HEALTH_EFFECT_SHOW && !owner.HasBuff(EET_LowHealth))
			owner.AddEffectDefault(EET_LowHealth, owner, 'vitality_change');
		else if(vitPerc >= theGame.params.LOW_HEALTH_EFFECT_SHOW && owner.HasBuff(EET_LowHealth))
			owner.RemoveBuff(EET_LowHealth);
			
		if(vitPerc < 1.f)
			ResetOverhealBonus();
	
		theTelemetry.SetCommonStatFlt(CS_VITALITY, GetStat(BCS_Vitality));
	}
	// Called when Air Stat current value has changed
	protected final function OnAirChanged()
	{
		if(GetStat(BCS_Air) > 0)
		{
			if ( owner.HasBuff(EET_Drowning) )
				owner.RemoveBuff(EET_Drowning);
				
			if( owner.HasBuff(EET_Choking) )
				owner.RemoveBuff(EET_Choking);
		}
	}
	
	// Called when Toxicity Stat current value has changed
	protected final function OnToxicityChanged()
	{
		var tox : float;
	
		if( !((W3PlayerWitcher)owner) )
			return;
			
		tox = GetStat(BCS_Toxicity);
	
		//apply toxicity debuff
		if(tox == 0 && owner.HasBuff(EET_Toxicity))
			owner.RemoveBuff(EET_Toxicity);
		else if(tox > 0 && !owner.HasBuff(EET_Toxicity))
			owner.AddEffectDefault(EET_Toxicity,owner,'toxicity_change');
			
		theTelemetry.SetCommonStatFlt(CS_TOXICITY, GetStat(BCS_Toxicity));
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////    ---===  @MUTAGENS  ===---    /////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	public final function GetPlayerSkillMutagens() : array<SMutagenSlot>
	{
		return mutagenSlots;
	}
	
	public final function GetSkillGroupIdOfMutagenSlot(eqSlot : EEquipmentSlots) : int
	{
		var i : int;
		
		i = GetMutagenSlotIndex(eqSlot);
		if(i<0)
			return -1;
			
		return mutagenSlots[i].skillGroupID;
	}
	
	//returns true if given mutagen slot is unlocked and can be used
	public final function IsSkillMutagenSlotUnlocked(eqSlot : EEquipmentSlots) : bool
	{
		var i : int;
		
		i = GetMutagenSlotIndex(eqSlot);
		if(i<0)
			return false;
		
		return ((W3PlayerWitcher)owner).GetLevel() >= mutagenSlots[i].unlockedAtLevel;
	}
	
	private final function GetMutagenSlotForGroupId(groupID : int) : EEquipmentSlots
	{
		var i : int;
		
		for(i=0; i<mutagenSlots.Size(); i+=1)
		{
			if(mutagenSlots[i].skillGroupID == groupID)
			{
				return mutagenSlots[i].equipmentSlot;
			}
		}
		
		return EES_InvalidSlot;
	}
	
	public final function GetSkillGroupsCount() : int
	{
		return mutagenSlots.Size();
	}
	
	public final function GetSkillGroupIDFromIndex(idx : int) : int
	{
		if(idx >= 0 && idx <mutagenSlots.Size())
			return mutagenSlots[idx].skillGroupID;
			
		return -1;
	}
	
	//returns index of mutagen slot paired with given equipment slot
	private final function GetMutagenSlotIndex(eqSlot : EEquipmentSlots) : int
	{
		var i : int;
		
		for(i=0; i<mutagenSlots.Size(); i+=1)
			if(mutagenSlots[i].equipmentSlot == eqSlot)
				return i;
				
		return -1;
	}
	
	//returns index of mutagen slot paired with given item
	private final function GetMutagenSlotIndexFromItemId(item : SItemUniqueId) : int
	{
		var i : int;
		
		for(i=0; i<mutagenSlots.Size(); i+=1)
			if(mutagenSlots[i].item == item)
				return i;
				
		return -1;
	}	
	
	public final function OnSkillMutagenEquipped(item : SItemUniqueId, slot : EEquipmentSlots, prevColor : ESkillColor)
	{
		var i : int;
		var newColor : ESkillColor;
		var tutState : W3TutorialManagerUIHandlerStateCharDevMutagens;
		
		i = GetMutagenSlotIndex(slot);
		if(i<0)
			return;
		
		mutagenSlots[i].item = item;
		
		//update link
		newColor = GetSkillGroupColor(mutagenSlots[i].skillGroupID);
		LinkUpdate(newColor, prevColor );
		
		//"synergy" skill bonus
		if(CanUseSkill(S_Alchemy_s19))
		{
			MutagenSynergyBonusEnable(item, true, GetSkillLevel(S_Alchemy_s19));
		}
		
		//tutorial
		if(ShouldProcessTutorial('TutorialCharDevMutagens'))
		{
			tutState = (W3TutorialManagerUIHandlerStateCharDevMutagens)theGame.GetTutorialSystem().uiHandler.GetCurrentState();
			if(tutState)
			{
				tutState.EquippedMutagen();
			}
		}
		
		theTelemetry.LogWithValueStr(TE_HERO_MUTAGEN_USED, owner.GetInventory().GetItemName( item ) );
		
		//trial of grasses achievement
		theGame.GetGamerProfile().CheckTrialOfGrasses();
	}
	
	public final function OnSkillMutagenUnequipped(item : SItemUniqueId, slot : EEquipmentSlots, prevColor : ESkillColor)
	{
		var i : int;
		var newColor : ESkillColor;
		
		i = GetMutagenSlotIndex(slot);
		if(i<0)
			return;
		
		//"synergy" skill bonus
		if(CanUseSkill(S_Alchemy_s19))
		{
			MutagenSynergyBonusEnable(item, false, GetSkillLevel(S_Alchemy_s19));
		}
		
		mutagenSlots[i].item = GetInvalidUniqueId();
		
		newColor = GetSkillGroupColor(mutagenSlots[i].skillGroupID);
		LinkUpdate(newColor, prevColor);
	}
	
	//called after mutagens were swapped (without equip/unequip handling)
	public final function OnSwappedMutagensPost(a : SItemUniqueId, b : SItemUniqueId)
	{
		var oldSlotIndexA, oldSlotIndexB : int;
		var oldColorA, oldColorB, newColorA, newColorB : ESkillColor;
	
		oldSlotIndexA = GetMutagenSlotIndexFromItemId(a);
		oldSlotIndexB = GetMutagenSlotIndexFromItemId(b);
		
		oldColorA = GetSkillGroupColor(mutagenSlots[oldSlotIndexA].skillGroupID);
		oldColorB = GetSkillGroupColor(mutagenSlots[oldSlotIndexB].skillGroupID);
		
		mutagenSlots[oldSlotIndexA].item = b;
		mutagenSlots[oldSlotIndexB].item = a;
		
		newColorA = GetSkillGroupColor(mutagenSlots[oldSlotIndexA].skillGroupID);
		newColorB = GetSkillGroupColor(mutagenSlots[oldSlotIndexB].skillGroupID);
		
		LinkUpdate(newColorA, oldColorA);
		LinkUpdate(newColorB, oldColorB);
	}
	
	//Called when "synergy" skill is equipped or unequipped. Goes through all mutagens and enables/disables the bonus
	private final function MutagensSyngergyBonusProcess(enable : bool, skillLevel : int)
	{
		var i : int;
		var inv : CInventoryComponent;
		
		inv = owner.GetInventory();
		for(i=0; i<mutagenSlots.Size(); i+=1)
		{
			//has mutagen in this slot
			if(inv.IsIdValid(mutagenSlots[i].item))
			{
				MutagenSynergyBonusEnable(mutagenSlots[i].item, enable, skillLevel);
			}
		}
	}
	
	//turns on/off "syngergy" skill bonus for given mutagen
	private final function MutagenSynergyBonusEnable(mutagenItemId : SItemUniqueId, enable : bool, bonusSkillLevel : int)
	{
		var i, count : int;
		var color : ESkillColor;
		
		count = 1;
		
		for (i=0; i < mutagenSlots.Size(); i+=1)
		{
			if (mutagenSlots[i].item == mutagenItemId)
			{
				//skillGroupID
				color = owner.GetInventory().GetSkillMutagenColor( mutagenItemId );
				count += GetGroupBonusCount(color, mutagenSlots[i].skillGroupID);
				break;
			}
		}
	
		if(enable)
		{
			owner.AddAbilityMultiple(GetMutagenBonusAbilityName(mutagenItemId), count * bonusSkillLevel);
		}
		else
		{
			owner.RemoveAbilityMultiple(GetMutagenBonusAbilityName(mutagenItemId), count * bonusSkillLevel);
		}
	}
	
	//returns name of ability holding "syngery" skill bonus for this mutagen
	public final function GetMutagenBonusAbilityName(mutagenItemId : SItemUniqueId) : name
	{
		var i : int;
		var abs : array<name>;
		owner.GetInventory().GetItemContainedAbilities(mutagenItemId, abs);
		
		for(i=0; i<abs.Size(); i+=1)
		{
			if(theGame.GetDefinitionsManager().AbilityHasTag(abs[i], 'alchemy_s19'))
				return abs[i];
		}
		return '';
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////    ---===  @LINKS BETWEEN SKILLSLOTS ===---    //////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/*
	private final function GetLinkColor(skillSlotIndex : int, dir : EDirectionZ) : ESkillColor
	{
		var ind : int;
		var color : ESkillColor;
	
		ind = GetSkillIndex(skillSlots[skillSlotIndex].socketedSkill);
		if(ind < 0)
			return SC_Undefined;
			
		if(dir == DZ_Left)
			color = skills[ind].linkLeft;
		else if(dir == DZ_Right)
			color = skills[ind].linkRight;
		else if(dir == DZ_Up || dir == DZ_Down)
			color = skills[ind].linkVertical;
			
		if(color == SC_Socketable && HasSkillMutagen(skills[ind].skillType))
			color = theGame.GetDefinitionsManager().GetMutagenIngredientColor(skills[ind].equippedMutagenName);
		
		return color;
	}
	
	//given skill slot index and direction returns color of the opposite slot's link
	private final function GetLinkOppositeColor(skillSlotIndex : int, dir : EDirectionZ) : ESkillColor
	{
		var neighbourSlotID, neighbourSkillIndex : int;
	
		switch(dir)
		{
			case DZ_Down : 
				neighbourSlotID = skillSlots[skillSlotIndex].neighbourDown;
				break;
			case DZ_Up : 
				neighbourSlotID = skillSlots[skillSlotIndex].neighbourUp;
				break;
			case DZ_Left : 
				neighbourSlotID = skillSlots[skillSlotIndex].neighbourLeft;
				break;
			case DZ_Right : 
				neighbourSlotID = skillSlots[skillSlotIndex].neighbourRight;
				break;
		}
		
		if(neighbourSlotID < 0)
			return SC_Undefined;
			
		neighbourSkillIndex = GetSkillIndexFromSlotID(neighbourSlotID);
		if(neighbourSkillIndex < 0)
			return SC_Undefined;
		
		switch(dir)
		{
			case DZ_Up :
			case DZ_Down : 		return skills[neighbourSkillIndex].linkVertical;
			case DZ_Left : 		return skills[neighbourSkillIndex].linkLeft;
			case DZ_Right :		return skills[neighbourSkillIndex].linkRight;
		}
	}*/
	
	public final function GetSkillGroupIdFromSkillSlotId(skillSlotId : int) : int
	{
		var i : int;
		
		for(i=0; i<skillSlots.Size(); i+=1)
		{
			if(skillSlots[i].id == skillSlotId)
			{
				return skillSlots[i].groupID;
			}
		}
		
		return -1;
	}
	
	public function GetMutagenSlotIDFromGroupID(groupID : int) : int
	{
		return GetMutagenSlotForGroupId(groupID);
	}
		
	public final function GetGroupBonus(groupID : int) : name
	{
		var groupColor : ESkillColor;
		var item : SItemUniqueId;
		
		groupColor = GetSkillGroupColor(groupID);
		
		/*if(groupColor != SC_None)
		{
			//if mutagen overrides color then there is no basic bonus
			if(GetWitcherPlayer().GetItemEquippedOnSlot(GetMutagenSlotForGroupId(groupID), item))
				return '';
		}*/
		
		switch (groupColor)
		{
			case SC_None: return '';
			case SC_Blue: return LINK_BONUS_BLUE;
			case SC_Green: return LINK_BONUS_GREEN;
			case SC_Red: return LINK_BONUS_RED;
		}
	}
	
	public final function GetGroupBonusCount(commonColor : ESkillColor, groupID : int) : int
	{
		var groupColorCount : int;
		var item : SItemUniqueId;
		
		groupColorCount = GetSkillGroupColorCount(commonColor, groupID);
		
		/*if(groupColor != SC_None)
		{
			//if mutagen overrides color then there is no basic bonus
			if(GetWitcherPlayer().GetItemEquippedOnSlot(GetMutagenSlotForGroupId(groupID), item))
				return '';
		}*/
			return groupColorCount;
	}	
	
	//returns color of the whole group
	public final function GetSkillGroupColor(groupID : int) : ESkillColor
	{
		var i : int;
		var commonColor : ESkillColor;
		var mutagenSlot : EEquipmentSlots;
		var skillColors : array<ESkillColor>;
		var item : SItemUniqueId;
		
		//get skills' colors
		for(i=0; i<skillSlots.Size(); i+=1)
		{
			if(skillSlots[i].unlocked && skillSlots[i].groupID == groupID)
			{
				skillColors.PushBack(GetSkillColor(skillSlots[i].socketedSkill));
			}
		}
		
		//check for common color
		commonColor = SC_None;
		for(i=0; i<skillColors.Size(); i+=1)
		{
			if(skillColors[i] != SC_None && skillColors[i] != SC_Yellow)	//color not set (bug?) or perk
			{
				if(commonColor == SC_None)
				{
					commonColor = skillColors[i];
				}
				else if(skillColors[i] != commonColor)
				{
					//bonus broken
					commonColor = SC_None;
					break;
				}
			}
		}
		
		//no bonus
		if(commonColor == SC_None)
			return SC_None;
			
		//if bonus, check for mutagen override
		mutagenSlot = GetMutagenSlotForGroupId(groupID);
		if(IsSkillMutagenSlotUnlocked(mutagenSlot))
		{
			if(GetWitcherPlayer().GetItemEquippedOnSlot(mutagenSlot, item))
				return owner.GetInventory().GetSkillMutagenColor( item );
		}
		
		return commonColor;
	}
	
	//returns color of the whole group - how many common color
	public final function GetSkillGroupColorCount(commonColor : ESkillColor, groupID : int) : ESkillColor
	{
		var count, i : int;
		var mutagenSlot : EEquipmentSlots;
		var skillColors : array<ESkillColor>;
		var item : SItemUniqueId;
		
		//get skills' colors
		for(i=0; i<skillSlots.Size(); i+=1)
		{
			if(skillSlots[i].unlocked && skillSlots[i].groupID == groupID && CanUseSkill(skillSlots[i].socketedSkill))
			{
				skillColors.PushBack(GetSkillColor(skillSlots[i].socketedSkill));
			}
		}
		
		//check for common color
		count = 0;
		for(i=0; i<skillColors.Size(); i+=1)
		{
			if(skillColors[i] == commonColor )	//color not set (bug?) or perk
			{
				count = count + 1;
			}
		}
		
		return count;
	}	
		
	//checks which bonus to update on given link and calls update
	private final function LinkUpdate(newColor : ESkillColor, prevColor : ESkillColor)
	{
		//no change
		if(newColor == prevColor)
			return;
		
		//remove previous link and add current
		UpdateLinkBonus(prevColor, false);
		UpdateLinkBonus(newColor, true);
	}
	
	//updates link bonus
	private final function UpdateLinkBonus(a : ESkillColor, added : bool)
	{	
		return;
		if(added)
		{
			if(a == SC_Blue)
				charStats.AddAbility(LINK_BONUS_BLUE, true);
			else if(a == SC_Green)
				charStats.AddAbility(LINK_BONUS_GREEN, true);
			else if(a == SC_Red)
				charStats.AddAbility(LINK_BONUS_RED, true);
		}
		else
		{
			if(a == SC_Blue)
				charStats.RemoveAbility(LINK_BONUS_BLUE);
			else if(a == SC_Green)
				charStats.RemoveAbility(LINK_BONUS_GREEN);
			else if(a == SC_Red)
				charStats.RemoveAbility(LINK_BONUS_RED);
		}
	}
	
	public final function GetSkillColor(skill : ESkill) : ESkillColor
	{
		switch(skills[skill].skillPath)
		{
			case ESP_Sword :		return SC_Red;
			case ESP_Signs :		return SC_Blue;
			case ESP_Alchemy : 		return SC_Green;
			case ESP_Perks :        return SC_Yellow;
			default :				return SC_None;
		}
	}
	
	/*
	public final function GetSkillLinkColorVertical(skill : ESkill, out color : ESkillColor, out isJoker : bool)
	{
		var ind : int;
		
		ind = GetSkillIndex(skill);
		if(ind < 0)
		{
			isJoker = false;
			color = SC_Undefined;
		}
		else
		{
			//TODO
			color = skills[ind].linkVertical;
			isJoker = false;
		}
	}
	
	public final function GetSkillLinkColorLeft(skill : ESkill, out color : ESkillColor, out isJoker : bool)
	{
		var ind : int;
		
		ind = GetSkillIndex(skill);
		if(ind < 0)
		{
			isJoker = false;
			color = SC_Undefined;
		}
		else
		{
			//TODO
			color = skills[ind].linkLeft;
			isJoker = false;
		}
	}
	
	public final function GetSkillLinkColorRight(skill : ESkill, out color : ESkillColor, out isJoker : bool)
	{
		var ind : int;
		
		ind = GetSkillIndex(skill);
		if(ind < 0)
		{
			isJoker = false;
			color = SC_Undefined;
		}
		else
		{
			//TODO
			color = skills[ind].linkRight;
			isJoker = false;
		}
	}*/
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////    ---===  @SKILLS  ===---    ///////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	public final function GetSkillLevel(skill : ESkill) : int
	{
		return skills[skill].level;
	}
	
	public final function GetBoughtSkillLevel(skill : ESkill) : int
	{
		return skills[skill].level;
	}
	
	public final function GetSkillMaxLevel(skill : ESkill) : int
	{
		return skills[skill].maxLevel;
	}
	
	public final function GetSkillStaminaUseCost(skill : ESkill, optional isPerSec : bool) : float
	{
		var reductionCounter : int;
		var ability, attributeName : name;
		var ret, costReduction : SAbilityAttributeValue;
	
		ability = '';
		
		//search skills
		if(CanUseSkill(skill))
			ability = GetSkillAbilityName(skill);
		
		if(isPerSec)
			attributeName = theGame.params.STAMINA_COST_PER_SEC_DEFAULT;
		else 
			attributeName = theGame.params.STAMINA_COST_DEFAULT;
		
		ret = GetSkillAttributeValue(ability, attributeName, true, true);
		
		//cost reduction
		reductionCounter = GetSkillLevel(skill) - 1;
		if(reductionCounter > 0)
		{
			costReduction = GetSkillAttributeValue(ability, 'stamina_cost_reduction_after_1', false, false) * reductionCounter;
			ret -= costReduction;
		}
		
		return CalculateAttributeValue(ret);
	}
	
	public final function GetSkillAttributeValue(abilityName: name, attributeName : name, addBaseCharAttribute : bool, addSkillModsAttribute : bool) : SAbilityAttributeValue
	{
		// OPTIMIZE
		var min, max, ret : SAbilityAttributeValue;
		var i, j : int;
		var dm : CDefinitionsManagerAccessor;
		var skill : SSkill;
		var skillEnum : ESkill;
		var skillLevel : int;
	
		//value from skill ability
		ret = super.GetSkillAttributeValue(abilityName, attributeName, addBaseCharAttribute, addSkillModsAttribute);
				
		//bonus from other skills that modify this value
		if(addSkillModsAttribute)
		{
			//find skill/perk/bookperk structure for given ability
			
			skillEnum = SkillNameToEnum( abilityName );
			if( skillEnum != S_SUndefined )
			{
				skill = skills[skillEnum];
			}
			else
			{
				LogAssert(false, "W3PlayerAbilityManager.GetSkillAttributeValue: cannot find skill for ability <<" + abilityName + ">>! Aborting");
				return min;
			}
			
			dm = theGame.GetDefinitionsManager();
			
			for( j = 0; j < skill.precachedModifierSkills.Size(); j += 1 )
			{
				i = skill.precachedModifierSkills[ j ];
			
				if( CanUseSkill( skills[i].skillType ) )
				{
					dm.GetAbilityAttributeValue(skills[i].abilityName, attributeName, min, max);

					skillLevel = GetSkillLevel(i);
					ret += GetAttributeRandomizedValue( min * skillLevel, max * skillLevel );
				}
			}
		}
		
		//value from character stats
		if(addBaseCharAttribute)
		{
			ret += GetAttributeValueInternal(attributeName);
		}
		
		return ret;
	}
	
	protected final function GetStaminaActionCostInternal(action : EStaminaActionType, isPerSec : bool, out cost : SAbilityAttributeValue, out delay : SAbilityAttributeValue, optional abilityName : name)
	{
		var attributeName : name;
		var skill : ESkill;
	
		super.GetStaminaActionCostInternal(action, isPerSec, cost, delay, abilityName);
		
		if(isPerSec)
		{
			attributeName = theGame.params.STAMINA_COST_PER_SEC_DEFAULT;
		}
		else
		{
			attributeName = theGame.params.STAMINA_COST_DEFAULT;
		}
		
		if(action == ESAT_LightAttack && CanUseSkill(S_Sword_1) )
			cost += GetSkillAttributeValue(SkillEnumToName(S_Sword_1), attributeName, false, true);
		else if(action == ESAT_HeavyAttack && CanUseSkill(S_Sword_2) )
			cost += GetSkillAttributeValue(SkillEnumToName(S_Sword_2), attributeName, false, true);
		else if ((action == ESAT_Sprint || action == ESAT_Jump) && thePlayer.HasBuff(EET_Mutagen24) && !thePlayer.IsInCombat())
		{
			cost.valueAdditive = 0;
			cost.valueBase = 0;
			cost.valueMultiplicative = 0;
		}
		
		//level 3 blizzard potion removes stamina cost if you also have battle trance and maxed focus
		if(thePlayer.HasBuff(EET_Blizzard) && owner == GetWitcherPlayer() && GetWitcherPlayer().GetPotionBuffLevel(EET_Blizzard) == 3 && thePlayer.HasBuff(EET_BattleTrance) && GetStatPercents(BCS_Focus) == 1)
		{
			cost.valueAdditive = 0;
			cost.valueBase = 0;
			cost.valueMultiplicative = 0;
		}
	}
		
	/*
		TK - apparently not wanted currently - commenting out entire final function	
		
	//returns action's stamina cost and delay
	public final function GetStaminaActionCost(action : EStaminaActionType, out cost : float, out delay : float, optional fixedCost : float, optional fixedDelay : float, optional abilityName : name, optional dt : float, optional costMult : float)
	{
		super.GetStaminaActionCost(action, cost, delay, fixedCost, fixedDelay, abilityName, dt, costMult);
		
		if(dt == 0)
		{
			//round up to full stamina segments if not a continuous mode
			//cost = CeilF(cost / theGame.params.STAMINA_SEGMENT_SIZE) * theGame.params.STAMINA_SEGMENT_SIZE;
			//i commented it because it was taking 10 stamina instead of 0.2.../ PF - which is as intended...
		}
	}
	*/
	
	/*
		Returns list of skill related abilities that the character has:
		- only known skills
		- only unblocked abilities
		- all abilities having one of the tags passed (can be empty)
	*/
	protected final function GetNonBlockedSkillAbilitiesList( optional tags : array<name> ) : array<name>
	{
		var i, j : int;
		var ret : array<name>;
		var dm : CDefinitionsManagerAccessor;
		var abilityName : name;
		
		if(tags.Size() == 0)
			return ret;
	
		dm = theGame.GetDefinitionsManager();
		for(i=0; i<skillAbilities.Size(); i+=1)		//skill abilities holds only abilities of equipped skills
		{
			abilityName = skillAbilities[i];
			
			for(j=0; j<tags.Size(); j+=1)
			{
				if(dm.AbilityHasTag(abilityName, tags[j]))
				{
					ret.PushBack(abilityName);
				}
			}
		}
		
		return ret;
	}
	
	public final function IsSkillBlocked(skill : ESkill) : bool
	{
		return skills[skill].remainingBlockedTime != 0;
	}
	
	//returns true if lock changed state
	public final function BlockSkill(skill : ESkill, block : bool, optional cooldown : float) : bool
	{
		var i : int;
		var min : float;
	
		if(block)
		{
			if(skills[skill].remainingBlockedTime == -1 || (cooldown > 0 && cooldown <= skills[skill].remainingBlockedTime) )
				return false;	//already locked for good or locked for longer
			
			//lock			
			if(cooldown > 0)
				skills[skill].remainingBlockedTime = cooldown;
			else
				skills[skill].remainingBlockedTime = -1;
				
			//find next timer call time
			min = 1000000;
			for(i=0; i<skills.Size(); i+=1)
			{
				if(skills[i].remainingBlockedTime > 0)
				{
					min = MinF(min, skills[i].remainingBlockedTime);
				}
			}
			
			//schedule next update
			if(min != 1000000)
				GetWitcherPlayer().AddTimer('CheckBlockedSkills', min, , , , true);
			
			//also block skill's ability
			if(theGame.GetDefinitionsManager().IsAbilityDefined(skills[skill].abilityName) && charStats.HasAbility(skills[skill].abilityName))
				BlockAbility(GetSkillAbilityName(skill), block, cooldown);
			
			if(IsSkillEquipped(skill))
				OnSkillUnequip(skill);
			
			return true;
		}
		else
		{
			if(skills[skill].remainingBlockedTime == 0)
				return false;		//already unlocked
		
			skills[skill].remainingBlockedTime = 0;
			
			if(theGame.GetDefinitionsManager().IsAbilityDefined(skills[skill].abilityName) && charStats.HasAbility(skills[skill].abilityName))
				BlockAbility(GetSkillAbilityName(skill), false);
			
			if(IsSkillEquipped(skill))
				OnSkillEquip(skill);
				
			return true;
		}
	}
	
	// Runs through all skills and checks their cooldowns. Unblocks those that have their cooldown finished.
	// Returns time till next call or -1 if no calls needed
	public final function CheckBlockedSkills(dt : float) : float
	{
		var i : int;
		var cooldown, min : float;
		
		min = 1000000;
		for(i=0; i<skills.Size(); i+=1)
		{
			if(skills[i].remainingBlockedTime > 0)
			{
				skills[i].remainingBlockedTime = MaxF(0, skills[i].remainingBlockedTime - dt);
				
				if(skills[i].remainingBlockedTime == 0)
				{
					BlockSkill(skills[i].skillType, false);
				}
				else
				{
					min = MinF(min, skills[i].remainingBlockedTime);
				}
			}
		}
		
		if(min == 1000000)
			min = -1;
			
		return min;
	}
	
	//@Override
	public final function BlockAbility(abilityName : name, block : bool, optional cooldown : float) : bool
	{
		var i : int;
	
		if( super.BlockAbility(abilityName, block, cooldown))
		{
			//if ability was blocked then remove it from cached arrays
			if(block)
			{
				skillAbilities.Remove(abilityName);
			}
			else
			{
				//if added then if it's a skill ability then put it to proper cached array
				for(i=0; i<skills.Size(); i+=1)
				{	
					if(skills[i].abilityName == abilityName)
					{
						if(!theGame.GetDefinitionsManager().AbilityHasTag(skills[i].abilityName, theGame.params.SKILL_GLOBAL_PASSIVE_TAG))
							skillAbilities.PushBack(abilityName);
							
						break;
					}
				}
			}
			
			return true;			
		}
		
		return false;
	}
		
	//adds all initial skills to the player
	protected final function InitSkills()
	{
		var atts : array<name>;
		var i, size : int;
		var skillEnum : ESkill;
		
		charStats.GetAllContainedAbilities(atts);
		size = atts.Size();
		for( i = 0; i < size; i += 1 )
		{
			skillEnum = SkillNameToEnum( atts[i] );
			if( skillEnum != S_SUndefined )
			{
				if( !IsAbilityBlocked( atts[i] ) )
				{
					AddSkillInternal( skillEnum, false, false, true );
				}
				continue;
			}
		}
	}
	
	protected final function IsCoreSkill(skill : ESkill) : bool
	{
		return skills[skill].isCoreSkill;
	}
	
	// Loads a single skill definition for this player from the XML and caches it (basically loads all skills data)
	protected final function CacheSkills(skillDefinitionName : name, out cache : array<SSkill>)
	{
		var dm : CDefinitionsManagerAccessor;
		var main, sks : SCustomNode;
		var i, size, size2, j : int;
		var skillType : ESkill;
		var bFound : bool;
		var tmpName : name;
		var skillDefs : array<name>;
		
		dm = theGame.GetDefinitionsManager();
		sks = dm.GetCustomDefinition('skills');
		
		//find definition
		bFound = false;
		size = sks.subNodes.Size();		
		cache.Clear();
		cache.Resize( S_Perk_MAX );
		for( i = 0; i < size; i += 1 )
		{
			if(dm.GetCustomNodeAttributeValueName(sks.subNodes[i], 'def_name', tmpName))
			{
				if(tmpName == skillDefinitionName)
				{
					bFound = true;
					main = sks.subNodes[i];
					
					//do the caching					
					size2 = main.subNodes.Size();
					for( j = 0; j < size2; j += 1 )
					{
						dm.GetCustomNodeAttributeValueName(main.subNodes[j], 'skill_name', tmpName);
						skillType = SkillNameToEnum(tmpName);
						
						if( skillType != S_SUndefined )
						{
							if( cache[skillType].skillType == skillType )
							{
								LogChannel('Skills', "W3AbilityManager.CacheSkills: actor's <<" + this + ">> skill <<" + skillType + ">> is already defined!!! Skipping!!!");
								continue;
							}
							
							CacheSkill( skillType, tmpName, main.subNodes[j], cache[skillType] );
						}
						else
						{
							LogAssert(false, "W3PlayerAbilityManager.CacheSkills: skill <<" + tmpName + ">> is not defined in PST enum, ignoring skill!");
						}
					}
				}
			}
		}
		
		if( !bFound )
		{
			LogAssert(false, "W3AbilityManager.CacheSkills: cannot find skill definition named <<" + skillDefinitionName + ">> aborting!");
		}
	}
	
	private final function CacheSkill( skillType : int, abilityName : name, definitionNode : SCustomNode, out skill : SSkill )
	{
		var dm : CDefinitionsManagerAccessor = theGame.GetDefinitionsManager();
		var modifiers, reqSkills : SCustomNode;
		var pathType : ESkillPath;
		var subpathType : ESkillSubPath;
		var tmpName : name;
		var tmpInt, k, size : int;
		var tmpString : string;
		var tmpBool : bool;
		
		skill.wasEquippedOnUIEnter = false;
		skill.level = 0;
		
		//skill type
		skill.skillType = skillType;
		skill.abilityName = abilityName;
		
		//path type
		if(dm.GetCustomNodeAttributeValueName(definitionNode, 'pathType_name', tmpName))
		{
			pathType = SkillPathNameToType(tmpName);
			if(pathType != ESP_NotSet)
				skill.skillPath = pathType;
			else if(skill.skillType != S_Perk_08)	//perk 08 is a hidden skill now
				LogAssert(false, "W3PlayerAbilityManager.CacheSkill: skill <<" + skill.skillType + ">> has wrong path type set <<" + tmpName + ">>");
		}
		
		//subpath type
		if(dm.GetCustomNodeAttributeValueName(definitionNode, 'subpathType_name', tmpName))
		{
			subpathType = SkillSubPathNameToType(tmpName);
			if(subpathType != ESSP_NotSet)
				skill.skillSubPath = subpathType;
			else if(skill.skillType != S_Perk_08)	//perk 08 is a hidden skill now
				LogAssert(false, "W3PlayerAbilityManager.CacheSkill: skill <<" + skill.skillType + ">> has wrong subpath type set <<" + tmpName + ">>");
		}
		
		//required skills list
		reqSkills = dm.GetCustomDefinitionSubNode(definitionNode,'required_skills');
		if(reqSkills.values.Size() > 0)
		{
			size = reqSkills.values.Size();
			for(k=0; k<size; k+=1)
			{
				if(IsNameValid(reqSkills.values[k]))
				{
					skill.requiredSkills.PushBack(SkillNameToEnum(reqSkills.values[k]));
				}
			}
		}
		
		//required skills 'mode'
		if(dm.GetCustomNodeAttributeValueBool(reqSkills, 'isAlternative', tmpBool))
			skill.requiredSkillsIsAlternative = tmpBool;
		
		//skill priority used for autoleveling
		if(dm.GetCustomNodeAttributeValueInt(definitionNode, 'priority', tmpInt))
			skill.priority = tmpInt;
		
		//required points spent in same path
		if(dm.GetCustomNodeAttributeValueInt(definitionNode, 'requiredPointsSpent', tmpInt))
			skill.requiredPointsSpent = tmpInt;
		
		//localisation
		if(dm.GetCustomNodeAttributeValueString(definitionNode, 'localisationName', tmpString))
			skill.localisationNameKey = tmpString;
		if(dm.GetCustomNodeAttributeValueString(definitionNode, 'localisationDescription', tmpString))
			skill.localisationDescriptionKey = tmpString;
		if(dm.GetCustomNodeAttributeValueString(definitionNode, 'localisationDescriptionLevel2', tmpString))
			skill.localisationDescriptionLevel2Key = tmpString;
		if(dm.GetCustomNodeAttributeValueString(definitionNode, 'localisationDescriptionLevel3', tmpString))
			skill.localisationDescriptionLevel3Key = tmpString;
			
		//cost
		if(dm.GetCustomNodeAttributeValueInt(definitionNode, 'cost', tmpInt))
			skill.cost = tmpInt;
			
		//maxLevel
		if(dm.GetCustomNodeAttributeValueInt(definitionNode, 'maxLevel', tmpInt))
			skill.maxLevel = tmpInt;
		else
			skill.maxLevel = 1;
			
		//is core skill
		if(dm.GetCustomNodeAttributeValueBool(definitionNode, 'isCoreSkill', tmpBool))
			skill.isCoreSkill = tmpBool;
			
		//GUI ID
		if(dm.GetCustomNodeAttributeValueInt(definitionNode, 'guiPositionID', tmpInt))
			skill.positionID = tmpInt;
	
		//modifier tags
		modifiers = dm.GetCustomDefinitionSubNode(definitionNode,'modifier_tags');
		if(modifiers.values.Size() > 0)
		{
			size = modifiers.values.Size();
			for(k=0; k<size; k+=1)
			{
				if(IsNameValid(modifiers.values[k]))
				{
					skill.modifierTags.PushBack(modifiers.values[k]);
				}
			}
		}
		
		//icon
		if(dm.GetCustomNodeAttributeValueString(definitionNode, 'iconPath', tmpString))
			skill.iconPath = tmpString;
			
		//link colors
		/*
		if(!skill.isCoreSkill)
		{
			if(dm.GetCustomNodeAttributeValueString(main.subNodes[i], 'linkVertical', tmpString))
				skill.linkVertical = LinkStringToType(tmpString);
			
			if(dm.GetCustomNodeAttributeValueString(main.subNodes[i], 'linkLeft', tmpString))
				skill.linkLeft = LinkStringToType(tmpString);
				
			if(dm.GetCustomNodeAttributeValueString(main.subNodes[i], 'linkRight', tmpString))
				skill.linkRight = LinkStringToType(tmpString);
		}*/
	}
	
	private final function LoadMutagenSlotsDataFromXML()
	{		
		var mut : SCustomNode;
		var i : int;
		var mutagen : SMutagenSlot;
		var dm : CDefinitionsManagerAccessor;
	
		//mutagen slots
		dm = theGame.GetDefinitionsManager();
		mut = dm.GetCustomDefinition('mutagen_slots');		
		
		for(i=0; i<mut.subNodes.Size(); i+=1)
		{
			dm.GetCustomNodeAttributeValueInt(mut.subNodes[i], 'skillGroup', mutagen.skillGroupID);
			dm.GetCustomNodeAttributeValueInt(mut.subNodes[i], 'unlockedAtLevel', mutagen.unlockedAtLevel);
			
			mutagen.item = GetInvalidUniqueId();
			mutagen.equipmentSlot = EES_SkillMutagen1 + i;
			
			if(mutagen.equipmentSlot > EES_SkillMutagen4)
			{
				LogAssert(false, "W3PlayerAbilityManager.LoadMutagenSlotsDataFromXML: too many slots defined in XML!!! Aborting");
				return;
			}
		
			mutagenSlots.PushBack(mutagen);
		}
	}
	
	//Acquires skill. 
	//The temporary flag informs that the skill was not developed through character development but as a temporary bonus and will be lost soon
	public final function AddSkill(skill : ESkill, isTemporary : bool)
	{
		var i : int;
		var learnedAll, ret : bool;
		var tree : ESkillPath;
		var uiStateCharDev : W3TutorialManagerUIHandlerStateCharacterDevelopment;
		var uiStateSpecialAttacks : W3TutorialManagerUIHandlerStateSpecialAttacks;
	
		ret = AddSkillInternal(skill, true, isTemporary);
		
		if(!ret)
			return;
			
		//dendrology achievement - fully develop one skill tree
		tree = GetSkillPathType(skill);
		
		learnedAll = true;
		for(i=0; i<skills.Size(); i+=1)
		{
			if(skills[i].skillPath == tree && skills[i].level == 0)
			{
				learnedAll = false;
				break;
			}
		}
		
		if(learnedAll)
			theGame.GetGamerProfile().AddAchievement(EA_Dendrology);
		
		//tutorial
		if(ShouldProcessTutorial('TutorialCharDevBuySkill'))
		{
			uiStateCharDev = (W3TutorialManagerUIHandlerStateCharacterDevelopment)theGame.GetTutorialSystem().uiHandler.GetCurrentState();
			if(uiStateCharDev)
			{
				uiStateCharDev.OnBoughtSkill(skill);
			}
		}
		if(ShouldProcessTutorial('TutorialSpecialAttacks') || ShouldProcessTutorial('TutorialAlternateSigns'))
		{
			uiStateSpecialAttacks = (W3TutorialManagerUIHandlerStateSpecialAttacks)theGame.GetTutorialSystem().uiHandler.GetCurrentState();
			if(uiStateSpecialAttacks)
				uiStateSpecialAttacks.OnBoughtSkill(skill);
		}
		// Elys start

		if( MustEquipSkill(skill) )
			ForceEquipSkill(skill);
		// Elys end
	}
	
	protected final function AddSkillInternal(skill : ESkill, spendPoints : bool, isTemporary : bool, optional skipTutorialMessages : bool) : bool
	{
		if(skill == S_SUndefined )
		{
			LogAssert(false,"W3AbilityManager.AddSkill: trying to add undefined skill, aborting!");
			return false;
		}	
		if(HasLearnedSkill(skill) && skills[skill].level >= skills[skill].maxLevel)
		{
			LogAssert(false,"W3AbilityManager.AddSkill: trying to add skill already known <<" + SkillEnumToName(skill) + ">>, aborting!");
			return false;
		}
		
		//add skill
		skills[skill].level += 1;
		
		//add path point spent if not core skill
		if(!skills[skill].isCoreSkill)
			pathPointsSpent[skills[skill].skillPath] = pathPointsSpent[skills[skill].skillPath] + 1;
		
		if(!isTemporary)
		{
			LogSkills("Skill <<" + skills[skill].abilityName + ">> learned");
			
			if(spendPoints)
				((W3PlayerWitcher)owner).levelManager.SpendPoints(ESkillPoint, skills[skill].cost);
			if ( this.IsSkillEquipped(skill) )
				OnSkillEquippedLevelChange(skill, GetSkillLevel(skill) - 1, GetSkillLevel(skill));
			theTelemetry.LogWithValueStr(TE_HERO_SKILL_UP, SkillEnumToName(skill));
		}
		
		return true;
	}	
		
	//removes temporary skill granted through another skill's bonus
	//FIXME - update for skill slots - used by non-tutorial testing fakes and skill_swors_s19
	public final function RemoveTemporarySkill(skill : SSimpleSkill) : bool
	{
		var ind : int;
		
		LogAssert( skill.skillType >= S_SUndefined, "W3AbilityManager.RemoveTemporarySkill: trying to remove undefined skill" );
		
		if(!skills[skill.skillType].isCoreSkill)
			pathPointsSpent[skills[skill.skillType].skillPath] = pathPointsSpent[skills[skill.skillType].skillPath] - (skills[skill.skillType].level - skill.level);
			
		skills[skill.skillType].level = skill.level;
		
		if(skills[skill.skillType].level < 1)
		{
			ind = GetSkillSlotID(skill.skillType);
			if(ind >= 0)
				UnequipSkill(ind);
		}
		
		tempSkills.Remove(skill.skillType);
		return true;
	}
		
	public final function HasLearnedSkill(skill : ESkill) : bool
	{
		return skills[skill].level > 0;
	}
	
	private final function GetSkillFromAbilityName(abilityName : name) : ESkill
	{
		var i : int;
		
		for(i=0; i<skills.Size(); i+=1)
			if(skills[i].abilityName == abilityName)
				return skills[i].skillType;
				
		return S_SUndefined;
	}
	
	public final function CanLearnSkill(skill : ESkill) : bool
	{
		var j : int;
		var hasSomeRequiredSkill : bool;
		
		//if skill type is valid at all
		if(skill == S_SUndefined)
			return false;
		
		//if skill is already known
		if(skills[skill].level >= skills[skill].maxLevel)
			return false;
			
		//if requirements are not met
		// #J removed this logic since it does not apply to current design
		/*if(skills[skill].requiredSkills.Size() > 0)
		{
			if(skills[skill].requiredSkillsIsAlternative)
				hasSomeRequiredSkill = false;
			else
				hasSomeRequiredSkill = true;
		
			for(j=0; j<skills[skill].requiredSkills.Size(); j+=1)
			{
				if(skills[skill].requiredSkillsIsAlternative)
				{
					if(HasLearnedSkill(skills[skill].requiredSkills[j]))
					{
						hasSomeRequiredSkill = true;
						break;
					}
				}
				else if(!HasLearnedSkill(skills[skill].requiredSkills[j]))
				{
					return false;	//conjunction check and some skill is missing
				}
			}
			
			if(!hasSomeRequiredSkill)
				return false;		//alternative check and no skill is known
		}*/
		
		//path spent points requirement
		if(skills[skill].requiredPointsSpent > 0 && pathPointsSpent[skills[skill].skillPath] < skills[skill].requiredPointsSpent)
			return false;
			
		//cost
		if(((W3PlayerWitcher)owner).levelManager.GetPointsFree(ESkillPoint) < skills[skill].cost)
			return false;
			
		//all conditions ok
		return true;
	}
	
	public final function HasSpentEnoughPoints(skill : ESkill) : bool // #J
	{
		if (skills[skill].requiredPointsSpent > 0 && pathPointsSpent[skills[skill].skillPath] < skills[skill].requiredPointsSpent)
		{
			return false;
		}
	
		return true;
	}
	
	public final function GetPathPointsSpent(skillPath : ESkillPath) : int
	{
		return pathPointsSpent[skillPath];
	}
	
	public final function PathPointsSpentInSkillPathOfSkill(skill : ESkill) : int // #J
	{
		return pathPointsSpent[skills[skill].skillPath];
	}
	
	// Returns ability name that this skill grants
	public final function GetSkillAbilityName(skill : ESkill) : name
	{
		return skills[skill].abilityName;
	}

	public final function GetSkillLocalisationKeyName(skill : ESkill) : string //#B
	{
		return skills[skill].localisationNameKey;
	}

	public final function GetSkillLocalisationKeyDescription(skill : ESkill, optional level : int) : string //#B
	{
		switch (level)
		{
			case 2:
				return skills[skill].localisationDescriptionLevel2Key;
			case 3: 
				return skills[skill].localisationDescriptionLevel3Key;
			case 4: 
				return skills[skill].localisationDescriptionLevel3Key;
			case 5: 
				return skills[skill].localisationDescriptionLevel3Key;
			default:
				return skills[skill].localisationDescriptionKey;
		}
	}

	public final function GetSkillIconPath(skill : ESkill) : string //#B
	{
		return skills[skill].iconPath;
	}
	
	public final function GetSkillSubPathType(skill : ESkill) : ESkillSubPath
	{
		return skills[skill].skillSubPath;
	}
	
	public final function GetSkillPathType(skill : ESkill) : ESkillPath
	{
		return skills[skill].skillPath;
	}
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////    ---===  @RESISTS  ===---    //////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
	
	protected function GetItemResistStatIndex( slot : EEquipmentSlots, stat : ECharacterDefenseStats ) : int
	{
		var i, size : int;
		size = resistStatsItems[slot].Size();
		for ( i = 0; i < size; i+=1 )
		{
			if ( resistStatsItems[slot][i].type == stat )
			{
				return i;
			}
		}				
		return -1;
	}
	
	//@Override
	//updates resist stat value - Overrides parent, we need to take armor durability into considreation
	protected final function RecalcResistStat(stat : ECharacterDefenseStats)
	{		
		var witcher : W3PlayerWitcher;
		var item : SItemUniqueId;
		var slot, idxItems : int;
		var itemResists : array<ECharacterDefenseStats>;
		var resistStat : SResistanceValue;

		//take all resists
		super.RecalcResistStat(stat);
		
		//check if character can have item slots => durability
		witcher = (W3PlayerWitcher)owner;
		if(!witcher)
			return;

		GetResistStat( stat, resistStat );
		
		for(slot=0; slot < resistStatsItems.Size(); slot+=1)
		{
			//get item if it has durability
			if( witcher.GetItemEquippedOnSlot(slot, item) && witcher.inv.HasItemDurability(item))
			{
				itemResists = witcher.inv.GetItemResistanceTypes(item);
				//check if item boosts resist stat
				if(itemResists.Contains(stat))
				{			
					//remove resists from items		
					resistStat.points.valueBase -= CalculateAttributeValue(witcher.inv.GetItemAttributeValue(item, ResistStatEnumToName(stat, true)));
					resistStat.percents.valueBase -= CalculateAttributeValue(witcher.inv.GetItemAttributeValue(item, ResistStatEnumToName(stat, false)));

					//calculate item durability modified resistances
					SetItemResistStat(slot, stat);

					//then add resists from items with durability modification
					idxItems = GetItemResistStatIndex( slot, stat );
					if(idxItems >= 0)
					{
						resistStat.percents.valueBase += CalculateAttributeValue(resistStatsItems[slot][idxItems].percents);
						resistStat.points.valueBase   += CalculateAttributeValue(resistStatsItems[slot][idxItems].points);
					}
				}
			}
		}
		
		SetResistStat( stat, resistStat );
	}
	
	// Updates cached durability-modified item resist
	private final function SetItemResistStat(slot : EEquipmentSlots, stat : ECharacterDefenseStats)
	{
		var item : SItemUniqueId;
		var tempResist : SResistanceValue;
		var witcher : W3PlayerWitcher;
		var i : int;
		
		witcher = (W3PlayerWitcher)owner;
		if(!witcher)
			return;
			
		//get cached stat index
		i = GetItemResistStatIndex( slot, stat );
		
		//get equipped item
		if( witcher.GetItemEquippedOnSlot(slot, item) && witcher.inv.HasItemDurability(item) )
		{
			//set item resist with durability
			if(i >= 0)
			{
				//if this resist is already cached then update the value
				witcher.inv.GetItemResistStatWithDurabilityModifiers(item, stat, resistStatsItems[slot][i].points, resistStatsItems[slot][i].percents);
			}
			else
			{
				//if this resist is not cached then add it to cached array
				witcher.inv.GetItemResistStatWithDurabilityModifiers(item, stat, tempResist.points, tempResist.percents);
				tempResist.type = stat;
				resistStatsItems[slot].PushBack(tempResist);
			}			
		}
		else if(i >= 0)
		{
			//no item in that slot but something cached - delete the cached item resist
			resistStatsItems[slot].Erase(i);
		}
	}
		
	// called when item durability has changed to update the cached durability-modified resists from that item
	public final function RecalcItemResistDurability(slot : EEquipmentSlots, itemId : SItemUniqueId)
	{
		var i : int;
		var witcher : W3PlayerWitcher;
		var itemResists : array<ECharacterDefenseStats>;
	
		witcher = (W3PlayerWitcher)owner;
		if(!witcher)
			return;
			
		itemResists = witcher.inv.GetItemResistanceTypes(itemId);
		for(i=0; i<itemResists.Size(); i+=1)
		{
			if(itemResists[i] != CDS_None)
			{
				RecalcResistStatFromItem(itemResists[i], slot);
			}
		}
	}
	
	// updates resistances of given type from given item. When we call this we know that the item HAS NOT CHANGED
	private final function RecalcResistStatFromItem(stat : ECharacterDefenseStats, slot : EEquipmentSlots)
	{
		var deltaResist, prevCachedResist : SResistanceValue;
		var idx : int;
		var resistStat : SResistanceValue;
		
		idx = GetItemResistStatIndex( slot, stat );
		prevCachedResist = resistStatsItems[slot][idx];
						
		//calculate new item durability modified resistances
		SetItemResistStat(slot, stat);
		
		//get diff
		deltaResist.points = resistStatsItems[slot][idx].points - prevCachedResist.points;
		deltaResist.percents = resistStatsItems[slot][idx].percents - prevCachedResist.percents;
		
		//update global resist
		if ( GetResistStat( stat, resistStat ) )
		{
			resistStat.percents += deltaResist.percents;
			resistStat.points += deltaResist.points;
			SetResistStat( stat, resistStat );
		}
	}
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////    ---===  @STATS  ===---    ////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	public final function DrainStamina(action : EStaminaActionType, optional fixedCost : float, optional fixedDelay : float, optional abilityName : name, optional dt : float, optional costMult : float) : float
	{	
		var cost : float;
		var mutagen : W3Mutagen21_Effect;
		var min, max : SAbilityAttributeValue;
		
		if(FactsDoesExist("debug_fact_stamina_boy"))
			return 0;
			
		cost = super.DrainStamina(action, fixedCost, fixedDelay, abilityName, dt, costMult);
		
		if(cost > 0 && dt > 0)
		{
			//if it's continuous cost then set up a timer that will do the flooring once the continuous cost stops
			owner.AddTimer('AbilityManager_FloorStaminaSegment', 0.1, , , , true);
		}
		
		// Mutagen 21 - action costing stamina heal geralt, Whirl and Rend handled separately due to their hacks
		if (cost > 0 && dt <= 0 && owner == thePlayer && thePlayer.HasBuff(EET_Mutagen21) && abilityName != 'sword_s1' && abilityName != 'sword_s2')
		{	
			mutagen = (W3Mutagen21_Effect)thePlayer.GetBuff(EET_Mutagen21);
			mutagen.Heal();
		}
		
		//Force abort sign cast if stamina reached 0. Otherwise if we have regen, stamina might regenerate before it is checked in 
		//next tick and as a result making even per tick test will always see your stamina >0
		if(owner == GetWitcherPlayer() && GetStat(BCS_Stamina, true) <= 0.f)
		{
			GetWitcherPlayer().GetSignEntity(GetWitcherPlayer().GetCurrentlyCastSign()).OnSignAborted(true);
		}
		
		return cost;
	}
	
	public function GainStat( stat : EBaseCharacterStats, amount : float )
	{
		//while under runeword 8 effect, don't add focus
		if(stat == BCS_Focus && owner.HasBuff(EET_Runeword8))
			return;
			
		super.GainStat(stat, amount);
	}
	
	//floors current stamina to full segment
	public final function FloorStaminaSegment()
	{
		//someone forgot to disable stamina segments when they disabled stamina segments... I want to strangle them...
		/*
		var wastedStamina : float;
	
		wastedStamina = ModF(GetStat(BCS_Stamina, true), theGame.params.STAMINA_SEGMENT_SIZE);
		InternalReduceStat(BCS_Stamina,	wastedStamina);
		*/
	}
	
	//needs to make a locked stamina check
	public final function GetStat(stat : EBaseCharacterStats, optional skipLock : bool) : float	
	{
		var value, lock : float;
		var i : int;
	
		value = super.GetStat(stat, skipLock);
		
		if(stat == BCS_Toxicity && !skipLock && toxicityOffset > 0)
		{
			value += toxicityOffset;
		}
		
		return value;
	}
	
	public final function AddToxicityOffset(val : float)
	{
		if(val > 0)
			toxicityOffset += val;
	}
	
	public final function SetToxicityOffset( val : float)
	{
		if(val >= 0)
			toxicityOffset = val;
	}
		
	public final function RemoveToxicityOffset(val : float)
	{
		if(val > 0)
			toxicityOffset -= val;
		
		if (toxicityOffset < 0)
			toxicityOffset = 0;
	}
	
	// #Y TODO: Implement calculation
	public final function GetOffenseStat():int
	{
		var steelDmg, silverDmg : float;
		var steelCritChance, steelCritDmg : float;
		var silverCritChance, silverCritDmg : float;
		var attackPower	: SAbilityAttributeValue;
		var item : SItemUniqueId;
		var value : SAbilityAttributeValue;
		
		// steel and silve ap bonus
		if (CanUseSkill(S_Sword_s04))
			attackPower += GetSkillAttributeValue(SkillEnumToName(S_Sword_s04), PowerStatEnumToName(CPS_AttackPower), false, true) * GetSkillLevel(S_Sword_s04);
		if (CanUseSkill(S_Sword_s21))
			attackPower += GetSkillAttributeValue(SkillEnumToName(S_Sword_s21), PowerStatEnumToName(CPS_AttackPower), false, true) * GetSkillLevel(S_Sword_s21); 
		attackPower = attackPower * 0.5;
		
		// steel and silve crit and crit dmg bonus
		if (CanUseSkill(S_Sword_s08)) 
		{
			steelCritChance += CalculateAttributeValue(GetSkillAttributeValue(SkillEnumToName(S_Sword_s08), theGame.params.CRITICAL_HIT_CHANCE, false, true)) * GetSkillLevel(S_Sword_s08);
			steelCritDmg += CalculateAttributeValue(GetSkillAttributeValue(SkillEnumToName(S_Sword_s08), theGame.params.CRITICAL_HIT_DAMAGE_BONUS, false, true)) * GetSkillLevel(S_Sword_s08);
		}
		if (CanUseSkill(S_Sword_s17)) 
		{
			steelCritChance += CalculateAttributeValue(GetSkillAttributeValue(SkillEnumToName(S_Sword_s17), theGame.params.CRITICAL_HIT_CHANCE, false, true)) * GetSkillLevel(S_Sword_s17);
			steelCritDmg += CalculateAttributeValue(GetSkillAttributeValue(SkillEnumToName(S_Sword_s17), theGame.params.CRITICAL_HIT_DAMAGE_BONUS, false, true)) * GetSkillLevel(S_Sword_s17);
		}
		steelCritChance /= 2;
		steelCritDmg /= 2;
		silverCritChance = steelCritChance;
		silverCritDmg = steelCritDmg;
		
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SteelSword, item))
		{
			value = thePlayer.GetInventory().GetItemAttributeValue(item, theGame.params.DAMAGE_NAME_SLASHING);
			steelDmg += value.valueBase;
			steelCritChance += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_CHANCE));
			steelCritDmg += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
		}
		else
		{
			steelDmg += 0;
			steelCritChance += 0;
			steelCritDmg +=0;
		}
		
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SilverSword, item))
		{
			value = thePlayer.GetInventory().GetItemAttributeValue(item, theGame.params.DAMAGE_NAME_SILVER);
			silverDmg += value.valueBase;
			silverCritChance += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_CHANCE));
			silverCritDmg += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
		}
		else
		{
			silverDmg += 0;
			silverCritChance += 0;
			silverCritDmg +=0;
		}
		
		steelCritChance += CalculateAttributeValue(GetWitcherPlayer().GetAttributeValue(theGame.params.CRITICAL_HIT_CHANCE));
		silverCritChance += CalculateAttributeValue(GetWitcherPlayer().GetAttributeValue(theGame.params.CRITICAL_HIT_CHANCE));
		steelCritDmg += CalculateAttributeValue(GetWitcherPlayer().GetAttributeValue(theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
		silverCritDmg += CalculateAttributeValue(GetWitcherPlayer().GetAttributeValue(theGame.params.CRITICAL_HIT_DAMAGE_BONUS));
		attackPower += GetWitcherPlayer().GetPowerStatValue(CPS_AttackPower);
		
		steelCritChance *= 100;
		silverCritChance *= 100;
		steelDmg = steelDmg * (100 - steelCritChance) + steelDmg * (1 + steelCritDmg) * steelCritChance;
		steelDmg *= attackPower.valueMultiplicative;
		steelDmg /= 100;
		silverDmg = silverDmg * (100 - silverCritChance) + silverDmg * (1 + silverCritDmg) * silverCritChance;
		silverDmg *= attackPower.valueMultiplicative;
		silverDmg /= 100;
		return RoundMath((steelDmg + silverDmg)/2);
	}
	
	// #Y TODO: Implement calculation
	public final function GetDefenseStat():int
	{
		var valArmor : SAbilityAttributeValue;
		var valResists : float;
		var fVal1, fVal2 : float;
		
		valArmor = thePlayer.GetTotalArmor();
		thePlayer.GetResistValue(CDS_SlashingRes, fVal1, fVal2);
		valResists += fVal2;
		thePlayer.GetResistValue(CDS_PiercingRes, fVal1, fVal2);
		valResists += fVal2;
		thePlayer.GetResistValue(CDS_BludgeoningRes, fVal1, fVal2);
		valResists += fVal2;
		thePlayer.GetResistValue(CDS_RendingRes, fVal1, fVal2);
		valResists += fVal2;
		thePlayer.GetResistValue(CDS_ElementalRes, fVal1, fVal2);
		valResists += fVal2;
		
		valResists = valResists / 5;
		
		fVal1 = 100 - valArmor.valueBase;
		fVal1 *= valResists;
		fVal1 += valArmor.valueBase;
		
		return RoundMath(fVal1);
	}
	
	// #Y TODO: Implement calculation
	public final function GetSignsStat():float
	{
		var sp : SAbilityAttributeValue;
		
		sp += thePlayer.GetSkillAttributeValue(S_Magic_1, PowerStatEnumToName(CPS_SpellPower), true, true);
		sp += thePlayer.GetSkillAttributeValue(S_Magic_2, PowerStatEnumToName(CPS_SpellPower), true, true);
		sp += thePlayer.GetSkillAttributeValue(S_Magic_3, PowerStatEnumToName(CPS_SpellPower), true, true);
		sp += thePlayer.GetSkillAttributeValue(S_Magic_4, PowerStatEnumToName(CPS_SpellPower), true, true);
		sp += thePlayer.GetSkillAttributeValue(S_Magic_5, PowerStatEnumToName(CPS_SpellPower), true, true);
		sp.valueMultiplicative /= 5;
		
		return sp.valueMultiplicative;
	}
		
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////////////////  @SLOTS  //////////////////////////////////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	event OnLevelGained(currentLevel : int)
	{
		var i : int;
	
		for(i=0; i<skillSlots.Size(); i+=1)
		{
			if(currentLevel >= skillSlots[i].unlockedOnLevel)
				skillSlots[i].unlocked = true;
		}
	}
	
	//loads skill slots data from XML
	private final function InitSkillSlots()
	{
		var slot : SSkillSlot;
		var dm : CDefinitionsManagerAccessor;
		var main : SCustomNode;
		var i, tmpInt : int;
	
		dm = theGame.GetDefinitionsManager();
		main = dm.GetCustomDefinition('skill_slots');
		
		for(i=0; i<main.subNodes.Size(); i+=1)
		{
			if(!dm.GetCustomNodeAttributeValueInt(main.subNodes[i], 'id', slot.id))			
			{
				LogAssert(false, "W3PlayerAbilityManager.InitSkillSlots: slot definition is not valid!");
				continue;
			}
						
			if(!dm.GetCustomNodeAttributeValueInt(main.subNodes[i], 'unlockedOnLevel', slot.unlockedOnLevel))
				slot.unlockedOnLevel = 0;
			
			if(!dm.GetCustomNodeAttributeValueInt(main.subNodes[i], 'group', slot.groupID))
				slot.groupID = -1;
			
			if(dm.GetCustomNodeAttributeValueInt(main.subNodes[i], 'neighbourUp', tmpInt))
				slot.neighbourUp = tmpInt;
			else
				slot.neighbourUp = -1;
				
			if(dm.GetCustomNodeAttributeValueInt(main.subNodes[i], 'neighbourDown', tmpInt))
				slot.neighbourDown = tmpInt;
			else
				slot.neighbourDown = -1;
				
			if(dm.GetCustomNodeAttributeValueInt(main.subNodes[i], 'neighbourLeft', tmpInt))
				slot.neighbourLeft = tmpInt;
			else
				slot.neighbourLeft = -1;
				
			if(dm.GetCustomNodeAttributeValueInt(main.subNodes[i], 'neighbourRight', tmpInt))
				slot.neighbourRight = tmpInt;
			else
				slot.neighbourRight = -1;
				
			//slot.unlocked =  cannot set it now since LevelManager does not exist yet. Instead it's set in PostLoad			
			totalSkillSlotsCount = Max(totalSkillSlotsCount, slot.id);
			LogChannel('CHR', "Init W3PlayerAbilityManager, totalSkillSlotsCount "+totalSkillSlotsCount);
			skillSlots.PushBack(slot);
			
			slot.id = -1;
			slot.unlockedOnLevel = 0;
			slot.neighbourUp = -1;
			slot.neighbourDown = -1;
			slot.neighbourLeft = -1;
			slot.neighbourRight = -1;
			slot.groupID = -1;
		}
	}
	
	//returns skill slot ID for given equipped skill
	public final function GetSkillSlotID(skill : ESkill) : int
	{
		var i : int;
		
		if(skill == S_SUndefined)
			return -1;
		
		for(i=0; i<skillSlots.Size(); i+=1)
		{
			if(skillSlots[i].socketedSkill == skill)
			{
				if(skillSlots[i].unlocked)
					return skillSlots[i].id;
				else
					return -1;
			}
		}
		
		return -1;
	}
	
	public final function GetSkillSlotIDFromIndex(skillSlotIndex : int) : int
	{
		if(skillSlotIndex >= 0 && skillSlotIndex < skillSlots.Size())
			return skillSlots[skillSlotIndex].id;
			
		return -1;
	}
	
	/*
		Returns index of skillSlot for given slot ID.
		Returns -1 if not found.
		If checkIfUnlocked flag is set will return -1 if given slot in locked.
	*/
	public final function GetSkillSlotIndex(slotID : int, checkIfUnlocked : bool) : int
	{
		var i : int;
		
		for(i=0; i<skillSlots.Size(); i+=1)
		{
			if(skillSlots[i].id == slotID)
			{
				if(!checkIfUnlocked)
					return i;
				
				if(skillSlots[i].unlocked)
					return i;
				else
					return -1;
			}
		}
		
		return -1;
	}
		
	public final function GetSkillSlotIndexFromSkill(skill : ESkill) : int
	{
		var i : int;
	
		for(i=0; i<skillSlots.Size(); i+=1)
			if(skillSlots[i].socketedSkill == skill)
				return i;
				
		return -1;
	}
	
	//returns true if succeeded
	public final function EquipSkill(skill : ESkill, slotID : int) : bool
	{

		var idx, i : int; // Elys
		var prevColor : ESkillColor;
		
		if(!HasLearnedSkill(skill) || IsCoreSkill(skill))
			return false;
			
		idx = GetSkillSlotIndex(slotID, true);		
		
		if(idx < 0)
			return false;
		// Elys start

		if(IsSkillEquipped(skill))
		{
			i = GetSkillSlotID(skill);
			if (i > orgTotalSkillSlotsCount)
				UnequipSkill(i);
		}
		// Elys end
		
		prevColor = GetSkillGroupColor(skillSlots[idx].groupID);
		
		UnequipSkill(slotID);
	
		skillSlots[idx].socketedSkill = skill;
		
		LinkUpdate(GetSkillGroupColor(skillSlots[idx].groupID), prevColor);
		OnSkillEquip(skill);
		
		return true;
	}
	
	//returns true if succeeded
	public final function UnequipSkill(slotID : int) : bool
	{
		var idx : int;
		var prevColor : ESkillColor;
		var skill : ESkill;
	
		idx = GetSkillSlotIndex(slotID, true);
		if(idx < 0)
			return false;
		
		// Update synegry bonus
		if ( CanUseSkill(S_Alchemy_s19) )
			MutagensSyngergyBonusProcess(false, GetSkillLevel(S_Alchemy_s19));
			
		//update links
		prevColor = GetSkillGroupColor(skillSlots[idx].groupID);
		skill = skillSlots[idx].socketedSkill;
		skillSlots[idx].socketedSkill = S_SUndefined;
		LinkUpdate(GetSkillGroupColor(skillSlots[idx].groupID), prevColor);
		OnSkillUnequip(skill);

		// Elys start
		if ( idx <= orgTotalSkillSlotsCount )
		{
			if( MustEquipSkill(skill) )
				ForceEquipSkill(skill);
		}	
		// Elys end

		return true;
	}
	
	//called when char panel closes and a skill equip was done
	private final function OnSkillEquip(skill : ESkill)
	{
		var skillName : name;
		var names, abs : array<name>;
		var buff : W3Effect_Toxicity;
		var witcher : W3PlayerWitcher;
		var i, skillLevel : int;
		var isPassive, isNight : bool;
		var m_alchemyManager : W3AlchemyManager;
		var recipe : SAlchemyRecipe;
		var uiState : W3TutorialManagerUIHandlerStateCharacterDevelopment;
		var battleTrance : W3Effect_BattleTrance;
		var mutagens : array<CBaseGameplayEffect>;
		var trophy : SItemUniqueId;
		var horseManager : W3HorseManager;
		var weapon, armor : W3RepairObjectEnhancement;
		var foodBuff : W3Effect_WellFed;
		var commonMenu : CR4CommonMenu;
		var guiMan : CR4GuiManager;
		
		//always active
		if(IsCoreSkill(skill))
			return;
		
		witcher = GetWitcherPlayer();
	
		//add passive Buff that this skill grants
		AddPassiveSkillBuff(skill);
		
		//cache skill ability
		isPassive = theGame.GetDefinitionsManager().AbilityHasTag(skills[skill].abilityName, theGame.params.SKILL_GLOBAL_PASSIVE_TAG);
		
		for( i = 0; i < GetSkillLevel(skill); i += 1 )
		{
			if(isPassive)
				owner.AddAbility(skills[skill].abilityName, true);
			else
				skillAbilities.PushBack(skills[skill].abilityName);
		}
		
		//M.J. - adrenaline hack for sword skills
		if(GetSkillPathType(skill) == ESP_Sword)
		{
			owner.AddAbilityMultiple('sword_adrenalinegain', GetSkillLevel(skill) );
		}
		
		//some stamina hack for magic skills
		if(GetSkillPathType(skill) == ESP_Signs)
		{
			owner.AddAbilityMultiple('magic_staminaregen', GetSkillLevel(skill) );
		}
		
		//M.J. - potion duration hack for alchemy skills
		if(GetSkillPathType(skill) == ESP_Alchemy)
		{
			owner.AddAbilityMultiple('alchemy_potionduration', GetSkillLevel(skill) );
		}
		
		// Update Synergy bonus
		if ( CanUseSkill(S_Alchemy_s19) )
		{
			MutagensSyngergyBonusProcess(false, GetSkillLevel(S_Alchemy_s19));
			MutagensSyngergyBonusProcess(true, GetSkillLevel(S_Alchemy_s19));
		}
		else if(skill == S_Alchemy_s20)
		{
			if ( GetWitcherPlayer().GetStatPercents(BCS_Toxicity) >= GetWitcherPlayer().GetToxicityDamageThreshold() )
				owner.AddEffectDefault(EET_IgnorePain, owner, 'IgnorePain');
		}
		//custom instant skill checks
		if(skill == S_Alchemy_s18)
		{
			m_alchemyManager = new W3AlchemyManager in this;
			m_alchemyManager.Init();
			names = witcher.GetAlchemyRecipes();
			skillName = SkillEnumToName(S_Alchemy_s18);
			for(i=0; i<names.Size(); i+=1)
			{
				m_alchemyManager.GetRecipe(names[i], recipe);
				if ((recipe.cookedItemType != EACIT_Bolt) && (recipe.cookedItemType != EACIT_Undefined) && (recipe.level <= GetSkillLevel(S_Alchemy_s18)))
					charStats.AddAbility(skillName, true);
			}
		}
		else if(skill == S_Alchemy_s15 && owner.HasBuff(EET_Toxicity))
		{
			buff = (W3Effect_Toxicity)owner.GetBuff(EET_Toxicity);
			buff.RecalcEffectValue();
		}
		else if(skill == S_Alchemy_s13)
		{
			mutagens = GetWitcherPlayer().GetDrunkMutagens();
			if(mutagens.Size() > 0)
				charStats.AddAbilityMultiple(GetSkillAbilityName(skill), GetSkillLevel(skill));
		}		
		else if(skill == S_Magic_s11)		//yrden damaging
		{
			((W3YrdenEntity) (witcher.GetSignEntity(ST_Yrden))).SkillEquipped(skill);
		}
		else if(skill == S_Magic_s07)		//battle trance spell power bonus
		{
			if(owner.HasBuff(EET_BattleTrance))
				owner.AddAbility( GetSkillAbilityName(S_Magic_s07) );
		}
		else if(skill == S_Perk_08)
		{
			//change level 3 items abilities from 2 to 3
			thePlayer.ChangeAlchemyItemsAbilities(true);
		}
		else if(skill == S_Alchemy_s19)
		{
		//	MutagensSyngergyBonusProcess(true, GetSkillLevel(skill));
		}
		else if(skill == S_Perk_01)
		{
			isNight = theGame.envMgr.IsNight();
			SetPerk01Abilities(!isNight, isNight);
		}
		else if(skill == S_Perk_05)
		{
			SetPerkArmorBonus(S_Perk_05, true);
		}
		else if(skill == S_Perk_06)
		{
			SetPerkArmorBonus(S_Perk_06, true);
		}
		else if(skill == S_Perk_07)
		{
			SetPerkArmorBonus(S_Perk_07, true);
		}
		else if(skill == S_Perk_11)
		{
			battleTrance = (W3Effect_BattleTrance)owner.GetBuff(EET_BattleTrance);
			if(battleTrance)
				battleTrance.OnPerk11Equipped();
		}
		else if(skill == S_Perk_19 && witcher.HasBuff(EET_BattleTrance))
		{
			skillLevel = FloorF(witcher.GetStat(BCS_Focus));
			witcher.RemoveAbilityMultiple(thePlayer.GetSkillAbilityName(S_Sword_5), skillLevel);
			witcher.AddAbilityMultiple(thePlayer.GetSkillAbilityName(S_Perk_19), skillLevel);
		}		
		else if(skill == S_Perk_22)
		{
			GetWitcherPlayer().UpdateEncumbrance();
			guiMan = theGame.GetGuiManager();
			if(guiMan)
			{
				commonMenu = theGame.GetGuiManager().GetCommonMenu();
				if(commonMenu)
				{
					commonMenu.UpdateItemsCounter();
				}
			}
		}
		
		if(GetSkillPathType(skill) == ESP_Alchemy)
			witcher.RecalcPotionsDurations();
		
		//tutorial
		if(ShouldProcessTutorial('TutorialCharDevEquipSkill'))
		{
			uiState = (W3TutorialManagerUIHandlerStateCharacterDevelopment)theGame.GetTutorialSystem().uiHandler.GetCurrentState();
			if(uiState)
				uiState.EquippedSkill();
		}
		
		//trial of grasses achievement
		theGame.GetGamerProfile().CheckTrialOfGrasses();
	}
	
	private final function OnSkillUnequip(skill : ESkill)
	{
		var i, skillLevel : int;
		var isPassive : bool;
		var petard : W3Petard;
		var ents : array<CGameplayEntity>;
		var mutagens : array<CBaseGameplayEffect>;
		var tox : W3Effect_Toxicity;
		var names, abs : array<name>;
		var skillName : name;
		var battleTrance : W3Effect_BattleTrance;
		var trophy : SItemUniqueId;
		var horseManager : W3HorseManager;
		var witcher : W3PlayerWitcher;
		var weapon, armor : W3RepairObjectEnhancement;
		var foodBuff : W3Effect_WellFed;
		var commonMenu : CR4CommonMenu;
		var guiMan : CR4GuiManager;
		
		//always active
		if(IsCoreSkill(skill))
			return;
			
		//cache skill ability
		isPassive = theGame.GetDefinitionsManager().AbilityHasTag(skills[skill].abilityName, theGame.params.SKILL_GLOBAL_PASSIVE_TAG);
		
		skillLevel = skills[skill].level;
			
		for( i = 0; i < skillLevel; i += 1 )
		{
			if(isPassive)
				owner.RemoveAbility(skills[skill].abilityName);
			else
				skillAbilities.Remove(skills[skill].abilityName);
		}
		
		//M.J. - adrenaline hack for sword skills
		if(GetSkillPathType(skill) == ESP_Sword)
		{
			owner.RemoveAbilityMultiple('sword_adrenalinegain', skillLevel );
		}
		
		//some hack for magic skills
		if(GetSkillPathType(skill) == ESP_Signs)
		{
			owner.RemoveAbilityMultiple('magic_staminaregen', GetSkillLevel(skill) );
		}
		
		//M.J. - potion duration hack for alchemy skills
		if(GetSkillPathType(skill) == ESP_Alchemy)
		{
			owner.RemoveAbilityMultiple('alchemy_potionduration', GetSkillLevel(skill) );
		}
		
		//custom skill stuff		
		if(skill == S_Magic_s11)		//yrden damaging
		{
			((W3YrdenEntity) (GetWitcherPlayer().GetSignEntity(ST_Yrden))).SkillUnequipped(skill);
		}
		else if(skill == S_Magic_s07)	//battle trance spell power bonus
		{
			owner.RemoveAbility( GetSkillAbilityName(S_Magic_s07) );
		}
		else if(skill == S_Alchemy_s04)	//bonus random potion effect when drinking potion
		{
			owner.RemoveEffect(GetWitcherPlayer().GetSkillBonusPotionEffect());
		}
		/*
		else if(skill == PROXIMITY_BOMBS)	//proximity -> explode existing proximities, disable proxy on flying ones
		{
			FindGameplayEntitiesInSphere(ents, owner.GetWorldPosition(), theGame.params.MAX_THROW_RANGE + 0.5, 1000);
			for(i=ents.Size()-1; i>=0; i-=1)
			{
				petard = (W3Petard)ents[i];
				if(petard)
				{
					if(petard.IsStuck())
						petard.ProcessEffect();
					else if(petard.IsProximity())
						petard.DisableProximity();
				}
			}
		}*/
		else if(skill == S_Alchemy_s13)
		{
			mutagens = GetWitcherPlayer().GetDrunkMutagens();
			
			if(mutagens.Size() > 0)
				charStats.RemoveAbilityMultiple(GetSkillAbilityName(S_Alchemy_s13), GetSkillLevel(skill));
		}
		else if(skill == S_Alchemy_s20)
		{
			owner.RemoveBuff(EET_IgnorePain);
		}
		else if(skill == S_Alchemy_s15 && owner.HasBuff(EET_Toxicity))
		{
			tox = (W3Effect_Toxicity)owner.GetBuff(EET_Toxicity);
			tox.RecalcEffectValue();
		}
		else if(skill == S_Alchemy_s18)			//toxicity pool upgrade per known recipe
		{
			names = GetWitcherPlayer().GetAlchemyRecipes();
			skillName = SkillEnumToName(S_Alchemy_s18);
			for(i=0; i<names.Size(); i+=1)
				charStats.RemoveAbility(skillName);
		}
		else if(skill == S_Sword_s13)			//slowmo for aiming
		{
			theGame.RemoveTimeScale( theGame.GetTimescaleSource(ETS_ThrowingAim) );
		}
		else if(skill == S_Alchemy_s08)
		{
			skillLevel = GetSkillLevel(S_Alchemy_s08);
			for (i=0; i < skillLevel; i+=1)
				thePlayer.SkillReduceBombAmmoBonus();
		}
		else if(skill == S_Perk_08)
		{
			//change level 3 items abilities from 3 to 2
			thePlayer.ChangeAlchemyItemsAbilities(false);
		}
		else if(skill == S_Alchemy_s19)
		{
			MutagensSyngergyBonusProcess(false, GetSkillLevel(skill));
		}
		else if(skill == S_Perk_01)
		{
			SetPerk01Abilities(false, false);
		}
		else if(skill == S_Perk_05)
		{
			SetPerkArmorBonus(S_Perk_05, false);
		}
		else if(skill == S_Perk_06)
		{
			SetPerkArmorBonus(S_Perk_06, false);
		}
		else if(skill == S_Perk_07)
		{
			SetPerkArmorBonus(S_Perk_07, false);
		}
		else if(skill == S_Perk_11)
		{
			battleTrance = (W3Effect_BattleTrance)owner.GetBuff(EET_BattleTrance);
			if(battleTrance)
				battleTrance.OnPerk11Unequipped();
		}		
		else if(skill == S_Perk_19 && owner.HasBuff(EET_BattleTrance))
		{
			skillLevel = FloorF(owner.GetStat(BCS_Focus));
			owner.RemoveAbilityMultiple(thePlayer.GetSkillAbilityName(S_Perk_19), skillLevel);
			owner.AddAbilityMultiple(thePlayer.GetSkillAbilityName(S_Sword_5), skillLevel);
		}
		else if(skill == S_Perk_22)
		{
			GetWitcherPlayer().UpdateEncumbrance();
			guiMan = theGame.GetGuiManager();
			if(guiMan)
			{
				commonMenu = theGame.GetGuiManager().GetCommonMenu();
				if(commonMenu)
				{
					commonMenu.UpdateItemsCounter();
				}
			}
		}
		
		if(GetSkillPathType(skill) == ESP_Alchemy)
			GetWitcherPlayer().RecalcPotionsDurations();
		
		// Update synegry bonus
		if ( CanUseSkill(S_Alchemy_s19) )
		{
			MutagensSyngergyBonusProcess(false, GetSkillLevel(S_Alchemy_s19));
			MutagensSyngergyBonusProcess(true, GetSkillLevel(S_Alchemy_s19));
		}
	}
	
	//goes through all armor pieces and updates perk bonus
	private final function SetPerkArmorBonus(skill : ESkill, enable : bool)
	{
		var item : SItemUniqueId;
		var armors : array<SItemUniqueId>;
		var light, medium, heavy, i, cnt : int;
		var armorType : EArmorType;
		var witcher : W3PlayerWitcher;
		
		if(skill != S_Perk_05 && skill != S_Perk_06 && skill != S_Perk_07)
			return;
	
		witcher = GetWitcherPlayer();
		armors.Resize(4);
		
		if(witcher.inv.GetItemEquippedOnSlot(EES_Armor, item))
			armors[0] = item;
			
		if(witcher.inv.GetItemEquippedOnSlot(EES_Boots, item))
			armors[1] = item;
			
		if(witcher.inv.GetItemEquippedOnSlot(EES_Pants, item))
			armors[2] = item;
			
		if(witcher.inv.GetItemEquippedOnSlot(EES_Gloves, item))
			armors[3] = item;
		
		light = 0;
		medium = 0;
		heavy = 0;
		for(i=0; i<armors.Size(); i+=1)
		{
			armorType = witcher.inv.GetArmorType(armors[i]);
			if(armorType == EAT_Light)
				light += 1;
			else if(armorType == EAT_Medium)
				medium += 1;
			else if(armorType == EAT_Heavy)
				heavy += 1;
		}
		
		if(skill == S_Perk_05)
			cnt = light;
		else if(skill == S_Perk_06)
			cnt = medium;
		else
			cnt = heavy;
			
		if(cnt > 0)
			UpdatePerkArmorBonus(skill, enable, cnt);
	}
	
	// adds/removes perk armor bonus
	public final function UpdatePerkArmorBonus(skill : ESkill, enable : bool, optional count : int)
	{
		var abilityName : name;
		
		abilityName = GetSkillAbilityName(skill);
		
		if(count == 0)
			count = 1;
		
		if(enable)
			charStats.AddAbilityMultiple(abilityName, count);
		else
			charStats.RemoveAbilityMultiple(abilityName, count);
	}	
	
	//sets day/night perk01's abilities
	public final function SetPerk01Abilities(enableDay : bool, enableNight : bool)
	{
		var abilityName : name;
		var i : int;
		var dm : CDefinitionsManagerAccessor;
		var abs : array<name>;
		var enable : bool;
		
		abilityName = GetSkillAbilityName(S_Perk_01);
		dm = theGame.GetDefinitionsManager();
		dm.GetContainedAbilities(abilityName, abs);
		
		for(i=0; i<abs.Size(); i+=1)
		{
			if(dm.AbilityHasTag(abs[i], 'Day'))
				enable = enableDay;
			else
				enable = enableNight;
				
			if(enable)
				charStats.AddAbility(abs[i], false);
			else
				charStats.RemoveAbility(abs[i]);
		}
	}
	
	//called when equipped skill changes level
	private final function OnSkillEquippedLevelChange(skill : ESkill, prevLevel : int, currLevel : int)
	{
		var cnt, i : int;
		var names : array<name>;
		var skillAbilityName : name;
		var mutagens : array<CBaseGameplayEffect>;
		var recipe : SAlchemyRecipe;
		var m_alchemyManager : W3AlchemyManager;
		var ignorePain : W3Effect_IgnorePain;
		
		//never changes levels
		if(IsCoreSkill(skill))
			return;
		
		if(skill == S_Alchemy_s08)
		{
			if(currLevel < prevLevel)
				thePlayer.SkillReduceBombAmmoBonus();
		}
		else if(skill == S_Alchemy_s18)
		{
			m_alchemyManager = new W3AlchemyManager in this;
			m_alchemyManager.Init();
			names = GetWitcherPlayer().GetAlchemyRecipes();
			skillAbilityName = SkillEnumToName(S_Alchemy_s18);
			cnt = 0;
			
			//count how much we should have
			for(i=0; i<names.Size(); i+=1)
			{
				m_alchemyManager.GetRecipe(names[i], recipe);
				if ((recipe.cookedItemType != EACIT_Bolt) && (recipe.cookedItemType != EACIT_Undefined) && (recipe.level <= GetSkillLevel(S_Alchemy_s18)))
					cnt += 1;
			}
			
			//add/remove abilities
			cnt -= owner.GetAbilityCount(skillAbilityName);
			if(cnt > 0)
				charStats.AddAbilityMultiple(skillAbilityName, cnt);
			else if(cnt < 0)
				charStats.RemoveAbilityMultiple(skillAbilityName, -cnt);
		}
		else if(skill == S_Alchemy_s13)
		{
			mutagens = GetWitcherPlayer().GetDrunkMutagens();
			skillAbilityName = GetSkillAbilityName(S_Alchemy_s13);			
			
			if(mutagens.Size() > 0)
				charStats.AddAbilityMultiple(skillAbilityName, GetSkillLevel(skill));
			else
				charStats.RemoveAbilityMultiple(skillAbilityName, GetSkillLevel(skill));						
		}
		else if(skill == S_Alchemy_s19)
		{
			//remove old, add new
			if ( CanUseSkill(S_Alchemy_s19) )
			{
				MutagensSyngergyBonusProcess(false, prevLevel);
				MutagensSyngergyBonusProcess(true, currLevel);
			}
		}
		else if(skill == S_Alchemy_s20)
		{
			if(owner.HasBuff(EET_IgnorePain))
			{
				ignorePain = (W3Effect_IgnorePain)owner.GetBuff(EET_IgnorePain);
				ignorePain.OnSkillLevelChanged(currLevel - prevLevel);
			}
		}
		else if(skill == S_Perk_08)
		{
			if(currLevel == 3)
				thePlayer.ChangeAlchemyItemsAbilities(true);
			else if(currLevel == 2 && prevLevel == 3)
				thePlayer.ChangeAlchemyItemsAbilities(false);
		}
		
		//some hack for sword skills
		if(GetSkillPathType(skill) == ESP_Sword)
		{
			if ( (currLevel - prevLevel) > 0)
				owner.AddAbilityMultiple('sword_adrenalinegain', currLevel - prevLevel );
			else if ( (currLevel - prevLevel) < 0)
				owner.RemoveAbilityMultiple('sword_adrenalinegain', currLevel - prevLevel );
		}
		
		//some hack for magic skills
		if(GetSkillPathType(skill) == ESP_Signs)
		{
			if ( (currLevel - prevLevel) > 0)
				owner.AddAbilityMultiple('magic_staminaregen', currLevel - prevLevel );
			else if ( (currLevel - prevLevel) < 0)
				owner.RemoveAbilityMultiple('magic_staminaregen', currLevel - prevLevel );
		}
		
		//some hack for alchemy skills
		if(GetSkillPathType(skill) == ESP_Alchemy)
		{
			if ( (currLevel - prevLevel) > 0)
				owner.AddAbilityMultiple('alchemy_potionduration', currLevel - prevLevel );
			else if ( (currLevel - prevLevel) < 0)
				owner.RemoveAbilityMultiple('alchemy_potionduration', currLevel - prevLevel );
		}
		
		if(GetSkillPathType(skill) == ESP_Alchemy)
			GetWitcherPlayer().RecalcPotionsDurations();
	}
	
	public final function CanUseSkill(skill : ESkill) : bool
	{
		var ind : int;
		
		if(!IsSkillEquipped(skill))
			return false;
			
		if(skills[skill].level < 1)
			return false;
			
		if(skills[skill].remainingBlockedTime != 0)
			return false;
			
		if(theGame.GetDefinitionsManager().IsAbilityDefined(skills[skill].abilityName) && charStats.HasAbility(skills[skill].abilityName))
			return !IsAbilityBlocked(skills[skill].abilityName);
		
		return true;
	}
		
	public final function IsSkillEquipped(skill : ESkill) : bool
	{
		var i, idx : int;
				
		//core skills always equipped
		if(IsCoreSkill(skill))
			return true;
		
		//skill slots
		for(i=0; i<skillSlots.Size(); i+=1)
			if(skillSlots[i].socketedSkill == skill)
				return true;
		
		//temp skills always equipped
		if(tempSkills.Contains(skill))
			return true;
		
		return false;
	}
	
	//sets skill on given skill slot. Returns false if skillslot is locked
	public final function GetSkillOnSlot(slotID : int, out skill : ESkill) : bool
	{
		var idx : int;
			
		if(slotID > 0 && slotID <= totalSkillSlotsCount)
		{
			idx = GetSkillSlotIndex(slotID, true);
			if(idx >= 0)
			{
				skill = skillSlots[idx].socketedSkill;
				return true;
			}
		}
		
		skill = S_SUndefined;
		return false;
	}
	
	public final function GetSkillSlots() : array<SSkillSlot>
	{
		return skillSlots;
	}
	
	public final function GetSkillSlotsCount() : int
	{
		return totalSkillSlotsCount;
	}
	
	public final function IsSkillSlotUnlocked(slotIndex : int) : bool
	{
		if(slotIndex >= 0 && slotIndex < skillSlots.Size())
			return skillSlots[slotIndex].unlocked;
			
		return false;
	}
	
	//resets character dev
	public final function ResetCharacterDev()
	{
		var i : int;
		var skillType : ESkill;
		
		for(i=0; i<skills.Size(); i+=1)
		{			
			skillType = skills[i].skillType;
			// Dazedy start

			if(IsDefaultSkill(skillType)){
				skills[i].level=1;
				continue;
			}
			// Dazedy end





		}
		
		for(i=0; i<pathPointsSpent.Size(); i+=1)
		{
			pathPointsSpent[i] = 30;
		}
		SetStatPointMax(BCS_Toxicity, 1000);
		SetStatPointMax(BCS_Stamina, 100);




	}
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////////////////  @TUTORIAL  ///////////////////////////////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	/*
		Stores (as returned value) skills equipped in three skill slots connected with first mutagen slot.
		Then it unequips those skills, 
	*/
	public final function TutorialMutagensUnequipPlayerSkills() : array<STutorialSavedSkill>
	{
		var savedSkills : array<STutorialSavedSkill>;		//array of skills that were initially in the slots, needed to restore them after tutorial is done		
		var i : int;
		var slots : array<int>;								//slot IDs of slots that are in the group connected to equipped mutagen slot
		var equippedSkill : ESkill;
		var savedSkill : STutorialSavedSkill;
		
		//get three skill slots' indexes of group in which we have the mutagen
		slots = TutorialGetConnectedSkillsSlotsIDs();
		
		//save equipped skills and clear slots
		for(i=0; i<slots.Size(); i+=1)
		{			
			if(GetSkillOnSlot(slots[i], equippedSkill) && equippedSkill != S_SUndefined)
			{
				//save skill
				savedSkill.skillType = equippedSkill;
				savedSkill.skillSlotID = slots[i];
				savedSkills.PushBack(savedSkill);
				
				//clear slot
				UnequipSkill(slots[i]);
			}
		}
		
		//update UI
		TutorialUpdateUI();
		
		return savedSkills;
	}
	
	/*
		'learns' temporary skill if not known and equips it in first skill slot.
		Such temporary skill has the same color as the color of equipped mutagen.
	*/
	public final function TutorialMutagensEquipOneGoodSkill()
	{		
		var slots : array<int>;
				
		//get three skill slots' indexes of group in which we have the mutagen
		slots = TutorialGetConnectedSkillsSlotsIDs();
		
		//select temp skill
		TutorialSelectAndAddTempSkill();
				
		//equip temp skill to first slot
		EquipSkill(temporaryTutorialSkills[0].skillType, ArrayFindMinInt(slots));
		
		//update UI
		TutorialUpdateUI();
	}
	
	//Adds one improper temp skill to second slot
	public final function TutorialMutagensEquipOneGoodOneBadSkill()
	{
		var slots : array<int>;
		
		//add temp skill
		TutorialSelectAndAddTempSkill(true);
		
		//equip to second slot
		slots = TutorialGetConnectedSkillsSlotsIDs();
		ArraySortInts(slots);
		EquipSkill(temporaryTutorialSkills[1].skillType, slots[1] );
		
		//refresh UI
		TutorialUpdateUI();		
	}
	
	//Removes improper skill from second slot and adds two proper ones to slot 2 & 3
	public final function TutorialMutagensEquipThreeGoodSkills()
	{
		var slots : array<int>;		
		
		//we no longer need the temp wrong color skill - remove it
		TutorialGetRidOfTempSkill(1);
				
		//add two proper color temp skills
		TutorialSelectAndAddTempSkill(false, 1);
		TutorialSelectAndAddTempSkill(false, 2);
		
		//equip to second & third slots
		slots = TutorialGetConnectedSkillsSlotsIDs();
		ArraySortInts(slots);
		EquipSkill(temporaryTutorialSkills[1].skillType, slots[1]);
		EquipSkill(temporaryTutorialSkills[2].skillType, slots[2]);
		
		//refresh UI
		TutorialUpdateUI();	
	}
	
	//removes all temp skills of tutorial and restores previous skills
	public final function TutorialMutagensCleanupTempSkills(savedEquippedSkills : array<STutorialSavedSkill>)
	{
		//remove 3 temp skills
		TutorialGetRidOfTempSkill(2);
		TutorialGetRidOfTempSkill(1);
		TutorialGetRidOfTempSkill(0);
		
		//restore skills you had previously equipped
		EquipSkill(savedEquippedSkills[0].skillType, savedEquippedSkills[0].skillSlotID);
		EquipSkill(savedEquippedSkills[1].skillType, savedEquippedSkills[1].skillSlotID);
		EquipSkill(savedEquippedSkills[2].skillType, savedEquippedSkills[2].skillSlotID);
		
		TutorialUpdateUI();
	}
	
	private final function TutorialGetRidOfTempSkill(tutTempArrIdx : int)
	{
		var tempSkill : ESkill;
		var i, ind : int;
		
		tempSkill = temporaryTutorialSkills[tutTempArrIdx].skillType;
		if(temporaryTutorialSkills[tutTempArrIdx].wasLearned)
		{
			if(!skills[tempSkill].isCoreSkill)
				pathPointsSpent[skills[tempSkill].skillPath] = pathPointsSpent[skills[tempSkill].skillPath] - 1;
			
			skills[tempSkill].level = 0;
		}
		
		ind = GetSkillSlotID(tempSkill);
		if(ind >= 0)
			UnequipSkill(ind);
			
		temporaryTutorialSkills.EraseFast(tutTempArrIdx);
		tempSkills.Remove(tempSkill);
	}
	
	//Selects and 'learns' temp skill matching for mutagen on EES_SkillMutange1 slot.
	//If 'of wrong' color is set, temp skill will have different color than the mutagen.
	//If 'index' is set then it picks next in line skill. Eg. we have 3 skills prepared for chosing so index =1 will select the second in line.
	private final function TutorialSelectAndAddTempSkill(optional ofWrongColor : bool, optional index : int)
	{
		var witcher : W3PlayerWitcher;
		var mutagenColor : ESkillColor;				//color of equipped mutagen
		var tempSkill : ESkill;
		var tutSkill : STutorialTemporarySkill;
		var mutagenItemId : SItemUniqueId;
		
		//get mutagen color
		witcher = GetWitcherPlayer();
		witcher.GetItemEquippedOnSlot(EES_SkillMutagen1, mutagenItemId);
		mutagenColor = witcher.inv.GetSkillMutagenColor(mutagenItemId);
		
		if(!ofWrongColor)
		{
			if(mutagenColor == SC_Blue)
			{
				if(index == 0)			tempSkill = S_Magic_s01;
				else if(index == 1)		tempSkill = S_Magic_s02;
				else if(index == 2)		tempSkill = S_Magic_s03;
			}
			else if(mutagenColor == SC_Red)
			{
				if(index == 0)			tempSkill = S_Sword_s01;
				else if(index == 1)		tempSkill = S_Sword_s02;
				else if(index == 2)		tempSkill = S_Sword_s03;
			}
			else if(mutagenColor == SC_Green)
			{
				if(index == 0)			tempSkill = S_Alchemy_s01;
				else if(index == 1)		tempSkill = S_Alchemy_s02;
				else if(index == 2)		tempSkill = S_Alchemy_s03;
			}
		}
		else
		{
			if(mutagenColor == SC_Green)
				tempSkill = S_Magic_s01;
			else
				tempSkill = S_Alchemy_s01;
		}
					
		//add temp skill if not known
		if(GetSkillLevel(tempSkill) <= 0)
		{
			tempSkills.PushBack(tempSkill);
			AddSkill(tempSkill, true);
			tutSkill.wasLearned = true;
		}
		else
		{
			tutSkill.wasLearned = false;
		}
		
		tutSkill.skillType = tempSkill;
		temporaryTutorialSkills.PushBack(tutSkill);
	}
	
	//returns array of Slot IDs of those three slots that are connected to EES_SkillMutagen1 mutagen slot
	private final function TutorialGetConnectedSkillsSlotsIDs() : array<int>
	{
		var i, connectedSkillsGroupID, processedSlots : int;
		var slots : array<int>;
		
		connectedSkillsGroupID = GetSkillGroupIdOfMutagenSlot(EES_SkillMutagen1);
		
		for(i=0; i<skillSlots.Size(); i+=1)
		{
			if(skillSlots[i].groupID == connectedSkillsGroupID)
			{
				slots.PushBack(skillSlots[i].id);
				processedSlots += 1;
				
				if(processedSlots == 3)
					break;
			}
		}
		
		return slots;
	}
	
	private final function TutorialUpdateUI()
	{
		( (CR4CharacterMenu) ((CR4MenuBase)theGame.GetGuiManager().GetRootMenu()).GetLastChild() ).UpdateData(false);
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////////////////  @HAXXX  //////////////////////////////////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	//returns true if slot was unlocked in the process
	final function Debug_HAX_UnlockSkillSlot(slotIndex : int) : bool
	{
		if(!IsSkillSlotUnlocked(slotIndex))
		{
			skillSlots[slotIndex].unlocked = true;
			LogSkills("W3PlayerAbilityManager.Debug_HAX_UnlockSkillSlot: unlocking skill slot " + slotIndex + " for debug purposes");
			return true;
		}
		
		return false;
	}
	
	final function DBG_SkillSlots()
	{
		var i : int;
		
		for(i=0; i<skillSlots.Size(); i+=1)
		{
			LogChannel('DEBUG_SKILLS', i + ") ID=" + skillSlots[i].id + " | skill=" + skillSlots[i].socketedSkill + " | groupID=" + skillSlots[i].groupID + " | unlockedAt=" + skillSlots[i].unlockedOnLevel);
		}
		
		LogChannel('DEBUG_SKILLS',"");
	}
// Elys start

	public final function MustEquipSkill(skill : ESkill) : bool
	{
		if(IsSkillEquipped(skill))
			return false;
		// Dazedy start
		if(IsDefaultSkill(skill) || IsPassiveSkill(skill) && HasLearnedSkill(skill))
			return true;
		return false;
	}
	
	public final function IsDefaultSkill(skill : ESkill) : bool
	{
		if(     skill == S_Sword_s01 ||
				skill == S_Sword_s02 ||
				skill == S_Sword_s10 ||
				skill == S_Magic_s01 ||
				skill == S_Magic_s02 ||
				skill == S_Magic_s03 ||
				skill == S_Magic_s04 ||
				skill == S_Magic_s05 ||
				skill == S_Alchemy_s06 ||
				skill == S_Perk_02 ||
				skill == S_Perk_05 ||
				skill == S_Perk_06 ||
				skill == S_Perk_07 ||
				skill == S_Perk_11 ) {		
			return true;
		}
		else {
			return false;
		}
	}
	// Dazedy end
	
	//Chicken Start
	public final function IsPassiveSkill(skill : ESkill) : bool
	{
		if(     skill == S_Sword_s21 ||
				skill == S_Sword_s04 ||
				skill == S_Sword_s11 ||
				skill == S_Sword_s07 ||
				skill == S_Sword_s13 ||
				skill == S_Sword_s16 ||
				skill == S_Sword_s20 ||
				skill == S_Magic_s07 ||
				skill == S_Magic_s12 ||
				skill == S_Magic_s15 ||
				skill == S_Magic_s16 ||
				skill == S_Magic_s18 ||
				skill == S_Perk_09 ||
				skill == S_Perk_10 ||
				skill == S_Perk_12 ||
				skill == S_Perk_13 ||
				skill == S_Perk_17 ||
				skill == S_Perk_18 ||
				skill == S_Perk_19 ||
				skill == S_Perk_22 ||
				skill == S_Alchemy_s01 ||
				skill == S_Alchemy_s05 ||
				skill == S_Alchemy_s09 ||
				skill == S_Alchemy_s10 ||
				skill == S_Alchemy_s13 ||
				skill == S_Alchemy_s15 ||
				skill == S_Alchemy_s19 ||
				skill == S_Alchemy_s20 ) {		
			return true;
		}
		else {
			return false;
		}
	}
	//Chicken End
	public final function GetFreeSkillSlotIndex() : int
	{
		var i : int;
		var slot : SSkillSlot;
		
		for(i=0; i<skillSlots.Size(); i+=1)
		{
			if(skillSlots[i].socketedSkill == S_SUndefined)
			{
				if( (skillSlots[i].unlocked) && (skillSlots[i].id > orgTotalSkillSlotsCount) )
					return i;
			}
		}

		totalSkillSlotsCount += 1;	
		slot.id = totalSkillSlotsCount;
		slot.unlockedOnLevel = 0;
		slot.neighbourUp = -1;
		slot.neighbourDown = -1;
		slot.neighbourLeft = -1;
		slot.neighbourRight = -1;
		slot.groupID = -1;
		slot.unlocked = true;	
		skillSlots.PushBack(slot);
		return skillSlots.Size() - 1;
	}

	public final function ForceEquipSkill(skill : ESkill)
	{
		var idx : int;



		idx = GetFreeSkillSlotIndex();		
		







		skillSlots[idx].socketedSkill = skill;
		

		OnSkillEquip(skill);
	}
	//Elys end
}



exec function dbgskillslots()
{
	thePlayer.DBG_SkillSlots();
}
