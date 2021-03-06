/***********************************************************************/
/** Copyright © 2014
/** Author : 
/***********************************************************************/

class W3Mutagen21_Effect extends W3Mutagen_Effect
{
	default effectType = EET_Mutagen21;
	
	//TODO
	//default dontAddAbilityOnTarget = 
	
	//modSigns: heal percentage depends on stamina spent
	public final function Heal(cost : float)
	{
		var vitality : float;
		var min, max : SAbilityAttributeValue;
		
		theGame.GetDefinitionsManager().GetAbilityAttributeValue(abilityName, 'healingRatio', min, max);
		vitality = target.GetStatMax(BCS_Vitality);
		vitality *= CalculateAttributeValue(GetAttributeRandomizedValue(min, max));
		vitality *= cost / target.GetStatMax(BCS_Stamina); // modSigns
		target.GainStat(BCS_Vitality, vitality);
	}
}