/obj/structure/window
	name = "направленное окно"
	desc = "Окно. Невероятно."
	icon_state = "window"
	base_icon_state = "window"
	density = TRUE
	layer = ABOVE_OBJ_LAYER //Just above doors
	pressure_resistance = 4*ONE_ATMOSPHERE
	anchored = TRUE //initially is 0 for tile smoothing
	flags_1 = ON_BORDER_1
	obj_flags = CAN_BE_HIT | BLOCKS_CONSTRUCTION_DIR | IGNORE_DENSITY
	max_integrity = 50
	can_be_unanchored = TRUE
	resistance_flags = ACID_PROOF
	armor_type = /datum/armor/structure_window
	can_atmos_pass = ATMOS_PASS_PROC
	rad_insulation = RAD_VERY_LIGHT_INSULATION
	pass_flags_self = PASSGLASS
	set_dir_on_move = FALSE
	flags_ricochet = RICOCHET_HARD
	receive_ricochet_chance_mod = 0.5
	var/state = WINDOW_OUT_OF_FRAME
	var/reinf = FALSE
	var/heat_resistance = 800
	var/decon_speed = 30
	var/wtype = "glass"
	var/fulltile = FALSE
	var/glass_type = /obj/item/stack/sheet/glass
	var/glass_amount = 1
	var/mutable_appearance/crack_overlay
	var/real_explosion_block //ignore this, just use explosion_block
	var/break_sound = SFX_SHATTER
	var/knock_sound = 'sound/effects/glassknock.ogg'
	var/bash_sound = 'sound/effects/glassbash.ogg'
	var/hit_sound = 'sound/effects/glasshit.ogg'
	/// If some inconsiderate jerk has had their blood spilled on this window, thus making it cleanable
	var/bloodied = FALSE
	///Datum that the shard and debris type is pulled from for when the glass is broken.
	var/datum/material/glass_material_datum = /datum/material/glass

/datum/armor/structure_window
	melee = 50
	fire = 80
	acid = 100

/obj/structure/window/Initialize(mapload, direct)
	AddElement(/datum/element/blocks_explosives)
	. = ..()
	if(direct)
		setDir(direct)
	if(reinf && anchored)
		state = RWINDOW_SECURE

	if(!reinf && anchored)
		state = WINDOW_SCREWED_TO_FRAME

	air_update_turf(TRUE, TRUE)

	if(fulltile)
		setDir()
		obj_flags &= ~BLOCKS_CONSTRUCTION_DIR
		obj_flags &= ~IGNORE_DENSITY
		AddElement(/datum/element/can_barricade)

	//windows only block while reinforced and fulltile
	if(!reinf || !fulltile)
		set_explosion_block(0)

	flags_1 |= ALLOW_DARK_PAINTS_1
	RegisterSignal(src, COMSIG_OBJ_PAINTED, PROC_REF(on_painted))
	AddElement(/datum/element/atmos_sensitive, mapload)
	AddComponent(/datum/component/simple_rotation, ROTATION_NEEDS_ROOM, AfterRotation = CALLBACK(src, PROC_REF(AfterRotation)))

	var/static/list/loc_connections = list(
		COMSIG_ATOM_EXIT = PROC_REF(on_exit),
	)

	if (flags_1 & ON_BORDER_1)
		AddElement(/datum/element/connect_loc, loc_connections)

/obj/structure/window/examine(mob/user)
	. = ..()
	if(flags_1 & NODECONSTRUCT_1)
		return

	switch(state)
		if(WINDOW_SCREWED_TO_FRAME)
			. += span_notice("Окно <b>прикручено</b> к рамке.")
		if(WINDOW_IN_FRAME)
			. += span_notice("Окно <i>откручено</i> от рамки, но всё ещё <b>пристыковано</b> к ней.")
		if(WINDOW_OUT_OF_FRAME)
			if (anchored)
				. += span_notice("Окно вышло из рамки, но может быть <i>пристыковано</i> к ней. Оно <b>прикручено</b> к полу.")
			else
				. += span_notice("Окно <i>окручено</i> от пола, и может быть разобрано <b>раскручиванием</b>.")

/obj/structure/window/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	if(the_rcd.mode == RCD_DECONSTRUCT)
		return list("delay" = 2 SECONDS, "cost" = 5)
	return FALSE

/obj/structure/window/rcd_act(mob/user, obj/item/construction/rcd/the_rcd, list/rcd_data)
	if(rcd_data["[RCD_DESIGN_MODE]"] == RCD_DECONSTRUCT)
		to_chat(user, span_notice("Разбираю окно."))
		qdel(src)
		return TRUE
	return FALSE

/obj/structure/window/narsie_act()
	add_atom_colour(NARSIE_WINDOW_COLOUR, FIXED_COLOUR_PRIORITY)

/obj/structure/window/singularity_pull(S, current_size)
	..()
	if(anchored && current_size >= STAGE_TWO)
		set_anchored(FALSE)
	if(current_size >= STAGE_FIVE)
		deconstruct(FALSE)

