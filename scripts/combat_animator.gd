class_name CombatAnimator
extends Node

const SLIDE_DURATION  := 0.18
const RETURN_DURATION := 0.13
const TURN_DELAY      := 0.32
const DEATH_DURATION  := 0.35
const UNIT_W          := 108.0
const UNIT_H          := 68.0

var _zone: Control
var _panels:     Dictionary = {}
var _unit_hp:    Dictionary = {}
var _unit_atk:   Dictionary = {}
var _unit_names: Dictionary = {}


func setup(zone: Control) -> void:
	_zone = zone


func play(events: Array, player_initial: Array, enemy_initial: Array) -> void:
	_clear()
	_spawn_side(player_initial, "player")
	_spawn_side(enemy_initial, "enemy")

	await get_tree().create_timer(0.2).timeout

	# Synergy activation sequence (player side only)
	var active := _active_synergies(player_initial)
	if not active.is_empty():
		_apply_synergy_glows(player_initial, active)
		await _show_synergy_banners(active)
		await get_tree().create_timer(0.1).timeout

	for event in events:
		match event["type"]:
			"pre_combat":
				_flash(_panels.get(event["side"] + "_" + str(event["slot"])))
				await get_tree().create_timer(0.18).timeout
			"attack":
				await _do_attack(event)
				await get_tree().create_timer(TURN_DELAY).timeout
			"death":
				await _do_death(event)
			"stat_change":
				_apply_stat_change(event)
			"stat_transfer":
				await _do_stat_transfer(event)
			"retaliation":
				await _do_retaliation(event)

	await get_tree().create_timer(0.4).timeout
	_clear()


# ── SYNERGY ───────────────────────────────────────────────────────────────────

func _active_synergies(units: Array) -> Dictionary:
	var counts: Dictionary = {}
	for u in units:
		for tag in u.get("tags", []):
			counts[tag] = counts.get(tag, 0) + 1
	var result: Dictionary = {}
	for tag in counts:
		if counts[tag] >= 2:
			result[tag] = counts[tag]
	return result


func _apply_synergy_glows(units: Array, active: Dictionary) -> void:
	for u in units:
		var active_tag := ""
		for tag in u.get("tags", []):
			if tag in active:
				active_tag = tag
				break
		if active_tag == "":
			continue
		var key: String = "player_" + str(u["slot"])
		var panel: Panel = _panels.get(key)
		if panel == null:
			continue

		var syn_color: Color = UnitData.TAG_COLORS.get(active_tag, Color(1, 1, 0))

		# Bold colored border
		var style := StyleBoxFlat.new()
		style.bg_color = u.get("color", Color(0.4, 0.4, 0.4))
		style.set_border_width_all(4)
		style.border_color = syn_color
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)

		# Tag pip in bottom-right corner — first 3 chars, clearly readable
		var pip := Label.new()
		pip.text = active_tag.substr(0, 3).to_upper()
		pip.add_theme_font_size_override("font_size", 10)
		pip.add_theme_color_override("font_color", syn_color)
		pip.position = Vector2(UNIT_W - 26.0, UNIT_H - 15.0)
		pip.z_index  = 2
		panel.add_child(pip)

		# Visible pulse — brightness swings clearly
		var tw := create_tween().set_loops(0)
		tw.tween_property(panel, "modulate", Color(1.35, 1.35, 1.35), 0.45).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(panel, "modulate", Color(1.0,  1.0,  1.0),  0.45).set_ease(Tween.EASE_IN_OUT)


func _show_synergy_banners(active: Dictionary) -> void:
	var zh: float = _zone.size.y if _zone.size.y > 10 else 180.0
	var zw: float = _zone.size.x if _zone.size.x > 10 else 1152.0
	var n: int    = active.size()
	var gap       := 8.0
	var bh        := 36.0
	var total_h   := n * bh + (n - 1) * gap
	var start_y   := (zh - total_h) * 0.5
	var i         := 0

	for tag in active:
		var y := start_y + i * (bh + gap)
		_spawn_banner(tag, active[tag], zw, y, i * 0.09)
		i += 1

	await get_tree().create_timer(n * 0.09 + 1.55).timeout


