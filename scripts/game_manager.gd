extends Node2D

const MAX_BENCH_SLOTS := 5
const STARTING_HEALTH := 10
const STARTING_GOLD   := 10
const GOLD_PER_ROUND  := 10
const REROLL_COST     := 1
const SELL_VALUE      := 1
const SHOP_SIZE       := 3

enum State { SHOP, COMBAT, RESULT }

var state: State       = State.SHOP
var current_round: int = 1
var player_health: int = STARTING_HEALTH
var player_gold: int   = STARTING_GOLD
var win_streak: int    = 0

var player_bench: Array   = []
var shop_offerings: Array = []
var selected_bench_slot: int = -1
var _prev_gold: int = STARTING_GOLD

# UI refs
var _round_label:   Label
var _gold_label:    Label
var _synergy_row: HBoxContainer
var _combat_log:    RichTextLabel
var _combat_zone:   Control
var _bench_row:     HBoxContainer
var _enemy_row:     HBoxContainer
var _bench_slots:   Array = []
var _enemy_slots:   Array = []
var _shop_panels:   Array = []
var _fight_btn:     Button
var _hearts:        Array = []   # 10 Label nodes showing ♥

# Overlays
var _round_overlay:       Panel
var _round_overlay_title: Label
var _round_overlay_sub:   Label
var _result_panel:        Panel
var _result_label:        Label

var _animator: CombatAnimator


func _ready() -> void:
	player_bench.resize(MAX_BENCH_SLOTS)
	_build_ui()
	_animator = CombatAnimator.new()
	add_child(_animator)
	_animator.setup(_combat_zone)
	_generate_shop()
	_refresh_ui()


