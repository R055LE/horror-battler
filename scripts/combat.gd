class_name Combat

# Resolves combat and returns structured events for animation playback.
# Events: attack, death, stat_change, pre_combat, result

static func resolve(player_bench: Array, enemy_bench: Array) -> Dictionary:
	var events: Array = []
	var log: Array = []

	var pside: Array = _build_side(player_bench, "player")
	var eside: Array = _build_side(enemy_bench, "enemy")

	log.append("=== COMBAT START ===")
	log.append("Player: " + _bench_summary(pside))
	log.append("Enemy:  " + _bench_summary(eside))

	_apply_pre_combat(pside, eside, events, log)
	_apply_pre_combat(eside, pside, events, log)
	Synergy.apply(pside, events, log)
	Synergy.apply(eside, events, log)

	# Snapshot post-pre-combat, post-synergy state for animator
	var player_initial: Array = _snapshot(pside)
	var enemy_initial: Array  = _snapshot(eside)

	var turn := 0
	while _living(pside).size() > 0 and _living(eside).size() > 0:
		turn += 1
		if turn > 200:
			log.append("[!] Turn limit")
			break

		for atk_info in _get_turn_order(_living(pside), _living(eside)):
			var attacker: Dictionary = atk_info["unit"]
			var targets: Array     = atk_info["targets"]
			var own_side: Array    = atk_info["own_side"]

			if attacker["hp"] <= 0:
				continue
			var target: Variant = _pick_target(attacker, targets)
			if target == null:
				continue

			var dmg: int = max(1, attacker["atk"] - target.get("damage_reduction", 0))
			target["hp"] -= dmg

			log.append("  %s -> %s for %d (HP->%d)" % [
				attacker["name"], target["name"], dmg, target["hp"]])

			events.append({
				"type": "attack",
				"attacker_side": attacker["side"], "attacker_slot": attacker["slot"],
				"target_side":   target["side"],   "target_slot":   target["slot"],
				"damage": dmg,  "target_hp_after": target["hp"]
			})

			# Parasite on-hit steal (only if target survived the main hit)
			if target["hp"] > 0:
				if attacker.get("parasite_steal_atk", false) and target["atk"] > 0:
					target["atk"] -= 1
					attacker["atk"] += 1
					log.append("  %s steals 1 ATK (→%d)" % [attacker["name"], attacker["atk"]])
					events.append({"type": "stat_change", "side": target["side"], "slot": target["slot"],
						"stat": "atk", "new_val": target["atk"]})
					events.append({"type": "stat_change", "side": attacker["side"], "slot": attacker["slot"],
						"stat": "atk", "new_val": attacker["atk"], "delta": 1})
				elif attacker.get("parasite_steal_hp", false):
					target["hp"] -= 1
					attacker["hp"] += 1
					log.append("  %s steals 1 HP (→%d)" % [attacker["name"], attacker["hp"]])
					events.append({"type": "stat_change", "side": attacker["side"], "slot": attacker["slot"],
						"stat": "hp", "new_val": attacker["hp"], "delta": 1})

			if target["hp"] <= 0:
				log.append("  %s dies!" % target["name"])
				events.append({"type": "death", "side": target["side"], "slot": target["slot"]})
				var dead_side: Array = pside if target["side"] == "player" else eside
				_on_death(target, attacker, targets, events, log)
				_on_kill(attacker, events, log)
				_on_ally_death(target, dead_side, events, log)

			# Flesh regen: attacker heals 1 HP after each attack
			if attacker.get("flesh_regen", false) and attacker["hp"] > 0:
				attacker["hp"] += 1
				log.append("  %s flesh regen (HP→%d)" % [attacker["name"], attacker["hp"]])
				events.append({"type": "stat_change", "side": attacker["side"], "slot": attacker["slot"],
					"stat": "hp", "new_val": attacker["hp"], "delta": 1})

			# Swarm double: second attack at half ATK
			if attacker.get("swarm_double", false) and attacker["hp"] > 0:
				var second_target: Variant = _pick_target(attacker, targets)
				if second_target != null and second_target["hp"] > 0:
					var half_atk: int = max(1, attacker["atk"] / 2)
					var dmg2: int = max(1, half_atk - second_target.get("damage_reduction", 0))
					second_target["hp"] -= dmg2
					log.append("  %s swarm double -> %s for %d (HP→%d)" % [
						attacker["name"], second_target["name"], dmg2, second_target["hp"]])
					events.append({
						"type": "attack",
						"attacker_side": attacker["side"], "attacker_slot": attacker["slot"],
						"target_side": second_target["side"], "target_slot": second_target["slot"],
						"damage": dmg2, "target_hp_after": second_target["hp"]
					})
					if second_target["hp"] <= 0:
						log.append("  %s dies!" % second_target["name"])
						events.append({"type": "death", "side": second_target["side"], "slot": second_target["slot"]})
						var dead_side2: Array = pside if second_target["side"] == "player" else eside
						_on_death(second_target, attacker, targets, events, log)
						_on_kill(attacker, events, log)
						_on_ally_death(second_target, dead_side2, events, log)

			if _living(pside).is_empty() or _living(eside).is_empty():
				break

	var esurv: int  = _living(eside).size()
	var player_wins := esurv == 0
	log.append("=== %s WINS ===" % ("PLAYER" if player_wins else "ENEMY"))

	return {
		"player_wins": player_wins, "enemy_survivors": esurv,
		"events": events, "log": log,
		"player_initial": player_initial, "enemy_initial": enemy_initial
	}


