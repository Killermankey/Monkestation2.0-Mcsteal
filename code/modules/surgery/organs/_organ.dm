
/obj/item/organ
	name = "organ"
	icon = 'icons/obj/medical/organs/organs.dmi'
	w_class = WEIGHT_CLASS_SMALL
	throwforce = 0
	/// The mob that owns this organ.
	var/mob/living/carbon/owner = null
	/// The body zone this organ is supposed to inhabit.
	var/zone = BODY_ZONE_CHEST
	/**
	 * The organ slot this organ is supposed to inhabit. This should be unique by type. (Lungs, Appendix, Stomach, etc)
	 * Do NOT add slots with matching names to different zones - it will break the organs_slot list!
	*/
	var/slot
	/// Random flags that describe this organ
	var/organ_flags = ORGAN_ORGANIC | ORGAN_EDIBLE
	/// Maximum damage the organ can take, ever.
	var/maxHealth = STANDARD_ORGAN_THRESHOLD
	/**
	 * Total damage this organ has sustained.
	 * Should only ever be modified by apply_organ_damage!
	*/
	var/damage = 0
	/// Healing factor and decay factor function on % of maxhealth, and do not work by applying a static number per tick
	var/healing_factor = 0 //fraction of maxhealth healed per on_life(), set to 0 for generic organs
	var/decay_factor = 0 //same as above but when without a living owner, set to 0 for generic organs
	var/high_threshold = STANDARD_ORGAN_THRESHOLD * 0.45 //when severe organ damage occurs
	var/low_threshold = STANDARD_ORGAN_THRESHOLD * 0.1 //when minor organ damage occurs
	var/severe_cooldown //cooldown for severe effects, used for synthetic organ emp effects.

	///Organ variables for determining what we alert the owner with when they pass/clear the damage thresholds
	var/prev_damage = 0
	var/low_threshold_passed
	var/high_threshold_passed
	var/now_failing
	var/now_fixed
	var/high_threshold_cleared
	var/low_threshold_cleared

	/// When set to false, this can't be used in surgeries and such - Honestly a terrible variable.
	var/useable = TRUE
	/// Food reagents if the organ is edible
	var/list/food_reagents = list(/datum/reagent/consumable/nutriment = 5)
	/// The size of the reagent container if the organ is edible
	var/reagent_vol = 10

	/// Time this organ has failed for
	var/failure_time = 0
	/// Do we affect the appearance of our mob. Used to save time in preference code
	var/visual = TRUE
	///If the organ is cosmetic only, it loses all organ functionality.
	var/cosmetic_only = FALSE
	/**
	 * Traits that are given to the holder of the organ.
	 * If you want an effect that changes this, don't add directly to this. Use the add_organ_trait() proc.
	 */
	var/list/organ_traits = list()
	/// Status Effects that are given to the holder of the organ.
	var/list/organ_effects
	///Sometimes we need multiple layers, for like the back, middle and front of the person
	var/list/layers
	///Defines what kind of 'organ' we're looking at. Sprites have names like 'm_mothwings_firemoth'. 'mothwings' would then be feature_key
	var/feature_key = ""
	///Similar to feature key, but overrides it in the case you need more fine control over the iconstate, like with Tails.
	var/render_key = ""
	///Stores the dna.features[feature_key], used for external organs that can be surgically removed or inserted.
	var/stored_feature_id = ""
	/// The savefile_key of the preference this relates to. Used for the preferences UI.
	var/preference
	///Sprite datum we use to draw on the bodypart
	var/datum/sprite_accessory/sprite_datum
	///With what DNA block do we mutate in mutate_feature() ? For genetics
	var/dna_block
	///Does this organ have any bodytypes to pass to it's ownerlimb?
	var/external_bodytypes = NONE
	/// String displayed when the organ has decayed.
	var/failing_desc = "has decayed for too long, and has turned a sickly color. It probably won't work without repairs."

// Players can look at prefs before atoms SS init, and without this
// they would not be able to see external organs, such as moth wings.
// This is also necessary because assets SS is before atoms, and so
// any nonhumans created in that time would experience the same effect.
INITIALIZE_IMMEDIATE(/obj/item/organ)

