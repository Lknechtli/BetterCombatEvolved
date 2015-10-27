/*
Copyright © CD Projekt RED 2015
*/

struct SQuenEffects
{
	editable var lastingEffectUpgNone	: name;
	editable var lastingEffectUpg1		: name;
	editable var lastingEffectUpg2		: name;
	editable var lastingEffectUpg3		: name;
	editable var castEffect				: name;
	editable var cameraShakeStranth		: float;
}

statemachine class W3QuenEntity extends W3SignEntity
{
	editable var effects : array< SQuenEffects >;
	editable var hitEntityTemplate : CEntityTemplate;
		
	
	protected var shieldDuration	: float;
	protected var shieldHealth		: float;
	protected var dischargePercent	: float;
	protected var ownerBoneIndex	: int;
	protected var blockedAllDamage  : bool;
	protected var shieldStartTime	: EngineTime;
	private var hitEntityTimestamps : array<EngineTime>;
	private const var MIN_HIT_ENTITY_SPAWN_DELAY : float;
	private var hitDoTEntities : array<W3VisualFx>;
	public var showForceFinishedFX : bool;
	
	default skillEnum = S_Magic_4;
	default MIN_HIT_ENTITY_SPAWN_DELAY = 0.25f;
	
	public function GetSignType() : ESignType
	{
		return ST_Quen;
	}
	
	public function SetBlockedAllDamage(b : bool)
	{
		blockedAllDamage = b;
	}
	
	public function GetBlockedAllDamage() : bool
	{
		return blockedAllDamage;
	}
	
	function Init( inOwner : W3SignOwner, prevInstance : W3SignEntity, optional skipCastingAnimation : bool, optional notPlayerCast : bool ) : bool
	{
		var oldQuen : W3QuenEntity;
		
		ownerBoneIndex = inOwner.GetActor().GetBoneIndex( 'pelvis' );
		if(ownerBoneIndex == -1)
			ownerBoneIndex = inOwner.GetActor().GetBoneIndex( 'k_pelvis_g' );
			
		oldQuen = (W3QuenEntity)prevInstance;
		if(oldQuen)
			oldQuen.OnSignAborted(true);
		
		hitEntityTimestamps.Clear();
		
		return super.Init( inOwner, prevInstance, skipCastingAnimation );
	}
	
	event OnTargetHit( out damageData : W3DamageAction )
	{
		if(owner.GetActor() == thePlayer && !damageData.IsDoTDamage() && !damageData.WasDodged())
			theGame.VibrateControllerHard();
	}
		
	protected function GetSignStats()
	{
		var level : int;
		var skillBonus : float;
		var spellPower : SAbilityAttributeValue;
		var ownerActor : CActor;
		super.GetSignStats();
		
		level = owner.GetSkillLevel(S_Magic_s15);
		ownerActor = owner.GetActor();
		
		// Dazedy start
		//shieldDuration = CalculateAttributeValue(owner.GetSkillAttributeValue(skillEnum, 'shield_duration', true, true));
		//shieldHealth = CalculateAttributeValue(owner.GetSkillAttributeValue(skillEnum, 'shield_health', false, true));
		
		//shieldDuration = 10 + (spellpower/10)
		shieldDuration = CalculateAttributeValue(owner.GetSkillAttributeValue(skillEnum, 'shield_duration', true, true));
		spellPower = ownerActor.GetTotalSignSpellPower(S_Magic_4);
		if( owner.CanUseSkill(S_Magic_s15)) {
			skillBonus = CalculateAttributeValue( owner.GetSkillAttributeValue( S_Magic_s15, 'bonus', false, true ) );
		} 
		else {
			skillBonus = 0;
		}
		//GetWitcherPlayer().DisplayHudMessage("spell power = " +((skillBonus + spellPower.valueMultiplicative-1)*10));
		shieldDuration += ((skillBonus + spellPower.valueMultiplicative)-1)*10;
		
		//shieldHealth = 1 hit + 1 more at level 3 and level 5 of sign% skill
		shieldHealth = 1;
		if(owner.CanUseSkill(S_Magic_s15)){
			if(level == 3 || level == 4) {
				shieldHealth += 1;
			}
			else if(level == 5){
				shieldHealth += 2;
			}
		}
		// Dazedy end
		if ( owner.CanUseSkill(S_Magic_s14))
		{			
			dischargePercent = CalculateAttributeValue(owner.GetSkillAttributeValue(S_Magic_s14, 'discharge_percent', false, true)) * owner.GetSkillLevel(S_Magic_s14);
		}
		else
		{
			dischargePercent = 0;
		}
	}
	
	public final function AddBuffImmunities(useDoTs : bool)
	{
		var actor : CActor;
		var i : int;
		
		var crits : array<CBaseGameplayEffect>;
		
		actor = owner.GetActor();
		crits = actor.GetBuffs();	
		for(i=0; i<crits.Size(); i+=1)
		{
			if( IsDoTEffect(crits[i]) && crits[i].GetEffectType() != EET_SnowstormQ403 && crits[i].GetEffectType() != EET_Snowstorm)
			{
				actor.RemoveEffect(crits[i], true);
			}
			else if(crits[i].GetEffectType() == EET_SnowstormQ403 || crits[i].GetEffectType() == EET_Snowstorm)
			{
				actor.FinishQuen(false);
				return;
			}
		}		
	}
	
	public final function RemoveBuffImmunities(useDoTs : bool)
	{
		var actor : CActor;
		var i, size : int;
		var dots : array<EEffectType>;
		
		actor = owner.GetActor();
		
		dots.PushBack(EET_Bleeding);
		dots.PushBack(EET_Burning);
		dots.PushBack(EET_Poison);
		dots.PushBack(EET_PoisonCritical);
		dots.PushBack(EET_Swarm);
		

		
		if(useDoTs)
		{
			for(i=0; i<dots.Size(); i+=1)
			{
				actor.RemoveBuffImmunity(dots[i], 'Quen' );
			}			
		}		
		

		
		size = EnumGetMax('EEffectType')+1;
		for(i=0; i<size; i+=1)
		{
			if(IsCriticalEffectType(i) && !dots.Contains(i))
				actor.RemoveBuffImmunity(i, 'Quen');
		}
	}
	
	event OnStarted() 
	{
		var isAlternate : bool;
		
		owner.ChangeAspect( this, S_Magic_s04 );
		isAlternate = IsAlternateCast();
		
		if(isAlternate)
		{

	
			CreateAttachment( owner.GetActor(), 'quen_sphere' );
			
			if((CPlayer)owner.GetActor())
				GetWitcherPlayer().FailFundamentalsFirstAchievementCondition();
		}
		else
		{
			super.OnStarted();
		}
		

		
		if(owner.GetActor() == thePlayer && ShouldProcessTutorial('TutorialSelectQuen'))
		{
			FactsAdd("tutorial_quen_cast");
		}
		
		if((CPlayer)owner.GetActor())
			GetWitcherPlayer().FailFundamentalsFirstAchievementCondition();
				
		if( isAlternate || !owner.IsPlayer() )
		{
			PlayEffect( effects[1].castEffect );
			CacheActionBuffsFromSkill();
			GotoState( 'QuenChanneled' );
		}
		else
		{
			PlayEffect( effects[0].castEffect );
			GotoState( 'QuenShield' );
		}
	}

	
	
	public function Impulse()
	{
		var level, i, j : int;
		var atts, damages : array<name>;
		var ents : array<CGameplayEntity>;
		var action : W3DamageAction;
		var dm : CDefinitionsManagerAccessor;
		var skillAbilityName : name;
		var dmg : float;
		var min, max : SAbilityAttributeValue;
		var ownerActor : CActor;
		
		level = owner.GetSkillLevel(S_Magic_s13);
		dm = theGame.GetDefinitionsManager();
		skillAbilityName = owner.GetPlayer().GetSkillAbilityName(S_Magic_s13);
		ownerActor = owner.GetActor();
		if(level >= 2)
		{
			dm.GetAbilityAttributes(skillAbilityName, atts);
			for(i=0; i<atts.Size(); i+=1)
			{
				if(IsDamageTypeNameValid(atts[i]))
				{
					damages.PushBack(atts[i]);
				}
			}
		}
		
		//find targets
		// alt cast has a larger explosion range.
		if(IsAlternateCast()) {
			FindGameplayEntitiesInSphere(ents, ownerActor.GetWorldPosition(), 6, 1000, '', FLAG_OnlyAliveActors+FLAG_ExcludeTarget+FLAG_Attitude_Hostile+FLAG_Attitude_Neutral, ownerActor);
		}
		else {
			FindGameplayEntitiesInSphere(ents, ownerActor.GetWorldPosition(), 3, 1000, '', FLAG_OnlyAliveActors+FLAG_ExcludeTarget+FLAG_Attitude_Hostile+FLAG_Attitude_Neutral, ownerActor);
		}
		
		//apply effects
		for(i=0; i<ents.Size(); i+=1)
		{
			action = new W3DamageAction in theGame;
			action.Initialize(ownerActor, ents[i], this, "quen_impulse", EHRT_Heavy, CPS_SpellPower, false, false, true, false);
			action.SetSignSkill(S_Magic_s13);
			action.SetCannotReturnDamage(true);
			action.SetProcessBuffsIfNoDamage(true);
			
			//hit fx for alternate level 2+, sphere has it at the end of func
			if(!IsAlternateCast() && level >= 2)
			{
				action.SetHitEffect('hit_electric_quen');
				action.SetHitEffect('hit_electric_quen', true);
				action.SetHitEffect('hit_electric_quen', false, true);
				action.SetHitEffect('hit_electric_quen', true, true);
			}
			
			if(level >= 1)
			{
				action.AddEffectInfo(EET_Stagger);
			}
			if(level >= 2)
			{
				for(j=0; j<damages.Size(); j+=1)
				{
					dm.GetAbilityAttributeValue(skillAbilityName, damages[j], min, max);
					dmg = CalculateAttributeValue(GetAttributeRandomizedValue(min, max));
					action.AddDamage(damages[j], dmg);
				}
			}
			if(level == 3)
			{
				action.AddEffectInfo(EET_KnockdownTypeApplicator);
			}
			
			theGame.damageMgr.ProcessAction( action );
			delete action;
		}
		
		if(IsAlternateCast())
		{
			PlayHitEffect('quen_impulse_explode', ownerActor.GetWorldRotation());
		}
		else
		{
			ownerActor.PlayEffect('lasting_shield_impulse');
		}
		
		if(IsAlternateCast() && level >= 2)
		{
			PlayHitEffect('quen_electric_explode', ownerActor.GetWorldRotation());
		}
	}
	
	public final function IsAnyQuenActive() : bool
	{
		if(GetCurrentStateName() == 'QuenChanneled' || (GetCurrentStateName() == 'ShieldActive' && shieldHealth > 0) )
		{
			return true;
		}
				
		return false;
	}
	
	event OnSignAborted( optional force : bool ){}
	
	public final function PlayHitEffect(fxName : name, rot : EulerAngles, optional isDoT : bool)
	{
		var hitEntity : W3VisualFx;
		var currentTime : EngineTime;
		var dt : float;
		
		currentTime = theGame.GetEngineTime();
		if(hitEntityTimestamps.Size() > 0)
		{
			dt = EngineTimeToFloat(currentTime - hitEntityTimestamps[0]);
			if(dt < MIN_HIT_ENTITY_SPAWN_DELAY)
				return;
		}
		hitEntityTimestamps.Erase(0);
		hitEntityTimestamps.PushBack(currentTime);
		
		hitEntity = (W3VisualFx)theGame.CreateEntity(hitEntityTemplate, GetWorldPosition(), rot);
		if(hitEntity)
		{
			
			hitEntity.CreateAttachment(owner.GetActor(), 'quen_sphere', , rot);
			hitEntity.PlayEffect(fxName);
			hitEntity.DestroyOnFxEnd(fxName);
			
			if(isDoT)
				hitDoTEntities.PushBack(hitEntity);
		}
	}
	
	timer function RemoveDoTFX(dt : float, id : int)
	{
		RemoveHitDoTEntities();
	}
	
	public final function RemoveHitDoTEntities()
	{
		var i : int;
		
		for(i=hitDoTEntities.Size()-1; i>=0; i-=1)
		{
			if(hitDoTEntities[i])
				hitDoTEntities[i].Destroy();
		}
	}
	
	public final function GetShieldHealth() : float 		{return shieldHealth;}
	
	public final function GetShieldRemainingDuration() : float
	{
		return shieldDuration - EngineTimeToFloat( theGame.GetEngineTime() - shieldStartTime );
	}
	
	public final function SetDataFromRestore(health : float, duration : float)
	{
		shieldHealth = health;
		shieldDuration = duration;
		shieldStartTime = theGame.GetEngineTime();
		AddTimer('Expire', shieldDuration, false, , , true, true);
	}
	
	timer function Expire( deltaTime : float , id : int)
	{		
		GotoState( 'Expired' );
	}
	
	public final function ForceFinishQuen(skipVisuals : bool)
	{
		if(IsAlternateCast())
		{
			OnEnded();
			
			if(!skipVisuals)
				owner.GetActor().PlayEffect('hit_electric_quen');
		}
		else
		{
			showForceFinishedFX = !skipVisuals;
			GotoState('Expired');
		}
	}
}

