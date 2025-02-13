/*
*	Trimmed and modified copy of ".../machinery/computer/crew.dm"
*	for the sake of modularity. (Blueshield Monitor Console soon?)
*/

#define SENSORS_UPDATE_PERIOD (10 SECONDS)

GLOBAL_DATUM_INIT(blueshield_crewmonitor, /datum/crewmonitor/blueshield, new)

//list of all Command/CC jobs
/datum/crewmonitor/blueshield
	var/list/jobs_command = list(
		JOB_CAPTAIN = 00,
		JOB_HEAD_OF_SECURITY = 10,
		JOB_CHIEF_MEDICAL_OFFICER = 20,
		JOB_RESEARCH_DIRECTOR = 30,
		JOB_CHIEF_ENGINEER = 40,
		JOB_HEAD_OF_PERSONNEL = 60,
		JOB_CENTCOM_ADMIRAL = 200,
		JOB_CENTCOM = 201,
		JOB_CENTCOM_OFFICIAL = 210,
		JOB_CENTCOM_COMMANDER = 211,
		JOB_CENTCOM_BARTENDER = 212,
		JOB_CENTCOM_CUSTODIAN = 213,
		JOB_CENTCOM_MEDICAL_DOCTOR = 214,
		JOB_CENTCOM_RESEARCH_OFFICER = 215,
		JOB_ERT_COMMANDER = 220,
		JOB_ERT_OFFICER = 221,
		JOB_ERT_ENGINEER = 222,
		JOB_ERT_MEDICAL_DOCTOR = 223,
		JOB_ERT_CLOWN = 224,
		JOB_ERT_CHAPLAIN = 225,
		JOB_ERT_JANITOR = 226,
		JOB_ERT_DEATHSQUAD = 227,
		JOB_NANOTRASEN_REPRESENTATIVE = 230,
		JOB_BLUESHIELD = 231,
	)

/datum/crewmonitor/blueshield/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "CrewConsoleNovaBlueshield")
		ui.open()

/*
*	Override of crewmonitor/update_data(z)
* 	- "trim_assignment" is now iterated for command-only jobs
*	- "if (id_card)" now encapsulates all the remaining checks to avoid showing unknowns
*/
/datum/crewmonitor/blueshield/update_data(z)
	if(data_by_z["[z]"] && last_update["[z]"] && world.time <= last_update["[z]"] + SENSORS_UPDATE_PERIOD)
		return data_by_z["[z]"]
	var/nt_net = GLOB.crewmonitor.get_ntnet_wireless_status(z)

	var/list/results = list()
	for(var/tracked_mob in GLOB.suit_sensors_list | GLOB.nanite_sensors_list)
		var/sensor_mode = GLOB.crewmonitor.get_tracking_level(tracked_mob, z, nt_net)
		if (sensor_mode == SENSOR_OFF)
			continue
		var/mob/living/tracked_living_mob = tracked_mob
		var/list/entry = list()

		var/obj/item/card/id/id_card = tracked_living_mob.get_idcard(hand_first = FALSE)
		if (id_card)

			entry["name"] = id_card.registered_name
			entry["assignment"] = id_card.assignment
			var/trim_assignment = id_card.get_trim_assignment()

			//Check if they are command
			if (jobs_command[trim_assignment] != null)
				entry["ijob"] = jobs_command[trim_assignment]
			else
				continue

			if (isipc(tracked_living_mob))
				entry["is_robot"] = TRUE

			if (sensor_mode >= SENSOR_LIVING)
				entry["life_status"] = (tracked_living_mob.stat != DEAD)

			if (sensor_mode >= SENSOR_VITALS)
				entry += list(
					"oxydam" = round(tracked_living_mob.getOxyLoss(), 1),
					"toxdam" = round(tracked_living_mob.getToxLoss(), 1),
					"burndam" = round(tracked_living_mob.getFireLoss(), 1),
					"brutedam" = round(tracked_living_mob.getBruteLoss(), 1),
					"health" = round(tracked_living_mob.health, 1),
				)

			if (sensor_mode >= SENSOR_COORDS)
				entry["area"] = get_area_name(tracked_living_mob, format_text = TRUE)

			entry["can_track"] = tracked_living_mob.can_track()

		else
			continue

		results[++results.len] = entry

	data_by_z["[z]"] = results
	last_update["[z]"] = world.time

	return results

#undef SENSORS_UPDATE_PERIOD
