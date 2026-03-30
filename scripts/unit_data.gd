class_name UnitData

const UNITS: Dictionary = {
	"crawling_molar": {
		"name": "Crawling Molar", "hp": 3, "atk": 1,
		"tier": 1, "cost": 1, "tags": ["flesh", "swarm"], "ability": "",
		"color": Color(0.8, 0.2, 0.2)
	},
	"moth_lantern": {
		"name": "Moth Lantern", "hp": 2, "atk": 2,
		"tier": 1, "cost": 1, "tags": ["signal", "swarm"], "ability": "on_death_damage",
		"color": Color(0.4, 0.4, 0.9)
	},
	"leaking_eye": {
		"name": "Leaking Eye", "hp": 4, "atk": 1,
		"tier": 1, "cost": 1, "tags": ["flesh", "omen"], "ability": "",
		"color": Color(0.7, 0.3, 0.3)
	},
	"rust_tick": {
		"name": "Rust Tick", "hp": 2, "atk": 1,
		"tier": 1, "cost": 1, "tags": ["parasite", "swarm"], "ability": "steal_atk",
		"color": Color(0.5, 0.7, 0.2)
	},
	"bone_radio": {
		"name": "Bone Radio", "hp": 5, "atk": 3,
		"tier": 2, "cost": 2, "tags": ["signal", "relic"], "ability": "signal_buff",
		"color": Color(0.6, 0.6, 0.9)
	},
	"gut_prophet": {
		"name": "Gut Prophet", "hp": 6, "atk": 2,
		"tier": 2, "cost": 2, "tags": ["flesh", "omen"], "ability": "on_ally_death_atk",
		"color": Color(0.9, 0.4, 0.1)
	},
	"host_sleeve": {
		"name": "Host Sleeve", "hp": 4, "atk": 2,
		"tier": 2, "cost": 2, "tags": ["parasite", "flesh"], "ability": "copy_behind_atk",
		"color": Color(0.3, 0.8, 0.4)
	},
	"frequency_worm": {
		"name": "Frequency Worm", "hp": 3, "atk": 4,
		"tier": 2, "cost": 2, "tags": ["parasite", "signal"], "ability": "attack_weakest",
		"color": Color(0.2, 0.8, 0.8)
	},
	"teeth_collector": {
		"name": "The Teeth Collector", "hp": 8, "atk": 4,
		"tier": 3, "cost": 3, "tags": ["relic", "omen"], "ability": "on_kill_hp",
		"color": Color(0.8, 0.6, 0.1)
	},
	"antenna_corpse": {
		"name": "Antenna Corpse", "hp": 7, "atk": 5,
		"tier": 3, "cost": 3, "tags": ["signal", "relic"], "ability": "signal_first",
		"color": Color(0.5, 0.9, 0.9)
	},
}

const TAG_COLORS: Dictionary = {
	"flesh": Color(0.8, 0.2, 0.2),
	"swarm": Color(0.9, 0.8, 0.1),
	"signal": Color(0.2, 0.8, 0.9),
	"parasite": Color(0.2, 0.8, 0.3),
	"omen": Color(0.6, 0.2, 0.8),
	"relic": Color(0.9, 0.5, 0.1),
}

static func get_all_keys() -> Array:
	return UNITS.keys()

static func get_tier(tier: int) -> Array:
	var result: Array = []
	for key in UNITS:
		if UNITS[key]["tier"] == tier:
			result.append(key)
	return result
