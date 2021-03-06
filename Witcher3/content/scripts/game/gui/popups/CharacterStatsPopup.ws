/***********************************************************************/
/** Witcher Script file - Layer for displaying system messages
/***********************************************************************/
/** Copyright © 2014 CDProjektRed
/** Author : Jason Slama
/***********************************************************************/

/*
	Book popup. Used inside Inventory menu
*/
class CharacterStatsPopupData extends TextPopupData
{	
	var m_flashValueStorage : CScriptedFlashValueStorage;
	
	protected /* override */ function GetContentRef() : string 
	{
		return "StatisticsFullRef";
	}
	
	protected /* override */ function DefineDefaultButtons():void
	{
		AddButtonDef("panel_button_common_exit", "escape-gamepad_B", IK_Escape);
		AddButtonDef("input_feedback_scroll_text", "gamepad_R_Scroll");
	}
	
	public function /* override */ OnUserFeedback( KeyCode:string ) : void
	{
		if (KeyCode == "escape-gamepad_B") // +"gamepad_R2"?
		{
			ClosePopup();
		}
	}
	
	public /* override */ function GetGFxData(parentFlashValueStorage : CScriptedFlashValueStorage) : CScriptedFlashObject 
	{ 
		var statsArray : CScriptedFlashArray;
		var gfxData : CScriptedFlashObject;
		
		m_flashValueStorage = parentFlashValueStorage;
		
		gfxData = m_flashValueStorage.CreateTempFlashObject();
		statsArray = m_flashValueStorage.CreateTempFlashArray();
		
		gfxData.SetMemberFlashString("ContentRef", GetContentRef());
		
		// If we don't add a character stat in one of the slots below, it will not be visible.
		// Note that stats don't readjust position for missing (hidden) attributes
		// format of function:
		// Parameter1: stat key, determines which text area the data will be associated with
		// Parameter2: A helper name for fetching the value of the stat
		// Parameter3: The localization key for the stat name
		// Parameter4: The icon item name. Only specific stat slots support these icons. They must match what is in the swf for expected behavior
		// Parameter5: The flash array to push the object into
		
		// #J Redundancy allows flexibility for setting stuff
		AddCharacterStat("majorStat1", 'vitality', "vitality", "vitality", statsArray, m_flashValueStorage);
		AddCharacterStat("majorStat2", 'toxicity', "toxicity", "toxicity", statsArray, m_flashValueStorage);
		AddCharacterStat("majorStat3", 'stamina', "stamina", "stamina", statsArray, m_flashValueStorage);
		AddCharacterStat("majorStat4", 'focus', "focus", "focus", statsArray, m_flashValueStorage); // Battle Trance :S
		AddCharacterStat("majorStat5", 'timeplayed', "message_total_play_time", "timeplayed", statsArray, m_flashValueStorage); // TIME PLAYED
		
		AddCharacterStat("mainMagicStat", 'spell_power', "stat_signs", "spell_power", statsArray, m_flashValueStorage);
		AddCharacterStatU("mainSilverStat", 'silverdamage', "panel_common_statistics_tooltip_silver_dps", "attack_silver", statsArray, m_flashValueStorage); 
		AddCharacterStatU("mainSteelStat", 'steeldamage', "panel_common_statistics_tooltip_steel_dps", "attack_steel", statsArray, m_flashValueStorage); 
		AddCharacterStat("mainResStat", 'armor', "attribute_name_armor", "armor", statsArray, m_flashValueStorage); // Armor :S
		
		
		// magicStats (NOTE) PLEASE keep these are one liners
		//modSigns: changed signs info output significantly to add new data
		AddCharacterHeader("panel_common_statistics_category_signs", statsArray, m_flashValueStorage);
		AddCharacterHeader("Aard", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("aardStat1", 'aard_power', "aard_intensity", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("aardStat2", 'aard_knockdownchance', "attribute_name_knockdown", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("aardStat3", 'aard_damage', "attribute_name_forcedamage", "", statsArray, m_flashValueStorage);
		AddCharacterHeader("Igni", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("igniStat1", 'igni_power', "igni_intensity", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("igniStat2", 'igni_burnchance', "effect_burning", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("igniStat3", 'igni_damage', "attribute_name_firedamage", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("igniStat3", 'igni_dmg_alt', "Channeling damage per sec", "", statsArray, m_flashValueStorage);
		AddCharacterHeader("Yrden", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("yrdenStat1", 'yrden_power', "yrden_intensity", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("yrdenStat4", 'yrden_traps', "Yrden Traps", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("yrdenStat2", 'yrden_duration', "duration", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("yrdenStat3", 'yrden_slowdown', "SlowdownEffect", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("yrdenStat7", 'yrden_health_drain', "Yrden Damage", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("yrdenStat5", 'yrden_duration_alt', "Alt Yrden Duration", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("yrdenStat5", 'yrden_charges', "Alt Yrden Charges", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("yrdenStat6", 'yrden_damage', "Alt Yrden Damage", "", statsArray, m_flashValueStorage);
		AddCharacterHeader("Quen", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("quenStat1", 'quen_power', "quen_intensity", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("quenStat1", 'quen_duration', "duration", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("quenStat1", 'quen_discharge_percent', "Returned Damage", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("quenStat2", 'quen_damageabs', "physical_resistance", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("quenStat3", 'quen_damageabs_alt', "Alt Quen Dmg Absorption", "", statsArray, m_flashValueStorage);
		AddCharacterHeader("Axii", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("axiiStat1", 'axii_power', "axii_intensity", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("axiiStat2", 'axii_chance', "Axii Chance", "", statsArray, m_flashValueStorage);
		AddCharacterStatSigns("axiiStat3", 'axii_duration_confusion', "duration", "", statsArray, m_flashValueStorage);
		//AddCharacterStatU("axiiStat3", '', "", "", statsArray);
		
		AddCharacterHeader("panel_inventory_tooltip_damage", statsArray, m_flashValueStorage);
		
		//AddCharacterStatU("silverStat1", '', "", "", statsArray); 
		AddCharacterStatU("silverStat2", 'silverFastDPS', "panel_common_statistics_tooltip_silver_fast_dps", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU("silverStat3", 'silverFastCritChance', "panel_common_statistics_tooltip_silver_fast_crit_chance", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU("silverStat4", 'silverFastCritDmg', "panel_common_statistics_tooltip_silver_fast_crit_dmg", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU("silverStat5", 'silverStrongDPS', "panel_common_statistics_tooltip_silver_strong_dps", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU("silverStat6", 'silverStrongCritChance', "panel_common_statistics_tooltip_silver_strong_crit_chance", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU("silverStat7", 'silverStrongCritDmg', "panel_common_statistics_tooltip_silver_strong_crit_dmg", "", statsArray, m_flashValueStorage); 
		//AddCharacterStatU("silverStat8", '', "", "", statsArray); 
		AddCharacterStatU2("silverStat9", 'silver_desc_poinsonchance_mult', "attribute_name_desc_poinsonchance_mult", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU2("silverStat10", 'silver_desc_bleedingchance_mult', "attribute_name_desc_bleedingchance_mult", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU2("silverStat11", 'silver_desc_burningchance_mult', "attribute_name_desc_burningchance_mult", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU2("silverStat12", 'silver_desc_confusionchance_mult', "attribute_name_desc_confusionchance_mult", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU2("silverStat13", 'silver_desc_freezingchance_mult', "attribute_name_desc_freezingchance_mult", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU2("silverStat14", 'silver_desc_staggerchance_mult', "attribute_name_desc_staggerchance_mult", "", statsArray, m_flashValueStorage); 
		//AddCharacterStatU("silverStat15", '', "", "", statsArray); 
		//AddCharacterStatU("silverStat16", '', "", "", statsArray); 
		//AddCharacterStatU("silverStat17", 'area_nml', "area_nml", "", statsArray); 
		//AddCharacterStatU("silverStat18", 'area_novigrad', "area_novigrad", "", statsArray); 
		//AddCharacterStatU("silverStat19", 'area_skellige', "area_skellige", "", statsArray);
		
		//AddCharacterStatU("steelStat1", '', "", "", statsArray);
		AddCharacterStatU("steelStat2", 'steelFastDPS', "panel_common_statistics_tooltip_steel_fast_dps", "", statsArray, m_flashValueStorage);
		AddCharacterStatU("steelStat3", 'steelFastCritChance', "panel_common_statistics_tooltip_steel_fast_crit_chance", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU("steelStat4", 'steelFastCritDmg', "panel_common_statistics_tooltip_steel_fast_crit_dmg", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU("steelStat5", 'steelStrongDPS', "panel_common_statistics_tooltip_steel_strong_dps", "", statsArray, m_flashValueStorage); 
		AddCharacterStatU("steelStat6", 'steelStrongCritChance', "panel_common_statistics_tooltip_steel_strong_crit_chance", "", statsArray, m_flashValueStorage);
		AddCharacterStatU("steelStat7", 'steelStrongCritDmg', "panel_common_statistics_tooltip_steel_strong_crit_dmg", "", statsArray, m_flashValueStorage);
		//AddCharacterStatU("steelStat8", '', "", "", statsArray);
		AddCharacterStatU2("steelStat9", 'steel_desc_poinsonchance_mult', "attribute_name_desc_poinsonchance_mult", "", statsArray, m_flashValueStorage);
		AddCharacterStatU2("steelStat10", 'steel_desc_bleedingchance_mult', "attribute_name_desc_bleedingchance_mult", "", statsArray, m_flashValueStorage);
		AddCharacterStatU2("steelStat11", 'steel_desc_burningchance_mult', "attribute_name_desc_burningchance_mult", "", statsArray, m_flashValueStorage);
		AddCharacterStatU2("steelStat12", 'steel_desc_confusionchance_mult', "attribute_name_desc_confusionchance_mult", "", statsArray, m_flashValueStorage);
		AddCharacterStatU2("steelStat13", 'steel_desc_freezingchance_mult', "attribute_name_desc_freezingchance_mult", "", statsArray, m_flashValueStorage);
		AddCharacterStatU2("steelStat14", 'steel_desc_staggerchance_mult', "attribute_name_desc_staggerchance_mult", "", statsArray, m_flashValueStorage);
		//AddCharacterStatU("steelStat15", '', "", "", statsArray);
		
		AddCharacterHeader("item_category_crossbow", statsArray, m_flashValueStorage);
		AddCharacterStatU("steelStat17", 'crossbowCritChance', "panel_common_statistics_tooltip_crossbow_crit_chance", "", statsArray, m_flashValueStorage);
		AddCharacterStatU("steelStat18", 'crossbowSteelDmg', "attribute_name_piercingdamage", "", statsArray, m_flashValueStorage);
		AddCharacterStatU("steelStat19", 'crossbowSilverDmg', "attribute_name_silverdamage", "", statsArray, m_flashValueStorage);
		
		// defStat(1-15)
		AddCharacterHeader("panel_common_statistics_category_resistance", statsArray, m_flashValueStorage);
		//AddCharacterStatU("defStat1", '', "", "", statsArray);
		AddCharacterStatF("defStat2", 'slashing_resistance_perc', "slashing_resistance_perc", "", statsArray, m_flashValueStorage);
		AddCharacterStatF("defStat3", 'piercing_resistance_perc', "attribute_name_piercing_resistance_perc", "", statsArray, m_flashValueStorage);
		AddCharacterStatF("defStat4", 'bludgeoning_resistance_perc', "bludgeoning_resistance_perc", "", statsArray, m_flashValueStorage);
		AddCharacterStatF("defStat5", 'rending_resistance_perc', "attribute_name_rending_resistance_perc", "", statsArray, m_flashValueStorage);
		AddCharacterStatF("defStat6", 'elemental_resistance_perc', "attribute_name_elemental_resistance_perc", "", statsArray, m_flashValueStorage);
		//AddCharacterStatU("defStat7", '', "", "", statsArray);
		AddCharacterStatF("defStat8", 'poison_resistance_perc', "attribute_name_poison_resistance_perc", "", statsArray, m_flashValueStorage);
		AddCharacterStatF("defStat9", 'bleeding_resistance_perc', "attribute_name_bleeding_resistance_perc", "", statsArray, m_flashValueStorage);
		AddCharacterStatF("defStat10", 'burning_resistance_perc', "attribute_name_burning_resistance_perc", "", statsArray, m_flashValueStorage);
		//AddCharacterStatU("defStat11", '', "", "", statsArray);
		AddCharacterStat("defStat12", 'vitalityRegen', "panel_common_statistics_tooltip_outofcombat_regen", "", statsArray, m_flashValueStorage);
		AddCharacterStat("defStat13", 'vitalityCombatRegen', "panel_common_statistics_tooltip_incombat_regen", "", statsArray, m_flashValueStorage);
		AddCharacterStat("defStat14", 'staminaOutOfCombatRegen', "attribute_name_staminaregen_out_of_combat", "", statsArray, m_flashValueStorage);
		AddCharacterStat("defStat15", 'staminaRegen', "attribute_name_staminaregen", "", statsArray, m_flashValueStorage);
		
		// extraStat(1-4)
		AddCharacterHeader("panel_common_statistics_category_additional", statsArray, m_flashValueStorage);
		AddCharacterStatF("extraStat1", 'bonus_herb_chance', "bonus_herb_chance", "", statsArray, m_flashValueStorage);
		AddCharacterStatU("extraStat2", 'instant_kill_chance_mult', "instant_kill_chance", "", statsArray, m_flashValueStorage);
		AddCharacterStatU("extraStat3", 'human_exp_bonus_when_fatal', "human_exp_bonus_when_fatal", "", statsArray, m_flashValueStorage);
		AddCharacterStatU("extraStat4", 'nonhuman_exp_bonus_when_fatal', "nonhuman_exp_bonus_when_fatal", "", statsArray, m_flashValueStorage);
		
		gfxData.SetMemberFlashArray("stats", statsArray);
		
		return gfxData;
	}
}

function AddCharacterHeader(locKey:string, toArray : CScriptedFlashArray, flashMaster:CScriptedFlashValueStorage):void
{
	var statObject : CScriptedFlashObject;
	var final_name : string;

	//modSigns: allows using of non-localized text
	final_name = GetLocStringByKeyExt(locKey); if ( final_name == "#" || final_name == "" ) { final_name = locKey; }
	statObject = flashMaster.CreateTempFlashObject();
	statObject.SetMemberFlashString("name", final_name);
	statObject.SetMemberFlashString("value", "");
	statObject.SetMemberFlashString("tag", "Header");
	statObject.SetMemberFlashString("iconTag", "");
	
	toArray.PushBackFlashObject(statObject);
}

function AddCharacterStat(tag : string, varKey:name, locKey:string, iconTag:string, toArray : CScriptedFlashArray, flashMaster:CScriptedFlashValueStorage):void
{
	var statObject 		: CScriptedFlashObject;
	var valueStr 		: string;
	var valueAbility 	: float;
	var final_name 		: string;
	var sp 				: SAbilityAttributeValue;
	
	var gameTime		: GameTime;
	var gameTimeDays	: string;
	var gameTimeHours	: string;
	var gameTimeMinutes	: string;
	var gameTimeSeconds	: string;
	
		
	statObject			= 	flashMaster.CreateTempFlashObject();
	
	gameTime			=	theGame.CalculateTimePlayed();
	gameTimeDays 		= 	(string)GameTimeDays(gameTime);
	gameTimeHours 		= 	(string)GameTimeHours(gameTime);
	gameTimeMinutes 	= 	(string)GameTimeMinutes(gameTime);
	gameTimeSeconds 	= 	(string)GameTimeSeconds(gameTime);
	
	
	
	//GetGenericStatValue(varKey, valueStr);
	if 		( varKey == 'vitality' )	{ valueStr = (string)RoundMath(thePlayer.GetStat(BCS_Vitality, true)) + " / " + (string)RoundMath(thePlayer.GetStatMax(BCS_Vitality)); }
	else if ( varKey == 'toxicity' ) 	{ valueStr = (string)RoundMath(thePlayer.GetStat(BCS_Toxicity, false)) + " / " + (string)RoundMath(thePlayer.GetStatMax(BCS_Toxicity)); }
	else if ( varKey == 'stamina' ) 	{ valueStr = (string)RoundMath(thePlayer.GetStat(BCS_Stamina, true)) + " / " + (string)RoundMath(thePlayer.GetStatMax(BCS_Stamina)); }
	else if ( varKey == 'focus' ) 		{ valueStr = (string)FloorF(thePlayer.GetStat(BCS_Focus, true)) + " / " + (string)RoundMath(thePlayer.GetStatMax(BCS_Focus)); }
	else if ( varKey == 'timeplayed' ) 	{ valueStr = GetLocStringByKeyExt("time_days") + " : " + gameTimeDays + " , " + GetLocStringByKeyExt("time_hours") + " : " + gameTimeHours + " , " + GetLocStringByKeyExt("time_minutes") + " : " + gameTimeMinutes + " , " + GetLocStringByKeyExt("time_seconds") + " : " + gameTimeSeconds; }//TIME PLAYED
	
	else if ( varKey == 'spell_power' )
	{
		//modSigns: show raw spell power
		sp = GetWitcherPlayer().GetAttributeValue('spell_power');
		valueAbility = sp.valueMultiplicative - 1;
		valueStr = "+" + (string)RoundMath(valueAbility * 100) + " %";
	}
	else if ( varKey == 'vitalityRegen' ) { valueStr = NoTrailZeros(RoundMath(CalculateAttributeValue( GetWitcherPlayer().GetAttributeValue( varKey ) ))) + "/" + GetLocStringByKeyExt("per_second"); }
	else if ( varKey == 'vitalityCombatRegen' ) { valueStr = NoTrailZeros(RoundMath(CalculateAttributeValue( GetWitcherPlayer().GetAttributeValue( varKey ) ))) + "/" + GetLocStringByKeyExt("per_second"); }
	else if ( varKey == 'staminaRegen' ) 
	{ 
		sp = GetWitcherPlayer().GetAttributeValue(varKey);
		valueAbility = sp.valueAdditive + sp.valueMultiplicative * GetWitcherPlayer().GetStatMax(BCS_Stamina);
	
		sp = GetWitcherPlayer().GetAttributeValue('staminaRegen_armor_mod');
		valueAbility *= 1 + sp.valueMultiplicative;
		valueStr = NoTrailZeros(RoundMath(valueAbility)) + "/" + GetLocStringByKeyExt("per_second"); 
	}
	else if ( varKey == 'staminaOutOfCombatRegen' ) 
	{
		sp = GetWitcherPlayer().GetAttributeValue(varKey);
		
		valueAbility = GetWitcherPlayer().GetStatMax(BCS_Stamina) * sp.valueMultiplicative + sp.valueAdditive;
		valueStr = NoTrailZeros(RoundMath(valueAbility)) + "/" + GetLocStringByKeyExt("per_second"); 
	}
	else if( varKey == 'armor')
	{	
		valueAbility =  CalculateAttributeValue( GetWitcherPlayer().GetTotalArmor() );
		valueStr = IntToString( RoundMath(  valueAbility ) );
	}
	else
	{	
		valueAbility =  CalculateAttributeValue( GetWitcherPlayer().GetAttributeValue( varKey ) );
		valueStr = IntToString( RoundMath(  valueAbility ) );
	}
	//modSigns: allows using of non-localized text
	final_name = GetLocStringByKeyExt(locKey); if ( final_name == "#" || final_name == "" ) { final_name = locKey; }
	statObject.SetMemberFlashString("name", final_name);
	statObject.SetMemberFlashString("value", valueStr);
	statObject.SetMemberFlashString("tag", tag);
	statObject.SetMemberFlashString("iconTag", iconTag);
	
	toArray.PushBackFlashObject(statObject);
}

//modSigns: function is rewritten to reflect mod changes and to add new params
function AddCharacterStatSigns(tag : string, varKey:name, locKey:string, iconTag:string, toArray : CScriptedFlashArray, flashMaster:CScriptedFlashValueStorage):void
{
	var statObject : CScriptedFlashObject;
	var valueStr : string;
	var valueAbility : float;
	var final_name : string;
	var min, max : float;
	var sp : SAbilityAttributeValue;
	
	statObject = flashMaster.CreateTempFlashObject();
	
	//GetGenericStatValue(varKey, valueStr);
	if ( varKey == 'aard_knockdownchance' )	
	{ 
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_1);
		//valueAbility = sp.valueMultiplicative / theGame.params.MAX_SPELLPOWER_ASSUMED;// - 4 * theGame.params.NPC_RESIST_PER_LEVEL;  
		//valueAbility = 0.25 + (sp.valueMultiplicative - 1)/2; //modded
		max = sp.valueMultiplicative - 1;
		valueAbility = 0.3 + ClampF(max, 0, 1)/2 + ClampF(max - 1, 0, 1)/3 + ClampF(max - 2, 0, 1)/4;
		valueAbility = valueAbility + MaxF(0, 1 - valueAbility) * valueAbility; //chance for any knockdown
		valueStr = (string)RoundMath( valueAbility * 100 ) + " %";
	}
	else if ( varKey == 'aard_damage' ) 	
	{  
		if ( GetWitcherPlayer().CanUseSkill(S_Magic_s06) )
		{
			sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_1);
			valueAbility = GetWitcherPlayer().GetSkillLevel(S_Magic_s06) * CalculateAttributeValue( GetWitcherPlayer().GetSkillAttributeValue( S_Magic_s06, theGame.params.DAMAGE_NAME_FORCE, false, true ) );
			valueAbility *= sp.valueMultiplicative; // modded
			valueStr = (string)RoundMath( valueAbility );
		}
		else
			valueStr = "0";
	}
	else if ( varKey == 'aard_power' ) 	
	{  
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_1);
		valueAbility = sp.valueMultiplicative - 1;
		valueStr = (string)RoundMath(valueAbility * 100) + " %";
	}
	else if ( varKey == 'igni_damage' ) 	
	{  
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_2);
		valueAbility = CalculateAttributeValue( GetWitcherPlayer().GetSkillAttributeValue( S_Magic_2, theGame.params.DAMAGE_NAME_FIRE, false, true ) );
		//modSigns: show damage bonus from pyromaniac
		if(GetWitcherPlayer().CanUseSkill(S_Magic_s09))
			valueAbility += CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_s09, theGame.params.DAMAGE_NAME_FIRE, false, false)) * GetWitcherPlayer().GetSkillLevel(S_Magic_s09);
		//valueAbility *= 1 + (sp.valueMultiplicative-1) * theGame.params.IGNI_SPELL_POWER_MILT;
		valueAbility *= sp.valueMultiplicative; // no actual change, but less unnecessary noise
		valueStr = (string)RoundMath( valueAbility );
	}
	else if ( varKey == 'igni_burnchance' ) 	
	{  
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_2);
		//valueAbility = sp.valueMultiplicative / theGame.params.MAX_SPELLPOWER_ASSUMED;// - 4 * theGame.params.NPC_RESIST_PER_LEVEL;
		valueAbility = 0.25 + (sp.valueMultiplicative - 1)/2; //modded
		//modSigns: pyromaniac no longer grants burning chance
		if (GetWitcherPlayer().CanUseSkill(S_Magic_s09))
		{
			sp = GetWitcherPlayer().GetSkillAttributeValue(S_Magic_s09, 'chance_bonus', false, false);
			valueAbility += valueAbility * sp.valueMultiplicative * GetWitcherPlayer().GetSkillLevel(S_Magic_s09) + sp.valueAdditive * GetWitcherPlayer().GetSkillLevel(S_Magic_s09);
		}
		if(GetWitcherPlayer().CanUseSkill(S_Perk_03)) //from damage manager's code
			valueAbility += CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Perk_03, 'burning_chance', false, true));
		//valueStr = (string)Min(100, RoundMath(valueAbility * 100)) + " %";
		valueStr = (string)RoundMath(valueAbility * 100) + " %";
	}
	else if ( varKey == 'igni_power' ) 	
	{  
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_2);
		valueAbility = sp.valueMultiplicative - 1;
		valueStr = (string)RoundMath(valueAbility * 100) + " %";
	}
	else if ( varKey == 'igni_dmg_alt' ) 	
	{  
		if(GetWitcherPlayer().CanUseSkill(S_Magic_s02))
		{
			sp = GetWitcherPlayer().GetSkillAttributeValue(S_Magic_s02, 'channeling_damage', false, false);
			valueAbility = sp.valueAdditive * GetWitcherPlayer().GetSkillLevel(S_Magic_s02);
			//modSigns: show damage bonus from pyromaniac
			if(GetWitcherPlayer().CanUseSkill(S_Magic_s09))
			{
				valueAbility += CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_s09, 'channeling_damage', false, false)) * GetWitcherPlayer().GetSkillLevel(S_Magic_s09);
			}
			sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_2);
			valueAbility *= sp.valueMultiplicative;
		}
		valueStr = (string)RoundMath(valueAbility);
	}
	else if ( varKey == 'yrden_slowdown' )
	{
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_3);
		//min = CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_3, 'min_slowdown', false, true));
		//max = CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_3, 'max_slowdown', false, true));
		//valueAbility = sp.valueMultiplicative / 4;
		//valueAbility =  min + (max - min) * valueAbility;
		//valueAbility = ClampF( valueAbility, min, max );
		//valueAbility *= 1 - ClampF(4 * theGame.params.NPC_RESIST_PER_LEVEL, 0, 1) ;
		//valueAbility = 0.25 + (sp.valueMultiplicative - 1)/2; // modded
		max = sp.valueMultiplicative - 1;
		valueAbility = 0.25 + ClampF(max, 0, 1)/2 + ClampF(max - 1, 0, 1)/3 + ClampF(max - 2, 0, 1)/4; //modded
		valueStr = (string)RoundMath( valueAbility * 100 ) + " %";
	}
	else if ( varKey == 'yrden_damage' )
	{
		if (GetWitcherPlayer().CanUseSkill(S_Magic_s03))
		{
			sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_3);
			valueAbility = CalculateAttributeValue( GetWitcherPlayer().GetSkillAttributeValue( S_Magic_s03, theGame.params.DAMAGE_NAME_SHOCK, false, true ) );
			valueAbility += CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_s03, 'damage_bonus_flat_after_1', false, true)) * (GetWitcherPlayer().GetSkillLevel(S_Magic_s03) - 1);
			valueAbility *= sp.valueMultiplicative;
			valueStr = (string)RoundMath( valueAbility );
		}
		else
			valueStr = "0";
	}
	else if ( varKey == 'yrden_duration' )
	{
		sp = GetWitcherPlayer().GetSkillAttributeValue(S_Magic_3, 'trap_duration', false, true);
		//sp += GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_3);
		//sp.valueMultiplicative -= 1;
		valueStr = FloatToStringPrec( CalculateAttributeValue(sp), 2 ) + GetLocStringByKeyExt("per_second");
	}
	else if ( varKey == 'yrden_duration_alt' )
	{
		if (GetWitcherPlayer().CanUseSkill(S_Magic_s03))
		{
			sp = GetWitcherPlayer().GetSkillAttributeValue(S_Magic_s03, 'trap_duration', false, true);
			//sp += GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_3);
			//sp.valueMultiplicative -= 1;
		}
		valueStr = FloatToStringPrec( CalculateAttributeValue(sp), 2 ) + GetLocStringByKeyExt("per_second");
	}
	else if ( varKey == 'yrden_traps' )
	{
		valueAbility = 1;
		if (GetWitcherPlayer().GetSkillLevel(S_Magic_s10) > 1)
		{
			valueAbility += 1;
		}
		valueStr = (string)RoundMath( valueAbility );
	}
	else if ( varKey == 'yrden_charges' )
	{
		if (GetWitcherPlayer().CanUseSkill(S_Magic_s03))
		{
			//valueAbility = CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_3, 'charge_count', false, true));
			valueAbility = CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue( S_Magic_s03, 'charge_count', false, false ));
			if (GetWitcherPlayer().CanUseSkill(S_Magic_s10))
			{
				valueAbility += CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue( S_Magic_s10, 'charge_count', false, false )) * GetWitcherPlayer().GetSkillLevel(S_Magic_s10);
			}
		}
		valueStr = (string)RoundMath( valueAbility );
	}
	else if ( varKey == 'yrden_health_drain' )
	{
		if (GetWitcherPlayer().CanUseSkill(S_Magic_s11))
		{
			valueAbility = CalculateAttributeValue( GetWitcherPlayer().GetSkillAttributeValue( S_Magic_s11, 'direct_damage_per_sec', false, true ) ) * GetWitcherPlayer().GetSkillLevel(S_Magic_s11);
			sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_3);
			valueAbility *= sp.valueMultiplicative;
			valueStr = (string)RoundMath( valueAbility );
		}
		else
			valueStr = "0";
	}
	else if ( varKey == 'yrden_power' ) 	
	{  
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_3);
		valueAbility = sp.valueMultiplicative - 1;
		valueStr = (string)RoundMath(valueAbility * 100) + " %";
	}
	else if ( varKey == 'quen_damageabs' )
	{
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_4);
		valueAbility = CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_4, 'shield_health', false, false)) * sp.valueMultiplicative;
		valueStr = (string)RoundMath( valueAbility );
	}
	else if ( varKey == 'quen_damageabs_alt' )
	{
		if (GetWitcherPlayer().CanUseSkill(S_Magic_s04))
		{
			sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_4);
			valueAbility = CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_4, 'shield_health', false, false)) * sp.valueMultiplicative;
			valueAbility *= CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_s04, 'shield_health_factor', false, true));
		}
		valueStr = (string)RoundMath( valueAbility );
	}
	else if ( varKey == 'quen_power' ) 	
	{  
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_4);
		valueAbility = sp.valueMultiplicative - 1;
		valueStr = (string)RoundMath(valueAbility * 100) + " %";
	}
	else if ( varKey == 'quen_duration' )
	{  
		valueAbility = CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_4, 'shield_duration', true, true));
		valueStr = (string)RoundMath(valueAbility) + GetLocStringByKeyExt("per_second");
	}
	else if ( varKey == 'quen_discharge_percent' )
	{  
		if (GetWitcherPlayer().CanUseSkill(S_Magic_s14))
		{			
			valueAbility = CalculateAttributeValue(GetWitcherPlayer().GetSkillAttributeValue(S_Magic_s14, 'discharge_percent', false, true)) * GetWitcherPlayer().GetSkillLevel(S_Magic_s14);
		}
		valueStr = (string)RoundMath(valueAbility * 100) + " %";
	}
	else if ( varKey == 'axii_duration_confusion' )
	{
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_5);
		sp += GetWitcherPlayer().GetSkillAttributeValue(S_Magic_5, 'duration', false, true);
		valueStr = FloatToStringPrec( CalculateAttributeValue(sp), 2 ) + GetLocStringByKeyExt("per_second");
	}
	else if ( varKey == 'axii_chance' ) 	
	{  
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_5);
		max = sp.valueMultiplicative - 1;
		valueAbility = 0.5 + ClampF(max, 0, 1)/2 + ClampF(max - 1, 0, 1)/3 + ClampF(max - 2, 0, 1)/4;
		//valueAbility = 0.25 + (sp.valueMultiplicative - 1)/2;
		valueStr = (string)RoundMath(valueAbility * 100) + " %";
	}
	else if ( varKey == 'axii_power' ) 	
	{  
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_5);
		valueAbility = sp.valueMultiplicative - 1;
		valueStr = (string)RoundMath(valueAbility * 100) + " %";
	}
	/*else if ( varKey == 'axii_duration_control' )
	{
		sp = GetWitcherPlayer().GetTotalSignSpellPower(S_Magic_s05);
		sp += GetWitcherPlayer().GetSkillAttributeValue(S_Magic_s05, 'duration', false, true);
		valueStr = FloatToStringPrec( CalculateAttributeValue(sp), 2 ) + " s";
	}*/
	else
	{	
		valueAbility =  CalculateAttributeValue( GetWitcherPlayer().GetAttributeValue( varKey ) );
		valueStr = IntToString( RoundF(  valueAbility ) );
	}
	
	final_name = GetLocStringByKeyExt(locKey); if ( final_name == "#" || final_name == "" ) { final_name = locKey; }
	statObject.SetMemberFlashString("name", final_name);
	statObject.SetMemberFlashString("value", valueStr);
	statObject.SetMemberFlashString("tag", tag);
	statObject.SetMemberFlashString("iconTag", iconTag);
	
	toArray.PushBackFlashObject(statObject);
}