# ── UI CONSTRUCTION ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	canvas.add_child(root)

	# ── Top bar ──
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 40)
	top_bar.add_theme_constant_override("separation", 8)
	root.add_child(top_bar)

	_round_label = _label("ROUND: 1/10")
	_round_label.custom_minimum_size = Vector2(130, 0)
	top_bar.add_child(_round_label)
	top_bar.add_child(VSeparator.new())

	# Hearts row
	var heart_container := HBoxContainer.new()
	heart_container.alignment = BoxContainer.ALIGNMENT_CENTER
	heart_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heart_container.add_theme_constant_override("separation", 2)
	top_bar.add_child(heart_container)
	for i in range(STARTING_HEALTH):
		var h := Label.new()
		h.text = "♥"
		h.add_theme_font_size_override("font_size", 20)
		h.add_theme_color_override("font_color", Color(0.95, 0.18, 0.28))
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hearts.append(h)
		heart_container.add_child(h)

	top_bar.add_child(VSeparator.new())
	_gold_label = _label("10 g")
	_gold_label.custom_minimum_size = Vector2(80, 0)
	_gold_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(_gold_label)

	# ── Enemy bench ──
	root.add_child(_label("— ENEMY —"))
	_enemy_row = HBoxContainer.new()
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_enemy_row)
	for _i in range(MAX_BENCH_SLOTS):
		var s := _unit_panel("?", Color(0.25, 0.25, 0.25))
		_enemy_slots.append(s)
		_enemy_row.add_child(s)

	# ── Combat zone ──
	_combat_zone = Control.new()
	_combat_zone.custom_minimum_size = Vector2(0, 180)
	_combat_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_zone.clip_contents = true
	_combat_zone.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root.add_child(_combat_zone)

	# ── Player bench ──
	root.add_child(_label("— YOUR BENCH —"))
	_bench_row = HBoxContainer.new()
	_bench_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_bench_row)
	for i in range(MAX_BENCH_SLOTS):
		var s := _unit_panel("empty", Color(0.15, 0.15, 0.15))
		s.gui_input.connect(_on_bench_input.bind(i))
		_bench_slots.append(s)
		_bench_row.add_child(s)

	_synergy_row = HBoxContainer.new()
	_synergy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_synergy_row.add_theme_constant_override("separation", 6)
	_synergy_row.custom_minimum_size = Vector2(0, 30)
	root.add_child(_synergy_row)

	# ── Shop ──
	root.add_child(_label("— SHOP —"))
	var shop_row := HBoxContainer.new()
	shop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(shop_row)
	for i in range(SHOP_SIZE):
		var s := _unit_panel("...", Color(0.12, 0.12, 0.28))
		s.gui_input.connect(_on_shop_input.bind(i))
		_shop_panels.append(s)
		shop_row.add_child(s)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(btn_row)
	var reroll := Button.new()
	reroll.text = "REROLL (1g)"
	reroll.pressed.connect(_on_reroll)
	btn_row.add_child(reroll)
	_fight_btn = Button.new()
	_fight_btn.text = "FIGHT!"
	_fight_btn.pressed.connect(_on_fight)
	btn_row.add_child(_fight_btn)

	_combat_log = RichTextLabel.new()
	_combat_log.custom_minimum_size = Vector2(0, 60)
	_combat_log.bbcode_enabled  = true
	_combat_log.scroll_following = true
	root.add_child(_combat_log)

	# ── Round result overlay (hidden) ──
	_round_overlay = Panel.new()
	_round_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_round_overlay.custom_minimum_size = Vector2(380, 160)
	_round_overlay.visible   = false
	_round_overlay.modulate  = Color(1, 1, 1, 0)
	_round_overlay.z_index   = 20
	var ov_style := StyleBoxFlat.new()
	ov_style.bg_color = Color(0.06, 0.06, 0.1, 0.92)
	ov_style.set_border_width_all(2)
	ov_style.border_color = Color(0.5, 0.5, 0.6)
	ov_style.set_corner_radius_all(8)
	_round_overlay.add_theme_stylebox_override("panel", ov_style)
	canvas.add_child(_round_overlay)

	var ov_vbox := VBoxContainer.new()
	ov_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ov_vbox.add_theme_constant_override("separation", 10)
	_round_overlay.add_child(ov_vbox)

	_round_overlay_title = Label.new()
	_round_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_overlay_title.add_theme_font_size_override("font_size", 42)
	ov_vbox.add_child(_round_overlay_title)

	_round_overlay_sub = Label.new()
	_round_overlay_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_overlay_sub.add_theme_font_size_override("font_size", 18)
	_round_overlay_sub.modulate = Color(0.85, 0.85, 0.85)
	ov_vbox.add_child(_round_overlay_sub)

	# ── Game-over result panel (hidden) ──
	_result_panel = Panel.new()
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.custom_minimum_size = Vector2(360, 180)
	_result_panel.visible = false
	_result_panel.z_index = 30
	canvas.add_child(_result_panel)
	var rv := VBoxContainer.new()
	rv.set_anchors_preset(Control.PRESET_FULL_RECT)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_panel.add_child(rv)
	_result_label = _label("")
	_result_label.add_theme_font_size_override("font_size", 22)
	rv.add_child(_result_label)
	var rb := Button.new()
	rb.text = "RESTART"
	rb.pressed.connect(_on_restart)
	rv.add_child(rb)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _unit_panel(display: String, color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(110, 76)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.55, 0.55)
	p.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = display
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(lbl)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


# ── SHOP ─────────────────────────────────────────────────────────────────────

func _generate_shop() -> void:
	shop_offerings.clear()
	var pool := UnitData.get_all_keys()
	pool.shuffle()
	for i in range(SHOP_SIZE):
		shop_offerings.append(pool[i % pool.size()])


func _on_shop_input(event: InputEvent, idx: int) -> void:
	if state != State.SHOP:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_buy(idx)


func _buy(shop_idx: int) -> void:
	if shop_idx >= shop_offerings.size() or shop_offerings[shop_idx] == "":
		return
	var key: String = shop_offerings[shop_idx]
	var cost: int   = UnitData.UNITS[key]["cost"]
	if player_gold < cost:
		_log("[color=red]Not enough gold![/color]")
		return
	var empty := _first_empty()
	if empty == -1:
		_log("[color=red]Bench is full![/color]")
		return
	player_gold -= cost
	var unit: Dictionary = UnitData.UNITS[key].duplicate(true)
	unit["unit_key"]      = key
	unit["upgrade_level"] = 0
	var existing := _find_on_bench(key)
	if existing >= 0:
		_merge(existing)
	else:
		player_bench[empty] = unit
	shop_offerings[shop_idx] = ""
	_refresh_ui()