//basic, passive shield - when shield is finishing
state Expired in W3QuenEntity
{
	event OnEnterState( prevStateName : name )
	{
		parent.shieldHealth = 0;
		
		if(parent.showForceFinishedFX)
			parent.owner.GetActor().PlayEffect('quen_lasting_shield_hit');
			
		parent.DestroyAfter( 1.f );		
		
		if(parent.owner.GetActor() == thePlayer)
			theGame.VibrateControllerVeryHard();	//quen expired
	}
}

//basic, non-channeled version, while the shield is active
state ShieldActive in W3QuenEntity extends Active
{
	private final function GetLastingFxName() : name
	{
		var level : int;
		
		if(caster.CanUseSkill(S_Magic_s15))
		{
			//Dazedy start
			//show 1 particle per hit charge
			level = caster.GetSkillLevel(S_Magic_s15);
			if(level == 1)
				return parent.effects[0].lastingEffectUpgNone;
			else if(level == 2)
				return parent.effects[0].lastingEffectUpgNone;
			else if(level == 3)
				return parent.effects[0].lastingEffectUpg1;
			else if(level == 4)
				return parent.effects[0].lastingEffectUpg1;
			else if(level == 5)
				return parent.effects[0].lastingEffectUpg2;
			//Dazedy end
		}

		return parent.effects[0].lastingEffectUpgNone;
	}
	
	event OnEnterState( prevStateName : name )
	{
		var witcher : W3PlayerWitcher;
		var player : CR4Player;
		var cost, stamina : float;
		
		super.OnEnterState( prevStateName );
		
		witcher = (W3PlayerWitcher)caster.GetActor();
		if(witcher)
			witcher.SetUsedQuenInCombat();
		
		caster.GetActor().PlayEffect(GetLastingFxName());
		
		parent.AddTimer( 'Expire', parent.shieldDuration, false, , , true );
		
		parent.AddBuffImmunities(false);
		
		player = caster.GetPlayer();
		if(player == caster.GetActor() && player && player.CanUseSkill(S_Perk_09))
		{
			cost = player.GetStaminaActionCost(ESAT_Ability, SkillEnumToName( parent.skillEnum ), 0);
			stamina = player.GetStat(BCS_Stamina, true);
			
			if(cost > stamina)
				player.DrainFocus(1);
			else
				caster.GetActor().DrainStamina( ESAT_Ability, 0, 0, SkillEnumToName( parent.skillEnum ) );
		}
		else
			caster.GetActor().DrainStamina( ESAT_Ability, 0, 0, SkillEnumToName( parent.skillEnum ) );
		
		witcher.CriticalEffectAnimationInterrupted("quen channeled");
		
		//hack for signs not being saved
		witcher.AddTimer('HACK_QuenSaveStatus', 0, true);
		parent.shieldStartTime = theGame.GetEngineTime();
	}
	
	event OnLeaveState( nextStateName : name )
	{
		var witcher : W3PlayerWitcher;
		
		//stop 'basic' quen fx if it's current quen entity (when it's 'old' entity and new is active we don't stop the fx)
		witcher = (W3PlayerWitcher)caster.GetActor();
		if(witcher && parent == witcher.GetSignEntity(ST_Quen))
		{
			witcher.StopEffect(parent.effects[0].lastingEffectUpg1);
			witcher.StopEffect(parent.effects[0].lastingEffectUpg2);
			witcher.StopEffect(parent.effects[0].lastingEffectUpg3);
			witcher.StopEffect(parent.effects[0].lastingEffectUpgNone);
		}
	
		parent.RemoveBuffImmunities(false);
		
		parent.RemoveHitDoTEntities();
		
		if(parent.owner.GetActor() == thePlayer)
		{
			GetWitcherPlayer().OnBasicQuenFinishing();			
		}
	}
	
	event OnEnded(optional isEnd : bool)
	{
		parent.StopEffect( parent.effects[parent.fireMode].castEffect );
	}
		
	//not channeled version
	event OnTargetHit( out damageData : W3DamageAction )
	{
		var pos : Vector;
		var reducedDamage, drainedHealth, skillBonus, incomingDamage, directDamage : float;
		var spellPower : SAbilityAttributeValue;
		var physX : CEntity;
		var inAttackAction : W3Action_Attack;
		var action : W3DamageAction;
		var casterActor : CActor;
		var effectTypes : array < EEffectType >;
		var damageTypes : array<SRawDamage>;
		var i : int;
		var isBleeding : bool;
		var level : int;
		
		if( damageData.WasDodged() ||
			damageData.GetHitReactionType() == EHRT_Reflect )
		{
			return true;
		}
		
		parent.OnTargetHit(damageData);
		
		inAttackAction = (W3Action_Attack)damageData;
		if(inAttackAction && inAttackAction.CanBeParried() && (inAttackAction.IsParried() || inAttackAction.IsCountered()) )
			return true;
		
		casterActor = caster.GetActor();
		reducedDamage = 0;		
				
		//calulcate reduced damage
		damageData.GetDTs(damageTypes);
		for(i=0; i<damageTypes.Size(); i+=1)
		{
			if(damageTypes[i].dmgType == theGame.params.DAMAGE_NAME_DIRECT)
			{
				directDamage = damageTypes[i].dmgVal;
				break;
			}
		}
		
		//special handling for bleeding
		if( (W3Effect_Bleeding)damageData.causer )
		{
			incomingDamage = directDamage;
			isBleeding = true;
		}
		else
		{	
			isBleeding = false;
			incomingDamage = MaxF(0, damageData.processedDmg.vitalityDamage - directDamage);
		}
		
		// 
		level = caster.GetSkillLevel(S_Magic_s15);
		reducedDamage = MaxF(incomingDamage * (0.5 + level*0.05), 0);
		//GetWitcherPlayer().DisplayHudMessage("incomingDamage="+incomingDamage+", reduced="+reducedDamage);
		
		//quen hit fx
		if(!damageData.IsDoTDamage())
		{
			casterActor.PlayEffect( 'quen_lasting_shield_hit' );	//hack!
			GCameraShake( parent.effects[parent.fireMode].cameraShakeStranth, true, parent.GetWorldPosition(), 30.0f );
		}
		
		//modify incoming damage action
		if ( theGame.CanLog() )
		{
			LogDMHits("Quen ShieldActive.OnTargetHit: reducing damage from " + damageData.processedDmg.vitalityDamage + " to " + (damageData.processedDmg.vitalityDamage - reducedDamage), action );
		}
		
		damageData.SetHitAnimationPlayType( EAHA_ForceNo );		
		damageData.SetCanPlayHitParticle( false );
		
		if(reducedDamage > 0)
		{
			//reduce shield health
			spellPower = casterActor.GetTotalSignSpellPower(virtual_parent.GetSkill());
			
			if ( caster.CanUseSkill( S_Magic_s15 ) )
				skillBonus = CalculateAttributeValue( caster.GetSkillAttributeValue( S_Magic_s15, 'bonus', false, true ) );
			else
				skillBonus = 0;
			// Dazedy
			// Shield has up to 3 health (hits), each hit takes one away
			parent.shieldHealth -= 1;
			
				
			damageData.processedDmg.vitalityDamage -= reducedDamage;
			
			//?
			if( damageData.processedDmg.vitalityDamage >= 20 )
				casterActor.RaiseForceEvent( 'StrongHitTest' );
				
			//discharge effect's damage
			if (casterActor == thePlayer && damageData.attacker != casterActor && GetWitcherPlayer().CanUseSkill(S_Magic_s14) && parent.dischargePercent > 0 && !damageData.IsActionRanged() && VecDistanceSquared( casterActor.GetWorldPosition(), damageData.attacker.GetWorldPosition() ) <= 13 ) 
			{
				action = new W3DamageAction in theGame.damageMgr;
				action.Initialize( casterActor, damageData.attacker, parent, 'quen', EHRT_Light, CPS_SpellPower, false, false, true, false, 'hit_shock' );
				parent.InitSignDataForDamageAction( action );		
				action.AddDamage( theGame.params.DAMAGE_NAME_SHOCK, parent.dischargePercent * damageData.processedDmg.vitalityDamage );
				action.SetCanPlayHitParticle(true);
				action.SetHitEffect('hit_electric_quen');
				action.SetHitEffect('hit_electric_quen', true);
				action.SetHitEffect('hit_electric_quen', false, true);
				action.SetHitEffect('hit_electric_quen', true, true);
				
				theGame.damageMgr.ProcessAction( action );		
				delete action;
				
				casterActor.PlayEffect('quen_force_discharge');
			}			
		}
		
		//if quen blocked all damage (at this point damageData's damage is modified by quen, so DealsAnyDamage() checks if there is some damage AFTER quen processing
		/*	Dazedy
			always let % of damage through 
		if(reducedDamage > 0 && (!damageData.DealsAnyDamage() || (isBleeding && reducedDamage >= directDamage)) )
			parent.SetBlockedAllDamage(true);
		else
			parent.SetBlockedAllDamage(false);
		*/
		parent.SetBlockedAllDamage(false);
		
		//break shield if all shield's health is used up
		if( parent.shieldHealth <= 0 )
		{
			if ( parent.owner.CanUseSkill(S_Magic_s13) )
			{				
				casterActor.PlayEffect( 'lasting_shield_impulse' );
				parent.Impulse();
			}
			
			damageData.SetEndsQuen(true);
		}
	}
}

