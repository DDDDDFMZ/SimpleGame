class_name BattleHUD
extends Control

signal spawn_requested(def_id: String)
signal guild_action_requested(guild_id: String)
signal promote_requested
signal minimap_clicked(lane: int, world_x: float)
signal minimap_select(lane: int, x1: float, x2: float, additive: bool)
signal minimap_order(lane: int, world_x: float, shift: bool)
signal drag_started(screen_pos: Vector2)
signal drag_updated(screen_pos: Vector2)
signal drag_finished(screen_pos: Vector2, additive: bool)
signal world_right_click(screen_pos: Vector2, shift: bool)
signal result_action(action: String)

const VIEW_W := 640.0
const TOP_H := 64.0
const BOTTOM_Y := 300.0
const CARD_Y := 306.0
const CARD_W := 74.0
const CARD_H := 48.0
const CARD_GAP := 3.0
const CARD_X := 8.0
const WORLD_W := 1600.0
const CAM_VIEW_W := 640.0
const MINIMAP_RECT := Rect2(430.0, 6.0, 202.0, 52.0)
const MINIMAP_BAR_X := 448.0
const MINIMAP_BAR_W := 178.0
const MINIMAP_BAR_H := 14.0
const MINIMAP_LANE_Y := [11.0, 33.0]
const COMPANY_RECT := Rect2(120.0, 66.0, 400.0, 236.0)
const PROMOTE_RECT := Rect2(408.0, 84.0, 98.0, 20.0)
const RESULT_RECTS := {
	"retry": Rect2(180.0, 204.0, 84.0, 22.0),
	"next": Rect2(272.0, 204.0, 84.0, 22.0),
	"levels": Rect2(364.0, 204.0, 96.0, 22.0),
}

var snapshot: Dictionary = {}
var active_lane: int = 0
var panel_open: bool = false
var paused: bool = false
var camera_x: float = 320.0
var follow_mode: bool = true
var font: Font
var hover_card: int = -1
var hover_pos: Vector2 = Vector2.ZERO
var company_seen: bool = false
var checklist_open: bool = false
var checklist_initialized: bool = false
var guide_open: bool = false

var drag_active: bool = false
var minimap_drag: bool = false
var minimap_lane: int = 0
var minimap_start_x: float = 0.0
var minimap_current_x: float = 0.0
var minimap_moved: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	font = system_font
	queue_redraw()


func update_snapshot(p_snapshot: Dictionary, p_active_lane: int) -> void:
	snapshot = p_snapshot
	active_lane = clampi(p_active_lane, 0, 1)
	if not checklist_initialized and int(snapshot.get("contract", 0)) == 1:
		checklist_open = true
		checklist_initialized = true
	queue_redraw()


func set_camera(p_camera_x: float, p_follow: bool) -> void:
	camera_x = p_camera_x
	follow_mode = p_follow
	queue_redraw()


func set_paused(value: bool) -> void:
	paused = value
	queue_redraw()


func toggle_panel() -> void:
	panel_open = not panel_open
	company_seen = true
	queue_redraw()


func toggle_checklist() -> void:
	checklist_open = not checklist_open
	queue_redraw()


func toggle_guide() -> void:
	guide_open = not guide_open
	queue_redraw()


func set_guide(value: bool) -> void:
	guide_open = value
	queue_redraw()


func close_panel() -> void:
	panel_open = false
	queue_redraw()


