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
signal selection_changed(ids: Array)

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
const SELECTION_RECT := Rect2(444.0, 66.0, 188.0, 200.0)
const SELECTION_TAB_W := 45.0
const SELECTION_TABS := ["协会", "攻型", "甲型", "职业"]
const GUIDE_PAGE_COUNT := 2
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
var guide_page: int = 0
var selected_ids: Array = []
var selection_tab: int = 0

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
	active_lane = clampi(p_active_lane, 0, maxi(0, int(snapshot.get("lane_count", 2)) - 1))
	if not checklist_initialized and int(snapshot.get("contract", 0)) == 1:
		checklist_open = true
		checklist_initialized = true
	queue_redraw()


func set_selection(ids: Array) -> void:
	selected_ids = ids.duplicate()
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
	guide_page = 0
	queue_redraw()


func set_guide(value: bool) -> void:
	guide_open = value
	queue_redraw()


func change_guide_page(delta: int) -> void:
	guide_page = posmod(guide_page + delta, GUIDE_PAGE_COUNT)
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
	var target_total := int(snapshot.get("target_total", 0))
	var contract := int(snapshot.get("contract", 0))
	var mode := String(snapshot.get("mode", "defense"))
	var wave_text := ("无尽 第%d波  下一波 %.0f秒" % [wave_index, next_in]) if mode == "endless" else ("第%d/%d波  下一波 %.0f秒" % [wave_index, wave_count, next_in])

	draw_string(font, Vector2(8.0, 13.0), "金币 %d (+%.1f/秒)   兵力 %d/%d   基地 %d/%d   %s" % [gold, stipend, used, cap, int(hp[0]), int(snapshot.get("base_hp_max", 20)), wave_text], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9"))
	var contract_text := "无尽悬赏" if mode == "endless" else ("委托 %d" % contract)
	var target_text := "悬赏击杀 %d" % target_kills if mode == "endless" else "悬赏 %d/%d" % [target_kills, target_total]
	draw_string(font, Vector2(8.0, 28.0), "声望 R%d   名望 %d/%d   晋升 %d金   %s   %s" % [rank, fame, promo_kills, promo_cost, target_text, contract_text], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
	draw_string(font, Vector2(8.0, 42.0), "1-8 招募  B 协会  Q/E 换路  右键 指挥  Shift+右键 推进线  F1 指南", HORIZONTAL_ALIGNMENT_LEFT, 286.0, 7, Color("#8A8498"))
	var message := String(snapshot.get("message", ""))
	if message != "":
		draw_string(font, Vector2(8.0, 58.0), message, HORIZONTAL_ALIGNMENT_LEFT, 286.0, 8, Color("#E08A3C"))
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

	if _selection_visible():
		_draw_selection_panel()

	if panel_open:
		_draw_company()

	if checklist_open and not panel_open and not guide_open and not bool(snapshot.get("finished", false)):
		_draw_checklist()

	if hover_card >= 0 and not panel_open and not guide_open and not bool(snapshot.get("finished", false)):
		_draw_tooltip()

	if paused and not guide_open:
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
	var lane_count := clampi(int(snapshot.get("lane_count", 2)), 1, 2)
	var routes: Array = snapshot.get("map", {}).get("routes", [])
	var world_w := _world_width()

	for lane in range(lane_count):
		var y := float(MINIMAP_LANE_Y[lane])
		var bar := Rect2(MINIMAP_BAR_X, y, MINIMAP_BAR_W, MINIMAP_BAR_H)
		draw_rect(bar, Color("#1A1724"))
		draw_rect(bar, Color("#D9A441") if lane == active_lane else Color("#4A4658"), false, 1.0)
		var lane_name := "1路" if lane == 0 else "2路"
		if lane < routes.size():
			var full_name := String(routes[lane].get("name_cn", lane_name))
			lane_name = full_name if full_name.length() <= 2 else full_name.substr(full_name.length() - 2, 2)
		draw_string(font, Vector2(432.0, y + 11.0), lane_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#E8D5A9"))
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
		var cam_left := _minimap_x(clampf(camera_x - CAM_VIEW_W * 0.5, 0.0, world_w))
		var cam_right := _minimap_x(clampf(camera_x + CAM_VIEW_W * 0.5, 0.0, world_w))
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
	draw_string(font, rect.position + Vector2(4.0, 13.0), String(card.get("name", def_id)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9") if unlocked else Color("#6B6B6B"))
	var attack_short := UIText.attack_short(String(card.get("attack_type", "")))
	var armor_short := UIText.armor_short(String(card.get("armor_type", "")))
	draw_string(font, rect.position + Vector2(55.0, 13.0), attack_short + armor_short, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6FA8DC") if unlocked else Color("#4A4658"))
	if unlocked:
		draw_string(font, rect.position + Vector2(4.0, 43.0), UIText.role_label(String(card.get("role", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 6, Color("#6B6B6B"))
	if not unlocked:
		var req := String(card.get("requirement", "未解锁"))
		_center_text_in(req, Rect2(rect.position + Vector2(0.0, 16.0), Vector2(rect.size.x, 24.0)), 7, Color("#8A8498"))
		draw_string(font, rect.position + Vector2(4.0, 43.0), "[%d]" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#4A4658"))
		return

	draw_string(font, rect.position + Vector2(4.0, 27.0), "%d金 %d兵" % [cost, pop], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#D9A441") if can_gold else Color("#E06666"))
	draw_string(font, rect.position + Vector2(58.0, 43.0), "[%d]" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6B6B6B"))

	if not ready:
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.55))
		_center_text_in("%.1f秒" % cd, rect, 9, Color.WHITE)
	elif not can_gold:
		draw_rect(rect, Color(0.35, 0.05, 0.05, 0.35))
		_center_text_in("金币不足", rect, 8, Color("#E06666"))
	elif not can_pop:
		draw_rect(rect, Color(0.35, 0.05, 0.05, 0.35))
		_center_text_in("兵力已满", rect, 8, Color("#E06666"))


func _draw_company() -> void:
	draw_rect(COMPANY_RECT, Color(0.07, 0.06, 0.10, 0.98))
	draw_rect(COMPANY_RECT, Color("#D9A441"), false, 1.5)
	draw_string(font, COMPANY_RECT.position + Vector2(12.0, 18.0), "协会与声望   [B] 关闭", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#E8D5A9"))

	var rank := int(snapshot.get("rep_rank", 0))
	var fame := int(snapshot.get("fame", 0))
	var promo_kills := int(snapshot.get("promo_kills", 0))
	var promo_cost := int(snapshot.get("promo_cost", 0))
	var max_rank := int(snapshot.get("max_rank", 3))
	draw_string(font, COMPANY_RECT.position + Vector2(12.0, 38.0), "声望 R%d   名望 %d/%d   晋升 %d金" % [rank, fame, promo_kills, promo_cost], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
	draw_rect(PROMOTE_RECT, Color("#252232"))
	draw_rect(PROMOTE_RECT, Color("#D9A441") if rank < max_rank else Color("#4A4658"), false, 1.0)
	draw_string(font, PROMOTE_RECT.position + Vector2(28.0, 15.0), "晋升", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9") if rank < max_rank else Color("#6B6B6B"))

	var guilds: Array = snapshot.get("guilds", [])
	for i in range(mini(guilds.size(), 3)):
		var guild: Dictionary = guilds[i]
		var rect := _guild_rect(i)
		draw_rect(rect, Color("#1A1724"))
		draw_rect(rect, Color("#D9A441") if bool(guild.get("unlocked", false)) else Color("#4A4658"), false, 1.0)
		var guild_name := String(guild.get("name", guild.get("id", "")))
		var tier := int(guild.get("tier", -1))
		var tier_text := "未解锁" if not bool(guild.get("unlocked", false)) else ("未建交" if tier < 0 else "关系 %d" % tier)
		draw_string(font, rect.position + Vector2(7.0, 14.0), "%s   %s" % [guild_name, tier_text], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9"))
		var next_text := ""
		if bool(guild.get("unlocked", false)) and int(guild.get("max_tier", 0)) > tier:
			var unlock_names: Array = guild.get("next_unit_names", [])
			var unlock_text := UIText.join_names(unlock_names) if not unlock_names.is_empty() else "无新职业"
			next_text = "下级 %d金 · 兵力+%d · 解锁：%s" % [int(guild.get("next_cost", 0)), int(guild.get("next_cap", 0)), unlock_text]
		else:
			next_text = "已满级" if bool(guild.get("unlocked", false)) else "通关前置委托后开放"
		draw_string(font, rect.position + Vector2(7.0, 27.0), "%s   人情 %d · 已雇 %d" % [next_text, int(guild.get("favor", 0)), int(guild.get("usage", 0))], HORIZONTAL_ALIGNMENT_LEFT, 362.0, 7, Color("#8A8498"))

	draw_string(font, COMPANY_RECT.position + Vector2(12.0, 220.0), "花金币建交/升级协会：解锁职业并提高兵力上限。人情永久提供小幅属性与费用加成。", HORIZONTAL_ALIGNMENT_LEFT, 376.0, 7, Color("#6B6B6B"))


func _draw_pause() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 360.0), Color(0.0, 0.0, 0.0, 0.45))
	_center_text("暂停", 170.0, 20, Color("#E8D5A9"))
	_center_text("空格 继续   Ctrl+R 重开   Esc 返回委托", 195.0, 9, Color("#B8B0C8"))


func _draw_result() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 360.0), Color(0.0, 0.0, 0.0, 0.58))
	var panel := Rect2(130.0, 90.0, 380.0, 190.0)
	draw_rect(panel, Color(0.07, 0.06, 0.10, 0.98))
	draw_rect(panel, Color("#D9A441"), false, 1.5)
	var winner := int(snapshot.get("winner", -1))
	var stars := int(snapshot.get("stars", 0))
	var mode := String(snapshot.get("mode", "defense"))
	var title := "委托完成" if winner == 0 else ("防线失守" if winner == 1 else "平局")
	if mode == "endless":
		title = "本轮结束"
	var color := Color("#6FA8DC") if winner == 0 else Color("#E06666")
	_center_text(title, 116.0, 18, color)
	if mode == "endless":
		_center_text("波数 %d   得分 %d" % [int(snapshot.get("wave_index", 0)), int(snapshot.get("score", 0))], 142.0, 14, Color("#D9A441"))
	else:
		_center_text("%s%s%s" % ["★" if stars >= 1 else "☆", "★" if stars >= 2 else "☆", "★" if stars >= 3 else "☆"], 142.0, 18, Color("#D9A441"))
	var stats: Dictionary = snapshot.get("result_stats", {})
	var target_total := int(snapshot.get("target_total", 0))
	_center_text("悬赏目标 %d/%d   基地 %d/%d" % [int(snapshot.get("target_kills", 0)), target_total, int(snapshot.get("base_hp", [0, 0])[0]), int(snapshot.get("base_hp_max", 20))], 160.0, 9, Color("#B8B0C8"))
	var leak_parts: Array = []
	var leaks_by_unit: Dictionary = stats.get("leaks_by_unit", {})
	var leak_keys: Array = leaks_by_unit.keys()
	leak_keys.sort_custom(func(a, b): return int(leaks_by_unit[a]) > int(leaks_by_unit[b]))
	for i in range(mini(leak_keys.size(), 3)):
		leak_parts.append("%s×%d" % [_unit_name(String(leak_keys[i])), int(leaks_by_unit[leak_keys[i]])])
	var leak_text := "漏怪：" + ("、".join(PackedStringArray(leak_parts)) if not leak_parts.is_empty() else "无")
	_center_text(leak_text, 174.0, 8, Color("#E06666"))
	_center_text("招募 %d 金 / 协会 %d 金 / 晋升 %d 金   剩余 %d 金" % [int(stats.get("gold_spent_units", 0)), int(stats.get("gold_spent_guilds", 0)), int(stats.get("gold_spent_promote", 0)), int(stats.get("gold_unspent", 0))], 186.0, 7, Color("#8A8498"))
	for action in RESULT_RECTS:
		var r: Rect2 = RESULT_RECTS[action]
		draw_rect(r, Color("#252232"))
		draw_rect(r, Color("#4A4658"), false, 1.0)
		var label: String = {"retry": "重试", "next": "下一关", "levels": "委托列表"}[action]
		_center_text_in(label, r, 8, Color("#E8D5A9"))


func _draw_wave_preview() -> void:
	var preview: Dictionary = snapshot.get("next_wave_preview", {})
	if preview.is_empty():
		return
	var panel := Rect2(298.0, 6.0, 126.0, 52.0)
	draw_rect(panel, Color(0.05, 0.04, 0.08, 0.92))
	draw_rect(panel, Color("#4A4658"), false, 1.0)
	draw_string(font, panel.position + Vector2(7.0, 12.0), "下一波 %.0f秒" % float(preview.get("time", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#D9A441"))
	var y := 24.0
	for lane_data in preview.get("lanes", []):
		var parts: Array = []
		for unit in lane_data.get("units", []):
			var mark := "*" if bool(unit.get("target", false)) else ""
			var unit_name := _unit_name(String(unit.get("id", "")))
			parts.append("%d%s%s" % [int(unit.get("count", 1)), unit_name, mark])
		draw_string(font, panel.position + Vector2(7.0, y), "%d路 %s" % [int(lane_data.get("lane", 0)) + 1, " ".join(PackedStringArray(parts))], HORIZONTAL_ALIGNMENT_LEFT, 112.0, 7, Color("#B8B0C8"))
		y += 12.0
		if y > 46.0:
			break


func _draw_checklist() -> void:
	var panel := Rect2(8.0, 68.0, 190.0, 116.0)
	draw_rect(panel, Color(0.05, 0.04, 0.08, 0.92))
	draw_rect(panel, Color("#D9A441"), false, 1.0)
	draw_string(font, panel.position + Vector2(8.0, 14.0), "首份委托   [F2 关闭]", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9"))
	var iron_tier := -1
	for guild in snapshot.get("guilds", []):
		if String(guild.get("id", "")) == "iron":
			iron_tier = int(guild.get("tier", -1))
	var used := 0
	for value in snapshot.get("guild_usage", {}).values():
		used += int(value)
	var lines: Array = snapshot.get("advance_lines", [92.0, 92.0])
	var steps: Array = [
		["按 B 打开协会", company_seen],
		["与铁誓会建交", iron_tier >= 0],
		["招募一名冒险者", used > 0],
		["Shift+右键 设置推进线", absf(float(lines[0]) - 92.0) > 2.0 or absf(float(lines[1]) - 92.0) > 2.0],
		["击杀金色悬赏目标", int(snapshot.get("target_kills", 0)) > 0],
		["晋升声望", int(snapshot.get("rep_rank", 0)) > 0],
	]
	for i in range(steps.size()):
		var done := bool(steps[i][1])
		draw_string(font, panel.position + Vector2(9.0, 30.0 + i * 13.0), ("[x] " if done else "[ ] ") + String(steps[i][0]), HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#6FA8DC") if done else Color("#B8B0C8"))


func _draw_tooltip() -> void:
	var catalog: Array = snapshot.get("catalog", [])
	if hover_card < 0 or hover_card >= catalog.size():
		return
	var card: Dictionary = catalog[hover_card]
	var locked := not bool(card.get("unlocked", false))
	var panel := Rect2(clampf(8.0 + hover_card * 77.0 - 70.0, 8.0, 408.0), 166.0, 224.0, 98.0 if locked else 84.0)
	draw_rect(panel, Color(0.04, 0.03, 0.07, 0.98))
	draw_rect(panel, Color("#D9A441"), false, 1.0)
	var x := panel.position.x + 8.0
	var y := panel.position.y + 15.0
	draw_string(font, Vector2(x, y), "%s   %s 关系%d" % [String(card.get("name", "")), String(card.get("guild_name", "")), int(card.get("tier", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9"))
	y += 14.0
	draw_string(font, Vector2(x, y), "%s · %s · %s · %d金/%d兵" % [UIText.role_label(String(card.get("role", ""))), UIText.attack_label(String(card.get("attack_type", ""))), UIText.armor_label(String(card.get("armor_type", ""))), int(card.get("cost", 0)), int(card.get("pop", 1))], HORIZONTAL_ALIGNMENT_LEFT, 208.0, 7, Color("#B8B0C8"))
	y += 13.0
	draw_string(font, Vector2(x, y), "生命 %.0f   每秒伤害 %.1f   射程 %.0f" % [float(card.get("hp", 0)), float(card.get("dps", 0)), float(card.get("range", 0))], HORIZONTAL_ALIGNMENT_LEFT, 208.0, 7, Color("#B8B0C8"))
	y += 13.0
	draw_string(font, Vector2(x, y), "被动：%s — %s" % [UIText.passive_name(String(card.get("passive", ""))), UIText.passive_desc(String(card.get("passive", "")))], HORIZONTAL_ALIGNMENT_LEFT, 208.0, 7, Color("#8A8498"))
	y += 13.0
	draw_string(font, Vector2(x, y), "克制：%s   被克：%s" % [UIText.join_armor(card.get("good_vs", [])), UIText.join_armor(card.get("weak_vs", []))], HORIZONTAL_ALIGNMENT_LEFT, 208.0, 7, Color("#6FA8DC"))
	if locked:
		y += 13.0
		draw_string(font, Vector2(x, y), "未解锁：%s" % String(card.get("requirement", "")), HORIZONTAL_ALIGNMENT_LEFT, 208.0, 7, Color("#E06666"))


func _draw_selection_panel() -> void:
	var units := _selected_units()
	if units.is_empty():
		return
	var panel := _selection_panel_rect()
	draw_rect(panel, Color(0.05, 0.04, 0.08, 0.94))
	draw_rect(panel, Color("#6FA8DC"), false, 1.0)
	var total_hp := 0.0
	var total_max := 0.0
	var sum_x := 0.0
	for unit in units:
		total_hp += float(unit.get("hp", 0.0))
		total_max += float(unit.get("max_hp", 1.0))
		sum_x += float(unit.get("x", 0.0))
	var avg_x := sum_x / maxf(1.0, float(units.size()))
	draw_string(font, panel.position + Vector2(8.0, 14.0), "选中 %d 名   生命 %d/%d" % [units.size(), int(total_hp), int(total_max)], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 8, Color("#E8D5A9"))

	if units.size() == 1:
		var unit: Dictionary = units[0]
		draw_string(font, panel.position + Vector2(8.0, 29.0), "%s · %s" % [String(unit.get("name", "")), String(unit.get("guild_name", ""))], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 8, Color("#D9A441"))
		draw_string(font, panel.position + Vector2(8.0, 45.0), "%s · %s · %s" % [UIText.role_label(String(unit.get("role", ""))), UIText.attack_label(String(unit.get("attack_type", ""))), UIText.armor_label(String(unit.get("armor_type", "")))], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#B8B0C8"))
		draw_string(font, panel.position + Vector2(8.0, 61.0), "位置：%d路 x=%d" % [int(unit.get("lane", 0)) + 1, int(float(unit.get("x", 0.0)))], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#B8B0C8"))
		draw_string(font, panel.position + Vector2(8.0, 77.0), "状态：%s" % UIText.state_label(String(unit.get("state", ""))), HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#B8B0C8"))
		draw_line(panel.position + Vector2(8.0, 88.0), panel.position + Vector2(180.0, 88.0), Color("#3E3A4A"), 1.0)
		draw_string(font, panel.position + Vector2(8.0, 104.0), "右键 移动", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
		draw_string(font, panel.position + Vector2(8.0, 120.0), "H 驻守    R 返回推进线", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
		draw_string(font, panel.position + Vector2(8.0, 140.0), "拖框可选多支部队", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6B6B6B"))
		return

	draw_string(font, panel.position + Vector2(8.0, 29.0), "平均位置 x=%d   Shift 加选" % int(avg_x), HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#8A8498"))

	for i in range(SELECTION_TABS.size()):
		var tab_rect := _selection_tab_rect(i)
		var active := i == selection_tab
		draw_rect(tab_rect, Color("#252232") if not active else Color("#3B3348"))
		draw_rect(tab_rect, Color("#D9A441") if active else Color("#4A4658"), false, 1.0)
		_center_text_in(SELECTION_TABS[i], tab_rect, 7, Color("#E8D5A9") if active else Color("#8A8498"))

	var groups := selection_groups(selection_tab)
	var rows := mini(groups.size(), 6)
	for i in range(rows):
		var group: Dictionary = groups[i]
		var row := _selection_row_rect(i)
		draw_rect(row, Color("#1A1724") if i % 2 == 0 else Color("#211D2C"))
		draw_rect(row, Color("#4A4658"), false, 1.0)
		draw_string(font, row.position + Vector2(6.0, 11.0), "%s×%d" % [String(group.get("label", "")), int(group.get("count", 0))], HORIZONTAL_ALIGNMENT_LEFT, 88.0, 7, Color("#B8B0C8"))
		draw_string(font, row.position + Vector2(100.0, 11.0), "%d/%d" % [int(group.get("hp", 0.0)), int(group.get("max_hp", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, 76.0, 7, Color("#6FA8DC"))
	var rows_bottom := panel.position.y + 54.0 + rows * 17.0
	draw_line(Vector2(panel.position.x + 8.0, rows_bottom + 4.0), Vector2(panel.position.x + 180.0, rows_bottom + 4.0), Color("#3E3A4A"), 1.0)
	var footer_y := rows_bottom + 17.0
	if groups.size() > 6:
		draw_string(font, Vector2(panel.position.x + 8.0, footer_y), "另有 %d 组未显示" % (groups.size() - 6), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6B6B6B"))
		footer_y += 12.0
	draw_string(font, Vector2(panel.position.x + 8.0, footer_y), "点分组后：右键 移动", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	draw_string(font, Vector2(panel.position.x + 8.0, footer_y + 15.0), "H 驻守   R 归线", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))


func _draw_guide() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 360.0), Color(0.02, 0.02, 0.04, 0.985))
	draw_string(font, Vector2(20.0, 24.0), "战地指南   第 %d/%d 页   [F1 关闭]" % [guide_page + 1, GUIDE_PAGE_COUNT], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("#E8D5A9"))
	if guide_page == 0:
		_draw_guide_page_one()
	else:
		_draw_guide_page_two()
	draw_string(font, Vector2(20.0, 338.0), "←/→ 翻页   F1 关闭   F2 首份委托步骤   Esc 返回委托列表", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9"))


func _draw_guide_page_one() -> void:
	draw_string(font, Vector2(20.0, 48.0), "资源链", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 64.0), "金币：津贴 + 波次奖励 + 击杀赏金；用于招募、建交/升级协会、晋升。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 78.0), "名望：击杀金色菱形悬赏目标。声望：名望达标后花金币晋升。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 92.0), "协会：建交并升级可解锁职业、提高兵力上限；人情永久提供小幅属性/费用加成。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 118.0), "指挥", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 134.0), "推进线：Shift+右键设置；新招募的单位会前进并停在该线。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 148.0), "选中：左键点选、拖框多选、Shift 加选；右键移动，H 驻守，R 返回推进线。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 162.0), "小地图：左键跳转/拖框选择，右键移动，Shift+右键设置推进线。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 188.0), "选中信息面板", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 204.0), "多选时按 协会/攻型/甲型/职业 分组，显示数量与合计生命。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 218.0), "点击分组会把选择切换为该组，再右键移动或按 H/R。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 244.0), "首份委托流程", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#6FA8DC"))
	draw_string(font, Vector2(20.0, 260.0), "B 打开协会 → 与铁誓会建交 → 按 1 招募剑士 → Shift+右键设推进线", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))
	draw_string(font, Vector2(20.0, 274.0), "→ 击杀金色悬赏目标 → 名望达标后晋升 → 继续升级协会。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))
	draw_string(font, Vector2(20.0, 306.0), "按键：1-8 招募 · Alt+1-8 另一路 · B 协会 · Q/E 换路 · Space 暂停 · Ctrl+R 重开 · F2 首局步骤", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))


func _draw_guide_page_two() -> void:
	draw_string(font, Vector2(20.0, 48.0), "八种职业（定位 / 攻型 / 甲型 / 被动）", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#D9A441"))
	var catalog: Array = snapshot.get("catalog", [])
	for i in range(mini(catalog.size(), 8)):
		var card: Dictionary = catalog[i]
		var col := i % 2
		var row := int(i / 2)
		var line := "%s：%s / %s / %s · %s" % [
			String(card.get("name", "")),
			UIText.role_label(String(card.get("role", ""))),
			UIText.attack_label(String(card.get("attack_type", ""))),
			UIText.armor_label(String(card.get("armor_type", ""))),
			UIText.passive_name(String(card.get("passive", ""))),
		]
		draw_string(font, Vector2(20.0 + col * 306.0, 68.0 + row * 15.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 152.0), "克制关系", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 168.0), "近战：克制轻甲，弱于重甲。远程：对轻/重甲均衡，怕盗贼近身。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 182.0), "攻城：克制重甲，弱于轻甲。法师：范围伤害，适合清理密集队列。牧师：治疗最残血友军。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 196.0), "盗贼：背刺远程 +50%；盾墙：受到远程伤害 -30%。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 222.0), "悬赏目标与精英", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 238.0), "金色菱形 = 悬赏目标。击杀 +15 金 +1 名望；目标漏进基地同样会扣基地。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 252.0), "金色外框 = 精英。精英生命更高，漏进基地时造成额外伤害。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 278.0), "下一波预览", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#6FA8DC"))
	draw_string(font, Vector2(20.0, 294.0), "右上角显示下一波的路线、数量与目标标记；据攻/甲类型提前换兵。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))


func _selected_units() -> Array:
	var ids := {}
	for id in selected_ids:
		ids[int(id)] = true
	var result: Array = []
	for unit in snapshot.get("units", []):
		if int(unit.get("team", 1)) != 0:
			continue
		if ids.has(int(unit.get("id", -1))):
			result.append(unit)
	return result


func selection_groups(tab_index: int = -1) -> Array:
	var tab := selection_tab if tab_index < 0 else clampi(tab_index, 0, SELECTION_TABS.size() - 1)
	var groups := {}
	for unit in _selected_units():
		var key := ""
		var label := ""
		match tab:
			0:
				key = String(unit.get("guild", ""))
				label = String(unit.get("guild_name", key))
			1:
				key = String(unit.get("attack_type", ""))
				label = UIText.attack_label(key)
			2:
				key = String(unit.get("armor_type", ""))
				label = UIText.armor_label(key)
			_:
				key = String(unit.get("def_id", ""))
				label = String(unit.get("name", key))
		if not groups.has(key):
			groups[key] = {"key": key, "label": label, "count": 0, "hp": 0.0, "max_hp": 0.0, "ids": []}
		var group: Dictionary = groups[key]
		group["count"] = int(group["count"]) + 1
		group["hp"] = float(group["hp"]) + float(unit.get("hp", 0.0))
		group["max_hp"] = float(group["max_hp"]) + float(unit.get("max_hp", 0.0))
		group["ids"].append(int(unit.get("id", -1)))
	var result: Array = []
	for group in groups.values():
		result.append(group)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["count"]) == int(b["count"]):
			return String(a["label"]) < String(b["label"])
		return int(a["count"]) > int(b["count"])
	)
	return result


func _selection_visible() -> bool:
	return not selected_ids.is_empty() and not panel_open and not guide_open and not bool(snapshot.get("finished", false)) and not paused


func _selection_panel_rect() -> Rect2:
	var units := _selected_units()
	var height := 160.0
	if units.size() > 1:
		var rows := mini(selection_groups(selection_tab).size(), 6)
		height = 54.0 + maxi(1, rows) * 17.0 + 42.0
		if selection_groups(selection_tab).size() > 6:
			height += 12.0
	return Rect2(SELECTION_RECT.position.x, SELECTION_RECT.position.y, SELECTION_RECT.size.x, height)


func _selection_tab_rect(index: int) -> Rect2:
	return Rect2(SELECTION_RECT.position.x + 4.0 + index * SELECTION_TAB_W, SELECTION_RECT.position.y + 34.0, SELECTION_TAB_W - 2.0, 16.0)


func _selection_row_rect(index: int) -> Rect2:
	return Rect2(SELECTION_RECT.position.x + 4.0, SELECTION_RECT.position.y + 54.0 + index * 17.0, SELECTION_RECT.size.x - 8.0, 16.0)


func _selection_row_at(pos: Vector2) -> int:
	var groups := selection_groups(selection_tab)
	for i in range(mini(groups.size(), 6)):
		if _selection_row_rect(i).has_point(pos):
			return i
	return -1


func _selection_tab_at(pos: Vector2) -> int:
	for i in range(SELECTION_TABS.size()):
		if _selection_tab_rect(i).has_point(pos):
			return i
	return -1


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


func _world_width() -> float:
	return maxf(1.0, float(snapshot.get("world_width", WORLD_W)))


func _minimap_x(world_x: float) -> float:
	return MINIMAP_BAR_X + clampf(world_x, 0.0, _world_width()) / _world_width() * MINIMAP_BAR_W


func _minimap_world_x(local_x: float) -> float:
	return clampf((local_x - MINIMAP_BAR_X) / MINIMAP_BAR_W * _world_width(), 0.0, _world_width())


func _minimap_lane_at(pos: Vector2) -> int:
	var lane_count := clampi(int(snapshot.get("lane_count", 2)), 1, 2)
	for lane in range(lane_count):
		var bar := Rect2(MINIMAP_BAR_X, float(MINIMAP_LANE_Y[lane]), MINIMAP_BAR_W, MINIMAP_BAR_H)
		if bar.grow(3.0).has_point(pos):
			return lane
	return -1


func _unit_name(def_id: String) -> String:
	for card in snapshot.get("catalog", []):
		if String(card.get("id", "")) == def_id:
			return String(card.get("name", def_id))
	return def_id


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
	if _selection_visible() and _selection_panel_rect().has_point(pos):
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

	if _selection_visible() and _selection_panel_rect().has_point(pos):
		var tab := _selection_tab_at(pos)
		if tab >= 0:
			selection_tab = tab
			queue_redraw()
			return
		var row := _selection_row_at(pos)
		if row >= 0:
			var groups := selection_groups(selection_tab)
			if row < groups.size():
				selection_changed.emit(groups[row]["ids"])
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
