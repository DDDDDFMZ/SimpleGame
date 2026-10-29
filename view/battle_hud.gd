class_name BattleHUD
extends Control

signal spawn_requested(def_id: String)
signal build_requested(slot: int)
signal lane_requested(lane: int)

const VIEW_W := 640.0
const TOP_H := 50.0
const BOTTOM_Y := 300.0
const CARD_Y := 306.0
const CARD_W := 88.0
const CARD_H := 48.0
const CARD_GAP := 4.0
const CARD_X := 8.0
const BUILD_RECT := Rect2(564.0, 306.0, 68.0, 48.0)
const SLOT_NAMES := ["FARM A", "FARM B", "BARRACKS TOP", "BARRACKS DOWN"]

var snapshot: Dictionary = {}
var active_lane: int = 0
var panel_open: bool = false


func _ready() -> void:
	# Control is sized by the scene (640x360); accept mouse clicks.
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func update_snapshot(p_snapshot: Dictionary, p_active_lane: int) -> void:
	snapshot = p_snapshot
	active_lane = clampi(p_active_lane, 0, 1)
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
	draw_rect(Rect2(0.0, 0.0, VIEW_W, TOP_H), Color(0.07, 0.06, 0.10, 0.94))
	draw_line(Vector2(0.0, TOP_H), Vector2(VIEW_W, TOP_H), Color(0.2, 0.18, 0.26), 1.0)

	var gold := int(snapshot.get("gold", 0))
	var income := float(snapshot.get("income", 0.0))
	var pop_used := int(snapshot.get("pop_used", 0))
	var pop_max := int(snapshot.get("pop_max", 10))
	var hp: Array = snapshot.get("base_hp", [0, 0])
	var hp_max := int(snapshot.get("base_hp_max", 20))

	draw_string(font, Vector2(8.0, 13.0), "GOLD %d (+%.1f/s)   POP %d/%d   BASE %d/%d" % [gold, income, pop_used, pop_max, int(hp[0]), hp_max], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#E8D5A9"))

	var wave_index := int(snapshot.get("wave_index", 0))
	var wave_count := int(snapshot.get("wave_count", 0))
	var next_in := float(snapshot.get("next_wave_in", 0.0))
	if wave_count > 0:
		draw_string(font, Vector2(8.0, 27.0), "WAVE %d/%d    NEXT %.0fs" % [wave_index, wave_count, next_in], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
	else:
		draw_string(font, Vector2(8.0, 27.0), "SANDBOX", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))

	# Lane tabs.
	for lane in range(2):
		var r := _lane_rect(lane)
		var active := lane == active_lane
		draw_rect(r, Color("#3B6EA5") if active else Color("#252232"))
		draw_rect(r, Color("#D9A441") if active else Color("#4A4658"), false, 1.5 if active else 1.0)
		draw_string(font, r.position + Vector2(8.0, 13.0), "LANE %d" % (lane + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color.WHITE)

	# Wave/error message.
	var message := String(snapshot.get("message", ""))
	if message != "":
		_center_text(font, message, 41.0, 9, Color("#E08A3C"))
	var error := String(snapshot.get("error", ""))
	if error != "":
		_center_text(font, error, 295.0, 9, Color("#E06666"))

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
		_draw_buildings(font, gold)

	if bool(snapshot.get("finished", false)):
		_draw_result(font)


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


func _draw_buildings(font: Font, gold: int) -> void:
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
	draw_rect(Rect2(170.0, 128.0, 300.0, 104.0), Color(0.07, 0.06, 0.10, 0.98))
	draw_rect(Rect2(170.0, 128.0, 300.0, 104.0), Color("#D9A441"), false, 1.5)

	var winner := int(snapshot.get("winner", -1))
	var title := "VICTORY" if winner == 0 else ("DEFEAT" if winner == 1 else "DRAW")
	var color := Color("#6FA8DC") if winner == 0 else Color("#E06666")
	_center_text(font, title, 168.0, 22, color)
	_center_text(font, "Press R to retry", 196.0, 10, Color("#E8D5A9"))
	_center_text(font, "Wave %d/%d   Base %d/%d" % [int(snapshot.get("wave_index", 0)), int(snapshot.get("wave_count", 0)), int(snapshot.get("base_hp", [0, 0])[0]), int(snapshot.get("base_hp_max", 20))], 214.0, 9, Color("#B8B0C8"))


func _card_rect(index: int) -> Rect2:
	return Rect2(CARD_X + index * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H)


func _lane_rect(lane: int) -> Rect2:
	return Rect2(496.0 + lane * 68.0, 20.0, 64.0, 18.0)


func _building_row_rect(index: int) -> Rect2:
	return Rect2(152.0, 94.0 + index * 38.0, 336.0, 32.0)


func _center_text(font: Font, text: String, baseline: float, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2((VIEW_W - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _center_text_in(font: Font, text: String, rect: Rect2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + rect.size.y * 0.5 + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var pos: Vector2 = event.position

	if bool(snapshot.get("finished", false)):
		return

	if panel_open:
		for i in range(4):
			if _building_row_rect(i).has_point(pos):
				build_requested.emit(i)
				accept_event()
				return

	for lane in range(2):
		if _lane_rect(lane).has_point(pos):
			lane_requested.emit(lane)
			accept_event()
			return

	if BUILD_RECT.has_point(pos):
		toggle_panel()
		accept_event()
		return

	var catalog: Array = snapshot.get("catalog", [])
	for i in range(mini(catalog.size(), 6)):
		if _card_rect(i).has_point(pos):
			spawn_requested.emit(String(catalog[i].get("id", "")))
			accept_event()
			return
