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
	var/ui_x = 495
	var/ui_y = 550

	var/obj/item/stock_parts/matter_bin/matter_bin
	var/obj/item/reagent_containers/beaker = null
	var/max_total_reagents = 100 //Changed depending on the matter bin
	var/total_reagents = 0 		//Sum of all reagents that are in the item
	var/amount = 30
	
	var/list/dispensable_reagents = list(
		/datum/reagent/aluminium,
		/datum/reagent/bromine,
		/datum/reagent/carbon,
		/datum/reagent/chlorine,
		/datum/reagent/copper,
		/datum/reagent/consumable/ethanol,
		/datum/reagent/fluorine,
		/datum/reagent/hydrogen,
		/datum/reagent/iodine,
		/datum/reagent/iron,
		/datum/reagent/lithium,
		/datum/reagent/mercury,
		/datum/reagent/nitrogen,
		/datum/reagent/oxygen,
		/datum/reagent/phosphorus,
		/datum/reagent/potassium,
		/datum/reagent/uranium/radium,
		/datum/reagent/silicon,
		/datum/reagent/silver,
		/datum/reagent/sodium,
		/datum/reagent/stable_plasma,
		/datum/reagent/consumable/sugar,
		/datum/reagent/sulfur,
		/datum/reagent/toxin/acid,
		/datum/reagent/water,
		/datum/reagent/fuel
	)

	var/list/recording_recipe
	var/list/saved_recipes = list()


/obj/item/portable_chem_mixer/Initialize()
	for (var/path in dispensable_reagents)
		dispensable_reagents[path] = new path()
		dispensable_reagents[path].volume = 0
	. = ..()

/obj/item/portable_chem_mixer/Destroy()
	QDEL_NULL(beaker)
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
			max_total_reagents = 0
			icon_state = "portablechemicalmixer_open"
			for(var/re in dispensable_reagents)
				var/datum/reagent/R = dispensable_reagents[re]
				R.volume = 0
			to_chat(user, "<span class='warning'>The matter bin hisses as leftover reagents evaporate.</span>")
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
				max_total_reagents = 520 //Advanced matter bin
			else if(istype(I, /obj/item/stock_parts/matter_bin/super))
				max_total_reagents = 1040 //Super matter bin
			else if(istype(I, /obj/item/stock_parts/matter_bin/bluespace))
				max_total_reagents = 2080 //Bluespace matter bin
			else
				max_total_reagents = 260 //Normal matter bin (10u per reagent)
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


/obj/item/portable_chem_mixer/ui_data(mob/user)
	var/list/data = list()
	data["amount"] = amount
	data["isBeakerLoaded"] = beaker ? 1 : 0
	data["beakerCurrentVolume"] = beaker ? beaker.reagents.total_volume : null
	data["beakerMaxVolume"] = beaker ? beaker.volume : null
	data["beakerTransferAmounts"] = beaker ? list(1,2,3,4,5) : null
	data["max_total_reagents"] = max_total_reagents
	data["total_reagents"] = total_reagents
	var/chemicals[0]
	var/is_hallucinating = FALSE
	if(user.hallucinating())
		is_hallucinating = TRUE
	for(var/re in dispensable_reagents)
		var/datum/reagent/R = dispensable_reagents[re]
		var/datum/reagent/temp = GLOB.chemical_reagents_list[re]
		if(temp)
			var/chemname = temp.name
			if(is_hallucinating && prob(5))
				chemname = "[pick_list_replacements("hallucination.json", "chemicals")]"
			chemicals.Add(list(list("title" = chemname, "id" = ckey(temp.name), "volume" = R.volume )))
	data["chemicals"] = chemicals
	data["recipes"] = saved_recipes
	data["recordingRecipe"] = recording_recipe
	var/beakerContents[0]
	if(beaker)
		for(var/datum/reagent/R in beaker.reagents.reagent_list)
			beakerContents.Add(list(list("name" = R.name, "id" = ckey(R.name), "volume" = R.volume))) // list in a list because Byond merges the first list...
	data["beakerContents"] = beakerContents
	return data