/obj/item/organ/Initialize(mapload, mob_sprite)
	. = ..()
	if(organ_flags & ORGAN_EDIBLE)
		AddComponent(/datum/component/edible,\
			initial_reagents = food_reagents,\
			foodtypes = RAW | MEAT | GORE,\
			volume = reagent_vol,\
			after_eat = CALLBACK(src, PROC_REF(OnEatFrom)))

	if(cosmetic_only) //Cosmetic organs don't process.
		if(mob_sprite)
			set_sprite(mob_sprite)

/obj/item/organ/proc/set_sprite(sprite_name)
	stored_feature_id = sprite_name
	sprite_datum = get_global_feature_list()[sprite_name]
	if(!sprite_datum && stored_feature_id)
		stack_trace("External organ has no valid sprite datum for name [sprite_name]")

///Return a dumb glob list for this specific feature (called from parse_sprite)
/obj/item/organ/proc/get_global_feature_list()
	CRASH("External organ has no feature list, it will render invisible")

/*
 * Insert the organ into the select mob.
 *
 * receiver - the mob who will get our organ
 * special - "quick swapping" an organ out - when TRUE, the mob will be unaffected by not having that organ for the moment
 * drop_if_replaced - if there's an organ in the slot already, whether we drop it afterwards
 */
/obj/item/organ/proc/Insert(mob/living/carbon/receiver, special = FALSE, drop_if_replaced = TRUE)
	SHOULD_CALL_PARENT(TRUE)

	if(!iscarbon(receiver) || owner == receiver)
		return FALSE

	var/obj/item/organ/replaced = receiver.get_organ_slot(slot)
	if(replaced)
		replaced.Remove(receiver, special = TRUE)
		if(drop_if_replaced)
			replaced.forceMove(get_turf(receiver))
		else
			qdel(replaced)

	receiver.organs |= src
	receiver.organs_slot[slot] = src
	owner = receiver

	// Apply unique side-effects. Return value does not matter.
	on_insert(receiver, special)

	return TRUE

/// Called after the organ is inserted into a mob.
/// Adds Traits, Actions, and Status Effects on the mob in which the organ is impanted.
/// Override this proc to create unique side-effects for inserting your organ. Must be called by overrides.
/obj/item/organ/proc/on_insert(mob/living/carbon/organ_owner, special)
	SHOULD_CALL_PARENT(TRUE)

	moveToNullspace()

	for(var/trait in organ_traits)
		ADD_TRAIT(organ_owner, trait, REF(src))

	for(var/datum/action/action as anything in actions)
		action.Grant(organ_owner)

	for(var/datum/status_effect/effect as anything in organ_effects)
		organ_owner.apply_status_effect(effect, type)

	RegisterSignal(owner, COMSIG_ATOM_EXAMINE, PROC_REF(on_owner_examine))
	SEND_SIGNAL(src, COMSIG_ORGAN_IMPLANTED, organ_owner)
	SEND_SIGNAL(organ_owner, COMSIG_CARBON_GAIN_ORGAN, src, special)

/*
 * Remove the organ from the select mob.
 *
 * * organ_owner - the mob who owns our organ, that we're removing the organ from.
 * * special - "quick swapping" an organ out - when TRUE, the mob will be unaffected by not having that organ for the moment
 */
/obj/item/organ/proc/Remove(mob/living/carbon/organ_owner, special = FALSE)
	SHOULD_CALL_PARENT(TRUE)

	organ_owner.organs -= src
	if(organ_owner.organs_slot[slot] == src)
		organ_owner.organs_slot.Remove(slot)

	owner = null

	// Apply or reset unique side-effects. Return value does not matter.
	on_remove(organ_owner, special)

	return TRUE

