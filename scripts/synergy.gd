class_name Synergy

# Applies synergy bonuses for one side at the start of combat.
# Must be called AFTER pre-combat abilities (so stat steals/copies land first).
# Mutates unit dicts in-place; emits stat_change events for visible bonuses.

static func apply(side: Array, events: Array, log: Array) -> void:
	var c: Dictionary = _count_tags(side)
	if c.is_empty():
		return
	_stat_bonuses(side, c, events, log)
	_passive_flags(side, c)


static func _count_tags(side: Array) -> Dictionary:
	var counts: Dictionary = {}
	for u in side:
		for tag in u.get("tags", []):
			counts[tag] = counts.get(tag, 0) + 1
	return counts


static func _stat_bonuses(side: Array, c: Dictionary, events: Array, log: Array) -> void:
	for u in side:
		var tags: Array = u.get("tags", [])
		var dh := 0
		var da := 0

		# Per-tag bonuses
		if "flesh"  in tags and c.get("flesh",  0) >= 2: dh += 1
		if "swarm"  in tags and c.get("swarm",  0) >= 2: da += 1
		if "signal" in tags and c.get("signal", 0) >= 2: da += 1

		# Global bonuses (apply to all units on side)
		if c.get("omen",  0) >= 2: dh += 1
		if c.get("relic", 0) >= 2: da += 1

		# Relic 3: damage reduction set here, not a HP/ATK number
		if "relic" in tags and c.get("relic", 0) >= 3:
			u["damage_reduction"] = 1

		if dh > 0:
			u["hp"] += dh
			log.append("  %s synergy +%dHP" % [u["name"], dh])
			events.append({"type": "stat_change", "side": u["side"], "slot": u["slot"],
				"stat": "hp", "new_val": u["hp"], "delta": dh})
		if da > 0:
			u["atk"] += da
			log.append("  %s synergy +%dATK" % [u["name"], da])
			events.append({"type": "stat_change", "side": u["side"], "slot": u["slot"],
				"stat": "atk", "new_val": u["atk"], "delta": da})


static func _passive_flags(side: Array, c: Dictionary) -> void:
	var flesh3:  bool = c.get("flesh",    0) >= 3
	var swarm3:  bool = c.get("swarm",    0) >= 3
	var signal3: bool = c.get("signal",   0) >= 3
	var para2:   bool = c.get("parasite", 0) >= 2
	var para3:   bool = c.get("parasite", 0) >= 3
	var omen3:   bool = c.get("omen",     0) >= 3

	for u in side:
		var tags: Array = u.get("tags", [])
		if flesh3  and "flesh"    in tags: u["flesh_regen"]      = true
		if swarm3  and "swarm"    in tags: u["swarm_double"]      = true
		if signal3 and "signal"   in tags: u["signal_protected"]  = true
		if para3   and "parasite" in tags:
			u["parasite_steal_atk"] = true
		elif para2 and "parasite" in tags:
			u["parasite_steal_hp"]  = true
		if omen3: u["omen_3"] = true