func _spawn_banner(tag: String, count: int, zw: float, y: float, delay: float) -> void:
	var syn_color: Color = UnitData.TAG_COLORS.get(tag, Color(0.8, 0.8, 0.2))

	var p := Panel.new()
	p.position = Vector2(-(zw - 32.0), y)  # starts off-screen left
	p.custom_minimum_size = Vector2(zw - 32.0, 36.0)
	p.modulate = Color(1, 1, 1, 0)
	p.z_index  = 5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(syn_color.r * 0.25, syn_color.g * 0.25, syn_color.b * 0.25, 0.97)
	style.set_border_width_all(2)
	style.border_color = syn_color
	style.set_corner_radius_all(5)
	p.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", syn_color)
	lbl.text = "◆  %s  (%d)  —  %s  ◆" % [
		tag.to_upper(), count, _bonus_text(tag, count)]
	p.add_child(lbl)
	_zone.add_child(p)

	var tw := create_tween()
	tw.tween_interval(delay)
	# Slide in from left and fade up simultaneously
	tw.tween_property(p, "position:x", 16.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(0.9)
	tw.tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)


func _bonus_text(tag: String, count: int) -> String:
	match tag:
		"flesh":    return "+1 HP" if count < 3 else "Regen 1 HP/atk"
		"swarm":    return "+1 ATK" if count < 3 else "Attack twice"
		"signal":   return "+1 ATK" if count < 3 else "Protected"
		"parasite": return "Steal 1 HP on hit" if count < 3 else "Steal 1 ATK on hit"
		"omen":     return "+1 HP all" if count < 3 else "Ally death → +1 ATK all"
		"relic":    return "+1 ATK all" if count < 3 else "-1 damage taken"
	return ""


# ── ATTACK / DEATH ────────────────────────────────────────────────────────────

func _do_attack(event: Dictionary) -> void:
	var a_key: String = event["attacker_side"] + "_" + str(event["attacker_slot"])
	var t_key: String = event["target_side"]   + "_" + str(event["target_slot"])
	var ap: Panel = _panels.get(a_key)
	var tp: Panel = _panels.get(t_key)
	if ap == null or tp == null:
		return

	var home_a := _home(event["attacker_side"], event["attacker_slot"])
	var home_t := _home(event["target_side"],   event["target_slot"])
	var lunge  := home_a.lerp(home_t, 0.42)

	var fwd := create_tween()
	fwd.tween_property(ap, "position", lunge, SLIDE_DURATION).set_ease(Tween.EASE_OUT)
	await fwd.finished

	_flash(tp)
	_show_damage(tp.position, event["damage"])
	_unit_hp[t_key] = event["target_hp_after"]
	_refresh_label(t_key)

	var back := create_tween()
	back.tween_property(ap, "position", home_a, RETURN_DURATION).set_ease(Tween.EASE_IN)
	await back.finished


func _do_death(event: Dictionary) -> void:
	var key: String = event["side"] + "_" + str(event["slot"])
	var panel: Panel = _panels.get(key)
	if panel == null:
		return
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, DEATH_DURATION)
	await tw.finished
	panel.queue_free()
	_panels.erase(key)


func _apply_stat_change(event: Dictionary) -> void:
	var key: String = event["side"] + "_" + str(event["slot"])
	var is_hp: bool = event["stat"] == "hp"
	if is_hp:
		_unit_hp[key]  = event["new_val"]
	else:
		_unit_atk[key] = event["new_val"]
	_refresh_label(key)
	_flash(_panels.get(key))
	var delta: int = event.get("delta", 0)
	if delta != 0:
		var panel: Panel = _panels.get(key)
		if panel != null:
			var color := Color(0.3, 1.0, 0.5) if is_hp else Color(1.0, 0.88, 0.2)
			_show_floating_text(panel.position, "+%d %s" % [delta, "HP" if is_hp else "ATK"], color, 15)


# ── HELPERS ───────────────────────────────────────────────────────────────────

func _clear() -> void:
	for key in _panels:
		if is_instance_valid(_panels[key]):
			_panels[key].queue_free()
	_panels.clear()
	_unit_hp.clear()
	_unit_atk.clear()
	_unit_names.clear()


