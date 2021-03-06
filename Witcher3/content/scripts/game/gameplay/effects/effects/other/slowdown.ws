/***********************************************************************/
/** Copyright © 2012-2014
/** Author : Tomek Kozera
/***********************************************************************/

//Slowdown will start to decay after some delay time (can be 0, -1 means never to decay).
//When this happens slowdown will gradually lose its strength and once it reaches 0 buff will remove itself.
//Regardless of that duration can be used in a normal manner.
class W3Effect_Slowdown extends CBaseGameplayEffect
{
	private saved var slowdownCauserId : int;
	private saved var decayPerSec : float;			//slowdown decay per sec once delay finished
	private saved var decayDelay : float;			//delay after which slowdown decay starts
	private saved var delayTimer : float;			//delay timer
	private saved var slowdown : float;				//base slowdown

	default isPositive = false;
	default isNeutral = false;
	default isNegative = true;
	default effectType = EET_Slowdown;
	default attributeName = 'slowdown';
	
	//modSigns: override duration calculation to make the effect continuous
	protected function CalculateDuration(optional setInitialDuration : bool)
	{
		//since slowdown loop sleeps for 0.1f now, we need effect duration to be a bit longer to cumulate
		//with previous one
		duration = 0.2f;
		
		if(setInitialDuration)
			initialDuration = duration;
	}
	
	event OnEffectAdded(optional customParams : W3BuffCustomParams)
	{
		var dm : CDefinitionsManagerAccessor;
		var min, max : SAbilityAttributeValue;
		var prc, pts, raw : float; //modSigns: new var for raw value
		
		super.OnEffectAdded(customParams);
		
		dm = theGame.GetDefinitionsManager();
		
		dm.GetAbilityAttributeValue(abilityName, 'decay_per_sec', min, max);
		decayPerSec = CalculateAttributeValue(GetAttributeRandomizedValue(min, max));
		
		dm.GetAbilityAttributeValue(abilityName, 'decay_delay', min, max);
		decayDelay = CalculateAttributeValue(GetAttributeRandomizedValue(min, max));
		
		//modSigns: calc final slowdown, apply YRDEN resist
		//prcs are not clamped to make negative resistance possible
		//points added (divided by 100 as slowdown factor < 1)
		raw = CalculateAttributeValue(effectValue);
		target.GetResistValue(CDS_ShockRes, pts, prc);
		slowdown = MaxF(0, raw - pts/100) * (1 - prc);
		//combat log
		/*theGame.witcherLog.AddCombatMessage("Slowdown effect:", GetCreator(), target);
		theGame.witcherLog.AddCombatMessage("Raw slowdown prc: " + FloatToString(raw), GetCreator(), target);
		theGame.witcherLog.AddCombatMessage("Shock resist pts: " + FloatToString(pts), GetCreator(), target);
		theGame.witcherLog.AddCombatMessage("Shock resist prc: " + FloatToString(prc), GetCreator(), target);
		theGame.witcherLog.AddCombatMessage("Slowdown prc: " + FloatToString(slowdown), GetCreator(), target);*/
		//final slowdown factor is clamped to 10-90%
		slowdown = ClampF(slowdown, 0.1, 0.9);
		
		//lvl 3 petri
		if(isSignEffect && GetCreator() == GetWitcherPlayer() && GetWitcherPlayer().GetPotionBuffLevel(EET_PetriPhiltre) == 3 && prc < 1)
		{
			slowdown = ClampF(slowdown, 0.5, 0.9); // 50% slowdown at least
		}
		
		slowdownCauserId = target.SetAnimationSpeedMultiplier( 1 - slowdown );
		delayTimer = 0;
	}
	
	//after delay time effect will slowly decay - once it does slowdown is removed
	event OnUpdate(dt : float)
	{
		if(decayDelay >= 0 && decayPerSec > 0)
		{
			if(delayTimer >= decayDelay)
			{
				target.ResetAnimationSpeedMultiplier(slowdownCauserId);
				slowdown -= decayPerSec * dt;
				
				if(slowdown > 0)
					slowdownCauserId = target.SetAnimationSpeedMultiplier( 1 - slowdown );
				else
					isActive = false;
			}
			else
			{
				delayTimer += dt;
			}
		}
		
		super.OnUpdate(dt);
	}
	
	public function CumulateWith(effect: CBaseGameplayEffect)
	{
		super.CumulateWith(effect);
		delayTimer = 0;
	}
	
	event OnEffectRemoved()
	{
		super.OnEffectRemoved();		
		target.ResetAnimationSpeedMultiplier(slowdownCauserId);
	}	
}