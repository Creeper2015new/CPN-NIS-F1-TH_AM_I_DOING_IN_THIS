/datum/crafting_recipe/curtain
	name = "Занавески"
	reqs = list(
		/obj/item/stack/sheet/cloth = 4,
		/obj/item/stack/rods = 1,
	)
	result = /obj/structure/curtain/cloth
	category = CAT_FURNITURE

/datum/crafting_recipe/showercurtain
	name = "Занавески для душа"
	reqs = list(
		/obj/item/stack/sheet/cloth = 2,
		/obj/item/stack/sheet/plastic = 2,
		/obj/item/stack/rods = 1,
	)
	result = /obj/structure/curtain
	category = CAT_FURNITURE

/datum/crafting_recipe/aquarium
	name = "Аквариум"
	result = /obj/structure/aquarium
	time = 10 SECONDS
	reqs = list(
		/obj/item/stack/sheet/iron = 15,
		/obj/item/stack/sheet/glass = 10,
		/obj/item/aquarium_kit = 1,
	)
	category = CAT_FURNITURE

/datum/crafting_recipe/mirror
	name = "Зеркало"
	result = /obj/item/wallframe/mirror
	reqs = list(
		/obj/item/stack/sheet/glass = 5,
		/obj/item/stack/sheet/mineral/silver = 2,
	)
	category = CAT_FURNITURE

/datum/crafting_recipe/surgery_tray
	name = "Хирургический стол"
	reqs = list(
		/obj/item/stack/sheet/mineral/silver = 1,
		/obj/item/stack/rods = 2
	)
	result = /obj/item/surgery_tray
	tool_behaviors = list(TOOL_SCREWDRIVER)
	category = CAT_FURNITURE
	time = 5 SECONDS
