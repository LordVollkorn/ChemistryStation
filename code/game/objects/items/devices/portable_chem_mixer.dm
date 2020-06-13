/obj/item/portable_chem_mixer
	name = "Portable Chemical Mixer" //Thanks to antropod for the help
	desc = "A chemical Mixer. We are still working on it and it won't create chemicals from thin air."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "portablechemicalmixer_open"
	w_class = WEIGHT_CLASS_HUGE
	slot_flags = ITEM_SLOT_BELT
	equip_sound = 'sound/items/equip/toolbelt_equip.ogg'
	custom_price = 2000
	custom_premium_price = 2000
	var/ui_x = 465
	var/ui_y = 550

	var/obj/item/stock_parts/matter_bin/matter_bin
	var/obj/item/reagent_containers/beaker = null
	var/obj/item/storage/pill_bottle/bottle = null
	var/mode = 1
	var/condi = FALSE
	var/chosenPillStyle = 1
	var/screen = "home"
	var/analyzeVars[0]
	var/useramount = 30 // Last used amount
	var/list/pillStyles = null

/obj/item/portable_chem_mixer/Initialize()
	create_reagents(100, REFILLABLE | NO_REACT)

	//Calculate the span tags and ids fo all the available pill icons
	var/datum/asset/spritesheet/simple/assets = get_asset_datum(/datum/asset/spritesheet/simple/pills)
	pillStyles = list()
	for (var/x in 1 to PILL_STYLE_COUNT)
		var/list/SL = list()
		SL["id"] = x
		SL["className"] = assets.icon_class_name("pill[x]")
		pillStyles += list(SL)

	. = ..()

/obj/item/portable_chem_mixer/Destroy()
	QDEL_NULL(beaker)
	QDEL_NULL(bottle)
	return ..()

/obj/item/portable_chem_mixer/ex_act(severity, target)
	if(severity < 3)
		..()


//----------------------------------------------------------------------------------------------------------
//	Add and remove beakers and matter bins
//----------------------------------------------------------------------------------------------------------

/obj/item/portable_chem_mixer/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/reagent_containers) && !(I.item_flags & ABSTRACT) && I.is_open_container())
		var/obj/item/reagent_containers/B = I
		. = TRUE //no afterattack
		if(!user.transferItemToLoc(B, src))
			return
		replace_beaker(user, B)
		if(matter_bin)
			icon_state = "portablechemicalmixer_full"
		else
			icon_state = "portablechemicalmixer_open"
		to_chat(user, "<span class='notice'>You add [B] to the [src].</span>")
		updateUsrDialog()
	else if(I.tool_behaviour == TOOL_SCREWDRIVER)
		//--------------Removing a matter bin 
		if(!beaker)
			remove_matter_bin(user)
			icon_state = "portablechemicalmixer_open"
		else
			to_chat(user, "<span class='warning'>You cannot change the matter bin with the beaker still in.</span>")
		return
	else if(istype(I, /obj/item/stock_parts/matter_bin))
		if(matter_bin)
			to_chat(user, "<span class='warning'>There is already a matter bin inside!</span>")
			return
		else
			if(!user.transferItemToLoc(I, src))
				return
			//--------------Adding a matter bin
			matter_bin = I
			//Maximum amount of chemicals that can be carried, depending on matter bin
			if(istype(I, /obj/item/stock_parts/matter_bin/adv))
				create_reagents(250, REFILLABLE | NO_REACT)
			else if(istype(I, /obj/item/stock_parts/matter_bin/super))
				create_reagents(500, REFILLABLE | NO_REACT)
			else if(istype(I, /obj/item/stock_parts/matter_bin/bluespace))
				create_reagents(1000, REFILLABLE | NO_REACT)
			else
				create_reagents(100, REFILLABLE | NO_REACT)
			if(beaker)
				icon_state = "portablechemicalmixer_full"
			else
				icon_state = "portablechemicalmixer_empty"
			return
	else if(user.a_intent != INTENT_HARM && !istype(I, /obj/item/card/emag))
		to_chat(user, "<span class='warning'>You can't load [I] into the [src]!</span>")
		return ..()
	else
		return ..()


/obj/item/portable_chem_mixer/AltClick(mob/living/user)
	. = ..()
	if(!can_interact(user) || !user.canUseTopic(src, BE_CLOSE, FALSE, NO_TK))
		return
	replace_beaker(user)
	if (matter_bin)
		icon_state = "portablechemicalmixer_empty"
	else
		icon_state = "portablechemicalmixer_open"