func _merge(bench_slot: int) -> void:
	var u: Dictionary    = player_bench[bench_slot]
	var base: Dictionary = UnitData.UNITS[u["unit_key"]]
	u["upgrade_level"] += 1
	if u["upgrade_level"] == 1:
		u["hp"]  = ceili(base["hp"]  * 1.5)
		u["atk"] = ceili(base["atk"] * 1.5)
	else:
		u["hp"]  = base["hp"]  * 2
		u["atk"] = base["atk"] * 2
	_log("[color=yellow]%s upgraded to level %d![/color]" % [u["name"], u["upgrade_level"]])


func _on_reroll() -> void:
	if state != State.SHOP or player_gold < REROLL_COST:
		return
	player_gold -= REROLL_COST
	_generate_shop()
	_refresh_ui()


func _on_bench_input(event: InputEvent, slot_idx: int) -> void:
	if state != State.SHOP:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_bench_click(slot_idx)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_sell(slot_idx)


func _bench_click(idx: int) -> void:
	if selected_bench_slot == -1:
		if player_bench[idx] != null:
			selected_bench_slot = idx
			_refresh_ui()
	else:
		var tmp = player_bench[selected_bench_slot]
		player_bench[selected_bench_slot] = player_bench[idx]
		player_bench[idx] = tmp
		selected_bench_slot = -1
		_refresh_ui()


func _sell(idx: int) -> void:
	if player_bench[idx] == null:
		return
	_log("Sold %s for %dg" % [player_bench[idx]["name"], SELL_VALUE])
	player_gold += SELL_VALUE
	player_bench[idx] = null
	_refresh_ui()


# ── COMBAT ────────────────────────────────────────────────────────────────────

func _on_fight() -> void:
	if state != State.SHOP:
		return
	if _get_active().is_empty():
		_log("[color=red]Place at least one unit first![/color]")
		return

	state = State.COMBAT
	_fight_btn.disabled = true

	var enemy_lineup: Array = EnemyRounds.get_lineup(current_round)
	var result: Dictionary  = Combat.resolve(player_bench, enemy_lineup)
	for line in result["log"]:
		print(line)

	await _reveal_enemy_bench(enemy_lineup)

	_enemy_row.visible = false
	_bench_row.visible = false
	await _animator.play(result["events"], result["player_initial"], result["enemy_initial"])
	_enemy_row.visible = true
	_bench_row.visible = true

	if result["player_wins"]:
		win_streak += 1
		var bonus: int = min(win_streak, 3)
		await _show_round_result(true, 0)
		current_round += 1
		if current_round > 10:
			_end_game(true)
			return
		player_gold = GOLD_PER_ROUND + bonus
	else:
		win_streak = 0
		var dmg: int   = result["enemy_survivors"]
		var old_hp: int = player_health
		player_health -= dmg
		_animate_heart_loss(old_hp, player_health)
		await _show_round_result(false, dmg)
		current_round += 1
		if player_health <= 0:
			_end_game(false)
			return
		player_gold = GOLD_PER_ROUND

	# Reset enemy slots back to ? for next round
	for i in range(MAX_BENCH_SLOTS):
		var ep: Panel = _enemy_slots[i]
		ep.modulate = Color(1, 1, 1, 1)
		var es := StyleBoxFlat.new()
		es.bg_color = Color(0.25, 0.25, 0.25)
		es.set_border_width_all(2)
		es.border_color = Color(0.45, 0.45, 0.45)
		ep.add_theme_stylebox_override("panel", es)
		ep.get_node("Label").text = "?"

	state = State.SHOP
	_fight_btn.disabled = false
	_generate_shop()
	_refresh_ui()


func _get_active() -> Array:
	var out: Array = []
	for u in player_bench:
		if u != null:
			out.append(u)
	return out


