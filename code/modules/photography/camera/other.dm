/obj/item/camera/spooky
	name = "камера обскура"
	desc = "Полароид с функцией захвата призраков в объектив!"
	see_ghosts = CAMERA_SEE_GHOSTS_BASIC

/obj/item/camera/spooky/steal_souls(list/victims)
	for(var/mob/living/target in victims)
		if(!(target.mob_biotypes & MOB_SPIRIT))
			continue

		// time to steal your soul
		if(istype(target, /mob/living/basic/revenant))
			var/mob/living/basic/revenant/peek_a_boo = target
			peek_a_boo.apply_status_effect(/datum/status_effect/revenant/revealed, 2 SECONDS) // no hiding
			peek_a_boo.apply_status_effect(/datum/status_effect/incapacitating/paralyzed/revenant, 2 SECONDS)

		target.visible_message(
			span_warning("[target] злобно дергается!"),
			span_revendanger("Вы чувствуете, как сама ваша суть исчезает после того, как вас сфотографировали!"),
		)
		target.apply_damage(rand(10, 15))

/obj/item/camera/spooky/badmin
	desc = "A polaroid camera, some say it can see ghosts! It seems to have an extra magnifier on the end."
	see_ghosts = CAMERA_SEE_GHOSTS_ORBIT

/obj/item/camera/detective
	name = "камера детектива"
	desc = "Полароид с большим запасом фотографий."
	pictures_max = 30
	pictures_left = 30