/obj/item/portable_chem_mixer/proc/replace_beaker(mob/living/user, obj/item/reagent_containers/new_beaker)
	if(!user)
		return FALSE
	if(beaker)
		user.put_in_hands(beaker)
		beaker = null
	if(new_beaker)
		beaker = new_beaker
	//update_icon()
	return TRUE


/obj/item/portable_chem_mixer/proc/remove_matter_bin(mob/living/user)
	if(!user)
		return FALSE
	if(matter_bin)
		user.put_in_hands(matter_bin)
		matter_bin = null
	return TRUE


//----------------------------------------------------------------------------------------------------------
//	Accessing the Mixer and moving it back to the hand
//----------------------------------------------------------------------------------------------------------

/obj/item/portable_chem_mixer/attack_hand(mob/user)
	if(loc != user)
		return ..()
	if(!(slot_flags & ITEM_SLOT_BELT))
		return
	if(user.get_item_by_slot(ITEM_SLOT_BELT) != src)
		to_chat(user, "<span class='warning'>You must strap the portable chemical mixer's belt on to handle it properly!</span>")
		return
	if(matter_bin)
		ui_interact(user)
	else
		to_chat(user, "<span class='warning'>It has no matter bin installed!</span>")


/obj/item/portable_chem_mixer/attack_self(mob/user)
	to_chat(user, "<span class='warning'>You must strap the portable chemical mixer's belt on to handle it properly!")
	

/obj/item/portable_chem_mixer/MouseDrop(obj/over_object)
	. = ..()
	if(ismob(loc))
		var/mob/M = loc
		if(!M.incapacitated() && istype(over_object, /obj/screen/inventory/hand))
			var/obj/screen/inventory/hand/H = over_object
			M.putItemFromInventoryInHandIfPossible(src, H.held_index)


//----------------------------------------------------------------------------------------------------------
//	Mixer Basic Functionality
//----------------------------------------------------------------------------------------------------------

/obj/item/portable_chem_mixer/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, \
										datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state)
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		var/datum/asset/assets = get_asset_datum(/datum/asset/spritesheet/simple/pills)
		assets.send(user)

		ui = new(user, src, ui_key, "PortableChemMixer", name, ui_x, ui_y, master_ui, state)
		ui.open()

//Insert our custom spritesheet css link into the html
/obj/item/portable_chem_mixer/ui_base_html(html)
	var/datum/asset/spritesheet/simple/assets = get_asset_datum(/datum/asset/spritesheet/simple/pills)
	. = replacetext(html, "<!--customheadhtml-->", assets.css_tag())

/obj/item/portable_chem_mixer/ui_data(mob/user)
	var/list/data = list()
	data["isBeakerLoaded"] = beaker ? 1 : 0
	data["beakerCurrentVolume"] = beaker ? beaker.reagents.total_volume : null
	data["beakerMaxVolume"] = beaker ? beaker.volume : null
	data["mode"] = mode
	data["condi"] = condi
	data["screen"] = screen
	data["analyzeVars"] = analyzeVars
	data["chosenPillStyle"] = chosenPillStyle
	data["isPillBottleLoaded"] = bottle ? 1 : 0
	if(bottle)
		var/datum/component/storage/STRB = bottle.GetComponent(/datum/component/storage)
		data["pillBottleCurrentAmount"] = bottle.contents.len
		data["pillBottleMaxAmount"] = STRB.max_items

	var/beakerContents[0]
	if(beaker)
		for(var/datum/reagent/R in beaker.reagents.reagent_list)
			beakerContents.Add(list(list("name" = R.name, "id" = ckey(R.name), "volume" = R.volume))) // list in a list because Byond merges the first list...
	data["beakerContents"] = beakerContents

	var/bufferContents[0]
	if(reagents.total_volume)
		for(var/datum/reagent/N in reagents.reagent_list)
			bufferContents.Add(list(list("name" = N.name, "id" = ckey(N.name), "volume" = N.volume))) // ^
	data["bufferContents"] = bufferContents

	//Calculated at init time as it never changes
	data["pillStyles"] = pillStyles
	return data