function AddCharacterStatF(tag : string, varKey:name, locKey:string, iconTag:string, toArray : CScriptedFlashArray, flashMaster:CScriptedFlashValueStorage):void
{
	var statObject : CScriptedFlashObject;
	var valueStr : string;
	var valueAbility, pts, perc : float;
	var final_name : string;
	var witcher : W3PlayerWitcher;
	var isPointResist : bool;
	var stat : EBaseCharacterStats;
	var resist : ECharacterDefenseStats;
	var attributeValue : SAbilityAttributeValue;
	var powerStat : ECharacterPowerStats;
	
	statObject = flashMaster.CreateTempFlashObject();
		
	//GetGenericStatValue(varKey, valueStr);
	witcher = GetWitcherPlayer();
	stat = StatNameToEnum(varKey);
	if(stat != BCS_Undefined)
	{
		valueAbility = witcher.GetStat(stat);
	}
	else
	{
		resist = ResistStatNameToEnum(varKey, isPointResist);
		if(resist != CDS_None)
		{
			witcher.GetResistValue(resist, pts, perc);
			
			if(isPointResist)
				valueAbility = pts;
			else
				valueAbility = perc;
		}
		else
		{
			powerStat = PowerStatNameToEnum(varKey);
			if(powerStat != CPS_Undefined)
			{
				attributeValue = witcher.GetPowerStatValue(powerStat);
			}
			else
			{
				attributeValue = witcher.GetAttributeValue(varKey);
			}
			
			valueAbility = CalculateAttributeValue( attributeValue );
		}
	}
	
	//valueStr = FloatToStringPrec( valueAbility, 2 );
	valueStr = NoTrailZeros( RoundMath(valueAbility * 100) );
	//modSigns: allows using of non-localized text
	final_name = GetLocStringByKeyExt(locKey); if ( final_name == "#" || final_name == "" ) { final_name = locKey; }
	statObject.SetMemberFlashString("name", final_name);
	statObject.SetMemberFlashString("value", valueStr + " %");
	statObject.SetMemberFlashString("tag", tag);
	statObject.SetMemberFlashString("iconTag", iconTag);
	
	toArray.PushBackFlashObject(statObject);
}

