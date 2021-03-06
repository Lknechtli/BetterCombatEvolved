/***********************************************************************/
/** Copyright © 2014
/** Author : Tomek Kozera
/***********************************************************************/

class W3Effect_YrdenHealthDrain extends W3DamageOverTimeEffect
{
	private var hitFxDelay : float;
	
	default effectType = EET_YrdenHealthDrain;
	default isPositive = false;
	default isNeutral = false;
	default isNegative = true;
	
	event OnEffectAdded(optional customParams : W3BuffCustomParams)
	{
		super.OnEffectAdded(customParams);
		
		//modSigns: since this effect last for 0.1 sec fx is never played. Moved it to Yrden entity.
		//hitFxDelay = 0.9 + RandF() / 5;	//0.9-1.1
		//hitFxDelay = 0;
		
		//recalc value
		SetEffectValue();
	}
	
	//@Overrides parent - effectValue depends on skill only
	protected function SetEffectValue()
	{
		//modSigns: it would probably be easier to add it as damage inside slowdown loop (similar to how Igni channeling damage works),
		//but I don't feel I know every damage action param that well, so I better do it this way.
		//Also, it's not actual DoT damage as it doesn't have corresponding DoT resist stat. And it's already hacky enough.
		var sp : SAbilityAttributeValue;
		effectValue = thePlayer.GetSkillAttributeValue(S_Magic_s11, 'direct_damage_per_sec', false, true);
		//don't touch effect multiplier to not trigger HP % damage accidentally
		effectValue.valueAdditive *= thePlayer.GetSkillLevel(S_Magic_s11); // multiply by skill level
		// combat log
		//theGame.witcherLog.AddCombatMessage("Yrden health drain:", GetCreator(), target);
		//theGame.witcherLog.AddCombatMessage("Target: " + target.GetDisplayName(), GetCreator(), target);
		//theGame.witcherLog.AddCombatMessage("Raw dmg: " + FloatToString(effectValue.valueAdditive), GetCreator(), target);
		sp = thePlayer.GetTotalSignSpellPower(S_Magic_3);
		effectValue.valueAdditive *= sp.valueMultiplicative;  // multiply by spell power
		target.GetResistValue(CDS_ShockRes, resistancePts, resistance);
		effectValue.valueAdditive -= resistancePts; // subtract target's resistance
		effectValue.valueAdditive *= 1 - resistance; // scale with target's resistance
		// combat log
		//theGame.witcherLog.AddCombatMessage("Power mult: " + FloatToString(sp.valueMultiplicative), GetCreator(), target);
		//theGame.witcherLog.AddCombatMessage("Resist pts: " + FloatToString(resistancePts), GetCreator(), target);
		//theGame.witcherLog.AddCombatMessage("Resist prc: " + FloatToString(resistance), GetCreator(), target);
		//theGame.witcherLog.AddCombatMessage("Dmg: " + FloatToString(effectValue.valueAdditive), GetCreator(), target);
	}
	
	event OnUpdate(dt : float)
	{
		super.OnUpdate(dt);
		
		//modSigns: since this effect last for 0.1 sec fx is never played. Moved it to Yrden entity.
		/*hitFxDelay -= dt;
		if(hitFxDelay <= 0)
		{
			hitFxDelay = 0.9 + RandF() / 5;	//0.9-1.1
			target.PlayEffect('yrden_shock');
		}*/
	}
}