/obj/structure/window/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(.)
		return

	if(fulltile)
		return FALSE

	if(border_dir == dir)
		return FALSE

	if(istype(mover, /obj/structure/window))
		var/obj/structure/window/moved_window = mover
		return valid_build_direction(loc, moved_window.dir, is_fulltile = moved_window.fulltile)

	if(istype(mover, /obj/structure/windoor_assembly) || istype(mover, /obj/machinery/door/window))
		return valid_build_direction(loc, mover.dir, is_fulltile = FALSE)

	return TRUE

/obj/structure/window/proc/on_exit(datum/source, atom/movable/leaving, direction)
	SIGNAL_HANDLER

	if(leaving.movement_type & PHASING)
		return

	if(leaving == src)
		return // Let's not block ourselves.

	if (leaving.pass_flags & pass_flags_self)
		return

	if (fulltile)
		return

	if(direction == dir && density)
		leaving.Bump(src)
		return COMPONENT_ATOM_BLOCK_EXIT

/obj/structure/window/attack_tk(mob/user)
	user.changeNext_move(CLICK_CD_MELEE)
	user.visible_message(span_notice("Что-то стучит по окну."))
	add_fingerprint(user)
	playsound(src, knock_sound, 50, TRUE)
	return COMPONENT_CANCEL_ATTACK_CHAIN


/obj/structure/window/attack_hulk(mob/living/carbon/human/user, does_attack_animation = 0)
	if(!can_be_reached(user))
		return
	. = ..()

/obj/structure/window/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(!can_be_reached(user))
		return
	user.changeNext_move(CLICK_CD_MELEE)

	if(!user.combat_mode)
		user.visible_message(span_notice("[user] стучит по окну.") , \
			span_notice("Стучу по окну."))
		playsound(src, knock_sound, 50, TRUE)
	else
		user.visible_message(span_warning("[user] долбится в окно!") , \
			span_warning("Долблю окно!"))
		playsound(src, bash_sound, 100, TRUE)

/obj/structure/window/attack_paw(mob/user, list/modifiers)
	return attack_hand(user, modifiers)

/obj/structure/window/attack_generic(mob/user, damage_amount = 0, damage_type = BRUTE, damage_flag = 0, sound_effect = 1) //used by attack_alien, attack_animal, and attack_slime
	if(!can_be_reached(user))
		return
	return ..()

/obj/structure/window/tool_act(mob/living/user, obj/item/tool, tool_type, is_right_clicking)
	if(!can_be_reached(user))
		return TRUE //skip the afterattack
	add_fingerprint(user)
	return ..()

/obj/structure/window/welder_act(mob/living/user, obj/item/tool)
	if(atom_integrity >= max_integrity)
		to_chat(user, span_warning("[capitalize(skloname(src.name, VINITELNI, src.gender))] не требуется починка!"))
		return TOOL_ACT_TOOLTYPE_SUCCESS
	if(!tool.tool_start_check(user, amount = 0))
		return FALSE
	to_chat(user, span_notice("Начинаю чинить [src.name]..."))
	if(tool.use_tool(src, user, 4 SECONDS, volume = 50))
		atom_integrity = max_integrity
		update_nearby_icons()
		to_chat(user, span_notice("Чиню [src.name]."))
	return TOOL_ACT_TOOLTYPE_SUCCESS

/obj/structure/window/screwdriver_act(mob/living/user, obj/item/tool)
	if(flags_1 & NODECONSTRUCT_1)
		return

	switch(state)
		if(WINDOW_SCREWED_TO_FRAME)
			to_chat(user, span_notice("Начинаю откручивать окно от рамы..."))
			if(tool.use_tool(src, user, decon_speed, volume = 75, extra_checks = CALLBACK(src, PROC_REF(check_state_and_anchored), state, anchored)))
				state = WINDOW_IN_FRAME
				to_chat(user, span_notice("Откручиваю окно от рамы."))
		if(WINDOW_IN_FRAME)
			to_chat(user, span_notice("Начинаю вставлять окно в раму..."))
			if(tool.use_tool(src, user, decon_speed, volume = 75, extra_checks = CALLBACK(src, PROC_REF(check_state_and_anchored), state, anchored)))
				state = WINDOW_SCREWED_TO_FRAME
				to_chat(user, span_notice("Вставляю окно в раму."))
		if(WINDOW_OUT_OF_FRAME)
			if(anchored)
				to_chat(user, span_notice("Начинаю откручивать от пола..."))
				if(tool.use_tool(src, user, decon_speed, volume = 75, extra_checks = CALLBACK(src, PROC_REF(check_state_and_anchored), state, anchored)))
					set_anchored(FALSE)
					to_chat(user, span_notice("Откручиваю от пола."))
			else
				to_chat(user, span_notice("Начинаю прикручивать к полу..."))
				if(tool.use_tool(src, user, decon_speed, volume = 75, extra_checks = CALLBACK(src, PROC_REF(check_state_and_anchored), state, anchored)))
					set_anchored(TRUE)
					to_chat(user, span_notice("Прикручиваю к полу."))
	return TOOL_ACT_TOOLTYPE_SUCCESS