/obj/item/portable_chem_mixer/ui_act(action, params)
	if(..())
		return
	switch(action)
		if("amount")
			if(QDELETED(matter_bin))
				return
			var/target = text2num(params["target"])
			//if(target in beaker.possible_transfer_amounts)
			amount = target
			. = TRUE
		if("dispense")
			if(QDELETED(matter_bin))
				return
			var/reagent_name = params["reagent"]
			if(!recording_recipe)
				var/reagent = GLOB.name2reagent[reagent_name]
				if(beaker && dispensable_reagents.Find(reagent))
					
					//What the beaker could hold
					var/datum/reagents/R = beaker.reagents
					var/free = R.maximum_volume - R.total_volume
					var/actual = min(amount, 1000, free)

					//The maximum we have available to dispense
					var/datum/reagent/DR = dispensable_reagents[reagent]
					var/max_dispensable = min(amount,DR.volume)

					//Dispense the best possible amount
					var/to_dispense = min(max_dispensable, actual)
					DR.volume -= to_dispense

					//Add to beaker
					R.add_reagent(reagent, to_dispense)
					
					//Remove from total_reagent amount
					total_reagents -= to_dispense
			else
				recording_recipe[reagent_name] += amount
			. = TRUE
		if("remove")
			if(recording_recipe)
				return
			var/amount = text2num(params["amount"])
			// if(beaker && (amount in beaker.possible_transfer_amounts))
				beaker.reagents.remove_all(amount)
				. = TRUE
		if("eject")
			icon_state = "portablechemicalmixer_empty"
			replace_beaker(usr)
			. = TRUE
		if("dispense_recipe")
			if(QDELETED(matter_bin))
				return
			var/list/chemicals_to_dispense = saved_recipes[params["recipe"]]
			if(!LAZYLEN(chemicals_to_dispense))
				return
			for(var/key in chemicals_to_dispense)
				var/reagent = GLOB.name2reagent[translate_legacy_chem_id(key)]
				var/dispense_amount = chemicals_to_dispense[key]
				if(!dispensable_reagents.Find(reagent))
					return
				if(!recording_recipe)
					if(!beaker)
						return
					var/datum/reagents/R = beaker.reagents
					var/free = R.maximum_volume - R.total_volume
					var/actual = min(dispense_amount, 1000, free)
					if(actual)
						R.add_reagent(reagent, actual)
				else
					recording_recipe[key] += dispense_amount
			. = TRUE
		if("clear_recipes")
			// if(!is_operational())
			// 	return
			var/yesno = alert("Clear all recipes?",, "Yes","No")
			if(yesno == "Yes")
				saved_recipes = list()
			. = TRUE
		if("record_recipe")
			// if(!is_operational())
			// 	return
			recording_recipe = list()
			. = TRUE
		if("save_recording")
		// 	if(!is_operational())
				// return
			var/name = stripped_input(usr,"Name","What do you want to name this recipe?", "Recipe", MAX_NAME_LEN)
			if(!usr.canUseTopic(src, !issilicon(usr)))
				return
			if(saved_recipes[name] && alert("\"[name]\" already exists, do you want to overwrite it?",, "Yes", "No") == "No")
				return
			if(name && recording_recipe)
				for(var/reagent in recording_recipe)
					var/reagent_id = GLOB.name2reagent[translate_legacy_chem_id(reagent)]
					if(!dispensable_reagents.Find(reagent_id))
						visible_message("<span class='warning'>[src] buzzes.</span>", "<span class='hear'>You hear a faint buzz.</span>")
						to_chat(usr, "<span class ='danger'>[src] cannot find <b>[reagent]</b>!</span>")
						playsound(src, 'sound/machines/buzz-two.ogg', 50, TRUE)
						return
				saved_recipes[name] = recording_recipe
				recording_recipe = null
				. = TRUE
		if("cancel_recording")
			// if(!is_operational())
			// 	return
			recording_recipe = null
			. = TRUE



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

/obj/item/portable_chem_mixer/handle_atom_del(atom/A)
	..()
	if(A == beaker)
		beaker = null
		reagents.clear_reagents()




//---------------------------------------------------------
// Function to add to all chemicals at once (Multi-Cartridge perhaps)
/obj/item/portable_chem_mixer/proc/add_all_reagents(mob/living/user, amount)

	var/emptyspace = max_total_reagents - total_reagents	//How much space do we have?
	var/adjustedamount = min(amount*26, emptyspace)			//Either the amount fits in the space or we get the amount of space that is left back
	adjustedamount = adjustedamount/26						//What we get back, we divide by 26(number of reagents possible)
	
	for(var/re in dispensable_reagents)						//We add this amount to each chemical we have
		var/datum/reagent/R = dispensable_reagents[re]
		R.volume += adjustedamount

	total_reagents += adjustedamount*26						//Update the total amount of chemicals currently in the item