/// Called after the organ is removed from a mob.
/// Removes Traits, Actions, and Status Effects on the mob in which the organ was impanted.
/// Override this proc to create unique side-effects for removing your organ. Must be called by overrides.
/obj/item/organ/proc/on_remove(mob/living/carbon/organ_owner, special)
	SHOULD_CALL_PARENT(TRUE)

	for(var/trait in organ_traits)
		REMOVE_TRAIT(organ_owner, trait, REF(src))

	for(var/datum/action/action as anything in actions)
		action.Remove(organ_owner)

	for(var/datum/status_effect/effect as anything in organ_effects)
		organ_owner.remove_status_effect(effect, type)

	UnregisterSignal(organ_owner, COMSIG_ATOM_EXAMINE)
	SEND_SIGNAL(src, COMSIG_ORGAN_REMOVED, organ_owner)
	SEND_SIGNAL(organ_owner, COMSIG_CARBON_LOSE_ORGAN, src, special)

/// Add a Trait to an organ that it will give its owner.
/obj/item/organ/proc/add_organ_trait(trait)
	LAZYADD(organ_traits, trait)
	if(isnull(owner))
		return
	ADD_TRAIT(owner, trait, REF(src))

/// Removes a Trait from an organ, and by extension, its owner.
/obj/item/organ/proc/remove_organ_trait(trait)
	LAZYREMOVE(organ_traits, trait)
	if(isnull(owner))
		return
	REMOVE_TRAIT(owner, trait, REF(src))

/// Add a Status Effect to an organ that it will give its owner.
/obj/item/organ/proc/add_organ_status(status)
	LAZYADD(organ_effects, status)
	if(isnull(owner))
		return
	owner.apply_status_effect(status, type)

/// Removes a Status Effect from an organ, and by extension, its owner.
/obj/item/organ/proc/remove_organ_status(status)
	LAZYREMOVE(organ_effects, status)
	if(isnull(owner))
		return
	owner.remove_status_effect(status, type)

/obj/item/organ/proc/on_owner_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	return

/obj/item/organ/proc/on_find(mob/living/finder)
	return

/obj/item/organ/process(seconds_per_tick, times_fired)
	return

/obj/item/organ/proc/on_death(seconds_per_tick, times_fired)
	return

/obj/item/organ/proc/on_life(seconds_per_tick, times_fired)
	CRASH("Oh god oh fuck something is calling parent organ life")

/obj/item/organ/examine(mob/user)
	. = ..()

	. += span_notice("It should be inserted in the [parse_zone(zone)].")

	if(organ_flags & ORGAN_FAILING)
		if(IS_ROBOTIC_ORGAN(src))
			. += span_warning("[src] seems to be broken.")
			return
		. += span_warning("[src] has decayed for too long, and has turned a sickly color. It probably won't work without repairs.")
		return

	if(damage > high_threshold)
		. += span_warning("[src] is starting to look discolored.")

///Used as callbacks by object pooling
/obj/item/organ/proc/exit_wardrobe()
	return

//See above
/obj/item/organ/proc/enter_wardrobe()
	return

/obj/item/organ/proc/OnEatFrom(eater, feeder)
	useable = FALSE //You can't use it anymore after eating it you spaztic

/obj/item/organ/item_action_slot_check(slot,mob/user)
	return //so we don't grant the organ's action to mobs who pick up the organ.

///Adjusts an organ's damage by the amount "damage_amount", up to a maximum amount, which is by default max damage
/obj/item/organ/proc/apply_organ_damage(damage_amount, maximum = maxHealth, required_organ_flag = NONE) //use for damaging effects
	if(!damage_amount) //Micro-optimization.
		return
	maximum = clamp(maximum, 0, maxHealth) // the logical max is, our max
	if(maximum < damage)
		return
	if(required_organ_flag && !(organ_flags & required_organ_flag))
		return
	damage = clamp(damage + damage_amount, 0, maximum)
	var/mess = check_damage_thresholds(owner)
	prev_damage = damage

	if(damage >= maxHealth)
		organ_flags |= ORGAN_FAILING
	else
		organ_flags &= ~ORGAN_FAILING

	if(mess && owner && owner.stat <= SOFT_CRIT)
		to_chat(owner, mess)

