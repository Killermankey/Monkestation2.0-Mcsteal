GLOBAL_LIST_EMPTY(mentor_datums)
GLOBAL_PROTECT(mentor_datums)

GLOBAL_VAR_INIT(mentor_href_token, GenerateToken())
GLOBAL_PROTECT(mentor_href_token)

/datum/mentors
	var/name = "someone's mentor datum"
	/// The Mentor's Client
	var/client/owner
	/// the Mentor's Ckey
	var/target
	/// href token for Mentor commands, uses the same token used by Admins.
	var/href_token
	var/mob/following
	/// Are we a Contributor?
	var/is_contributor = FALSE
	var/not_active = FALSE

/datum/mentors/New(ckey)
	if(!ckey)
		QDEL_IN(src, 0)
		CRASH("Mentor datum created without a ckey")
	target = ckey(ckey)
	name = "[ckey]'s mentor datum"
	href_token = GenerateToken()
	GLOB.mentor_datums[target] = src
	/// Set the owner var and load commands
	owner = GLOB.directory[ckey]
	if(owner)
		owner.mentor_datum = src
		owner.add_mentor_verbs()
		GLOB.mentors += owner

/datum/mentors/proc/CheckMentorHREF(href, href_list)
	var/auth = href_list["mentor_token"]
	. = auth && (auth == href_token || auth == GLOB.mentor_href_token)
	if(.)
		return
	var/msg = !auth ? "no" : "a bad"
	message_admins("[key_name_admin(usr)] clicked an href with [msg] authorization key!")
	if(CONFIG_GET(flag/debug_admin_hrefs))
		message_admins("Debug mode enabled, call not blocked. Please ask your coders to review this round's logs.")
		log_world("UAH: [href]")
		return TRUE
	log_admin_private("[key_name(usr)] clicked an href with [msg] authorization key! [href]")

/proc/RawMentorHrefToken(forceGlobal = FALSE)
	var/tok = GLOB.mentor_href_token
	if(!forceGlobal && usr)
		var/client/all_clients = usr.client
		to_chat(world, all_clients)
		to_chat(world, usr)
		if(!all_clients)
			CRASH("No client for HrefToken()!")
		var/datum/mentors/holder = all_clients.mentor_datum
		if(holder)
			tok = holder.href_token
	return tok

/proc/MentorHrefToken(forceGlobal = FALSE)
	return "mentor_token=[RawMentorHrefToken(forceGlobal)]"

/proc/load_mentors()
	var/dbfail
	if(!CONFIG_GET(flag/admin_legacy_system) && !SSdbcore.Connect())
		message_admins("Failed to connect to database while loading mentors. Loading from backup.")
		log_sql("Failed to connect to database while loading mentors. Loading from backup.")
		dbfail = 1
	GLOB.mentor_datums.Cut()
	for(var/client/mentor_clients in GLOB.mentors)
		mentor_clients.remove_mentor_verbs()
		mentor_clients.mentor_datum = null
	GLOB.mentors.Cut()
	var/list/lines = world.file2list("[global.config.directory]/mentors.txt")
	for(var/line in lines)
		if(!length(line))
			continue
		if(findtextEx(line, "#", 1, 2))
			continue
		new /datum/mentors(line)

	if(!CONFIG_GET(flag/mentor_legacy_system) || dbfail)
		var/datum/db_query/query_load_mentors = SSdbcore.NewQuery("SELECT ckey, rank FROM [format_table_name("mentor")]")
		if(!query_load_mentors.Execute())
			message_admins("Error loading mentors from database. Loading from backup.")
			log_sql("Error loading mentors from database. Loading from backup.")
			dbfail = 1
		else
			while(query_load_mentors.NextRow())
				var/mentor_ckey = ckey(query_load_mentors.item[1])
				var/skip

				if(GLOB.mentor_datums[mentor_ckey])
					skip = 1
				if(!skip)
					new /datum/mentors(mentor_ckey)
		qdel(query_load_mentors)