/obj/structure/window/wrench_act(mob/living/user, obj/item/tool)
	if(anchored)
		return FALSE
	if((flags_1 & NODECONSTRUCT_1) || (reinf && state >= RWINDOW_FRAME_BOLTED))
		return FALSE

	to_chat(user, span_notice("Начинаю разбирать [src]..."))
	if(!tool.use_tool(src, user, decon_speed, volume = 75, extra_checks = CALLBACK(src, PROC_REF(check_state_and_anchored), state, anchored)))
		return TOOL_ACT_TOOLTYPE_SUCCESS
	var/obj/item/stack/sheet/G = new glass_type(user.loc, glass_amount)
	if (!QDELETED(G))
		G.add_fingerprint(user)
	playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)
	to_chat(user, span_notice("Разобрал [src]."))
	qdel(src)
	return TOOL_ACT_TOOLTYPE_SUCCESS

/obj/structure/window/crowbar_act(mob/living/user, obj/item/tool)
	if(!anchored || (flags_1 & NODECONSTRUCT_1))
		return FALSE

	switch(state)
		if(WINDOW_IN_FRAME)
			to_chat(user, span_notice("Начинаю доставать окно из рамы..."))
			if(tool.use_tool(src, user, 10 SECONDS, volume = 75, extra_checks = CALLBACK(src, PROC_REF(check_state_and_anchored), state, anchored)))
				state = WINDOW_OUT_OF_FRAME
				to_chat(user, span_notice("Достаю окно из рамы."))
		if(WINDOW_OUT_OF_FRAME)
			to_chat(user, span_notice("Начинаю вставлять окно в раму..."))
			if(tool.use_tool(src, user, 5 SECONDS, volume = 75, extra_checks = CALLBACK(src, PROC_REF(check_state_and_anchored), state, anchored)))
				state = WINDOW_SCREWED_TO_FRAME
				to_chat(user, span_notice("Вставил окно в раму."))
		else
			return FALSE

	return TOOL_ACT_TOOLTYPE_SUCCESS

/obj/structure/window/attackby(obj/item/I, mob/living/user, params)
	if(!can_be_reached(user))
		return TRUE //skip the afterattack

	add_fingerprint(user)
	return ..()

/obj/structure/window/AltClick(mob/user)
	return ..() // This hotkey is BLACKLISTED since it's used by /datum/component/simple_rotation

/obj/structure/window/set_anchored(anchorvalue)
	..()
	air_update_turf(TRUE, anchorvalue)
	update_nearby_icons()

/obj/structure/window/proc/check_state(checked_state)
	if(state == checked_state)
		return TRUE

/obj/structure/window/proc/check_anchored(checked_anchored)
	if(anchored == checked_anchored)
		return TRUE

/obj/structure/window/proc/check_state_and_anchored(checked_state, checked_anchored)
	return check_state(checked_state) && check_anchored(checked_anchored)


/obj/structure/window/proc/can_be_reached(mob/user)
	if(fulltile)
		return TRUE
	var/checking_dir = get_dir(user, src)
	if(!(checking_dir & dir))
		return TRUE // Only windows on the other side may be blocked by other things.
	checking_dir = REVERSE_DIR(checking_dir)
	for(var/obj/blocker in loc)
		if(!blocker.CanPass(user, checking_dir))
			return FALSE
	return TRUE


/obj/structure/window/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	. = ..()
	if(.) //received damage
		update_nearby_icons()

/obj/structure/window/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	switch(damage_type)
		if(BRUTE)
			if(damage_amount)
				playsound(src, hit_sound, 75, TRUE)
			else
				playsound(src, 'sound/weapons/tap.ogg', 50, TRUE)
		if(BURN)
			playsound(src, 'sound/items/welder.ogg', 100, TRUE)


/obj/structure/window/deconstruct(disassembled = TRUE)
	if(QDELETED(src))
		return
	if(!disassembled)
		playsound(src, break_sound, 70, TRUE)
		if(!(flags_1 & NODECONSTRUCT_1))
			for(var/obj/item/shard/debris in spawn_debris(drop_location()))
				transfer_fingerprints_to(debris) // transfer fingerprints to shards only
	qdel(src)
	update_nearby_icons()


///Spawns shard and debris decal based on the glass_material_datum, spawns rods if window is reinforned and number of shards/rods is determined by the window being fulltile or not.
/obj/structure/window/proc/spawn_debris(location)
	var/datum/material/glass_material_ref = GET_MATERIAL_REF(glass_material_datum)
	var/obj/item/shard_type = glass_material_ref.shard_type
	var/obj/effect/decal/debris_type = glass_material_ref.debris_type
	var/list/dropped_debris = list()
	if(!isnull(shard_type))
		dropped_debris += new shard_type(location)
		if (fulltile)
			dropped_debris += new shard_type(location)
	if(!isnull(debris_type))
		dropped_debris += new debris_type(location)
	if (reinf)
		dropped_debris += new /obj/item/stack/rods(location, (fulltile ? 2 : 1))
	return dropped_debris