func _reveal_enemy_bench(lineup: Array) -> void:
	# Update all slots with real data while still transparent
	for i in range(MAX_BENCH_SLOTS):
		var p: Panel = _enemy_slots[i]
		p.modulate = Color(1, 1, 1, 0)
		var style := StyleBoxFlat.new()
		style.set_border_width_all(2)
		if i < lineup.size():
			var u: Dictionary = lineup[i]
			style.bg_color     = u.get("color", Color(0.4, 0.4, 0.4))
			style.border_color = Color(0.7, 0.7, 0.7)
			p.get_node("Label").text = "%s\n%dHP %dATK" % [u["name"], u["hp"], u["atk"]]
		else:
			style.bg_color     = Color(0.1, 0.1, 0.1)
			style.border_color = Color(0.25, 0.25, 0.25)
			p.get_node("Label").text = "—"
		p.add_theme_stylebox_override("panel", style)

	# Staggered flash-reveal left to right
	for i in range(lineup.size()):
		var p: Panel = _enemy_slots[i]
		var tw := create_tween()
		tw.tween_interval(i * 0.13)
		tw.tween_property(p, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.07)
		tw.tween_property(p, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)

	# Wait for all flashes to complete + brief reading pause
	await get_tree().create_timer(lineup.size() * 0.13 + 0.45).timeout


# ── ROUND RESULT OVERLAY ──────────────────────────────────────────────────────