static func _build_side(bench: Array, side_name: String) -> Array:
	var result: Array = []
	for i in range(bench.size()):
		if bench[i] != null:
			var u: Dictionary = bench[i].duplicate(true)
			u["slot"] = i
			u["side"] = side_name
			result.append(u)
	return result


static func _snapshot(side: Array) -> Array:
	var result: Array = []
	for u in side:
		result.append({
			"slot":  u["slot"],  "name": u["name"],
			"hp":    u["hp"],    "atk":  u["atk"],
			"color": u.get("color", Color(0.5, 0.5, 0.5)),
			"tags":  u.get("tags", [])
		})
	return result


static func _living(bench: Array) -> Array:
	var out: Array = []
	for u in bench:
		if u["hp"] > 0:
			out.append(u)
	return out


static func _bench_summary(bench: Array) -> String:
	var parts: Array = []
	for u in bench:
		parts.append("%s(%dHP/%dATK)" % [u["name"], u["hp"], u["atk"]])
	return ", ".join(parts)


static func _get_turn_order(pliving: Array, eliving: Array) -> Array:
	var p_ord: Array = _signal_first_order(pliving)
	var e_ord: Array = _signal_first_order(eliving)
	var order: Array = []
	var max_len: int = max(p_ord.size(), e_ord.size())
	for i in range(max_len):
		if i < p_ord.size():
			order.append({"unit": p_ord[i], "targets": e_ord, "own_side": p_ord})
		if i < e_ord.size():
			order.append({"unit": e_ord[i], "targets": p_ord, "own_side": e_ord})
	return order


static func _signal_first_order(side: Array) -> Array:
	for u in side:
		if u.get("ability", "") == "signal_first":
			var sig: Array   = side.filter(func(x): return "signal" in x.get("tags", []))
			var other: Array = side.filter(func(x): return not "signal" in x.get("tags", []))
			return sig + other
	return side


static func _pick_target(attacker: Dictionary, targets: Array) -> Variant:
	var living := _living(targets)
	if living.is_empty():
		return null
	if attacker.get("ability", "") == "attack_weakest":
		var weakest: Dictionary = living[0]
		for t in living:
			if t["hp"] < weakest["hp"]:
				weakest = t
		return weakest
	# Signal 3: skip protected units if any unprotected targets exist
	var unprotected: Array = living.filter(func(u): return not u.get("signal_protected", false))
	if not unprotected.is_empty():
		return unprotected[0]
	return living[0]


