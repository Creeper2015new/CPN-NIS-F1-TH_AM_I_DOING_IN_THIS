/datum/wires/rnd
	holder_type = /obj/machinery/rnd
	proper_name = "R&D Machinery"
	randomize = TRUE

/datum/wires/rnd/New(atom/holder)
	wires = list(
		WIRE_HACK, WIRE_DISABLE,
		WIRE_SHOCK
	)
	add_duds(5)
	..()

/datum/wires/rnd/interactable(mob/user)
	if(!..())
		return FALSE
	var/obj/machinery/rnd/R = holder
	if(R.panel_open)
		return TRUE

/datum/wires/rnd/get_status()
	var/obj/machinery/rnd/R = holder
	var/list/status = list()
	status += "Красный индикатор [R.disabled ? "не горит" : "горит"]."
	status += "Синий индикатор [R.hacked ? "не горит" : "горит"]."
	return status

/datum/wires/rnd/on_pulse(wire)
	set waitfor = FALSE
	var/obj/machinery/rnd/R = holder
	switch(wire)
		if(WIRE_HACK)
			R.hacked = !R.hacked
		if(WIRE_DISABLE)
			R.disabled = !R.disabled
/datum/wires/rnd/on_cut(wire, mend, source)
	var/obj/machinery/rnd/R = holder
	switch(wire)
		if(WIRE_HACK)
			R.hacked = !mend
		if(WIRE_DISABLE)
			R.disabled = !mend
