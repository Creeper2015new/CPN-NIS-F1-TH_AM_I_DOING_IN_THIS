/datum/action/changeling/absorb_dna
	name = "Поглотить ДНК"
	desc = "Поглощает ДНК нашей жертвы. Необходимо её душить при этом."
	button_icon_state = "absorb_dna"
	chemical_cost = 0
	dna_cost = CHANGELING_POWER_INNATE
	req_human = TRUE
	///if we're currently absorbing, used for sanity
	var/is_absorbing = FALSE

/datum/action/changeling/absorb_dna/can_sting(mob/living/carbon/owner)
	if(!..())
		return

	if(is_absorbing)
		owner.balloon_alert(owner, "уже поглощаю!")
		return

	if(!owner.pulling || !iscarbon(owner.pulling))
		owner.balloon_alert(owner, "нужно держать существо для поглощения!")
		return
	if(owner.grab_state <= GRAB_NECK)
		owner.balloon_alert(owner, "нужно держать сильнее!")
		return

	var/mob/living/carbon/target = owner.pulling
	var/datum/antagonist/changeling/changeling = owner.mind.has_antag_datum(/datum/antagonist/changeling)
	return changeling.can_absorb_dna(target)

/datum/action/changeling/absorb_dna/sting_action(mob/owner)
	SHOULD_CALL_PARENT(FALSE) // the only reason to call parent is for proper blackbox logging, and we do that ourselves in a snowflake way

	var/datum/antagonist/changeling/changeling = owner.mind.has_antag_datum(/datum/antagonist/changeling)
	var/mob/living/carbon/human/target = owner.pulling
	is_absorbing = TRUE

	if(!attempt_absorb(target))
		return

	SSblackbox.record_feedback("nested tally", "changeling_powers", 1, list("Absorb DNA", "4"))
	owner.visible_message(span_danger("<b>[owner]</b> высасывает жидкости из <b>[target]</b>!") , span_notice("Поглощаем <b>[target]</b>."))
	to_chat(target, span_userdanger("Похоже, меня сожрал генокрад!"))

	if(!changeling.has_profile_with_dna(target.dna))
		changeling.add_new_profile(target)
		changeling.true_absorbs++

	if(owner.nutrition < NUTRITION_LEVEL_WELL_FED)
		owner.set_nutrition(min((owner.nutrition + target.nutrition), NUTRITION_LEVEL_WELL_FED))

	// Absorb a lizard, speak Draconic.
	owner.copy_languages(target, LANGUAGE_ABSORB)

	if(target.mind && owner.mind)//if the victim and owner have minds
		absorb_memories(target)

	is_absorbing = FALSE

	changeling.adjust_chemicals(10)
	changeling.can_respec = TRUE

	if(target.stat != DEAD)
		target.investigate_log("has died from being changeling absorbed.", INVESTIGATE_DEATHS)
	target.death(FALSE)
	target.Drain()
	return TRUE

