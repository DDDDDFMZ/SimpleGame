class_name BattleHUD
extends Control

signal spawn_requested(def_id: String)
signal build_requested(slot: int)
signal lane_requested(lane: int)
signal minimap_clicked(lane: int, world_x: float)
signal world_clicked(screen_pos: Vector2, additive: bool)
signal world_drag(rect: Rect2, additive: bool)
signal world_right_click(screen_pos: Vector2, shift: bool)

const VIEW_W := 640.0
const TOP_H := 64.0
const BOTTOM_Y := 300.0
const CARD_Y := 306.0
const CARD_W := 88.0
const CARD_H := 48.0
const CARD_GAP := 4.0
const CARD_X := 8.0
const BUILD_RECT := Rect2(564.0, 306.0, 68.0, 48.0)
const WORLD_W := 1600.0
const CAM_VIEW_W := 640.0
const MINIMAP_RECT := Rect2(430.0, 6.0, 202.0, 52.0)
const MINIMAP_BAR_X := 448.0
const MINIMAP_BAR_W := 178.0
const MINIMAP_BAR_H := 14.0
const MINIMAP_LANE_Y := [11.0, 33.0]
const SLOT_NAMES := ["FARM A", "FARM B", "BARRACKS TOP", "BARRACKS DOWN"]

var snapshot: Dictionary = {}
var active_lane: int = 0
var panel_open: bool = false
var camera_x: float = 320.0
var follow_mode: bool = true

var drag_active: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func update_snapshot(p_snapshot: Dictionary, p_active_lane: int) -> void:
	snapshot = p_snapshot
	active_lane = clampi(p_active_lane, 0, 1)
	queue_redraw()


func set_camera(p_camera_x: float, p_follow: bool) -> void:
	camera_x = p_camera_x
	follow_mode = p_follow
	queue_redraw()


func toggle_panel() -> void:
	panel_open = not panel_open
	queue_redraw()


func close_panel() -> void:
	panel_open = false
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return

	# Top bar.
	draw_rect(Rect2(0.0, 0.0, VIEW_W, TOP_H), Color(0.07, 0.06, 0.10, 0.95))
	draw_line(Vector2(0.0, TOP_H), Vector2(VIEW_W, TOP_H), Color(0.2, 0.18, 0.26), 1.0)

	var gold := int(snapshot.get("gold", 0))
	var income := float(snapshot.get("income", 0.0))
	var pop_used := int(snapshot.get("pop_used", 0))
	var pop_max := int(snapshot.get("pop_max", 10))
	var hp: Array = snapshot.get("base_hp", [0, 0])
	var hp_max := int(snapshot.get("base_hp_max", 20))
	var wave_index := int(snapshot.get("wave_index", 0))
	var wave_count := int(snapshot.get("wave_count", 0))
	var next_in := float(snapshot.get("next_wave_in", 0.0))
	var level_name := String(snapshot.get("level_name", "Sandbox"))

	draw_string(font, Vector2(8.0, 13.0), "GOLD %d (+%.1f/s)   POP %d/%d   BASE %d/%d" % [gold, income, pop_used, pop_max, int(hp[0]), hp_max], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#E8D5A9"))
	draw_string(font, Vector2(8.0, 27.0), "%s   LANE %d   CAM %s   WAVE %d/%d   NEXT %.0fs" % [level_name, active_lane + 1, "FOLLOW" if follow_mode else "FREE", wave_index, wave_count, next_in], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
	draw_string(font, Vector2(8.0, 41.0), "LMB select/drag   RMB move   Shift+RMB line   H hold   R return   F follow   B build   Ctrl+R retry", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))

	var message := String(snapshot.get("message", ""))
	if message != "":
		draw_string(font, Vector2(8.0, 58.0), message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E08A3C"))

	var error := String(snapshot.get("error", ""))
	if error != "":
		_center_text(font, error, 295.0, 9, Color("#E06666"))

	_draw_minimap(font)

	# Bottom bar.
	draw_rect(Rect2(0.0, BOTTOM_Y, VIEW_W, 360.0 - BOTTOM_Y), Color(0.07, 0.06, 0.10, 0.96))
	draw_line(Vector2(0.0, BOTTOM_Y), Vector2(VIEW_W, BOTTOM_Y), Color(0.2, 0.18, 0.26), 1.0)

	var catalog: Array = snapshot.get("catalog", [])
	var cooldowns: Array = snapshot.get("cooldowns", [{}, {}])
	var cd_map: Dictionary = cooldowns[active_lane] if active_lane < cooldowns.size() else {}
	for i in range(mini(catalog.size(), 6)):
		_draw_card(font, i, catalog[i], cd_map, gold, pop_used, pop_max)

	# Build button.
	draw_rect(BUILD_RECT, Color("#252232"))
	draw_rect(BUILD_RECT, Color("#D9A441") if panel_open else Color("#4A4658"), false, 1.0)
	draw_string(font, BUILD_RECT.position + Vector2(9.0, 19.0), "BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9"))
	draw_string(font, BUILD_RECT.position + Vector2(19.0, 33.0), "[B]", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))

	if panel_open:
		_draw_buildings(font)

	if drag_active:
		var drag_rect := Rect2(drag_start, drag_end - drag_start).abs()
		draw_rect(drag_rect, Color(0.42, 0.66, 0.89, 0.14))
		draw_rect(drag_rect, Color("#6FA8DC"), false, 1.0)

	if bool(snapshot.get("finished", false)):
		_draw_result(font)