///SETS an organ's damage to the amount "damage_amount", and in doing so clears or sets the failing flag, good for when you have an effect that should fix an organ if broken
/obj/item/organ/proc/set_organ_damage(damage_amount, required_organ_flag = NONE) //use mostly for admin heals
	return apply_organ_damage(damage_amount - damage, required_organ_flag = required_organ_flag)

/** check_damage_thresholds
 * input: mob/organ_owner (a mob, the owner of the organ we call the proc on)
 * output: returns a message should get displayed.
 * description: By checking our current damage against our previous damage, we can decide whether we've passed an organ threshold.
 *  If we have, send the corresponding threshold message to the owner, if such a message exists.
 */
/obj/item/organ/proc/check_damage_thresholds(mob/organ_owner)
	if(damage == prev_damage)
		return
	var/delta = damage - prev_damage
	if(delta > 0)
		if(damage >= maxHealth)
			return now_failing
		if(damage > high_threshold && prev_damage <= high_threshold)
			return high_threshold_passed
		if(damage > low_threshold && prev_damage <= low_threshold)
			return low_threshold_passed
	else
		if(prev_damage > low_threshold && damage <= low_threshold)
			return low_threshold_cleared
		if(prev_damage > high_threshold && damage <= high_threshold)
			return high_threshold_cleared
		if(prev_damage == maxHealth)
			return now_fixed

//Looking for brains?
//Try code/modules/mob/living/carbon/brain/brain_item.dm

/**
 * Heals all of the mob's organs, and re-adds any missing ones.
 *
 * * regenerate_existing - if TRUE, existing organs will be deleted and replaced with new ones
 */
/mob/living/carbon/proc/regenerate_organs(regenerate_existing = FALSE)

	// Delegate to species if possible.
	if(dna?.species)
		dna.species.regenerate_organs(src, replace_current = regenerate_existing)

		// Species regenerate organs doesn't ALWAYS handle healing the organs because it's dumb
		for(var/obj/item/organ/organ as anything in organs)
			organ.set_organ_damage(0)
		set_heartattack(FALSE)

		// Ears have aditional vаr "deaf", need to update it too
		var/obj/item/organ/internal/ears/ears = get_organ_slot(ORGAN_SLOT_EARS)
		ears?.adjustEarDamage(0, -INFINITY) // full heal ears deafness

		return

	// Default organ fixing handling
	// May result in kinda cursed stuff for mobs which don't need these organs
	var/obj/item/organ/internal/lungs/lungs = get_organ_slot(ORGAN_SLOT_LUNGS)
	if(!lungs)
		lungs = new()
		lungs.Insert(src)
	lungs.set_organ_damage(0)

	var/obj/item/organ/internal/heart/heart = get_organ_slot(ORGAN_SLOT_HEART)
	if(heart)
		set_heartattack(FALSE)
	else
		heart = new()
		heart.Insert(src)
	heart.set_organ_damage(0)

	var/obj/item/organ/internal/tongue/tongue = get_organ_slot(ORGAN_SLOT_TONGUE)
	if(!tongue)
		tongue = new()
		tongue.Insert(src)
	tongue.set_organ_damage(0)

	var/obj/item/organ/internal/eyes/eyes = get_organ_slot(ORGAN_SLOT_EYES)
	if(!eyes)
		eyes = new()
		eyes.Insert(src)
	eyes.set_organ_damage(0)

	var/obj/item/organ/internal/ears/ears = get_organ_slot(ORGAN_SLOT_EARS)
	if(!ears)
		ears = new()
		ears.Insert(src)
	ears.adjustEarDamage(-INFINITY, -INFINITY) // actually do: set_organ_damage(0) and deaf = 0

	var/obj/item/organ/internal/butt/butt = get_organ_slot(ORGAN_SLOT_BUTT)
	if(!butt)
		butt = new()
		butt.Insert(src)
		butt.set_organ_damage(0)

	var/obj/item/organ/internal/bladder/bladder = get_organ_slot(ORGAN_SLOT_BLADDER)
	if(!bladder)
		bladder = new()
		bladder.Insert(src)
		bladder.set_organ_damage(0)