function AddCharacterStatU(tag : string, varKey:name, locKey:string, iconTag:string, toArray : CScriptedFlashArray, flashMaster:CScriptedFlashValueStorage):void
{
	var curStats:SPlayerOffenseStats;
	var statObject : CScriptedFlashObject;
	var valueStr : string;
	var valueAbility, maxHealth, curHealth : float;
	var sp : SAbilityAttributeValue;
	var final_name : string;
	var item : SItemUniqueId;

	statObject = flashMaster.CreateTempFlashObject();
	
	//GetGenericStatValue(varKey, valueStr);
	//valueAbility =  CalculateAttributeValue( GetWitcherPlayer().GetAttributeValue( varKey ) );
	//valueStr = FloatToStringPrec( valueAbility, 2 );
	
	//get stats
	if(varKey != 'instant_kill_chance_mult' && varKey != 'human_exp_bonus_when_fatal' && varKey != 'nonhuman_exp_bonus_when_fatal' && varKey != 'area_nml' && varKey != 'area_novigrad' && varKey != 'area_skellige')
	{
		curStats = GetWitcherPlayer().GetOffenseStatsList();
	}
	
	if ( varKey == 'silverdamage' ) 				valueStr = NoTrailZeros(RoundMath((curStats.silverFastDPS+curStats.silverStrongDPS)/2));
	else if ( varKey == 'steeldamage' ) 			valueStr = NoTrailZeros(RoundMath((curStats.steelFastDPS+curStats.steelStrongDPS)/2));	
	else if ( varKey == 'silverFastDPS' ) 			valueStr = NoTrailZeros(RoundMath(curStats.silverFastDmg));	
	else if ( varKey == 'silverFastCritChance' )	valueStr = NoTrailZeros(RoundMath(curStats.silverFastCritChance))+" %";
	else if ( varKey == 'silverFastCritDmg' )		valueStr = NoTrailZeros(RoundMath(curStats.silverFastCritDmg));
	else if ( varKey == 'silverStrongDPS' )			valueStr = NoTrailZeros(RoundMath(curStats.silverStrongDmg));
	else if ( varKey == 'silverStrongCritChance' )	valueStr = NoTrailZeros(RoundMath(curStats.silverStrongCritChance))+" %";
	else if ( varKey == 'silverStrongCritDmg' )		valueStr = NoTrailZeros(RoundMath(curStats.silverStrongCritDmg));
	else if ( varKey == 'steelFastDPS' ) 			valueStr = NoTrailZeros(RoundMath(curStats.steelFastDmg));	
	else if ( varKey == 'steelFastCritChance' )		valueStr = NoTrailZeros(RoundMath(curStats.steelFastCritChance))+" %";
	else if ( varKey == 'steelFastCritDmg' )		valueStr = NoTrailZeros(RoundMath(curStats.steelFastCritDmg));
	else if ( varKey == 'steelStrongDPS' )			valueStr = NoTrailZeros(RoundMath(curStats.steelStrongDmg));
	else if ( varKey == 'steelStrongCritChance' )	valueStr = NoTrailZeros(RoundMath(curStats.steelStrongCritChance))+" %";
	else if ( varKey == 'steelStrongCritDmg' )		valueStr = NoTrailZeros(RoundMath(curStats.steelStrongCritDmg));
	else if ( varKey == 'crossbowCritChance' )		valueStr = NoTrailZeros(RoundMath(curStats.crossbowCritChance * 100))+" %";
	else if ( varKey == 'crossbowDmg' )				valueStr = "";
	else if ( varKey == 'crossbowSteelDmg' )				
	{ 
		valueStr = NoTrailZeros(RoundMath(curStats.crossbowSteelDmg));
		switch (curStats.crossbowSteelDmgType)
		{
			case theGame.params.DAMAGE_NAME_BLUDGEONING: locKey = "attribute_name_bludgeoningdamage"; break;
			case theGame.params.DAMAGE_NAME_FIRE: locKey = "attribute_name_firedamage"; break;
			default : locKey = "attribute_name_piercingdamage"; break;
		}
	} 
	else if ( varKey == 'crossbowSilverDmg' )				
	{
		valueStr = NoTrailZeros(RoundMath(curStats.crossbowSilverDmg));
	}
	else if ( varKey == 'instant_kill_chance_mult') 
	{
		valueAbility = 0;
		if (thePlayer.CanUseSkill(S_Sword_s03))
		{
			sp += GetWitcherPlayer().GetSkillAttributeValue(S_Sword_s03, 'instant_kill_chance', false, true);
			valueAbility = CalculateAttributeValue(sp);
			valueAbility *= thePlayer.GetSkillLevel(S_Sword_s03);
			valueAbility *= RoundF(thePlayer.GetStat(BCS_Focus));
		}
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SteelSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.inv.GetItemAttributeValue(item, varKey)); 
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SilverSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.inv.GetItemAttributeValue(item, varKey)); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if (varKey == 'human_exp_bonus_when_fatal' || varKey == 'nonhuman_exp_bonus_when_fatal') 
	{
		sp = thePlayer.GetAttributeValue(varKey);

		valueStr = NoTrailZeros(RoundMath(CalculateAttributeValue(sp) * 100)) + " %";
	}
	else if (varKey == 'area_nml') 
	{
		if (!thePlayer.HasAbility(varKey))
			locKey = "";
		else
		{
			//valueAbility =  1 - CalculateAttributeValue( GetWitcherPlayer().GetAttributeValue( 'nomansland_price_mult' ) );
			//valueStr = IntToString( RoundF(  valueAbility * 100 ) ) + " %";
		}
	}
	else if (varKey == 'area_novigrad') 
	{
		if (!thePlayer.HasAbility(varKey))
			locKey = "";
		else
		{
			//valueAbility =  1 - CalculateAttributeValue( GetWitcherPlayer().GetAttributeValue( 'novigrad_price_mult' ) );
			//valueStr = IntToString( RoundF(  valueAbility * 100 ) ) + " %";
		}
	}
	else if (varKey == 'area_skellige') 
	{
		if (!thePlayer.HasAbility(varKey))
			locKey = "";
		else
		{
			//valueAbility =  1 - CalculateAttributeValue( GetWitcherPlayer().GetAttributeValue( 'skellige_price_mult' ) );
			//valueStr = IntToString( RoundF(  valueAbility * 100 ) ) + " %";
		}
	}
	//modSigns: allows using of non-localized text
	final_name = GetLocStringByKeyExt(locKey); if ( final_name == "#" || final_name == "" ) { final_name = locKey; }
	statObject.SetMemberFlashString("name", final_name);
	statObject.SetMemberFlashString("value", valueStr );
	statObject.SetMemberFlashString("tag", tag);
	statObject.SetMemberFlashString("iconTag", iconTag);
	
	toArray.PushBackFlashObject(statObject);
}