/obj/structure/window/proc/AfterRotation(mob/user, degrees)
	air_update_turf(TRUE, FALSE)

/obj/structure/window/proc/on_painted(obj/structure/window/source, mob/user, obj/item/toy/crayon/spraycan/spraycan, is_dark_color)
	SIGNAL_HANDLER
	if(!spraycan.actually_paints)
		return
	if (is_dark_color && fulltile) //Opaque directional windows restrict vision even in directions they are not placed in, please don't do this
		set_opacity(255)
	else
		set_opacity(initial(opacity))

/obj/structure/window/wash(clean_types)
	. = ..()
	if(!(clean_types & CLEAN_SCRUB))
		return
	set_opacity(initial(opacity))
	remove_atom_colour(WASHABLE_COLOUR_PRIORITY)
	for(var/atom/movable/cleanables as anything in src)
		if(cleanables == src)
			continue
		if(!cleanables.wash(clean_types))
			continue
		vis_contents -= cleanables
	bloodied = FALSE

/obj/structure/window/Destroy()
	set_density(FALSE)
	air_update_turf(TRUE, FALSE)
	update_nearby_icons()
	return ..()

/obj/structure/window/Move()
	var/turf/T = loc
	. = ..()
	if(anchored)
		move_update_air(T)

/obj/structure/window/can_atmos_pass(turf/T, vertical = FALSE)
	if(!anchored || !density)
		return TRUE
	return !(fulltile || dir == get_dir(loc, T))

//This proc is used to update the icons of nearby windows.
/obj/structure/window/proc/update_nearby_icons()
	update_appearance()
	if(smoothing_flags & (SMOOTH_CORNERS|SMOOTH_BITMASK))
		QUEUE_SMOOTH_NEIGHBORS(src)

//merges adjacent full-tile windows into one
/obj/structure/window/update_overlays(updates=ALL)
	. = ..()
	if(QDELETED(src) || !fulltile)
		return

	if((updates & UPDATE_SMOOTHING) && (smoothing_flags & (SMOOTH_CORNERS|SMOOTH_BITMASK)))
		QUEUE_SMOOTH(src)

	var/ratio = atom_integrity / max_integrity
	ratio = CEILING(ratio*4, 1) * 25
	cut_overlay(crack_overlay)
	if(ratio > 75)
		return
	crack_overlay = mutable_appearance('icons/obj/structures.dmi', "damage[ratio]", -(layer+0.1))
	. += crack_overlay

/obj/structure/window/should_atmos_process(datum/gas_mixture/air, exposed_temperature)
	return exposed_temperature > T0C + heat_resistance

/obj/structure/window/atmos_expose(datum/gas_mixture/air, exposed_temperature)
	take_damage(round(air.return_volume() / 100), BURN, 0, 0)

/obj/structure/window/get_dumping_location()
	return null

/obj/structure/window/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	if(!density)
		return TRUE
	if(fulltile || (dir == to_dir))
		return FALSE

	return TRUE

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/window/spawner, 0)

/obj/structure/window/unanchored
	anchored = FALSE

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/window/unanchored/spawner, 0)

/obj/structure/window/reinforced
	name = "направленное армированное окно"
	desc = "Окно, которое укреплено стальными прутьями."
	icon_state = "rwindow"
	base_icon_state = "rwindow"
	reinf = TRUE
	heat_resistance = 1600
	armor_type = /datum/armor/window_reinforced
	max_integrity = 75
	explosion_block = 1
	damage_deflection = 11
	state = RWINDOW_SECURE
	glass_type = /obj/item/stack/sheet/rglass
	rad_insulation = RAD_LIGHT_INSULATION
	receive_ricochet_chance_mod = 1.1

//this is shitcode but all of construction is shitcode and needs a refactor, it works for now
//If you find this like 4 years later and construction still hasn't been refactored, I'm so sorry for this

//Adding a timestamp, I found this in 2020, I hope it's from this year -Lemon
//2021 AND STILLLL GOING STRONG
//2022 BABYYYYY ~lewc
//2023 ONE YEAR TO GO! -LT3
/datum/armor/window_reinforced
	melee = 80
	bomb = 25
	fire = 80
	acid = 100

/obj/structure/window/reinforced/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	if(the_rcd.mode == RCD_DECONSTRUCT)
		return list("delay" = 3 SECONDS, "cost" = 15)
	return FALSE

