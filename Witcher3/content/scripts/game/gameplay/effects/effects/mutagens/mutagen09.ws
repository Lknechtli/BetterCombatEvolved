/***********************************************************************/
/** Copyright © 2014
/** Author : Tomek Kozera
/***********************************************************************/

//foglet mutagen: increase sign power for bad weather
class W3Mutagen09_Effect extends W3Mutagen_Effect
{
	default effectType = EET_Mutagen09;
	default dontAddAbilityOnTarget = true;
	
	private var hasAbility : bool;
	
	event OnUpdate(dt : float)
	{
		super.OnUpdate(dt);
		
		//modSigns: fix weather condition
		if(GetCurWeather() != EWE_Rain && GetCurWeather() != EWE_Snow && GetCurWeather() != EWE_Storm)
		{
			if(hasAbility)
			{
				target.RemoveAbility(abilityName);
				hasAbility = false;
			}
		}
		else
		{
			if(!hasAbility)
			{
				target.AddAbility(abilityName, false);
				hasAbility = true;
			}
		}
	}
	
	public function OnLoad(t : CActor, eff : W3EffectManager)
	{
		super.OnLoad(t, eff);
		hasAbility = target.HasAbility(abilityName);
	}
}