/obj/item/portable_chem_mixer/ui_act(action, params)
	if(..())
		return

	if(action == "eject")
		icon_state = "portablechemicalmixer_empty"
		replace_beaker(usr)
		return TRUE

	if(action == "ejectPillBottle")
		if(!bottle)
			return FALSE
		bottle.forceMove(drop_location())
		//adjust_item_drop_location(bottle)
		bottle = null
		return TRUE

	if(action == "transfer")
		if(!beaker)
			return FALSE
		var/reagent = GLOB.name2reagent[params["id"]]
		var/amount = text2num(params["amount"])
		var/to_container = params["to"]
		// Custom amount
		if (amount == -1)
			amount = text2num(input(
				"Enter the amount you want to transfer:",
				name, ""))
		if (amount == null || amount <= 0)
			return FALSE
		if (to_container == "buffer")
			beaker.reagents.trans_id_to(src, reagent, amount)
			return TRUE
		if (to_container == "beaker" && mode)
			reagents.trans_id_to(beaker, reagent, amount)
			return TRUE
		if (to_container == "beaker" && !mode)
			reagents.remove_reagent(reagent, amount)
			return TRUE
		return FALSE

	if(action == "toggleMode")
		mode = !mode
		return TRUE

	if(action == "pillStyle")
		var/id = text2num(params["id"])
		chosenPillStyle = id
		return TRUE

	if(action == "create")
		if(reagents.total_volume == 0)
			return FALSE
		var/item_type = params["type"]
		// Get amount of items
		var/amount = text2num(params["amount"])
		if(amount == null)
			amount = text2num(input(usr,
				"Max 10. Buffer content will be split evenly.",
				"How many to make?", 1))
		amount = clamp(round(amount), 0, 10)
		if (amount <= 0)
			return FALSE
		// Get units per item
		var/vol_each = text2num(params["volume"])
		var/vol_each_text = params["volume"]
		var/vol_each_max = reagents.total_volume / amount
		if (item_type == "pill")
			vol_each_max = min(50, vol_each_max)
		else if (item_type == "patch")
			vol_each_max = min(40, vol_each_max)
		else if (item_type == "bottle")
			vol_each_max = min(30, vol_each_max)
		else if (item_type == "condimentPack")
			vol_each_max = min(10, vol_each_max)
		else if (item_type == "condimentBottle")
			vol_each_max = min(50, vol_each_max)
		else
			return FALSE
		if(vol_each_text == "auto")
			vol_each = vol_each_max
		if(vol_each == null)
			vol_each = text2num(input(usr,
				"Maximum [vol_each_max] units per item.",
				"How many units to fill?",
				vol_each_max))
		vol_each = clamp(vol_each, 0, vol_each_max)
		if(vol_each <= 0)
			return FALSE
		// Get item name
		var/name = params["name"]
		var/name_has_units = item_type == "pill" || item_type == "patch"
		if(!name)
			var/name_default = reagents.get_master_reagent_name()
			if (name_has_units)
				name_default += " ([vol_each]u)"
			name = stripped_input(usr,
				"Name:",
				"Give it a name!",
				name_default,
				MAX_NAME_LEN)
		if(!name || !reagents.total_volume || !src || QDELETED(src) || !usr.canUseTopic(src, !issilicon(usr)))
			return FALSE
		// Start filling
		if(item_type == "pill")
			var/obj/item/reagent_containers/pill/P
			var/target_loc = drop_location()
			var/drop_threshold = INFINITY
			if(bottle)
				var/datum/component/storage/STRB = bottle.GetComponent(
					/datum/component/storage)
				if(STRB)
					drop_threshold = STRB.max_items - bottle.contents.len
			for(var/i = 0; i < amount; i++)
				if(i < drop_threshold)
					P = new/obj/item/reagent_containers/pill(target_loc)
				else
					P = new/obj/item/reagent_containers/pill(drop_location())
				P.name = trim("[name] pill")
				if(chosenPillStyle == RANDOM_PILL_STYLE)
					P.icon_state ="pill[rand(1,21)]"
				else
					P.icon_state = "pill[chosenPillStyle]"
				if(P.icon_state == "pill4")
					P.desc = "A tablet or capsule, but not just any, a red one, one taken by the ones not scared of knowledge, freedom, uncertainty and the brutal truths of reality."
				//adjust_item_drop_location(P)
				reagents.trans_to(P, vol_each, transfered_by = usr)
			return TRUE
		if(item_type == "patch")
			var/obj/item/reagent_containers/pill/patch/P
			for(var/i = 0; i < amount; i++)
				P = new/obj/item/reagent_containers/pill/patch(drop_location())
				P.name = trim("[name] patch")
				//adjust_item_drop_location(P)
				reagents.trans_to(P, vol_each, transfered_by = usr)
			return TRUE
		if(item_type == "bottle")
			var/obj/item/reagent_containers/glass/bottle/P
			for(var/i = 0; i < amount; i++)
				P = new/obj/item/reagent_containers/glass/bottle(drop_location())
				P.name = trim("[name] bottle")
				//adjust_item_drop_location(P)
				reagents.trans_to(P, vol_each, transfered_by = usr)
			return TRUE
		if(item_type == "condimentPack")
			var/obj/item/reagent_containers/food/condiment/pack/P
			for(var/i = 0; i < amount; i++)
				P = new/obj/item/reagent_containers/food/condiment/pack(drop_location())
				P.originalname = name
				P.name = trim("[name] pack")
				P.desc = "A small condiment pack. The label says it contains [name]."
				reagents.trans_to(P, vol_each, transfered_by = usr)
			return TRUE
		if(item_type == "condimentBottle")
			var/obj/item/reagent_containers/food/condiment/P
			for(var/i = 0; i < amount; i++)
				P = new/obj/item/reagent_containers/food/condiment(drop_location())
				P.originalname = name
				P.name = trim("[name] bottle")
				reagents.trans_to(P, vol_each, transfered_by = usr)
			return TRUE
		return FALSE

	if(action == "analyze")
		var/datum/reagent/R = GLOB.name2reagent[params["id"]]
		if(R)
			var/state = "Unknown"
			if(initial(R.reagent_state) == 1)
				state = "Solid"
			else if(initial(R.reagent_state) == 2)
				state = "Liquid"
			else if(initial(R.reagent_state) == 3)
				state = "Gas"
			var/const/P = 3 //The number of seconds between life ticks
			var/T = initial(R.metabolization_rate) * (60 / P)
			analyzeVars = list("name" = initial(R.name), "state" = state, "color" = initial(R.color), "description" = initial(R.description), "metaRate" = T, "overD" = initial(R.overdose_threshold), "addicD" = initial(R.addiction_threshold))
			screen = "analyze"
			return TRUE

	if(action == "goScreen")
		screen = params["screen"]
		return TRUE

	return FALSE


