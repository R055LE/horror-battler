class_name EnemyRounds

# Returns Array of unit dicts for a given round number (1-10)
static func get_lineup(round_num: int) -> Array:
	var lineups := _build_lineups()
	var idx: int = clamp(round_num - 1, 0, lineups.size() - 1)
	return lineups[idx]


static func _unit(key: String, hp_override: int = -1, atk_override: int = -1) -> Dictionary:
	var base: Dictionary = UnitData.UNITS[key].duplicate()
	base["unit_key"] = key
	if hp_override >= 0:
		base["hp"] = hp_override
	if atk_override >= 0:
		base["atk"] = atk_override
	return base


static func _build_lineups() -> Array:
	return [
		# Round 1
		[_unit("crawling_molar")],
		# Round 2
		[_unit("leaking_eye"), _unit("leaking_eye")],
		# Round 3
		[_unit("rust_tick"), _unit("moth_lantern")],
		# Round 4
		[_unit("crawling_molar"), _unit("crawling_molar"), _unit("bone_radio")],
		# Round 5
		[_unit("frequency_worm"), _unit("frequency_worm"), _unit("frequency_worm")],
		# Round 6
		[_unit("gut_prophet"), _unit("gut_prophet"), _unit("moth_lantern")],
		# Round 7
		[_unit("host_sleeve"), _unit("host_sleeve"), _unit("rust_tick"), _unit("rust_tick")],
		# Round 8
		[_unit("antenna_corpse"), _unit("bone_radio"), _unit("bone_radio"), _unit("moth_lantern")],
		# Round 9
		[_unit("teeth_collector"), _unit("gut_prophet"), _unit("gut_prophet"), _unit("leaking_eye")],
		# Round 10 - Boss
		[_unit("teeth_collector", 15, 8), _unit("antenna_corpse"), _unit("antenna_corpse"),
		 _unit("frequency_worm"), _unit("frequency_worm")],
	]