/obj/structure/window/reinforced/attackby_secondary(obj/item/tool, mob/user, params)
	if(flags_1 & NODECONSTRUCT_1)
		return ..()

	switch(state)
		if(RWINDOW_SECURE)
			if(tool.tool_behaviour == TOOL_WELDER)
				if(tool.tool_start_check(user))
					user.visible_message(span_notice("[user] направляет [skloname(tool.name, VINITELNI, tool.gender)] на защищённые винтики [skloname(src.name, VINITELNI, src.gender)]...") ,
										span_notice("Начинаю нагревать винтики [skloname(src.name, VINITELNI, src.gender)]..."))
					if(tool.use_tool(src, user, 15 SECONDS, volume = 100))
						to_chat(user, span_notice("Винтики раскалены до бела, похоже можно открутить их прямо сейчас."))
						state = RWINDOW_BOLTS_HEATED
						addtimer(CALLBACK(src, PROC_REF(cool_bolts)), 30 SECONDS)
			else if (tool.tool_behaviour)
				to_chat(user, span_warning("Сначала нужно нагреть винтики!"))

		if(RWINDOW_BOLTS_HEATED)
			if(tool.tool_behaviour == TOOL_SCREWDRIVER)
				user.visible_message(span_notice("[user] втыкает отвёртку в раскалённые винтики и начинает их выкручивать...") ,
										span_notice("Втыкаю отвёртку в раскалённые винтики и начинаю их выкручивать..."))
				if(tool.use_tool(src, user, 50, volume = 50))
					state = RWINDOW_BOLTS_OUT
					to_chat(user, span_notice("Винтики удалены и теперь окно можно подпереть."))
			else if (tool.tool_behaviour)
				to_chat(user, span_warning("Сначала нужно выкрутить винтики!"))

		if(RWINDOW_BOLTS_OUT)
			if(tool.tool_behaviour == TOOL_CROWBAR)
				user.visible_message(span_notice("[user] вставляет [skloname(tool.name, VINITELNI, tool.gender)] в щель и начинает подпирать окно...") ,
										span_notice("Вставляю [skloname(tool.name, VINITELNI, tool.gender)] в щель и начинаю подпирать окно..."))
				if(tool.use_tool(src, user, 40, volume = 50))
					state = RWINDOW_POPPED
					to_chat(user, span_notice("Основная плита вышла из рамки и стали видны прутья, которые можно откусить."))
			else if (tool.tool_behaviour)
				to_chat(user, span_warning("Сначала нужно подпереть окно!"))

		if(RWINDOW_POPPED)
			if(tool.tool_behaviour == TOOL_WIRECUTTER)
				user.visible_message(span_notice("[user] начинает откусывать доступные прутья [skloname(src.name, VINITELNI, src.gender)]...") ,
										span_notice("Начинаю откусывать доступные прутья [skloname(src.name, VINITELNI, src.gender)]..."))
				if(tool.use_tool(src, user, 20, volume = 50))
					state = RWINDOW_BARS_CUT
					to_chat(user, span_notice("Основная плита отделена от рамки и теперь её удерживает только несколько болтов."))
			else if (tool.tool_behaviour)
				to_chat(user, span_warning("Сначала нужно откусить прутья!"))

		if(RWINDOW_BARS_CUT)
			if(tool.tool_behaviour == TOOL_WRENCH)
				user.visible_message(span_notice("[user] начинает откручивать [skloname(src.name, VINITELNI, src.gender)] от рамки...") ,
					span_notice("Начинаю откручивать болты..."))
				if(tool.use_tool(src, user, 40, volume = 50))
					to_chat(user, span_notice("Снимаю окно с болтов и теперь оно может быть свободно перемещено."))
					state = WINDOW_OUT_OF_FRAME
					set_anchored(FALSE)
			else if (tool.tool_behaviour)
				to_chat(user, span_warning("Сначала нужно открутить болты!"))

	if (tool.tool_behaviour)
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	return ..()

/obj/structure/window/reinforced/crowbar_act(mob/living/user, obj/item/tool)
	if(!anchored)
		return FALSE
	if((flags_1 & NODECONSTRUCT_1) || (state != WINDOW_OUT_OF_FRAME))
		return FALSE
	to_chat(user, span_notice("Начинаю вставлять окно в раму..."))
	if(tool.use_tool(src, user, 10 SECONDS, volume = 75, extra_checks = CALLBACK(src, PROC_REF(check_state_and_anchored), state, anchored)))
		state = RWINDOW_SECURE
		to_chat(user, span_notice("Вставляю окно в раму."))
	return TOOL_ACT_TOOLTYPE_SUCCESS

/obj/structure/window/proc/cool_bolts()
	if(state == RWINDOW_BOLTS_HEATED)
		state = RWINDOW_SECURE
		visible_message(span_notice("Винтики на [skloname(src.name, TVORITELNI, src.gender)] выглядят как будто они остыли..."))
