/obj/item/clothing/mask/whistle/minigame
	name = "referee whistle"
	desc = "A referee whistle used to call fouls against players."
	actions_types = list(/datum/action/innate/timeout)
	action_slots = ALL

// should be /datum/action/item_action but it doesn't support InterceptClickOn()
/datum/action/innate/timeout
	name = "Call foul"
	desc = "Puts a person in a timeout for a few seconds."
	button_icon = 'icons/obj/clothing/masks.dmi'
	button_icon_state = "whistle"
	click_action = TRUE
	enable_text = span_cult("You prepare to call a foul on someone...")
	disable_text = span_cult("You decide it was a bad call...")
	COOLDOWN_DECLARE(whistle_cooldown_minigame)

/datum/action/innate/timeout/InterceptClickOn(mob/living/user, params, atom/clicked_on)
	var/turf/caller_turf = get_turf(user)
	if(!isturf(caller_turf))
		return FALSE

	if(!ishuman(clicked_on) || get_dist(user, clicked_on) > 7)
		return FALSE

	if(clicked_on == user) // can't call a foul on yourself
		return FALSE

	if(!COOLDOWN_FINISHED(src, whistle_cooldown_minigame))
		user.balloon_alert(user, "cant cast for [COOLDOWN_TIMELEFT(src, whistle_cooldown_minigame) *0.1] seconds!")
		unset_ranged_ability(user)
		return FALSE

	return ..()

/datum/action/innate/timeout/do_ability(mob/living/user, mob/living/carbon/human/target)
	user.say("FOUL BY [target]!", forced = "whistle")
	playsound(user, 'sound/misc/whistle.ogg', 30, FALSE, 4, ignore_walls = FALSE)

	new /obj/effect/timestop(get_turf(target), 0, 5 SECONDS, list(user), TRUE, TRUE)

	COOLDOWN_START(src, whistle_cooldown_minigame, 1 MINUTES)
	unset_ranged_ability(user)

	to_chat(target, span_bold("[user] has given you a timeout for a foul!"))
	to_chat(user, span_bold("You put [target] in a timeout!"))
	return TRUE