func _draw() -> void:
	if font == null:
		return
	draw_rect(Rect2(0.0, 0.0, VIEW_W, TOP_H), Color(0.07, 0.06, 0.10, 0.95))
	draw_line(Vector2(0.0, TOP_H), Vector2(VIEW_W, TOP_H), Color(0.2, 0.18, 0.26), 1.0)

	var hp: Array = snapshot.get("base_hp", [0, 0])
	var gold := int(snapshot.get("gold", 0))
	var stipend := float(snapshot.get("stipend", 0.0))
	var used := int(snapshot.get("pop_used", 0))
	var cap := int(snapshot.get("pop_max", 8))
	var wave_index := int(snapshot.get("wave_index", 0))
	var wave_count := int(snapshot.get("wave_count", 0))
	var next_in := float(snapshot.get("next_wave_in", 0.0))
	var rank := int(snapshot.get("rep_rank", 0))
	var fame := int(snapshot.get("fame", 0))
	var promo_kills := int(snapshot.get("promo_kills", 0))
	var promo_cost := int(snapshot.get("promo_cost", 0))
	var target_kills := int(snapshot.get("target_kills", 0))
	var contract := int(snapshot.get("contract", 0))
	var mode := String(snapshot.get("mode", "defense"))
	var wave_text := ("ENDLESS W%d   NEXT %.0fs" % [wave_index, next_in]) if mode == "endless" else ("WAVE %d/%d   NEXT %.0fs" % [wave_index, wave_count, next_in])

	draw_string(font, Vector2(8.0, 13.0), "GOLD %d (+%.1f/s)   CAP %d/%d   BASE %d/%d   %s" % [gold, stipend, used, cap, int(hp[0]), int(snapshot.get("base_hp_max", 20)), wave_text], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9"))
	var contract_text := "ENDLESS" if mode == "endless" else ("CONTRACT %d" % contract)
	var target_total := int(snapshot.get("target_total", 0))
	draw_string(font, Vector2(8.0, 28.0), "REP R%d   FAME %d/%d   PROMOTE %dg   TARGETS %d/%d   %s" % [rank, fame, promo_kills, promo_cost, target_kills, target_total, contract_text], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
	draw_string(font, Vector2(8.0, 42.0), "1-8 recruit  B company  Q/E lane  drag/RMB orders  Shift+RMB line  F1 guide  F2 steps  Ctrl+R retry", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	var message := String(snapshot.get("message", ""))
	if message != "":
		draw_string(font, Vector2(8.0, 58.0), message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E08A3C"))
	var error := String(snapshot.get("error", ""))
	if error != "":
		_center_text(error, 295.0, 9, Color("#E06666"))

	_draw_minimap()
	_draw_wave_preview()

	draw_rect(Rect2(0.0, BOTTOM_Y, VIEW_W, 60.0), Color(0.07, 0.06, 0.10, 0.96))
	draw_line(Vector2(0.0, BOTTOM_Y), Vector2(VIEW_W, BOTTOM_Y), Color(0.2, 0.18, 0.26), 1.0)
	var catalog: Array = snapshot.get("catalog", [])
	var cooldowns: Array = snapshot.get("cooldowns", [{}, {}])
	var cd_map: Dictionary = cooldowns[active_lane] if active_lane < cooldowns.size() else {}
	for i in range(mini(catalog.size(), 8)):
		_draw_card(i, catalog[i], cd_map, gold, used, cap)

	if panel_open:
		_draw_company()

	if checklist_open:
		_draw_checklist()

	if hover_card >= 0 and not panel_open and not guide_open and not bool(snapshot.get("finished", false)):
		_draw_tooltip()

	if paused:
		_draw_pause()

	if bool(snapshot.get("finished", false)):
		_draw_result()

	if guide_open:
		_draw_guide()


func _draw_minimap() -> void:
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
		draw_rect(Rect2(_minimap_x(base_x) - 1.0, y + 2.0, 2.0, 10.0), Color("#6FA8DC"))
		draw_rect(Rect2(_minimap_x(enemy_x) - 1.0, y + 2.0, 2.0, 10.0), Color("#E06666"))
		if lane < lines.size():
			var lx := _minimap_x(float(lines[lane]))
			draw_line(Vector2(lx, y + 1.0), Vector2(lx, y + 13.0), Color("#D9A441"), 1.0)
		for u in units:
			if int(u.get("lane", -1)) != lane:
				continue
			var ux := _minimap_x(float(u.get("x", 0.0)))
			var color := Color("#6FA8DC") if int(u.get("team", 0)) == 0 else Color("#E06666")
			if bool(u.get("is_target", false)):
				color = Color("#D9A441")
			draw_rect(Rect2(ux - 1.0, y + 5.0, 2.0, 4.0), color)
		var cam_left := _minimap_x(clampf(camera_x - CAM_VIEW_W * 0.5, 0.0, WORLD_W))
		var cam_right := _minimap_x(clampf(camera_x + CAM_VIEW_W * 0.5, 0.0, WORLD_W))
		draw_rect(Rect2(cam_left, y + 1.0, maxf(8.0, cam_right - cam_left), 12.0), Color(1.0, 1.0, 1.0, 0.35), false, 1.0)


func _draw_card(index: int, card: Dictionary, cd_map: Dictionary, gold: int, used: int, cap: int) -> void:
	var rect := _card_rect(index)
	var def_id := String(card.get("id", ""))
	var unlocked := bool(card.get("unlocked", false))
	var cost := int(card.get("cost", 0))
	var pop := int(card.get("pop", 1))
	var cd := float(cd_map.get(def_id, 0.0))
	var can_gold := gold >= cost
	var can_pop := used + pop <= cap
	var ready := cd <= 0.0

	draw_rect(rect, Color("#1A1724") if unlocked else Color("#121019"))
	var border := Color("#6FA8DC") if unlocked and ready and can_gold and can_pop else Color("#4A4658")
	draw_rect(rect, border, false, 1.0)
	draw_string(font, rect.position + Vector2(4.0, 13.0), String(card.get("name", def_id)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9") if unlocked else Color("#6B6B6B"))
	var attack_short := String(card.get("attack_type", "")).substr(0, 1).to_upper()
	var armor_short := String(card.get("armor_type", "")).substr(0, 1).to_upper()
	draw_string(font, rect.position + Vector2(57.0, 13.0), "%s%s" % [attack_short, armor_short], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6FA8DC") if unlocked else Color("#4A4658"))
	if unlocked:
		draw_string(font, rect.position + Vector2(30.0, 43.0), String(card.get("role", "")).substr(0, 4).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 6, Color("#6B6B6B"))
	if not unlocked:
		var req := String(card.get("requirement", "LOCKED"))
		_center_text_in(req, Rect2(rect.position + Vector2(0.0, 16.0), Vector2(rect.size.x, 24.0)), 7, Color("#8A8498"))
		draw_string(font, rect.position + Vector2(4.0, 43.0), "[%d]" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#4A4658"))
		return

	draw_string(font, rect.position + Vector2(4.0, 26.0), "%dg p%d" % [cost, pop], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#D9A441") if can_gold else Color("#E06666"))
	draw_string(font, rect.position + Vector2(4.0, 43.0), "[%d]" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6B6B6B"))

	if not ready:
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55))
		_center_text_in("%.1fs" % cd, rect, 9, Color.WHITE)
	elif not can_gold:
		draw_rect(rect, Color(0.35, 0.05, 0.05, 0.35))
		_center_text_in("GOLD", rect, 8, Color("#E06666"))
	elif not can_pop:
		draw_rect(rect, Color(0.35, 0.05, 0.05, 0.35))
		_center_text_in("CAP", rect, 8, Color("#E06666"))


func _draw_company() -> void:
	draw_rect(COMPANY_RECT, Color(0.07, 0.06, 0.10, 0.98))
	draw_rect(COMPANY_RECT, Color("#D9A441"), false, 1.5)
	draw_string(font, COMPANY_RECT.position + Vector2(12.0, 18.0), "COMPANY   [B] close", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#E8D5A9"))

	var rank := int(snapshot.get("rep_rank", 0))
	var fame := int(snapshot.get("fame", 0))
	var promo_kills := int(snapshot.get("promo_kills", 0))
	var promo_cost := int(snapshot.get("promo_cost", 0))
	draw_string(font, COMPANY_RECT.position + Vector2(12.0, 38.0), "REPUTATION R%d   FAME %d/%d   PROMOTE %dg" % [rank, fame, promo_kills, promo_cost], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
	draw_rect(PROMOTE_RECT, Color("#252232"))
	draw_rect(PROMOTE_RECT, Color("#D9A441") if rank < 3 else Color("#4A4658"), false, 1.0)
	draw_string(font, PROMOTE_RECT.position + Vector2(12.0, 14.0), "PROMOTE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9") if rank < 3 else Color("#6B6B6B"))

	var guilds: Array = snapshot.get("guilds", [])
	for i in range(mini(guilds.size(), 3)):
		var guild: Dictionary = guilds[i]
		var rect := _guild_rect(i)
		draw_rect(rect, Color("#1A1724"))
		draw_rect(rect, Color("#D9A441") if bool(guild.get("unlocked", false)) else Color("#4A4658"), false, 1.0)
		var name := String(guild.get("name", guild.get("id", "")))
		var tier := int(guild.get("tier", -1))
		var tier_text := "LOCKED" if not bool(guild.get("unlocked", false)) else ("NOT CONTACTED" if tier < 0 else "T%d" % tier)
		draw_string(font, rect.position + Vector2(7.0, 14.0), "%s   %s" % [name, tier_text], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9"))
		var next_text := ""
		if bool(guild.get("unlocked", false)) and int(guild.get("max_tier", 0)) > tier:
			next_text = "next %dg  +%d cap  %s" % [int(guild.get("next_cost", 0)), int(guild.get("next_cap", 0)), str(guild.get("next_units", []))]
		else:
			next_text = "MAX" if bool(guild.get("unlocked", false)) else "clear prior contracts"
		draw_string(font, rect.position + Vector2(7.0, 27.0), "%s   favor %d  used %d" % [next_text, int(guild.get("favor", 0)), int(guild.get("usage", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))

	draw_string(font, COMPANY_RECT.position + Vector2(12.0, 220.0), "Guild tier unlocks classes and raises the recruitment cap. Favor is permanent and small.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6B6B6B"))


func _draw_pause() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 360.0), Color(0.0, 0.0, 0.0, 0.45))
	_center_text("PAUSED", 170.0, 20, Color("#E8D5A9"))
	_center_text("Space resume   Ctrl+R retry   Esc contracts", 195.0, 9, Color("#B8B0C8"))


func _draw_result() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 360.0), Color(0.0, 0.0, 0.0, 0.58))
	var panel := Rect2(130.0, 90.0, 380.0, 190.0)
	draw_rect(panel, Color(0.07, 0.06, 0.10, 0.98))
	draw_rect(panel, Color("#D9A441"), false, 1.5)
	var winner := int(snapshot.get("winner", -1))
	var stars := int(snapshot.get("stars", 0))
	var mode := String(snapshot.get("mode", "defense"))
	var title := "CONTRACT COMPLETE" if winner == 0 else ("DEFEAT" if winner == 1 else "DRAW")
	if mode == "endless":
		title = "RUN OVER"
	var color := Color("#6FA8DC") if winner == 0 else Color("#E06666")
	_center_text(title, 116.0, 18, color)
	if mode == "endless":
		_center_text("Waves %d   Score %d" % [int(snapshot.get("wave_index", 0)), int(snapshot.get("score", 0))], 142.0, 14, Color("#D9A441"))
	else:
		_center_text("%s%s%s" % ["★" if stars >= 1 else "☆", "★" if stars >= 2 else "☆", "★" if stars >= 3 else "☆"], 142.0, 18, Color("#D9A441"))
	var stats: Dictionary = snapshot.get("result_stats", {})
	var target_total := int(snapshot.get("target_total", 0))
	_center_text("Targets %d/%d   Base %d/%d" % [int(snapshot.get("target_kills", 0)), target_total, int(snapshot.get("base_hp", [0, 0])[0]), int(snapshot.get("base_hp_max", 20))], 160.0, 9, Color("#B8B0C8"))
	var leak_parts: Array = []
	var leaks_by_unit: Dictionary = stats.get("leaks_by_unit", {})
	var leak_keys: Array = leaks_by_unit.keys()
	leak_keys.sort_custom(func(a, b): return int(leaks_by_unit[a]) > int(leaks_by_unit[b]))
	for i in range(mini(leak_keys.size(), 3)):
		leak_parts.append("%s x%d" % [String(leak_keys[i]), int(leaks_by_unit[leak_keys[i]])])
	var leak_text := "Leaks " + (", ".join(PackedStringArray(leak_parts)) if not leak_parts.is_empty() else "0")
	_center_text(leak_text, 174.0, 8, Color("#E06666"))
	_center_text("Spent units %d / guilds %d / promote %d   Unspent %d" % [int(stats.get("gold_spent_units", 0)), int(stats.get("gold_spent_guilds", 0)), int(stats.get("gold_spent_promote", 0)), int(stats.get("gold_unspent", 0))], 186.0, 7, Color("#8A8498"))
	for action in RESULT_RECTS:
		var r: Rect2 = RESULT_RECTS[action]
		draw_rect(r, Color("#252232"))
		draw_rect(r, Color("#4A4658"), false, 1.0)
		var label: String = {"retry": "RETRY", "next": "NEXT", "levels": "CONTRACTS"}[action]
		_center_text_in(label, r, 8, Color("#E8D5A9"))


func _draw_wave_preview() -> void:
	var preview: Dictionary = snapshot.get("next_wave_preview", {})
	if preview.is_empty():
		return
	var panel := Rect2(298.0, 6.0, 126.0, 52.0)
	draw_rect(panel, Color(0.05, 0.04, 0.08, 0.92))
	draw_rect(panel, Color("#4A4658"), false, 1.0)
	draw_string(font, panel.position + Vector2(7.0, 12.0), "NEXT WAVE %.0fs" % float(preview.get("time", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#D9A441"))
	var y := 24.0
	for lane_data in preview.get("lanes", []):
		var parts: Array = []
		for unit in lane_data.get("units", []):
			var mark := "*" if bool(unit.get("target", false)) else ""
			parts.append("%d%s%s/%s" % [int(unit.get("count", 1)), String(unit.get("id", "")).substr(0, 4), mark, String(unit.get("armor_type", "")).substr(0, 1).to_upper()])
		draw_string(font, panel.position + Vector2(7.0, y), "L%d %s" % [int(lane_data.get("lane", 0)) + 1, " ".join(PackedStringArray(parts))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#B8B0C8"))
		y += 12.0
		if y > 46.0:
			break


func _draw_checklist() -> void:
	var panel := Rect2(8.0, 68.0, 190.0, 116.0)
	draw_rect(panel, Color(0.05, 0.04, 0.08, 0.92))
	draw_rect(panel, Color("#D9A441"), false, 1.0)
	draw_string(font, panel.position + Vector2(8.0, 14.0), "FIRST CONTRACT  [F2]", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9"))
	var iron_tier := -1
	for guild in snapshot.get("guilds", []):
		if String(guild.get("id", "")) == "iron":
			iron_tier = int(guild.get("tier", -1))
	var used := 0
	for value in snapshot.get("guild_usage", {}).values():
		used += int(value)
	var lines: Array = snapshot.get("advance_lines", [92.0, 92.0])
	var steps: Array = [
		["B opens Company", company_seen],
		["Contact Iron Oath", iron_tier >= 0],
		["Recruit a class", used > 0],
		["Shift+RMB set line", absf(float(lines[0]) - 92.0) > 2.0 or absf(float(lines[1]) - 92.0) > 2.0],
		["Kill a gold target", int(snapshot.get("target_kills", 0)) > 0],
		["PROMOTE reputation", int(snapshot.get("rep_rank", 0)) > 0],
	]
	for i in range(steps.size()):
		var done := bool(steps[i][1])
		draw_string(font, panel.position + Vector2(9.0, 30.0 + i * 12.0), ("[x] " if done else "[ ] ") + String(steps[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6FA8DC") if done else Color("#B8B0C8"))


func _draw_tooltip() -> void:
	var catalog: Array = snapshot.get("catalog", [])
	if hover_card < 0 or hover_card >= catalog.size():
		return
	var card: Dictionary = catalog[hover_card]
	var panel := Rect2(clampf(8.0 + hover_card * 77.0 - 70.0, 8.0, 408.0), 168.0, 224.0, 130.0)
	draw_rect(panel, Color(0.04, 0.03, 0.07, 0.98))
	draw_rect(panel, Color("#D9A441"), false, 1.0)
	var x := panel.position.x + 8.0
	var y := panel.position.y + 15.0
	draw_string(font, Vector2(x, y), "%s   %s T%d" % [String(card.get("name", "")), String(card.get("guild_name", "")), int(card.get("tier", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9"))
	y += 14.0
	draw_string(font, Vector2(x, y), "Role: %s   %s   %s   %dg / p%d" % [String(card.get("role", "")), String(card.get("attack_type", "")), String(card.get("armor_type", "")), int(card.get("cost", 0)), int(card.get("pop", 1))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#B8B0C8"))
	y += 13.0
	draw_string(font, Vector2(x, y), "HP %.0f   DPS %.1f   Range %.0f" % [float(card.get("hp", 0)), float(card.get("dps", 0)), float(card.get("range", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#B8B0C8"))
	y += 13.0
	draw_string(font, Vector2(x, y), "Passive: %s" % _passive_label(String(card.get("passive", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	y += 13.0
	draw_string(font, Vector2(x, y), "Good vs: %s   Weak vs: %s" % [_join_armor(card.get("good_vs", [])), _join_armor(card.get("weak_vs", []))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6FA8DC"))
	if not bool(card.get("unlocked", false)):
		y += 13.0
		draw_string(font, Vector2(x, y), "Locked: %s" % String(card.get("requirement", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#E06666"))


func _draw_guide() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 360.0), Color(0.02, 0.02, 0.04, 0.985))
	draw_string(font, Vector2(20.0, 24.0), "FIELD GUIDE  [F1 close]", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("#E8D5A9"))
	draw_string(font, Vector2(20.0, 44.0), "GOLD: stipend + wave pay + kills.   FAME: kill gold-marked targets.   RANK: FAME + gold PROMOTE.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 56.0), "GUILD: spend gold to open classes/cap.   CAP: recruit limit.   LINE: Shift+RMB; new units hold there.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 72.0), "COUNTERS: MELEE > light / weak vs heavy.  RANGED even.  SIEGE > heavy / weak vs light.  Rogue > ranged.  Mage > clumps.  Cleric heals.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 90.0), "CLASSES (role / attack / armor / passive):", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9"))
	var catalog: Array = snapshot.get("catalog", [])
	for i in range(mini(catalog.size(), 8)):
		var card: Dictionary = catalog[i]
		var col := i % 2
		var row := int(i / 2)
		draw_string(font, Vector2(20.0 + col * 306.0, 106.0 + row * 16.0), "%s: %s / %s / %s. %s." % [String(card.get("name", "")), String(card.get("role", "")), String(card.get("attack_type", "")), String(card.get("armor_type", "")), _passive_short(String(card.get("passive", "")))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 6, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 186.0), "TARGETS: gold diamond -> +15g / +1 Fame. Target leaks hurt. ELITE: gold outline, extra base damage.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	draw_string(font, Vector2(20.0, 204.0), "CONTROLS: 1-8 / Alt+1-8 recruit; Q/E lane; drag select; RMB move; H hold; R return; Ctrl+R retry; F follow; Space pause.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	draw_string(font, Vector2(20.0, 222.0), "FIRST CONTRACT: B -> contact Iron Oath -> recruit -> Shift+RMB line -> kill gold target -> PROMOTE.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6FA8DC"))
	draw_string(font, Vector2(20.0, 244.0), "F1 close   F2 first-contract checklist   Esc contracts", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9"))


func _passive_short(passive: String) -> String:
	return {
		"shield_wall": "Shield Wall",
		"armor_pierce": "Armor Pierce",
		"volley": "Volley",
		"charge": "Charge",
		"splash": "Splash",
		"siege_master": "Siege Master",
		"backstab": "Backstab",
		"heal": "Heal",
	}.get(passive, passive)


func _passive_label(passive: String) -> String:
	return {
		"shield_wall": "Shield Wall (-30% ranged damage)",
		"armor_pierce": "Armor Pierce (1.25x vs heavy)",
		"volley": "Volley (+25% attack speed when stationary)",
		"charge": "Charge (first hit x2)",
		"splash": "Splash (50% nearby)",
		"siege_master": "Siege Master (+ vs heavy/buildings)",
		"backstab": "Backstab (+50% vs ranged)",
		"heal": "Heal (lowest-HP ally)",
	}.get(passive, passive)


func _join_armor(values: Array) -> String:
	if values.is_empty():
		return "none"
	var parts: Array = []
	for value in values:
		parts.append(String(value))
	return ", ".join(PackedStringArray(parts))


func _card_rect(index: int) -> Rect2:
	return Rect2(CARD_X + index * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H)


func _guild_rect(index: int) -> Rect2:
	return Rect2(132.0, 112.0 + index * 44.0, 376.0, 40.0)


func _card_at(pos: Vector2) -> int:
	var catalog: Array = snapshot.get("catalog", [])
	for i in range(mini(catalog.size(), 8)):
		if _card_rect(i).has_point(pos):
			return i
	return -1


func _minimap_x(world_x: float) -> float:
	return MINIMAP_BAR_X + clampf(world_x, 0.0, WORLD_W) / WORLD_W * MINIMAP_BAR_W


func _minimap_world_x(local_x: float) -> float:
	return clampf((local_x - MINIMAP_BAR_X) / MINIMAP_BAR_W * WORLD_W, 0.0, WORLD_W)


func _minimap_lane_at(pos: Vector2) -> int:
	for lane in range(2):
		var bar := Rect2(MINIMAP_BAR_X, float(MINIMAP_LANE_Y[lane]), MINIMAP_BAR_W, MINIMAP_BAR_H)
		if bar.grow(3.0).has_point(pos):
			return lane
	return -1


func _center_text(text: String, baseline: float, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2((VIEW_W - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _center_text_in(text: String, rect: Rect2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + rect.size.y * 0.5 + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _is_ui_point(pos: Vector2) -> bool:
	if pos.y < TOP_H or pos.y >= BOTTOM_Y:
		return true
	if panel_open and COMPANY_RECT.has_point(pos):
		return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover_card = -1
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_pos = event.position
		hover_card = _card_at(hover_pos)
		queue_redraw()
		if minimap_drag:
			minimap_current_x = event.position.x
			minimap_moved = minimap_moved or absf(minimap_current_x - minimap_start_x) > 4.0
			queue_redraw()
			accept_event()
		elif drag_active:
			drag_updated.emit(event.position)
			accept_event()
		return

	if not (event is InputEventMouseButton):
		return
	var pos: Vector2 = event.position

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if bool(snapshot.get("finished", false)):
				_handle_result_click(pos)
				accept_event()
				return
			var minimap_lane_hit := _minimap_lane_at(pos)
			if minimap_lane_hit >= 0:
				minimap_drag = true
				minimap_lane = minimap_lane_hit
				minimap_start_x = pos.x
				minimap_current_x = pos.x
				minimap_moved = false
				accept_event()
				return
			if _is_ui_point(pos):
				_handle_ui_click(pos)
				accept_event()
				return
			drag_active = true
			drag_started.emit(pos)
			accept_event()
		else:
			if minimap_drag:
				if minimap_moved:
					var x1 := _minimap_world_x(minimap_start_x)
					var x2 := _minimap_world_x(minimap_current_x)
					minimap_select.emit(minimap_lane, minf(x1, x2), maxf(x1, x2), event.shift_pressed)
				else:
					minimap_clicked.emit(minimap_lane, _minimap_world_x(pos.x))
				minimap_drag = false
				queue_redraw()
				accept_event()
				return
			if drag_active:
				drag_finished.emit(pos, event.shift_pressed)
				drag_active = false
				accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var minimap_lane_hit := _minimap_lane_at(pos)
		if minimap_lane_hit >= 0:
			minimap_order.emit(minimap_lane_hit, _minimap_world_x(pos.x), event.shift_pressed)
			accept_event()
			return
		if not _is_ui_point(pos):
			world_right_click.emit(pos, event.shift_pressed)
			accept_event()


func _handle_result_click(pos: Vector2) -> void:
	for action in RESULT_RECTS:
		if RESULT_RECTS[action].has_point(pos):
			result_action.emit(action)
			return


func _handle_ui_click(pos: Vector2) -> void:
	var minimap_lane_hit := _minimap_lane_at(pos)
	if minimap_lane_hit >= 0:
		minimap_clicked.emit(minimap_lane_hit, _minimap_world_x(pos.x))
		return

	if panel_open and COMPANY_RECT.has_point(pos):
		if PROMOTE_RECT.has_point(pos):
			promote_requested.emit()
			return
		var guilds: Array = snapshot.get("guilds", [])
		for i in range(mini(guilds.size(), 3)):
			if _guild_rect(i).has_point(pos):
				guild_action_requested.emit(String(guilds[i].get("id", "")))
				return
		return

	var catalog: Array = snapshot.get("catalog", [])
	for i in range(mini(catalog.size(), 8)):
		if _card_rect(i).has_point(pos):
			spawn_requested.emit(String(catalog[i].get("id", "")))
			return