/obj/structure/window/reinforced/examine(mob/user)
	. = ..()
	if(flags_1 & NODECONSTRUCT_1)
		return
	switch(state)
		if(RWINDOW_SECURE)
			. += span_notice("Окно прикручено одноразовыми винтами. Придётся <b>нагреть их</b>, чтобы получить хоть какой-то шанс выкрутить их обратно.")
		if(RWINDOW_BOLTS_HEATED)
			. += span_notice("Винтики раскалены до бела, похоже можно <b>открутить их</b> прямо сейчас.")
		if(RWINDOW_BOLTS_OUT)
			. += span_notice("Винтики удалены и теперь окно можно <b>подпереть</b> сквозь доступную щель.")
		if(RWINDOW_POPPED)
			. += span_notice("Основная плита вышла из рамки и стали видны прутья, которые можно <b>откусить</b>.")
		if(RWINDOW_BARS_CUT)
			. += span_notice("Основная плита отделена от рамки и теперь её удерживает только несколько <b>болтов</b>.")

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/window/reinforced/spawner, 0)

/obj/structure/window/reinforced/unanchored
	anchored = FALSE
	state = WINDOW_OUT_OF_FRAME

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/window/reinforced/unanchored/spawner, 0)

/obj/structure/window/plasma
	name = "направленное окно из плазмы"
	desc = "Окно из плазменно-силикатного сплава. Выглядит безумно сложным для ломания и прожигания."
	icon_state = "plasmawindow"
	reinf = FALSE
	heat_resistance = 25000
	armor_type = /datum/armor/window_plasma
	max_integrity = 200
	explosion_block = 1
	glass_type = /obj/item/stack/sheet/plasmaglass
	rad_insulation = RAD_MEDIUM_INSULATION
	glass_material_datum = /datum/material/alloy/plasmaglass

/datum/armor/window_plasma
	melee = 80
	bullet = 5
	bomb = 45
	fire = 99
	acid = 100

/obj/structure/window/plasma/Initialize(mapload, direct)
	. = ..()
	RemoveElement(/datum/element/atmos_sensitive)

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/window/plasma/spawner, 0)

/obj/structure/window/plasma/unanchored
	anchored = FALSE

/obj/structure/window/reinforced/plasma
	name = "направленное армированное окно из плазмы"
	desc = "Окно из плазменно-силикатного сплава и стержневой матрицы. Он выглядит безнадежно жестким для разрушения и, скорее всего, почти пожаробезопасным."
	icon_state = "plasmarwindow"
	reinf = TRUE
	heat_resistance = 50000
	armor_type = /datum/armor/reinforced_plasma
	max_integrity = 500
	damage_deflection = 21
	explosion_block = 2
	glass_type = /obj/item/stack/sheet/plasmarglass
	rad_insulation = RAD_HEAVY_INSULATION
	glass_material_datum = /datum/material/alloy/plasmaglass

/datum/armor/reinforced_plasma
	melee = 80
	bullet = 20
	bomb = 60
	fire = 99
	acid = 100

/obj/structure/window/reinforced/plasma/block_superconductivity()
	return TRUE

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/window/reinforced/plasma/spawner, 0)

/obj/structure/window/reinforced/plasma/unanchored
	anchored = FALSE
	state = WINDOW_OUT_OF_FRAME

/obj/structure/window/reinforced/tinted
	name = "затемненное окно"
	icon_state = "twindow"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/window/reinforced/tinted/spawner, 0)

/obj/structure/window/reinforced/tinted/frosted
	name = "заледеневшее окно"
	icon_state = "fwindow"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/window/reinforced/tinted/frosted/spawner, 0)

/* Full Tile Windows (more atom_integrity) */

/obj/structure/window/fulltile
	name = "окно"
	icon = 'icons/obj/windows/window_glass.dmi'
	icon_state = "window_glass-0"
	base_icon_state = "window_glass"
	max_integrity = 100
	fulltile = TRUE
	flags_1 = PREVENT_CLICK_UNDER_1
	obj_flags = CAN_BE_HIT
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WINDOW_FULLTILE
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS
	glass_amount = 2

/obj/structure/window/fulltile/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	if(the_rcd.mode == RCD_DECONSTRUCT)
		return list("delay" = 2.5 SECONDS, "cost" = 10)
	return FALSE

/obj/structure/window/fulltile/unanchored
	anchored = FALSE

/obj/structure/window/plasma/fulltile
	name = "окно из плазмы"
	icon = 'icons/obj/smooth_structures/plasma_window.dmi'
	icon_state = "plasma_window-0"
	base_icon_state = "plasma_window"
	max_integrity = 400
	fulltile = TRUE
	flags_1 = PREVENT_CLICK_UNDER_1
	obj_flags = CAN_BE_HIT
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WINDOW_FULLTILE
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS
	glass_amount = 2

/obj/structure/window/plasma/fulltile/unanchored
	anchored = FALSE

/obj/structure/window/reinforced/plasma/fulltile
	name = "армированное окно из плазмы"
	icon = 'icons/obj/windows/window_rplasma.dmi'
	icon_state = "window_rplasma-0"
	base_icon_state = "window_rplasma"
	state = RWINDOW_SECURE
	max_integrity = 1000
	fulltile = TRUE
	flags_1 = PREVENT_CLICK_UNDER_1
	obj_flags = CAN_BE_HIT
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WINDOW_FULLTILE
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS
	glass_amount = 2