//basic, passive version - when sign is being cast
state QuenShield in W3QuenEntity extends NormalCast
{
	event OnEnterState( prevStateName : name )
	{
		super.OnEnterState( prevStateName );
		
		caster.OnDelayOrientationChange();
		
		caster.GetActor().OnSignCastPerformed(ST_Quen, false);
	}
	
	event OnThrowing()
	{
		if( super.OnThrowing() )
		{
			parent.CleanUp();	//don't mistake with CleanMeUp. OnEnd is called not when you finish the cast but when the shield finishes
			parent.GotoState( 'ShieldActive' );
		}
	}
	
	event OnSignAborted( optional force : bool )
	{
		parent.StopEffect( parent.effects[parent.fireMode].castEffect );
		parent.GotoState( 'Expired' );
	}
}

state QuenChanneled in W3QuenEntity extends Channeling
{
	private const var HEALING_FACTOR : float;		//multiplied by damage reduced gives healed amount
	
		default HEALING_FACTOR = 1.0f;

	event OnEnterState( prevStateName : name )
	{
		var casterActor : CActor;
		var witcher : W3PlayerWitcher;
		
		super.OnEnterState( prevStateName );
	
		casterActor = caster.GetActor();
		witcher = (W3PlayerWitcher)casterActor;
		
		if(witcher)
			witcher.SetUsedQuenInCombat();
							
		caster.OnDelayOrientationChange();
		
		parent.GetSignStats();
		
		//increase capsule
		casterActor.GetMovingAgentComponent().SetVirtualRadius( 'QuenBubble' );
			
		parent.AddBuffImmunities(false);	
		
		//abort current DOT if any
		witcher.CriticalEffectAnimationInterrupted("quen channeled");
		
		casterActor.OnSignCastPerformed(ST_Quen, true);
	}
	
	event OnThrowing()
	{
		if( super.OnThrowing() )
		{
			ChannelQuen();
		}
	}
	
	private var HAXXOR_LeavingState : bool;
	event OnLeaveState( nextStateName : name )
	{
		HAXXOR_LeavingState = true;
		OnEnded(true);
		super.OnLeaveState(nextStateName);
	}
	
	//WHY THE FUCK IS THIS CALLED WHEN YOU CAST THE SIGN!?!?!
	//set isEnd if the spell acutally ends
	// - note: is probably in case you have quen already active
	event OnEnded(optional isEnd : bool)
	{
		var casterActor : CActor;
		
		if(!HAXXOR_LeavingState)
			super.OnEnded();
			
		casterActor = caster.GetActor();
		casterActor.GetMovingAgentComponent().ResetVirtualRadius();
		casterActor.StopEffect('quen_shield');
		
		parent.RemoveBuffImmunities(false);		
		
		parent.StopAllEffects();
		
		parent.RemoveHitDoTEntities();
		/*  Dazedy
			Only explode when shield is broken, not released.
		if(isEnd && caster.CanUseSkill(S_Magic_s13))
			parent.Impulse();
		*/
	}
	
	event OnSignAborted( optional force : bool )
	{
		OnEnded();
	}
	
	entry function ChannelQuen()
	{
		while( Update() )
		{
			ProcessQuenCollisionForRiders();
			SleepOneFrame();
		}
	}
	
	private function ProcessQuenCollisionForRiders()
	{
		var mac	: CMovingPhysicalAgentComponent;
		var collisionData : SCollisionData;
		var collisionNum : int;
		var i : int;
		var npc	: CNewNPC;
		var riderActor : CActor;
		var collidedWithRider : bool;
		var horseComp : W3HorseComponent;
		var riderToPlayerHeading, riderHeading : float;
		var angleDist : float;
		
		mac	= (CMovingPhysicalAgentComponent)thePlayer.GetMovingAgentComponent();
		if( !mac )
		{
			return;
		}
		
		collisionNum = mac.GetCollisionCharacterDataCount();
		for( i = 0; i < collisionNum; i += 1 )
		{
			collisionData = mac.GetCollisionCharacterData( i );
			npc	= (CNewNPC)collisionData.entity;
			if( npc )
			{
				if( npc.IsUsingHorse() )
				{
					collidedWithRider = true;
					horseComp = npc.GetUsedHorseComponent();
				}
				else
				{
					horseComp = npc.GetHorseComponent();
					if( horseComp.user )
						collidedWithRider = true;
				}
			}
			
			if( collidedWithRider )
			{
				riderActor = horseComp.user;
				
				if( IsRequiredAttitudeBetween( riderActor, thePlayer, true ) )
				{
					riderToPlayerHeading = VecHeading( thePlayer.GetWorldPosition() - riderActor.GetWorldPosition() );
					riderHeading = riderActor.GetHeading();
					angleDist = AngleDistance( riderToPlayerHeading, riderHeading );
					
					if( AbsF( angleDist ) < 45.0 )
					{
						horseComp.ReactToQuen();
					}
				}
			}
		}
	}
	
	public function ShowHitFX(damageData : W3DamageAction, rot : EulerAngles)
	{
		var movingAgent : CMovingPhysicalAgentComponent;
		var inWater, hasFireDamage, hasElectricDamage, hasPoisonDamage, isDoT, isBirds : bool;
		
		isBirds = (CFlyingCrittersLairEntityScript)damageData.causer;
		
		if (isBirds)
		{
			//start const effect
			parent.PlayHitEffect('quen_rebound_sphere_constant', rot, true);
			parent.AddTimer('RemoveDoTFX', 0.3, false, , , , true);
		}
		else
		{			
			isDoT = damageData.IsDoTDamage();
		
			if(!isDoT)
			{
				hasFireDamage = damageData.GetDamageValue(theGame.params.DAMAGE_NAME_FIRE) > 0;
				hasPoisonDamage = damageData.GetDamageValue(theGame.params.DAMAGE_NAME_POISON) > 0;		
				hasElectricDamage = damageData.GetDamageValue(theGame.params.DAMAGE_NAME_SHOCK) > 0;
		
				if (hasFireDamage)
					parent.PlayHitEffect( 'quen_rebound_sphere_fire', rot );
				else if (hasPoisonDamage)
					parent.PlayHitEffect( 'quen_rebound_sphere_poison', rot );
				else if (hasElectricDamage)
					parent.PlayHitEffect( 'quen_rebound_sphere_electricity', rot );
				else
					parent.PlayHitEffect( 'quen_rebound_sphere', rot );
			}
		}
		
		//ground fx when not in water
		movingAgent = (CMovingPhysicalAgentComponent)caster.GetActor().GetMovingAgentComponent();
		inWater = movingAgent.GetSubmergeDepth() < 0;
		if(!inWater)
		{
			parent.PlayHitEffect( 'quen_rebound_ground', rot );
		}
	}
		
	event OnTargetHit( out damageData : W3DamageAction )
	{
		var reducedDamage, skillBonus, drainedStamina, reducibleDamage, directDamage, shieldFactor : float;		
		var spellPower : SAbilityAttributeValue;
		var drainAllStamina, isBleeding : bool;
		var casterActor : CActor;
		var attackerVictimEuler : EulerAngles;
		var action : W3DamageAction;		
		var shieldHP : float;
		

		parent.OnTargetHit(damageData);
		parent.SetBlockedAllDamage(true); //Dazedy
		
		casterActor = caster.GetActor();
		directDamage = damageData.GetDamageValue(theGame.params.DAMAGE_NAME_DIRECT);
		
		//show hit fx
		//get rotation towards where the hit came from
		if( !( (CBaseGameplayEffect) damageData.causer ) )
		{
			attackerVictimEuler = VecToRotation(damageData.attacker.GetWorldPosition() - casterActor.GetWorldPosition());
			attackerVictimEuler.Pitch = 0;
			attackerVictimEuler.Roll = 0;
			
			ShowHitFX(damageData, attackerVictimEuler);
		}
	
		//reaction to strong hit
		if( damageData.processedDmg.vitalityDamage >= 20 )
			casterActor.RaiseForceEvent( 'StrongHitTest' );
		
		//spell power
		spellPower = casterActor.GetTotalSignSpellPower(virtual_parent.GetSkill());
		
		if ( caster.CanUseSkill( S_Magic_s15 ) )
			skillBonus = CalculateAttributeValue( caster.GetSkillAttributeValue( S_Magic_s15, 'bonus', false, true ) );
		else
			skillBonus = 0;
		
		//direct damage cannot be reduced
		if( (W3Effect_Bleeding)damageData.causer )
		{
			isBleeding = true;
			reducibleDamage = directDamage;
		}
		else
		{
			isBleeding = false;
			reducibleDamage = MaxF(0, damageData.processedDmg.vitalityDamage - directDamage);
		}
		
		shieldFactor = CalculateAttributeValue( caster.GetSkillAttributeValue( S_Magic_s04, 'shield_health_factor', false, true ) );
		//reduced damage is capped by stamina
		if(reducibleDamage > 0)
		{
			shieldHP = casterActor.GetStat( BCS_Stamina ) * shieldFactor * (skillBonus + spellPower.valueMultiplicative);
			reducedDamage = MinF( reducibleDamage, casterActor.GetStat( BCS_Stamina ) * shieldFactor * (skillBonus + spellPower.valueMultiplicative) );
			if(reducedDamage < reducibleDamage)
				drainAllStamina = true;
		}
		else
		{
			reducedDamage = 0;
		}

		//reduce damage
		if ( reducedDamage > 0 || (!damageData.DealsAnyDamage() || (isBleeding && reducedDamage >= reducibleDamage)) )
		{
			if ( theGame.CanLog() )
			{		
				LogDMHits("Quen QuenChanneled.OnTargetHit: reducing damage from " + damageData.processedDmg.vitalityDamage + " to " + (damageData.processedDmg.vitalityDamage - reducedDamage), damageData );
			}
			
			if(!damageData.IsDoTDamage())
				GCameraShake( parent.effects[parent.fireMode].cameraShakeStranth, true, parent.GetWorldPosition(), 30.0f );
			
			damageData.SetHitAnimationPlayType( EAHA_ForceNo );			
			damageData.processedDmg.vitalityDamage = 0;
			damageData.SetCanPlayHitParticle(false);
						
			//discharge effect's damage
			// no discharge effect because discharge should only happen when YOU take damage.
		}		
		parent.SetBlockedAllDamage( true );//!damageData.DealsAnyDamage() );
		
		//drain stamina
		if(!drainAllStamina)
		{
			drainedStamina = reducedDamage / ((skillBonus + spellPower.valueMultiplicative) * shieldFactor);		
			casterActor.DrainStamina( ESAT_FixedValue, drainedStamina, 1 );
		}
		else
		{
			casterActor.DrainStamina( ESAT_FixedValue, casterActor.GetStat(BCS_Stamina), 2 );
		}
		
		//heal
		//Dazedy start
		spellPower = casterActor.GetTotalSignSpellPower(S_Magic_4);
		caster.GetActor().Heal(MinF(reducedDamage * .25, (casterActor.GetStatMax(BCS_Vitality) * ((skillBonus+spellPower.valueMultiplicative-1)/20))));
		// Dazedy end
		
		//check quen finish
		if( casterActor.GetStat( BCS_Stamina ) <= 0 )
		{
			if ( caster.CanUseSkill(S_Magic_s13) )
			{
				parent.PlayHitEffect( 'quen_rebound_sphere_impulse', attackerVictimEuler );
				parent.Impulse();
			}
			
			damageData.SetEndsQuen(true);			
		}
	}
}