function AddCharacterStatU2(tag : string, varKey:name, locKey:string, iconTag:string, toArray : CScriptedFlashArray, flashMaster:CScriptedFlashValueStorage):void
{
	var curStats:SPlayerOffenseStats;
	var statObject : CScriptedFlashObject;
	var valueStr : string;
	var valueAbility, maxHealth, curHealth : float;
	var sp : SAbilityAttributeValue;
	var final_name : string;
	var item : SItemUniqueId;

	statObject = flashMaster.CreateTempFlashObject();
	
	if ( varKey == 'silver_desc_poinsonchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SilverSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_poinsonchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if ( varKey == 'silver_desc_bleedingchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SilverSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_bleedingchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if ( varKey == 'silver_desc_burningchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SilverSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_burningchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if ( varKey == 'silver_desc_confusionchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SilverSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_confusionchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if ( varKey == 'silver_desc_freezingchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SilverSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_freezingchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if ( varKey == 'silver_desc_staggerchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SilverSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_staggerchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	}
	else if ( varKey == 'steel_desc_poinsonchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SteelSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_poinsonchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if ( varKey == 'steel_desc_bleedingchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SteelSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_bleedingchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if ( varKey == 'steel_desc_burningchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SteelSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_burningchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if ( varKey == 'steel_desc_confusionchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SteelSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_confusionchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if ( varKey == 'steel_desc_freezingchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SteelSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_freezingchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	} 
	else if ( varKey == 'steel_desc_staggerchance_mult') 
	{
		valueAbility = 0;
		if (GetWitcherPlayer().GetItemEquippedOnSlot(EES_SteelSword, item))
			valueAbility += CalculateAttributeValue(thePlayer.GetInventory().GetItemAttributeValue(item, 'desc_staggerchance_mult')); 
		valueStr = NoTrailZeros(RoundMath(valueAbility * 100)) + " %";
	}
	//modSigns: allows using of non-localized text
	final_name = GetLocStringByKeyExt(locKey); if ( final_name == "#" || final_name == "" ) { final_name = locKey; }
	statObject.SetMemberFlashString("name", final_name);
	statObject.SetMemberFlashString("value", valueStr );
	statObject.SetMemberFlashString("tag", tag);
	statObject.SetMemberFlashString("iconTag", iconTag);
	
	toArray.PushBackFlashObject(statObject);
}