/obj/structure/window/reinforced/plasma/fulltile/unanchored
	anchored = FALSE
	state = WINDOW_OUT_OF_FRAME

/obj/structure/window/reinforced/fulltile
	name = "армированное окно"
	icon = 'icons/obj/windows/window_rglass.dmi'
	icon_state = "window_rglass-0"
	base_icon_state = "window_rglass"
	max_integrity = 150
	fulltile = TRUE
	flags_1 = PREVENT_CLICK_UNDER_1
	obj_flags = CAN_BE_HIT
	state = RWINDOW_SECURE
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WINDOW_FULLTILE
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS
	glass_amount = 2

/obj/structure/window/reinforced/fulltile/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	if(the_rcd.mode == RCD_DECONSTRUCT)
		return list("mode" = RCD_DECONSTRUCT, "delay" = 4 SECONDS, "cost" = 20)
	return FALSE

/obj/structure/window/reinforced/fulltile/unanchored
	anchored = FALSE
	state = WINDOW_OUT_OF_FRAME

/obj/structure/window/reinforced/tinted/fulltile
	icon = 'icons/obj/windows/window_glass.dmi'
	icon_state = "window_glass-0"
	base_icon_state = "window_glass"
	fulltile = TRUE
	flags_1 = PREVENT_CLICK_UNDER_1
	obj_flags = CAN_BE_HIT
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WINDOW_FULLTILE
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS
	glass_amount = 2
	// Not on the parent because directional opacity does NOT WORK
	opacity = TRUE

/obj/structure/window/reinforced/fulltile/ice
	icon = 'icons/obj/smooth_structures/rice_window.dmi'
	icon_state = "rice_window-0"
	base_icon_state = "rice_window"
	max_integrity = 150
	glass_amount = 2

//there is a sub shuttle window in survival_pod.dm for mining pods
/obj/structure/window/reinforced/shuttle//this is called reinforced because it is reinforced w/titanium
	name = "окно шаттла"
	desc = "Усиленное герметичное окно кабины."
	icon = 'icons/obj/smooth_structures/shuttle_window.dmi'
	icon_state = "shuttle_window-0"
	base_icon_state = "shuttle_window"
	max_integrity = 150
	wtype = "shuttle"
	reinf = TRUE
	fulltile = TRUE
	flags_1 = PREVENT_CLICK_UNDER_1
	obj_flags = CAN_BE_HIT
	reinf = TRUE
	heat_resistance = 1600
	armor_type = /datum/armor/reinforced_shuttle
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_SHUTTLE_PARTS + SMOOTH_GROUP_WINDOW_FULLTILE_SHUTTLE
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE_SHUTTLE
	explosion_block = 3
	glass_type = /obj/item/stack/sheet/titaniumglass
	glass_amount = 2
	receive_ricochet_chance_mod = 1.2
	rad_insulation = RAD_MEDIUM_INSULATION
	glass_material_datum = /datum/material/alloy/titaniumglass

/datum/armor/reinforced_shuttle
	melee = 90
	bomb = 50
	fire = 80
	acid = 100

/obj/structure/window/reinforced/shuttle/narsie_act()
	add_atom_colour("#3C3434", FIXED_COLOUR_PRIORITY)

/obj/structure/window/reinforced/shuttle/tinted
	opacity = TRUE

/obj/structure/window/reinforced/shuttle/unanchored
	anchored = FALSE
	state = WINDOW_OUT_OF_FRAME

/obj/structure/window/reinforced/shuttle/indestructible
	name = "hardened shuttle window"
	flags_1 = PREVENT_CLICK_UNDER_1 | NODECONSTRUCT_1
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/structure/window/reinforced/shuttle/indestructible/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	return FALSE

/obj/structure/window/reinforced/plasma/plastitanium
	name = "пластитановое окно"
	desc = "Прочное окно из сплава плазмы и титана."
	icon = 'icons/obj/smooth_structures/plastitanium_window.dmi'
	icon_state = "plastitanium_window-0"
	base_icon_state = "plastitanium_window"
	max_integrity = 1200
	wtype = "shuttle"
	fulltile = TRUE
	flags_1 = PREVENT_CLICK_UNDER_1
	obj_flags = CAN_BE_HIT
	heat_resistance = 1600
	armor_type = /datum/armor/plasma_plastitanium
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_SHUTTLE_PARTS + SMOOTH_GROUP_WINDOW_FULLTILE_PLASTITANIUM
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE_PLASTITANIUM + SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS
	explosion_block = 3
	damage_deflection = 21 //The same as reinforced plasma windows.3
	glass_type = /obj/item/stack/sheet/plastitaniumglass
	glass_amount = 2
	rad_insulation = RAD_EXTREME_INSULATION
	glass_material_datum = /datum/material/alloy/plastitaniumglass