static func _apply_pre_combat(side: Array, other: Array, events: Array, log: Array) -> void:
	for u in side:
		match u.get("ability", ""):
			"steal_atk":
				var targets := _living(other)
				if not targets.is_empty():
					targets[0]["atk"] = max(0, targets[0]["atk"] - 1)
					u["atk"] += 1
					log.append("  %s steals 1 ATK from %s" % [u["name"], targets[0]["name"]])
					events.append({
						"type": "stat_transfer",
						"from_side": targets[0]["side"], "from_slot": targets[0]["slot"],
						"to_side": u["side"], "to_slot": u["slot"],
						"stat": "atk", "amount": 1
					})
			"copy_behind_atk":
				var idx: int = side.find(u)
				if idx > 0 and side[idx - 1]["hp"] > 0:
					u["atk"] = side[idx - 1]["atk"]
					log.append("  %s copies %d ATK" % [u["name"], u["atk"]])
					events.append({"type": "pre_combat", "side": u["side"], "slot": u["slot"],
						"description": "%s copies ATK" % u["name"]})
			"signal_buff":
				for ally in side:
					if "signal" in ally.get("tags", []) and ally != u:
						ally["atk"] += 1
						events.append({"type": "stat_change", "side": ally["side"], "slot": ally["slot"],
							"stat": "atk", "new_val": ally["atk"], "delta": 1})
				log.append("  %s buffs Signal allies" % u["name"])
				events.append({"type": "pre_combat", "side": u["side"], "slot": u["slot"],
					"description": "%s buffs Signal allies" % u["name"]})


static func _on_death(_unit: Dictionary, _killer: Dictionary, _targets: Array,
		_events: Array, log: Array) -> void:
	match _unit.get("ability", ""):
		"on_death_damage":
			var dmg := 1
			_killer["hp"] -= dmg
			log.append("  %s retaliates for %d (killer HP→%d)" % [_unit["name"], dmg, _killer["hp"]])
			_events.append({
				"type": "retaliation",
				"attacker_side": _unit["side"], "attacker_slot": _unit["slot"],
				"target_side": _killer["side"], "target_slot": _killer["slot"],
				"damage": dmg, "target_hp_after": _killer["hp"]
			})
			if _killer["hp"] <= 0:
				log.append("  %s dies from retaliation!" % _killer["name"])
				_events.append({"type": "death", "side": _killer["side"], "slot": _killer["slot"]})


static func _on_kill(killer: Dictionary, events: Array, log: Array) -> void:
	match killer.get("ability", ""):
		"on_kill_hp":
			killer["hp"] += 1
			log.append("  %s gains +1 HP (now %d)" % [killer["name"], killer["hp"]])
			events.append({"type": "stat_change", "side": killer["side"], "slot": killer["slot"],
				"stat": "hp", "new_val": killer["hp"], "delta": 1})


static func _on_ally_death(dead: Dictionary, own_side: Array, events: Array, log: Array) -> void:
	for u in own_side:
		if u["hp"] > 0:
			match u.get("ability", ""):
				"on_ally_death_atk":
					u["atk"] += 2
					log.append("  %s gains +2 ATK (now %d)" % [u["name"], u["atk"]])
					events.append({"type": "stat_change", "side": u["side"], "slot": u["slot"],
						"stat": "atk", "new_val": u["atk"], "delta": 2})
	# Omen 3: all surviving allies gain +1 ATK on any ally death
	var omen3_active := false
	for u in own_side:
		if u["hp"] > 0 and u.get("omen_3", false):
			omen3_active = true
			break
	if omen3_active:
		for u in own_side:
			if u["hp"] > 0:
				u["atk"] += 1
				log.append("  %s Omen 3 +1 ATK (→%d)" % [u["name"], u["atk"]])
				events.append({"type": "stat_change", "side": u["side"], "slot": u["slot"],
					"stat": "atk", "new_val": u["atk"], "delta": 1})