func _show_round_result(won: bool, damage: int) -> void:
	if won:
		_round_overlay_title.text = "VICTORY"
		_round_overlay_title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
		_round_overlay_sub.text   = "Round %d cleared!" % current_round
	else:
		_round_overlay_title.text = "DEFEAT"
		_round_overlay_title.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28))
		_round_overlay_sub.text   = "Lost %d HP" % damage if damage > 0 else "Somehow survived..."

	_round_overlay.visible  = true
	_round_overlay.modulate = Color(1, 1, 1, 0)

	var tw_in := create_tween()
	tw_in.tween_property(_round_overlay, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	await tw_in.finished

	await get_tree().create_timer(1.4).timeout

	var tw_out := create_tween()
	tw_out.tween_property(_round_overlay, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await tw_out.finished
	_round_overlay.visible = false


# ── HEART ANIMATION ───────────────────────────────────────────────────────────

func _animate_heart_loss(old_hp: int, new_hp: int) -> void:
	# Animate hearts that are newly dead (high index first for dramatic effect)
	for i in range(STARTING_HEALTH - 1, -1, -1):
		var was_alive := i < old_hp
		var now_alive := i < new_hp
		if was_alive and not now_alive:
			var h: Label = _hearts[i]
			var tw := create_tween()
			tw.tween_property(h, "modulate", Color(0.9, 0.9, 0.9, 1.0), 0.06)
			tw.tween_property(h, "modulate", Color(0.22, 0.05, 0.07, 1.0), 0.25)
			tw.parallel().tween_property(h, "scale", Vector2(0.6, 0.6), 0.25).set_ease(Tween.EASE_IN)


func _sync_hearts() -> void:
	for i in range(STARTING_HEALTH):
		var h: Label = _hearts[i]
		if i < player_health:
			h.modulate = Color(0.95, 0.18, 0.28)
			h.scale    = Vector2.ONE
		else:
			h.modulate = Color(0.22, 0.05, 0.07)
			h.scale    = Vector2(0.6, 0.6)


# ── GOLD FLASH ────────────────────────────────────────────────────────────────

func _flash_gold(delta: int) -> void:
	var target_color := Color(0.4, 1.0, 0.45) if delta > 0 else Color(1.0, 0.75, 0.15)
	var tw := create_tween()
	tw.tween_property(_gold_label, "modulate", target_color, 0.08)
	tw.tween_property(_gold_label, "modulate", Color(1, 1, 1), 0.35)


# ── GAME OVER ─────────────────────────────────────────────────────────────────

func _end_game(won: bool) -> void:
	state = State.RESULT
	_result_panel.visible = true
	_result_label.text = "YOU WIN!\nAll 10 rounds survived." if won \
		else "GAME OVER\nYour bench was destroyed."


func _on_restart() -> void:
	get_tree().reload_current_scene()


# ── REFRESH ───────────────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	_round_label.text = "ROUND: %d/10" % current_round

	# Gold — flash on change
	var gold_delta := player_gold - _prev_gold
	_gold_label.text = "%d g" % player_gold
	if _prev_gold != player_gold:
		_flash_gold(gold_delta)
	_prev_gold = player_gold

	# Hearts — sync without animation (animation is explicit via _animate_heart_loss)
	_sync_hearts()

	for i in range(MAX_BENCH_SLOTS):
		var p: Panel = _bench_slots[i]
		var style := StyleBoxFlat.new()
		style.set_border_width_all(2)
		if player_bench[i] != null:
			var u: Dictionary = player_bench[i]
			var upgrade: int = u.get("upgrade_level", 0)
			style.bg_color = u.get("color", Color(0.4, 0.4, 0.4)).lerp(Color.WHITE, upgrade * 0.07)
			if selected_bench_slot == i:
				style.border_color = Color.WHITE
				style.set_border_width_all(3)
			elif upgrade == 2:
				style.border_color = Color(1.0, 0.78, 0.1)   # gold
				style.set_border_width_all(4)
			elif upgrade == 1:
				style.border_color = Color(0.75, 0.75, 0.95)  # silver
				style.set_border_width_all(3)
			else:
				style.border_color = Color(0.6, 0.6, 0.6)
			var stars: String = "★".repeat(upgrade)
			p.get_node("Label").text = "%s\n%dHP %dATK%s" % [
				u["name"], u["hp"], u["atk"],
				"  " + stars if stars != "" else ""]
		else:
			style.bg_color     = Color(0.12, 0.12, 0.12)
			style.border_color = Color(0.35, 0.35, 0.35)
			p.get_node("Label").text = "empty"
		p.add_theme_stylebox_override("panel", style)

	for i in range(SHOP_SIZE):
		var p: Panel = _shop_panels[i]
		var style := StyleBoxFlat.new()
		style.set_border_width_all(2)
		if i < shop_offerings.size() and shop_offerings[i] != "":
			var u: Dictionary = UnitData.UNITS[shop_offerings[i]]
			style.bg_color     = u.get("color", Color(0.3, 0.3, 0.5))
			style.border_color = Color(0.6, 0.6, 0.6)
			p.get_node("Label").text = "%s\n%dg — %dHP %dATK" % [
				u["name"], u["cost"], u["hp"], u["atk"]]
		else:
			style.bg_color     = Color(0.08, 0.08, 0.18)
			style.border_color = Color(0.25, 0.25, 0.25)
			p.get_node("Label").text = "— sold —"
		p.add_theme_stylebox_override("panel", style)

	_rebuild_synergy_chips()


func _rebuild_synergy_chips() -> void:
	for child in _synergy_row.get_children():
		child.queue_free()

	var counts: Dictionary = {}
	for u in player_bench:
		if u == null:
			continue
		for tag in u.get("tags", []):
			counts[tag] = counts.get(tag, 0) + 1

	if counts.is_empty():
		var placeholder := _label("No synergies")
		placeholder.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		_synergy_row.add_child(placeholder)
		return

	# All 6 tags in a fixed order so layout is stable
	var tag_order := ["flesh", "swarm", "signal", "parasite", "omen", "relic"]
	for tag in tag_order:
		if not counts.has(tag):
			continue
		var count: int  = counts[tag]
		var active: bool = count >= 2
		_synergy_row.add_child(_make_synergy_chip(tag, count, active))


func _make_synergy_chip(tag: String, count: int, active: bool) -> Panel:
	var base: Color = UnitData.TAG_COLORS.get(tag, Color(0.5, 0.5, 0.5))
	var p := Panel.new()
	p.custom_minimum_size = Vector2(104, 30)

	var style := StyleBoxFlat.new()
	if active:
		style.bg_color     = Color(base.r * 0.42, base.g * 0.42, base.b * 0.42)
		style.border_color = base
		style.set_border_width_all(2)
	else:
		style.bg_color     = Color(0.07, 0.07, 0.07)
		style.border_color = Color(0.22, 0.22, 0.22)
		style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	if active:
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.text = "◆ %s  %d" % [tag.capitalize(), count]
	else:
		lbl.add_theme_color_override("font_color", Color(0.28, 0.28, 0.28))
		lbl.text = "%s  %d" % [tag.capitalize(), count]
	p.add_child(lbl)
	return p


# ── HELPERS ───────────────────────────────────────────────────────────────────

func _first_empty() -> int:
	for i in range(MAX_BENCH_SLOTS):
		if player_bench[i] == null:
			return i
	return -1


func _find_on_bench(key: String) -> int:
	for i in range(MAX_BENCH_SLOTS):
		if player_bench[i] != null and player_bench[i].get("unit_key", "") == key:
			return i
	return -1


func _log(text: String) -> void:
	_combat_log.append_text(text + "\n")
	print(text)