/obj/item/portable_chem_mixer/proc/isgoodnumber(num)
	if(isnum(num))
		if(num > 200)
			num = 200
		else if(num < 0)
			num = 0
		else
			num = round(num)
		return num
	else
		return 0



//----------------------------------------------------------------------------------------------------------
//	Mixer Additional Functionality
//----------------------------------------------------------------------------------------------------------

/obj/item/portable_chem_mixer/contents_explosion(severity, target)
	..()
	if(beaker)
		switch(severity)
			if(EXPLODE_DEVASTATE)
				SSexplosions.highobj += beaker
			if(EXPLODE_HEAVY)
				SSexplosions.medobj += beaker
			if(EXPLODE_LIGHT)
				SSexplosions.lowobj += beaker
	if(bottle)
		switch(severity)
			if(EXPLODE_DEVASTATE)
				SSexplosions.highobj += bottle
			if(EXPLODE_HEAVY)
				SSexplosions.medobj += bottle
			if(EXPLODE_LIGHT)
				SSexplosions.lowobj += bottle

/obj/item/portable_chem_mixer/handle_atom_del(atom/A)
	..()
	if(A == beaker)
		beaker = null
		reagents.clear_reagents()
		//update_icon()
	else if(A == bottle)
		bottle = null

// /obj/item/portable_chem_mixer/update_overlays()
// 	. = ..()
// 	if(machine_stat & BROKEN)
// 		. += "waitlight"

/obj/item/portable_chem_mixer/blob_act(obj/structure/blob/B)
	if (prob(50))
		qdel(src)







// /obj/item/portable_chem_mixer/on_deconstruction()
// 	replace_beaker()
// 	if(bottle)
// 		bottle.forceMove(drop_location())
// 		//adjust_item_drop_location(bottle)
// 		bottle = null
// 	return ..()


// /obj/item/portable_chem_mixer/adjust_item_drop_location(atom/movable/AM) // Special version for chemmasters and condimasters
// 	if (AM == beaker)
// 		AM.pixel_x = -8
// 		AM.pixel_y = 8
// 		return null
// 	else if (AM == bottle)
// 		if (length(bottle.contents))
// 			AM.pixel_x = -13
// 		else
// 			AM.pixel_x = -7
// 		AM.pixel_y = -8
// 		return null
// 	else
// 		var/md5 = md5(AM.name)
// 		for (var/i in 1 to 32)
// 			. += hex2num(md5[i])
// 		. = . % 9
// 		AM.pixel_x = ((.%3)*6)
// 		AM.pixel_y = -8 + (round( . / 3)*8)