/obj/item/organ/proc/handle_failing_organs(seconds_per_tick)
	return

/** organ_failure
 * generic proc for handling dying organs
 *
 * Arguments:
 * seconds_per_tick - seconds since last tick
 */
/obj/item/organ/proc/organ_failure(seconds_per_tick)
	return

/** get_availability
 * returns whether the species should innately have this organ.
 *
 * regenerate organs works with generic organs, so we need to get whether it can accept certain organs just by what this returns.
 * This is set to return true or false, depending on if a species has a trait that would nulify the purpose of the organ.
 * For example, lungs won't be given if you have NO_BREATH, stomachs check for NO_HUNGER, and livers check for NO_METABOLISM.
 * If you want a carbon to have a trait that normally blocks an organ but still want the organ. Attach the trait to the organ using the organ_traits var
 * Arguments:
 * owner_species - species, needed to return the mutant slot as true or false. stomach set to null means it shouldn't have one.
 * owner_mob - for more specific checks, like nightmares.
 */
/obj/item/organ/proc/get_availability(datum/species/owner_species, mob/living/owner_mob)
	return TRUE

/// Called before organs are replaced in regenerate_organs with new ones
/obj/item/organ/proc/before_organ_replacement(obj/item/organ/replacement)
	SHOULD_CALL_PARENT(TRUE)

	SEND_SIGNAL(src, COMSIG_ORGAN_BEING_REPLACED, replacement)

	// If we're being replace with an identical type we should take organ damage
	if(replacement.type == type)
		replacement.set_organ_damage(damage)

/// Called by medical scanners to get a simple summary of how healthy the organ is. Returns an empty string if things are fine.
/obj/item/organ/proc/get_status_text(advanced, add_tooltips)
	if(advanced && (organ_flags & ORGAN_HAZARDOUS))
		return conditional_tooltip("<font color='#cc3333'>Harmful Foreign Body</font>", "Remove surgically.", add_tooltips)

	if(organ_flags & ORGAN_EMP)
		return conditional_tooltip("<font color='#cc3333'>EMP-Derived Failure</font>", "Repair or replace surgically.", add_tooltips)

	var/tech_text = ""
	if(owner.has_reagent(/datum/reagent/inverse/technetium))
		tech_text = "[round((damage / maxHealth) * 100, 1)]% damaged"

	if(organ_flags & ORGAN_FAILING)
		return conditional_tooltip("<font color='#cc3333'>[tech_text || "Non-Functional"]</font>", "Repair or replace surgically.", add_tooltips)

	if(damage > high_threshold)
		return conditional_tooltip("<font color='#ff9933'>[tech_text || "Severely Damaged"]</font>", "[healing_factor ? "Treat with rest or use specialty medication." : "Repair surgically or use specialty medication."]", add_tooltips && owner.stat != DEAD)

	if(damage > low_threshold)
		return conditional_tooltip("<font color='#ffcc33'>[tech_text || "Mildly Damaged"] </font>", "[healing_factor ? "Treat with rest." : "Use specialty medication."]", add_tooltips && owner.stat != DEAD)

	if(tech_text)
		return "<font color='#33cc33'>[tech_text]</font>"

	return ""

/// Determines if this organ is shown when a user has condensed scans enabled
/obj/item/organ/proc/show_on_condensed_scans()
	// We don't need to show *most* damaged organs as they have no effects associated
	return (organ_flags & (ORGAN_PROMINENT|ORGAN_HAZARDOUS|ORGAN_FAILING|ORGAN_VITAL))

/// Similar to get_status_text, but appends the text after the damage report, for additional status info
/obj/item/organ/proc/get_status_appendix(advanced, add_tooltips)
	return

/// Tries to replace the existing organ on the passed mob with this one, with special handling for replacing a brain without ghosting target
/obj/item/organ/proc/replace_into(mob/living/carbon/new_owner)
	Insert(new_owner, special = TRUE, drop_if_replaced = FALSE)