func _draw_minimap(font: Font) -> void:
	draw_rect(MINIMAP_RECT, Color(0.05, 0.04, 0.08, 0.96))
	draw_rect(MINIMAP_RECT, Color("#4A4658"), false, 1.0)

	var base_x := float(snapshot.get("player_base_x", 80.0))
	var enemy_x := float(snapshot.get("enemy_base_x", 1520.0))
	var lines: Array = snapshot.get("advance_lines", [92.0, 92.0])
	var units: Array = snapshot.get("units", [])

	for lane in range(2):
		var y := float(MINIMAP_LANE_Y[lane])
		var bar := Rect2(MINIMAP_BAR_X, y, MINIMAP_BAR_W, MINIMAP_BAR_H)
		draw_rect(bar, Color("#1A1724"))
		draw_rect(bar, Color("#D9A441") if lane == active_lane else Color("#4A4658"), false, 1.0)
		draw_string(font, Vector2(434.0, y + 11.0), "L%d" % (lane + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9"))

		# Bases.
		var px := _minimap_x(base_x)
		var ex := _minimap_x(enemy_x)
		draw_rect(Rect2(px - 1.0, y + 2.0, 2.0, bar.size.y - 4.0), Color("#6FA8DC"))
		draw_rect(Rect2(ex - 1.0, y + 2.0, 2.0, bar.size.y - 4.0), Color("#E06666"))

		# Advance line.
		if lane < lines.size():
			var lx := _minimap_x(float(lines[lane]))
			draw_line(Vector2(lx, y + 1.0), Vector2(lx, y + bar.size.y - 1.0), Color("#D9A441"), 1.0)

		# Units.
		for u in units:
			if int(u.get("lane", -1)) != lane:
				continue
			var ux := _minimap_x(float(u.get("x", 0.0)))
			var color := Color("#6FA8DC") if int(u.get("team", 0)) == 0 else Color("#E06666")
			draw_rect(Rect2(ux - 1.0, y + 5.0, 2.0, 4.0), color)

		# Camera viewport.
		var cam_left := _minimap_x(clampf(camera_x - CAM_VIEW_W * 0.5, 0.0, WORLD_W))
		var cam_right := _minimap_x(clampf(camera_x + CAM_VIEW_W * 0.5, 0.0, WORLD_W))
		draw_rect(Rect2(cam_left, y + 1.0, maxf(8.0, cam_right - cam_left), bar.size.y - 2.0), Color(1.0, 1.0, 1.0, 0.35), false, 1.0)


func _draw_card(font: Font, index: int, card: Dictionary, cd_map: Dictionary, gold: int, pop_used: int, pop_max: int) -> void:
	var r := _card_rect(index)
	var def_id := String(card.get("id", ""))
	var cost := int(card.get("cost", 0))
	var pop := int(card.get("pop", 1))
	var cd := float(cd_map.get(def_id, 0.0))
	var can_gold := gold >= cost
	var can_pop := pop_used + pop <= pop_max
	var ready := cd <= 0.0

	draw_rect(r, Color("#1A1724"))
	var border := Color("#6FA8DC") if ready and can_gold and can_pop else Color("#4A4658")
	draw_rect(r, border, false, 1.0)
	draw_string(font, r.position + Vector2(5.0, 14.0), String(card.get("name", def_id)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9"))
	draw_string(font, r.position + Vector2(5.0, 28.0), "%dg  p%d" % [cost, pop], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#D9A441") if can_gold else Color("#E06666"))
	draw_string(font, r.position + Vector2(5.0, 41.0), "[%d]" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6B6B6B"))

	if not ready:
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.55))
		_center_text_in(font, "%.1fs" % cd, r, 9, Color.WHITE)
	elif not can_gold:
		draw_rect(r, Color(0.35, 0.05, 0.05, 0.35))
		_center_text_in(font, "GOLD", r, 8, Color("#E06666"))
	elif not can_pop:
		draw_rect(r, Color(0.35, 0.05, 0.05, 0.35))
		_center_text_in(font, "POP", r, 8, Color("#E06666"))


func _draw_buildings(font: Font) -> void:
	var panel := Rect2(140.0, 66.0, 360.0, 206.0)
	draw_rect(panel, Color(0.07, 0.06, 0.10, 0.98))
	draw_rect(panel, Color("#D9A441"), false, 1.5)
	draw_string(font, Vector2(152.0, 84.0), "BUILDINGS   [B] close", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#E8D5A9"))

	var buildings: Array = snapshot.get("buildings", [])
	for i in range(mini(buildings.size(), 4)):
		var b: Dictionary = buildings[i]
		var r := _building_row_rect(i)
		var level_now := int(b.get("level", 0))
		var max_level := int(b.get("max_level", 2))
		var next_cost := int(b.get("next_cost", 0))
		var can_afford := bool(b.get("can_afford", false))

		draw_rect(r, Color("#1A1724"))
		draw_rect(r, Color("#D9A441") if can_afford else Color("#4A4658"), false, 1.0)

		var label := String(SLOT_NAMES[i])
		var state := "EMPTY"
		if level_now > 0:
			state = "Lv%d/%d" % [level_now, max_level]
		var action := ""
		if level_now >= max_level:
			action = "MAX"
		elif level_now == 0:
			action = "build %dg" % next_cost
		else:
			action = "upgrade %dg" % next_cost

		draw_string(font, r.position + Vector2(7.0, 13.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9"))
		draw_string(font, r.position + Vector2(7.0, 26.0), "%s   %s" % [state, action], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#D9A441") if can_afford else Color("#8A8498"))
		if level_now == 0:
			draw_string(font, r.position + Vector2(170.0, 20.0), ("+2 gold/s" if i < 2 else "+4 pop / -10% cd"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))
		elif level_now == 1:
			draw_string(font, r.position + Vector2(170.0, 20.0), ("+3 gold/s" if i < 2 else "+4 pop / -20% cd"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))

	draw_string(font, Vector2(152.0, 260.0), "Farms add income. Barracks add population and reduce that lane's cooldowns.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#8A8498"))


func _draw_result(font: Font) -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 360.0), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(Rect2(160.0, 124.0, 320.0, 116.0), Color(0.07, 0.06, 0.10, 0.98))
	draw_rect(Rect2(160.0, 124.0, 320.0, 116.0), Color("#D9A441"), false, 1.5)

	var winner := int(snapshot.get("winner", -1))
	var title := "VICTORY" if winner == 0 else ("DEFEAT" if winner == 1 else "DRAW")
	var color := Color("#6FA8DC") if winner == 0 else Color("#E06666")
	_center_text(font, title, 160.0, 22, color)
	_center_text(font, "Ctrl+R retry   N next level", 190.0, 10, Color("#E8D5A9"))
	var hp: Array = snapshot.get("base_hp", [0, 0])
	_center_text(font, "Wave %d/%d   Base %d/%d" % [int(snapshot.get("wave_index", 0)), int(snapshot.get("wave_count", 0)), int(hp[0]), int(snapshot.get("base_hp_max", 20))], 212.0, 9, Color("#B8B0C8"))


func _card_rect(index: int) -> Rect2:
	return Rect2(CARD_X + index * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H)


func _building_row_rect(index: int) -> Rect2:
	return Rect2(152.0, 94.0 + index * 38.0, 336.0, 32.0)


func _minimap_x(world_x: float) -> float:
	return MINIMAP_BAR_X + clampf(world_x, 0.0, WORLD_W) / WORLD_W * MINIMAP_BAR_W


func _minimap_lane_at(pos: Vector2) -> int:
	for lane in range(2):
		var bar := Rect2(MINIMAP_BAR_X, float(MINIMAP_LANE_Y[lane]), MINIMAP_BAR_W, MINIMAP_BAR_H)
		if bar.grow(3.0).has_point(pos):
			return lane
	return -1


func _center_text(font: Font, text: String, baseline: float, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2((VIEW_W - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _center_text_in(font: Font, text: String, rect: Rect2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + rect.size.y * 0.5 + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _is_ui_point(pos: Vector2) -> bool:
	if pos.y < TOP_H or pos.y >= BOTTOM_Y:
		return true
	if panel_open and Rect2(140.0, 66.0, 360.0, 206.0).has_point(pos):
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and drag_active:
		drag_end = event.position
		queue_redraw()
		accept_event()
		return

	if not (event is InputEventMouseButton):
		return

	var pos: Vector2 = event.position
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_ui_point(pos):
				_handle_ui_click(pos)
				accept_event()
				return
			drag_active = true
			drag_start = pos
			drag_end = pos
			accept_event()
		else:
			if drag_active:
				var drag_rect := Rect2(drag_start, drag_end - drag_start).abs()
				if drag_rect.size.length() > 4.0:
					world_drag.emit(drag_rect, event.shift_pressed)
				else:
					world_clicked.emit(pos, event.shift_pressed)
				drag_active = false
				queue_redraw()
				accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not _is_ui_point(pos):
			world_right_click.emit(pos, event.shift_pressed)
			accept_event()


func _handle_ui_click(pos: Vector2) -> void:
	if bool(snapshot.get("finished", false)):
		return

	var minimap_lane := _minimap_lane_at(pos)
	if minimap_lane >= 0:
		var world_x := (pos.x - MINIMAP_BAR_X) / MINIMAP_BAR_W * WORLD_W
		minimap_clicked.emit(minimap_lane, clampf(world_x, 0.0, WORLD_W))
		return

	if panel_open and Rect2(140.0, 66.0, 360.0, 206.0).has_point(pos):
		for i in range(4):
			if _building_row_rect(i).has_point(pos):
				build_requested.emit(i)
				return
		return

	if BUILD_RECT.has_point(pos):
		toggle_panel()
		return

	var catalog: Array = snapshot.get("catalog", [])
	for i in range(mini(catalog.size(), 6)):
		if _card_rect(i).has_point(pos):
			spawn_requested.emit(String(catalog[i].get("id", "")))
			return