/datum/armor/plasma_plastitanium
	melee = 95
	bomb = 50
	fire = 80
	acid = 100

/obj/structure/window/reinforced/plasma/plastitanium/unanchored
	anchored = FALSE
	state = WINDOW_OUT_OF_FRAME

/obj/structure/window/paperframe
	name = "бумажная рамка"
	desc = "Хрупкий разделитель из тонкого дерева и бумаги."
	icon = 'icons/obj/smooth_structures/paperframes.dmi'
	icon_state = "paperframes-0"
	base_icon_state = "paperframes"
	opacity = TRUE
	max_integrity = 15
	fulltile = TRUE
	flags_1 = PREVENT_CLICK_UNDER_1
	obj_flags = CAN_BE_HIT
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_PAPERFRAME
	canSmoothWith = SMOOTH_GROUP_PAPERFRAME
	glass_amount = 2
	glass_type = /obj/item/stack/sheet/paperframes
	heat_resistance = 233
	decon_speed = 10
	can_atmos_pass = ATMOS_PASS_YES
	resistance_flags = FLAMMABLE
	armor_type = /datum/armor/none
	knock_sound = SFX_PAGE_TURN
	bash_sound = 'sound/weapons/slashmiss.ogg'
	break_sound = 'sound/items/poster_ripped.ogg'
	hit_sound = 'sound/weapons/slashmiss.ogg'
	var/static/mutable_appearance/torn = mutable_appearance('icons/obj/smooth_structures/paperframes.dmi',icon_state = "torn", layer = ABOVE_OBJ_LAYER - 0.1)
	var/static/mutable_appearance/paper = mutable_appearance('icons/obj/smooth_structures/paperframes.dmi',icon_state = "paper", layer = ABOVE_OBJ_LAYER - 0.1)

/obj/structure/window/paperframe/Initialize(mapload)
	. = ..()
	update_appearance()

/obj/structure/window/paperframe/examine(mob/user)
	. = ..()
	if(atom_integrity < max_integrity)
		. += span_info("Она выглядит немного поврежденной, можно починить с помощью <b>бумаги</b>.")

/obj/structure/window/paperframe/spawn_debris(location)
	. = list(new /obj/item/stack/sheet/mineral/wood(location))
	for (var/i in 1 to rand(1,4))
		. += new /obj/item/paper/natural(location)

/obj/structure/window/paperframe/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(user.combat_mode)
		take_damage(4, BRUTE, MELEE, 0)
		if(!QDELETED(src))
			update_appearance()

/obj/structure/window/paperframe/update_appearance(updates)
	. = ..()
	set_opacity(atom_integrity >= max_integrity)

/obj/structure/window/paperframe/update_icon(updates=ALL)
	. = ..()
	if((updates & UPDATE_SMOOTHING) && (smoothing_flags & (SMOOTH_CORNERS|SMOOTH_BITMASK)))
		QUEUE_SMOOTH(src)

/obj/structure/window/paperframe/update_overlays()
	. = ..()
	. += (atom_integrity < max_integrity) ? torn : paper

/obj/structure/window/paperframe/attackby(obj/item/W, mob/living/user)
	if(W.get_temperature())
		fire_act(W.get_temperature())
		return
	if(user.combat_mode)
		return ..()
	if(istype(W, /obj/item/paper) && atom_integrity < max_integrity)
		user.visible_message(span_notice("[user] начинает заделывать щели в [skloname(src.name, TVORITELNI, src.gender)]."))
		if(do_after(user, 20, target = src))
			atom_integrity = min(atom_integrity+4,max_integrity)
			qdel(W)
			user.visible_message(span_notice("[user] заделывает некоторые щели в [skloname(src.name, TVORITELNI, src.gender)]."))
			if(atom_integrity == max_integrity)
				update_appearance()
			return
	..()
	update_appearance()

/obj/structure/window/bronze
	name = "латунное окно"
	desc = "Тонкая, как бумага, панель из полупрозрачной, но усиленной латуни. Да ладно, это слабая латунь!"
	icon = 'icons/obj/smooth_structures/clockwork_window.dmi'
	icon_state = "clockwork_window_single"
	glass_type = /obj/item/stack/sheet/bronze

/obj/structure/window/bronze/unanchored
	anchored = FALSE

/obj/structure/window/bronze/fulltile
	icon_state = "clockwork_window-0"
	base_icon_state = "clockwork_window"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WINDOW_FULLTILE_BRONZE + SMOOTH_GROUP_WINDOW_FULLTILE
	canSmoothWith = SMOOTH_GROUP_WINDOW_FULLTILE_BRONZE
	fulltile = TRUE
	flags_1 = PREVENT_CLICK_UNDER_1
	obj_flags = CAN_BE_HIT
	max_integrity = 50
	glass_amount = 2

/obj/structure/window/bronze/fulltile/unanchored
	anchored = FALSE