/datum/action/changeling/absorb_dna/proc/absorb_memories(mob/living/carbon/human/target)
	var/datum/mind/suckedbrain = target.mind

	var/datum/antagonist/changeling/changeling = owner.mind.has_antag_datum(/datum/antagonist/changeling)

	for(var/memory_type in suckedbrain.memories)
		var/datum/memory/stolen_memory = suckedbrain.memories[memory_type]
		changeling.stolen_memories[stolen_memory.name] = stolen_memory.generate_story(STORY_CHANGELING_ABSORB, STORY_FLAG_NO_STYLE)
	suckedbrain.wipe_memory()

	for(var/datum/antagonist/antagonist_datum as anything in suckedbrain.antag_datums)
		var/list/all_objectives = antagonist_datum.objectives.Copy()
		if(antagonist_datum.antag_memory)
			changeling.antag_memory += "[target]'s antagonist memories: [antagonist_datum.antag_memory]."
		if(!LAZYLEN(all_objectives))
			continue
		changeling.antag_memory += " Цели:"
		var/obj_count = 1
		for(var/datum/objective/objective as anything in all_objectives)
			if(!objective) //nulls? in my objective list? it's more likely than you think.
				continue
			changeling.antag_memory += " Цель #[obj_count++]: [objective.explanation_text]."
			var/list/datum/mind/other_owners = objective.get_owners() - suckedbrain
			if(!other_owners.len)
				continue
			for(var/datum/mind/conspirator as anything in other_owners)
				changeling.antag_memory += " Сообщник: [conspirator.name]."
	changeling.antag_memory += "<b>Это всё, что [target] знает.</b><BR>"

	//Some of target's recent speech, so the changeling can attempt to imitate them better.
	//Recent as opposed to all because rounds tend to have a LOT of text.

	var/list/recent_speech = target.copy_recent_speech()

	if(recent_speech.len)
		changeling.antag_memory += "<B>Некоторые фразы сказанные [target] можно использовать их в наших целях!</B><br>"
		to_chat(owner, span_boldnotice("Некоторые фразы сказанные [target] можно использовать их в наших целях!"))
		for(var/spoken_memory in recent_speech)
			changeling.antag_memory += "\"[recent_speech[spoken_memory]]\"<br>"
			to_chat(owner, span_notice("\"[recent_speech[spoken_memory]]\""))
		changeling.antag_memory += "<B>У нас больше нет знаний о речевых шаблонах [target].</B><br>"
		to_chat(owner, span_boldnotice("У нас больше нет знаний о речевых шаблонах [target]."))


	var/datum/antagonist/changeling/target_ling = target.mind.has_antag_datum(/datum/antagonist/changeling)
	if(target_ling)//If the target was a changeling, suck out their extra juice and objective points!
		to_chat(owner, span_boldnotice("[target] один из нас. Мы поглотили его силы также."))

		// Gain half of their genetic points.
		var/genetic_points_to_add = round(target_ling.total_genetic_points / 2)
		changeling.genetic_points += genetic_points_to_add
		changeling.total_genetic_points += genetic_points_to_add

		// And half of their chemical charges.
		var/chems_to_add = round(target_ling.total_chem_storage / 2)
		changeling.adjust_chemicals(chems_to_add)
		changeling.total_chem_storage += chems_to_add

		// And of course however many they've absorbed, we've absorbed
		changeling.absorbed_count += target_ling.absorbed_count

		// Lastly, make them not a ling anymore. (But leave their objectives for round-end purposes).
		var/list/copied_objectives = target_ling.objectives.Copy()
		target.mind.remove_antag_datum(/datum/antagonist/changeling)
		var/datum/antagonist/fallen_changeling/fallen = target.mind.add_antag_datum(/datum/antagonist/fallen_changeling)
		fallen.objectives = copied_objectives

/datum/action/changeling/absorb_dna/proc/attempt_absorb(mob/living/carbon/human/target)
	for(var/absorbing_iteration in 1 to 3)
		switch(absorbing_iteration)
			if(1)
				to_chat(owner, span_notice("Это существо подходит. Нужно постараться не двигаться..."))
			if(2)
				owner.visible_message(span_warning("<b>[owner]</b> выпускает хоботок!") , span_notice("Выпускаем хоботок."))
			if(3)
				owner.visible_message(span_danger("<b>[owner]</b> протыкает <b>[target]</b> своим хоботком!") , span_notice("Протыкаем <b>[target]</b> своим хоботком."))
				to_chat(target, span_userdanger("Что-то острое проникает в меня!"))
				target.take_overall_damage(40)

		SSblackbox.record_feedback("nested tally", "changeling_powers", 1, list("Absorb DNA", "[absorbing_iteration]"))
		if(!do_after(owner, 15 SECONDS, target))
			owner.balloon_alert(owner, "меня прервали!")
			is_absorbing = FALSE
			return FALSE
	return TRUE