func _spawn_side(units: Array, side: String) -> void:
	for u in units:
		var slot: int   = u["slot"]
		var key: String = side + "_" + str(slot)
		var panel       := _make_panel(u["name"], u["hp"], u["atk"], u.get("color", Color(0.4, 0.4, 0.4)))
		panel.position  = _home(side, slot)
		_zone.add_child(panel)
		_panels[key]     = panel
		_unit_hp[key]    = u["hp"]
		_unit_atk[key]   = u["atk"]
		_unit_names[key] = u["name"]


func _home(side: String, slot: int) -> Vector2:
	var zw: float = _zone.size.x if _zone.size.x > 10 else 1152.0
	var zh: float = _zone.size.y if _zone.size.y > 10 else 180.0
	var slot_w := zw / 5.0
	var x := slot * slot_w + (slot_w - UNIT_W) * 0.5
	var y := 6.0 if side == "enemy" else (zh - UNIT_H - 6.0)
	return Vector2(x, y)


func _flash(panel: Variant) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var tw := create_tween()
	tw.tween_property(panel, "modulate", Color(2.5, 2.5, 2.5), 0.07)
	tw.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.13)


func _flash_color(panel: Variant, color: Color) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var tw := create_tween()
	tw.tween_property(panel, "modulate", color, 0.07)
	tw.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.25)


func _show_damage(target_pos: Vector2, damage: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % damage
	lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15))
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.position = target_pos + Vector2(UNIT_W * 0.5 - 12.0, 4.0)
	lbl.z_index  = 10
	_zone.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 38.0, 0.55)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)


func _show_floating_text(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.position = pos + Vector2(UNIT_W * 0.5 - 22.0, -6.0)
	lbl.z_index  = 10
	_zone.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 44.0, 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)


func _do_stat_transfer(event: Dictionary) -> void:
	var from_key: String = event["from_side"] + "_" + str(event["from_slot"])
	var to_key: String   = event["to_side"]   + "_" + str(event["to_slot"])
	var from_panel: Panel = _panels.get(from_key)
	var to_panel:   Panel = _panels.get(to_key)
	if from_panel == null or to_panel == null:
		return

	var stat: String = event["stat"].to_upper()
	var amount: int  = event["amount"]

	# Red flash on source — it's losing the stat
	_flash_color(from_panel, Color(1.0, 0.25, 0.15))

	# Floating label travels from source center to dest center
	var start_pos := from_panel.position + Vector2(UNIT_W * 0.5 - 18.0, UNIT_H * 0.4)
	var end_pos   := to_panel.position   + Vector2(UNIT_W * 0.5 - 18.0, UNIT_H * 0.4)

	var lbl := Label.new()
	lbl.text = "%d %s" % [amount, stat]
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = start_pos
	lbl.z_index  = 10
	_zone.add_child(lbl)

	var tw := create_tween()
	tw.tween_property(lbl, "position", end_pos, 0.48).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	lbl.queue_free()

	# Green flash on dest — it gained the stat
	_flash_color(to_panel, Color(0.3, 1.0, 0.5))
	await get_tree().create_timer(0.12).timeout


func _do_retaliation(event: Dictionary) -> void:
	var t_key: String = event["target_side"] + "_" + str(event["target_slot"])
	var tp: Panel = _panels.get(t_key)
	if tp == null:
		return
	# Amber flash — distinct from normal white hit flash
	_flash_color(tp, Color(1.0, 0.55, 0.05))
	_show_damage(tp.position, event["damage"])
	_unit_hp[t_key] = event["target_hp_after"]
	_refresh_label(t_key)
	await get_tree().create_timer(0.3).timeout


func _refresh_label(key: String) -> void:
	var panel: Panel = _panels.get(key)
	if panel == null:
		return
	var lbl: Label = panel.get_node_or_null("Label")
	if lbl == null:
		return
	lbl.text = "%s\n%dHP %dATK" % [
		_unit_names.get(key, "?"),
		_unit_hp.get(key, 0),
		_unit_atk.get(key, 0)
	]


func _make_panel(unit_name: String, hp: int, atk: int, color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(UNIT_W, UNIT_H)
	p.size = Vector2(UNIT_W, UNIT_H)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.85, 0.85)
	style.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = "%s\n%dHP %dATK" % [unit_name, hp, atk]
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(lbl)
	return p
