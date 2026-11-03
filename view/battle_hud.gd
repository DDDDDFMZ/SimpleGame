class_name BattleHUD
extends Control

signal spawn_requested(def_id: String)
signal guild_action_requested(guild_id: String)
signal promote_requested
signal minimap_clicked(world_pos: Vector2)
signal minimap_select(world_rect: Rect2, additive: bool)
signal minimap_order(world_pos: Vector2, shift: bool)
signal drag_started(screen_pos: Vector2)
signal drag_updated(screen_pos: Vector2)
signal drag_finished(screen_pos: Vector2, additive: bool)
signal world_right_click(screen_pos: Vector2, shift: bool)
signal result_action(action: String)
signal selection_changed(ids: Array)
signal zoom_requested(delta: float)
signal pause_action(action: String)
signal station_order_changed(order: Array)

const VIEW_W := 640.0
const VIEW_H := 360.0
const TOP_H := 64.0
const BOTTOM_Y := 300.0
const CARD_Y := 306.0
const CARD_W := 74.0
const CARD_H := 48.0
const CARD_GAP := 3.0
const CARD_X := 8.0
const MINIMAP_RECT := Rect2(462.0, 6.0, 170.0, 96.0)
const MINIMAP_INNER := Rect2(467.0, 11.0, 160.0, 82.0)
const MINIMAP_ZOOM_MINUS := Rect2(586.0, 84.0, 16.0, 13.0)
const MINIMAP_ZOOM_PLUS := Rect2(606.0, 84.0, 20.0, 13.0)
const WAVE_RECT := Rect2(298.0, 6.0, 126.0, 52.0)
const COMPANY_RECT := Rect2(120.0, 66.0, 400.0, 236.0)
const PROMOTE_RECT := Rect2(408.0, 84.0, 98.0, 20.0)
const SELECTION_RECT := Rect2(444.0, 108.0, 188.0, 181.0)
const SELECTION_TAB_W := 45.0
const SELECTION_TABS := ["协会", "攻型", "甲型", "职业"]
const GUIDE_PAGE_COUNT := 2
const PAUSE_RECT := Rect2(180.0, 70.0, 280.0, 226.0)
const STATION_RECT := Rect2(120.0, 52.0, 400.0, 256.0)
const RESULT_RECTS := {
	"retry": Rect2(180.0, 204.0, 84.0, 22.0),
	"next": Rect2(272.0, 204.0, 84.0, 22.0),
	"levels": Rect2(364.0, 204.0, 96.0, 22.0),
}
const PAUSE_BUTTONS := [
	{"action": "resume", "label": "继续", "rect": Rect2(198.0, 102.0, 112.0, 26.0)},
	{"action": "guide", "label": "战地指南", "rect": Rect2(330.0, 102.0, 112.0, 26.0)},
	{"action": "backup", "label": "备份进度", "rect": Rect2(198.0, 134.0, 112.0, 26.0)},
	{"action": "station_order", "label": "站位顺序", "rect": Rect2(330.0, 134.0, 112.0, 26.0)},
	{"action": "restart", "label": "重开本局", "rect": Rect2(198.0, 166.0, 112.0, 26.0)},
	{"action": "levels", "label": "返回委托", "rect": Rect2(330.0, 166.0, 112.0, 26.0)},
]

var snapshot: Dictionary = {}
var active_route: int = 0
var panel_open: bool = false
var paused: bool = false
var pause_menu: bool = false
var pause_confirm: String = ""
var pause_status: String = ""
var station_order_open: bool = false
var station_order: Array = []
var station_selected: int = 0
var camera_pos: Vector2 = Vector2(800.0, 450.0)
var zoom_level: float = 0.75
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
var minimap_start: Vector2 = Vector2.ZERO
var minimap_current: Vector2 = Vector2.ZERO
var minimap_moved: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	font = system_font
	queue_redraw()


func update_snapshot(p_snapshot: Dictionary, p_active_route: int) -> void:
	snapshot = p_snapshot
	active_route = clampi(p_active_route, 0, maxi(0, int(snapshot.get("routes", []).size()) - 1))
	if station_order.is_empty() or not station_order_open:
		station_order = snapshot.get("station_order", []).duplicate()
	if not checklist_initialized and int(snapshot.get("contract", 0)) == 1:
		checklist_open = true
		checklist_initialized = true
	queue_redraw()


func set_selection(ids: Array) -> void:
	selected_ids = ids.duplicate()
	queue_redraw()


func set_camera(pos: Vector2, zoom: float, follow: bool) -> void:
	camera_pos = pos
	zoom_level = maxf(0.1, zoom)
	follow_mode = follow
	queue_redraw()


func set_paused(value: bool) -> void:
	paused = value
	queue_redraw()


func set_pause_menu(value: bool) -> void:
	pause_menu = value
	if value:
		pause_status = ""
	if not value:
		pause_confirm = ""
		station_order_open = false
	queue_redraw()


func set_pause_status(text: String) -> void:
	pause_status = text
	queue_redraw()


func open_station_order() -> void:
	station_order_open = true
	station_selected = 0
	pause_status = ""
	station_order = snapshot.get("station_order", []).duplicate()
	queue_redraw()


func toggle_panel() -> void:
	if paused or station_order_open:
		return
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
	var route := _active_route_data()
	var route_name := String(route.get("name", "路线"))
	var route_used := int(route.get("used", 0))
	var route_cap := int(route.get("capacity", 0))
	var wave_text := ("无尽 第%d波 %.0f秒" % [wave_index, next_in]) if mode == "endless" else ("第%d/%d波 %.0f秒" % [wave_index, wave_count, next_in])

	draw_string(font, Vector2(8.0, 13.0), "金币 %d (+%.1f/秒)  兵力 %d/%d  基地 %d/%d" % [gold, stipend, used, cap, int(hp[0]), int(snapshot.get("base_hp_max", 20))], HORIZONTAL_ALIGNMENT_LEFT, 286.0, 8, Color("#E8D5A9"))
	var target_text := "悬赏击杀 %d" % target_kills if mode == "endless" else "悬赏 %d/%d" % [target_kills, target_total]
	draw_string(font, Vector2(8.0, 27.0), "%s  声望 R%d  功勋 %d/%d  晋级 %d金  %s" % [wave_text, rank, fame, promo_kills, promo_cost, target_text], HORIZONTAL_ALIGNMENT_LEFT, 286.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(8.0, 41.0), "路线 %s %d/%d  Q/E 换路  滚轮缩放 ×%.1f  F1 指南" % [route_name, route_used, route_cap, zoom_level], HORIZONTAL_ALIGNMENT_LEFT, 286.0, 7, Color("#8A8498"))
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
	var cooldowns: Dictionary = snapshot.get("cooldowns", {})
	var route_id := String(route.get("id", ""))
	var cd_map: Dictionary = cooldowns.get(route_id, {})
	for i in range(mini(catalog.size(), 8)):
		_draw_card(i, catalog[i], cd_map, gold, used, cap)

	if _selection_visible():
		_draw_selection_panel()

	if panel_open:
		_draw_company()

	if checklist_open and not panel_open and not guide_open and not bool(snapshot.get("finished", false)) and not paused:
		_draw_checklist()

	if hover_card >= 0 and not panel_open and not guide_open and not paused and not bool(snapshot.get("finished", false)):
		_draw_tooltip()

	if paused:
		_draw_pause_menu()

	if bool(snapshot.get("finished", false)):
		_draw_result()

	if guide_open:
		_draw_guide()


func _draw_minimap() -> void:
	draw_rect(MINIMAP_RECT, Color(0.05, 0.04, 0.08, 0.96))
	draw_rect(MINIMAP_RECT, Color("#4A4658"), false, 1.0)
	var world_w := maxf(1.0, float(snapshot.get("world_width", 1600.0)))
	var world_h := maxf(1.0, float(snapshot.get("world_height", 900.0)))
	var map: Dictionary = snapshot.get("map", {})
	var routes: Array = snapshot.get("routes", [])
	var active_path: Array = routes[active_route].get("path", []) if active_route < routes.size() else []
	for edge in map.get("edges", []):
		var edge_id := String(edge.get("id", ""))
		var points: Array = edge.get("points", [])
		var color := Color("#D9A441") if active_path.has(edge_id) else Color("#4A4658")
		for i in range(1, points.size()):
			draw_line(_minimap_point(points[i - 1], world_w, world_h), _minimap_point(points[i], world_w, world_h), color, 2.0 if active_path.has(edge_id) else 1.0)
	for node in map.get("nodes", []):
		var p := _minimap_point(node.get("pos", []), world_w, world_h)
		var team := int(node.get("team", -1))
		var color := Color("#6FA8DC") if team == 0 else (Color("#E06666") if team == 1 else Color("#8A8498"))
		draw_circle(p, 4.0 if team >= 0 else 2.0, color)
	for u in snapshot.get("units", []):
		var p := _minimap_point(u.get("pos", []), world_w, world_h)
		var color := Color("#6FA8DC") if int(u.get("team", 0)) == 0 else Color("#E06666")
		if bool(u.get("is_target", false)):
			color = Color("#D9A441")
		draw_rect(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), color)
	var cam_rect := Rect2(
		camera_pos - Vector2(VIEW_W, VIEW_H) / (2.0 * zoom_level),
		Vector2(VIEW_W, VIEW_H) / zoom_level
	)
	var cam_tl := _minimap_point([cam_rect.position.x, cam_rect.position.y], world_w, world_h)
	var cam_br := _minimap_point([cam_rect.end.x, cam_rect.end.y], world_w, world_h)
	draw_rect(Rect2(cam_tl, cam_br - cam_tl), Color(1.0, 1.0, 1.0, 0.55), false, 1.0)
	draw_string(font, Vector2(467.0, 96.0), "×%.1f" % zoom_level, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#B8B0C8"))
	draw_rect(MINIMAP_ZOOM_MINUS, Color("#252232"))
	draw_rect(MINIMAP_ZOOM_PLUS, Color("#252232"))
	_center_text_in("-", MINIMAP_ZOOM_MINUS, 9, Color("#E8D5A9"))
	_center_text_in("+", MINIMAP_ZOOM_PLUS, 9, Color("#E8D5A9"))


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
	draw_string(font, COMPANY_RECT.position + Vector2(12.0, 38.0), "声望 R%d   功勋 %d/%d（累计）   晋级 %d金" % [rank, fame, promo_kills, promo_cost], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, COMPANY_RECT.position + Vector2(12.0, 52.0), "下一级：%s" % _rank_effect(rank, max_rank), HORIZONTAL_ALIGNMENT_LEFT, 374.0, 7, Color("#D9A441"))
	draw_rect(PROMOTE_RECT, Color("#252232"))
	draw_rect(PROMOTE_RECT, Color("#D9A441") if rank < max_rank else Color("#4A4658"), false, 1.0)
	draw_string(font, PROMOTE_RECT.position + Vector2(18.0, 15.0), "晋级 R%d" % mini(rank + 1, max_rank), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9") if rank < max_rank else Color("#6B6B6B"))

	var guilds: Array = snapshot.get("guilds", [])
	for i in range(mini(guilds.size(), 3)):
		var guild: Dictionary = guilds[i]
		var rect := _guild_rect(i)
		draw_rect(rect, Color("#1A1724"))
		draw_rect(rect, Color("#D9A441") if bool(guild.get("unlocked", false)) else Color("#4A4658"), false, 1.0)
		var guild_name := String(guild.get("name", guild.get("id", "")))
		var identity := String(guild.get("identity_cn", ""))
		var tier := int(guild.get("tier", -1))
		var tier_text := "未解锁" if not bool(guild.get("unlocked", false)) else ("未建交" if tier < 0 else "关系 %d" % tier)
		draw_string(font, rect.position + Vector2(7.0, 14.0), "%s   %s   %s" % [guild_name, tier_text, identity], HORIZONTAL_ALIGNMENT_LEFT, 360.0, 8, Color("#E8D5A9"))
		var next_text := ""
		var gate := int(guild.get("rank_gate", 0))
		if bool(guild.get("unlocked", false)) and int(guild.get("max_tier", 0)) > tier:
			var unlock_names: Array = guild.get("next_unit_names", [])
			var unlock_text := UIText.join_names(unlock_names) if not unlock_names.is_empty() else "无新职业"
			next_text = "下级 %d金 · 兵力+%d · 解锁：%s" % [int(guild.get("next_cost", 0)), int(guild.get("next_cap", 0)), unlock_text]
		else:
			next_text = "已满级" if bool(guild.get("unlocked", false)) else "通关前置委托后开放"
		var gate_text := "需声望 R%d · " % gate if gate > rank and bool(guild.get("unlocked", false)) else ""
		draw_string(font, rect.position + Vector2(7.0, 28.0), "%s%s  人情 %d" % [gate_text, next_text, int(guild.get("favor", 0))], HORIZONTAL_ALIGNMENT_LEFT, 360.0, 7, Color("#E06666") if gate_text != "" else Color("#8A8498"))
	draw_string(font, COMPANY_RECT.position + Vector2(12.0, 220.0), "花金币建交/升级协会：解锁职业并提高兵力上限。人情：+%s%% 生命/伤害，-%s%% 费用。" % [str(_favor_stat()), str(_favor_cost())], HORIZONTAL_ALIGNMENT_LEFT, 376.0, 7, Color("#6B6B6B"))


func _rank_effect(rank: int, max_rank: int) -> String:
	if rank >= max_rank:
		return "声望已满：兵力上限已全部获得"
	match rank:
		0:
			return "R1：兵力上限+2 · 解锁协会关系 T2"
		1:
			return "R2：兵力上限+2 · 解锁协会关系 T3"
		_:
			return "R3：兵力上限+2（满级）"


func _favor_stat() -> float:
	return float(snapshot.get("favor_hp_per_point", 0.01)) * 100.0


func _favor_cost() -> float:
	return float(snapshot.get("favor_cost_per_point", 0.005)) * 100.0


func _draw_pause_menu() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 360.0), Color(0.0, 0.0, 0.0, 0.62))
	draw_rect(PAUSE_RECT, Color(0.06, 0.05, 0.09, 0.99))
	draw_rect(PAUSE_RECT, Color("#D9A441"), false, 1.5)
	_center_text("暂停", 94.0, 18, Color("#E8D5A9"))
	for button in PAUSE_BUTTONS:
		var rect: Rect2 = button["rect"]
		draw_rect(rect, Color("#252232"))
		draw_rect(rect, Color("#4A4658"), false, 1.0)
		_center_text_in(String(button["label"]), rect, 8, Color("#E8D5A9"))
	draw_string(font, Vector2(PAUSE_RECT.position.x + 18.0, 220.0), "空格/Esc 继续   F1 指南   暂停期间游戏输入已锁定", HORIZONTAL_ALIGNMENT_LEFT, 250.0, 7, Color("#8A8498"))
	if pause_status != "":
		_center_text(pause_status, 246.0, 8, Color("#6FA8DC"))
	if station_order_open:
		_draw_station_order()
		return
	if pause_confirm != "":
		var confirm := Rect2(210.0, 254.0, 220.0, 34.0)
		draw_rect(confirm, Color("#1A1724"))
		draw_rect(confirm, Color("#E06666"), false, 1.0)
		_center_text("确认%s？" % ("重开本局" if pause_confirm == "restart" else "返回委托"), 270.0, 9, Color("#E8D5A9"))
		draw_rect(Rect2(248.0, 276.0, 64.0, 20.0), Color("#3A2020"))
		draw_rect(Rect2(328.0, 276.0, 64.0, 20.0), Color("#252232"))
		_center_text_in("确认", Rect2(248.0, 276.0, 64.0, 20.0), 8, Color("#E06666"))
		_center_text_in("取消", Rect2(328.0, 276.0, 64.0, 20.0), 8, Color("#B8B0C8"))


func _draw_station_order() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 360.0), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(STATION_RECT, Color(0.06, 0.05, 0.09, 0.99))
	draw_rect(STATION_RECT, Color("#6FA8DC"), false, 1.5)
	draw_string(font, Vector2(132.0, 72.0), "站位顺序（前排 → 后排）", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color("#E8D5A9"))
	draw_string(font, Vector2(132.0, 88.0), "影响排队入路优先级与集结点前后站位；不改战斗数值。", HORIZONTAL_ALIGNMENT_LEFT, 360.0, 7, Color("#8A8498"))
	var catalog_lookup := _catalog_lookup()
	for i in range(mini(station_order.size(), 8)):
		var row := _station_row_rect(i)
		var def_id := String(station_order[i])
		draw_rect(row, Color("#252232") if i == station_selected else Color("#1A1724"))
		draw_rect(row, Color("#6FA8DC") if i == station_selected else Color("#4A4658"), false, 1.0)
		draw_string(font, row.position + Vector2(8.0, 14.0), "%d  %s" % [i + 1, String(catalog_lookup.get(def_id, def_id))], HORIZONTAL_ALIGNMENT_LEFT, 300.0, 8, Color("#E8D5A9"))
		var up := _station_up_rect(i)
		var down := _station_down_rect(i)
		draw_rect(up, Color("#252232"))
		draw_rect(down, Color("#252232"))
		_center_text_in("↑", up, 8, Color("#B8B0C8"))
		_center_text_in("↓", down, 8, Color("#B8B0C8"))
	draw_rect(Rect2(448.0, 272.0, 56.0, 22.0), Color("#252232"))
	_center_text_in("关闭", Rect2(448.0, 272.0, 56.0, 22.0), 8, Color("#E8D5A9"))


func _draw_wave_preview() -> void:
	var preview: Dictionary = snapshot.get("next_wave_preview", {})
	if preview.is_empty():
		return
	draw_rect(WAVE_RECT, Color(0.05, 0.04, 0.08, 0.92))
	draw_rect(WAVE_RECT, Color("#4A4658"), false, 1.0)
	draw_string(font, WAVE_RECT.position + Vector2(7.0, 12.0), "下一波 %.0f秒" % float(preview.get("time", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#D9A441"))
	var y := 24.0
	for route_data in preview.get("routes", []):
		var parts: Array = []
		for unit in route_data.get("units", []):
			var mark := "*" if bool(unit.get("target", false)) else ""
			parts.append("%d%s%s" % [int(unit.get("count", 1)), _unit_name(String(unit.get("id", ""))), mark])
		var route_name := String(route_data.get("name", "路"))
		var short_name := route_name if route_name.length() <= 2 else route_name.substr(route_name.length() - 2, 2)
		draw_string(font, WAVE_RECT.position + Vector2(7.0, y), "%s %s" % [short_name, " ".join(PackedStringArray(parts))], HORIZONTAL_ALIGNMENT_LEFT, 112.0, 7, Color("#B8B0C8"))
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
	var lines: Array = snapshot.get("routes", [])
	var rallied := false
	for line in lines:
		var rally: Dictionary = line.get("rally", {})
		if bool(rally.get("custom", false)):
			rallied = true
			break
	var steps: Array = [
		["按 B 打开协会", company_seen],
		["与铁誓会建交", iron_tier >= 0],
		["招募一名冒险者", used > 0],
		["Shift+右键 设置集结点", rallied],
		["击杀金色悬赏目标", int(snapshot.get("target_kills", 0)) > 0],
		["晋级声望", int(snapshot.get("rep_rank", 0)) > 0],
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
	if station_order_open:
		_draw_station_order()
		return
	var panel := _selection_panel_rect()
	draw_rect(panel, Color(0.05, 0.04, 0.08, 0.94))
	draw_rect(panel, Color("#6FA8DC"), false, 1.0)
	var total_hp := 0.0
	var total_max := 0.0
	var sum_x := 0.0
	var sum_y := 0.0
	for unit in units:
		var pos := _unit_pos(unit)
		total_hp += float(unit.get("hp", 0.0))
		total_max += float(unit.get("max_hp", 1.0))
		sum_x += pos.x
		sum_y += pos.y
	var avg_x := sum_x / maxf(1.0, float(units.size()))
	var avg_y := sum_y / maxf(1.0, float(units.size()))
	draw_string(font, panel.position + Vector2(8.0, 14.0), "选中 %d 名   生命 %d/%d" % [units.size(), int(total_hp), int(total_max)], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 8, Color("#E8D5A9"))

	if units.size() == 1:
		var unit: Dictionary = units[0]
		draw_string(font, panel.position + Vector2(8.0, 29.0), "%s · %s" % [String(unit.get("name", "")), String(unit.get("guild_name", ""))], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 8, Color("#D9A441"))
		draw_string(font, panel.position + Vector2(8.0, 45.0), "%s · %s · %s" % [UIText.role_label(String(unit.get("role", ""))), UIText.attack_label(String(unit.get("attack_type", ""))), UIText.armor_label(String(unit.get("armor_type", "")))], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#B8B0C8"))
		var edge_id := String(unit.get("edge_id", ""))
		var pos := _unit_pos(unit)
		draw_string(font, panel.position + Vector2(8.0, 61.0), "位置：x=%d y=%d" % [int(pos.x), int(pos.y)], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#B8B0C8"))
		draw_string(font, panel.position + Vector2(8.0, 75.0), "路段：%s" % ("排队" if bool(unit.get("waiting", false)) else edge_id), HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#B8B0C8"))
		draw_string(font, panel.position + Vector2(8.0, 89.0), "状态：%s" % UIText.state_label(String(unit.get("state", ""))), HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#B8B0C8"))
		draw_line(panel.position + Vector2(8.0, 100.0), panel.position + Vector2(180.0, 100.0), Color("#3E3A4A"), 1.0)
		draw_string(font, panel.position + Vector2(8.0, 116.0), "右键 移动   H 驻守", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
		draw_string(font, panel.position + Vector2(8.0, 132.0), "R 返回集结点", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
		return

	draw_string(font, panel.position + Vector2(8.0, 29.0), "平均位置 x=%d y=%d" % [int(avg_x), int(avg_y)], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#8A8498"))
	for i in range(SELECTION_TABS.size()):
		var tab_rect := _selection_tab_rect(i)
		var active := i == selection_tab
		draw_rect(tab_rect, Color("#252232") if not active else Color("#3B3348"))
		draw_rect(tab_rect, Color("#D9A441") if active else Color("#4A4658"), false, 1.0)
		_center_text_in(SELECTION_TABS[i], tab_rect, 7, Color("#E8D5A9") if active else Color("#8A8498"))
	var groups := selection_groups(selection_tab)
	var rows := mini(groups.size(), 5)
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
	if groups.size() > 5:
		draw_string(font, Vector2(panel.position.x + 8.0, footer_y), "另有 %d 组未显示" % (groups.size() - 5), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6B6B6B"))
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
	draw_string(font, Vector2(20.0, 338.0), "←/→ 翻页   F1/Esc 关闭   F2 首份委托步骤   暂停菜单可备份/重开/返回", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#E8D5A9"))


func _draw_guide_page_one() -> void:
	draw_string(font, Vector2(20.0, 48.0), "资源与晋升", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 64.0), "金币：津贴 + 波次奖励 + 击杀赏金；用于招募、建交/升级协会、晋级声望。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 78.0), "功勋：累计击杀金色悬赏目标，不会被消耗；晋级消耗金币。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 92.0), "协会：建交并升级可解锁职业、提高兵力上限；人情永久提供小幅属性/费用加成。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 112.0), "声望晋级：R1 解锁协会T2；R2 解锁T3；R3 仅再+2兵力（满级）。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 126.0), "每级晋级都 +2 兵力上限；协会行会显示“需声望 R1/R2”。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 150.0), "指挥", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 166.0), "路线：Q/E 切换出生路线；1-8 当前路线招募，Alt+1-8 下一路线。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 180.0), "集结点：Shift+右键；新兵/无手动指令单位走向该路线的集结点。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 194.0), "选中：左键点选、拖框多选、Shift 加选；右键移动，H 驻守，R 返回集结点。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 208.0), "容量：路线宽度决定每方人数上限；满员在交汇点排队，站位顺序决定入路优先级。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 230.0), "选中信息面板", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 246.0), "多选时按 协会/攻型/甲型/职业 分组；点击分组后移动/驻守/归线。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 268.0), "首份委托流程", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#6FA8DC"))
	draw_string(font, Vector2(20.0, 284.0), "B 打开协会 → 与铁誓会建交 → 1 招募剑士 → Shift+右键设集结点", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))
	draw_string(font, Vector2(20.0, 298.0), "→ 击杀金色悬赏目标 → 功勋达标后晋级声望 → 继续升级协会。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))
	draw_string(font, Vector2(20.0, 320.0), "按键：1-8 招募 · Alt+1-8 下一路线 · Q/E 换路 · B 协会 · Space 暂停 · F1 指南 · F2 步骤", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))


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
	draw_string(font, Vector2(20.0, 182.0), "攻城：克制重甲，弱于轻甲。法师：范围伤害。牧师：治疗最残血友军。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 196.0), "盗贼：背刺远程 +50%；盾墙：受到远程伤害 -30%。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 222.0), "悬赏目标与精英", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#D9A441"))
	draw_string(font, Vector2(20.0, 238.0), "金色菱形 = 悬赏目标。击杀 +15 金 +1 功勋；目标漏进基地会扣基地。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 252.0), "金色外框 = 精英。精英生命更高，漏进基地时造成额外伤害。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
	draw_string(font, Vector2(20.0, 278.0), "缩放与小地图", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#6FA8DC"))
	draw_string(font, Vector2(20.0, 294.0), "滚轮/减号/等号缩放；小地图相机框随缩放同步；右键小地图移动，Shift+右键设集结点。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))


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
	_center_text("招募 %d 金 / 协会 %d 金 / 晋级 %d 金   剩余 %d 金" % [int(stats.get("gold_spent_units", 0)), int(stats.get("gold_spent_guilds", 0)), int(stats.get("gold_spent_promote", 0)), int(stats.get("gold_unspent", 0))], 186.0, 7, Color("#8A8498"))
	for action in RESULT_RECTS:
		var r: Rect2 = RESULT_RECTS[action]
		draw_rect(r, Color("#252232"))
		draw_rect(r, Color("#4A4658"), false, 1.0)
		var label: String = {"retry": "重试", "next": "下一关", "levels": "委托列表"}[action]
		_center_text_in(label, r, 8, Color("#E8D5A9"))


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
		var rows := mini(selection_groups(selection_tab).size(), 5)
		height = 54.0 + maxi(1, rows) * 17.0 + 42.0
		if selection_groups(selection_tab).size() > 5:
			height += 12.0
	return Rect2(SELECTION_RECT.position.x, SELECTION_RECT.position.y, SELECTION_RECT.size.x, minf(181.0, height))


func _selection_tab_rect(index: int) -> Rect2:
	return Rect2(SELECTION_RECT.position.x + 4.0 + index * SELECTION_TAB_W, SELECTION_RECT.position.y + 34.0, SELECTION_TAB_W - 2.0, 16.0)


func _selection_row_rect(index: int) -> Rect2:
	return Rect2(SELECTION_RECT.position.x + 4.0, SELECTION_RECT.position.y + 54.0 + index * 17.0, SELECTION_RECT.size.x - 8.0, 16.0)


func _selection_row_at(pos: Vector2) -> int:
	var groups := selection_groups(selection_tab)
	for i in range(mini(groups.size(), 5)):
		if _selection_row_rect(i).has_point(pos):
			return i
	return -1


func _selection_tab_at(pos: Vector2) -> int:
	for i in range(SELECTION_TABS.size()):
		if _selection_tab_rect(i).has_point(pos):
			return i
	return -1


func _station_row_rect(index: int) -> Rect2:
	return Rect2(132.0, 98.0 + index * 21.0, 306.0, 19.0)


func _station_up_rect(index: int) -> Rect2:
	return Rect2(444.0, 100.0 + index * 21.0, 18.0, 17.0)


func _station_down_rect(index: int) -> Rect2:
	return Rect2(466.0, 100.0 + index * 21.0, 18.0, 17.0)


func _catalog_lookup() -> Dictionary:
	var result := {}
	for card in snapshot.get("catalog", []):
		result[String(card.get("id", ""))] = String(card.get("name", ""))
	return result


func _card_rect(index: int) -> Rect2:
	return Rect2(CARD_X + index * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H)


func _guild_rect(index: int) -> Rect2:
	return Rect2(132.0, 124.0 + index * 42.0, 376.0, 40.0)


func _card_at(pos: Vector2) -> int:
	var catalog: Array = snapshot.get("catalog", [])
	for i in range(mini(catalog.size(), 8)):
		if _card_rect(i).has_point(pos):
			return i
	return -1


func _active_route_data() -> Dictionary:
	var routes: Array = snapshot.get("routes", [])
	if active_route < 0 or active_route >= routes.size():
		return {}
	return routes[active_route]


func _minimap_scale(world_w: float, world_h: float) -> float:
	return minf(MINIMAP_INNER.size.x / world_w, MINIMAP_INNER.size.y / world_h)


func _minimap_point(world_pos_value: Variant, world_w: float, world_h: float) -> Vector2:
	var world_pos := _value_pos(world_pos_value)
	var scale := _minimap_scale(world_w, world_h)
	var used := Vector2(world_w, world_h) * scale
	var origin := MINIMAP_INNER.position + (MINIMAP_INNER.size - used) * 0.5
	return origin + world_pos * scale


func _minimap_world(local: Vector2, world_w: float, world_h: float) -> Vector2:
	var scale := _minimap_scale(world_w, world_h)
	var used := Vector2(world_w, world_h) * scale
	var origin := MINIMAP_INNER.position + (MINIMAP_INNER.size - used) * 0.5
	return Vector2(
		clampf((local.x - origin.x) / scale, 0.0, world_w),
		clampf((local.y - origin.y) / scale, 0.0, world_h)
	)


func _value_pos(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _unit_pos(unit: Dictionary) -> Vector2:
	return _value_pos(unit.get("pos", []))


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
	if MINIMAP_RECT.has_point(pos):
		return true
	if panel_open and COMPANY_RECT.has_point(pos):
		return true
	if _selection_visible() and _selection_panel_rect().has_point(pos):
		return true
	if paused and PAUSE_RECT.has_point(pos):
		return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover_card = -1
		drag_active = false
		minimap_drag = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if guide_open:
		accept_event()
		return
	if event is InputEventMouseMotion:
		hover_pos = event.position
		hover_card = _card_at(hover_pos) if not paused and not station_order_open else -1
		if minimap_drag:
			minimap_current = event.position
			minimap_moved = minimap_moved or minimap_start.distance_to(minimap_current) > 3.0
			queue_redraw()
			accept_event()
		elif drag_active:
			drag_updated.emit(event.position)
			accept_event()
		queue_redraw()
		return

	if not (event is InputEventMouseButton):
		return
	var pos: Vector2 = event.position

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if not paused and not station_order_open and not bool(snapshot.get("finished", false)):
			zoom_requested.emit(CameraRig.ZOOM_STEP)
			accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not paused and not station_order_open and not bool(snapshot.get("finished", false)):
			zoom_requested.emit(-CameraRig.ZOOM_STEP)
			accept_event()
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if bool(snapshot.get("finished", false)):
				_handle_result_click(pos)
				accept_event()
				return
			if pause_menu or paused:
				_handle_pause_click(pos)
				accept_event()
				return
			if station_order_open:
				_handle_station_click(pos)
				accept_event()
				return
			if MINIMAP_RECT.has_point(pos):
				if MINIMAP_ZOOM_MINUS.has_point(pos):
					zoom_requested.emit(-CameraRig.ZOOM_STEP)
				elif MINIMAP_ZOOM_PLUS.has_point(pos):
					zoom_requested.emit(CameraRig.ZOOM_STEP)
				else:
					minimap_drag = true
					minimap_start = pos
					minimap_current = pos
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
				var world_w := maxf(1.0, float(snapshot.get("world_width", 1600.0)))
				var world_h := maxf(1.0, float(snapshot.get("world_height", 900.0)))
				if minimap_moved:
					var a := _minimap_world(minimap_start, world_w, world_h)
					var b := _minimap_world(minimap_current, world_w, world_h)
					minimap_select.emit(Rect2(a, b - a).abs(), event.shift_pressed)
				else:
					minimap_clicked.emit(_minimap_world(pos, world_w, world_h))
				minimap_drag = false
				queue_redraw()
				accept_event()
				return
			if drag_active:
				drag_finished.emit(pos, event.shift_pressed)
				drag_active = false
				accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if paused or station_order_open or bool(snapshot.get("finished", false)):
			accept_event()
			return
		var world_w := maxf(1.0, float(snapshot.get("world_width", 1600.0)))
		var world_h := maxf(1.0, float(snapshot.get("world_height", 900.0)))
		if MINIMAP_RECT.has_point(pos) and not MINIMAP_ZOOM_MINUS.has_point(pos) and not MINIMAP_ZOOM_PLUS.has_point(pos):
			minimap_order.emit(_minimap_world(pos, world_w, world_h), event.shift_pressed)
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


func _handle_pause_click(pos: Vector2) -> void:
	if pause_confirm != "":
		if Rect2(248.0, 276.0, 64.0, 20.0).has_point(pos):
			var action := pause_confirm
			pause_confirm = ""
			pause_action.emit(action)
		elif Rect2(328.0, 276.0, 64.0, 20.0).has_point(pos):
			pause_confirm = ""
		return
	if station_order_open:
		_handle_station_click(pos)
		return
	for button in PAUSE_BUTTONS:
		if (button["rect"] as Rect2).has_point(pos):
			var action := String(button["action"])
			if action == "restart" or action == "levels":
				pause_confirm = action
			else:
				pause_action.emit(action)
			queue_redraw()
			return


func _handle_station_click(pos: Vector2) -> void:
	if Rect2(448.0, 272.0, 56.0, 22.0).has_point(pos):
		station_order_open = false
		queue_redraw()
		return
	for i in range(mini(station_order.size(), 8)):
		if _station_up_rect(i).has_point(pos):
			_move_station(i, -1)
			return
		if _station_down_rect(i).has_point(pos):
			_move_station(i, 1)
			return
		if _station_row_rect(i).has_point(pos):
			station_selected = i
			queue_redraw()
			return


func _move_station(index: int, delta: int) -> void:
	var other := index + delta
	if other < 0 or other >= station_order.size():
		return
	var temp: Variant = station_order[index]
	station_order[index] = station_order[other]
	station_order[other] = temp
	station_selected = other
	station_order_changed.emit(station_order.duplicate())
	queue_redraw()


func _handle_ui_click(pos: Vector2) -> void:
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
				var guild: Dictionary = guilds[i]
				var gate := int(guild.get("rank_gate", 0))
				if gate > int(snapshot.get("rep_rank", 0)) and bool(guild.get("unlocked", false)):
					return
				guild_action_requested.emit(String(guild.get("id", "")))
				return
		return

	var catalog: Array = snapshot.get("catalog", [])
	for i in range(mini(catalog.size(), 8)):
		if _card_rect(i).has_point(pos):
			spawn_requested.emit(String(catalog[i].get("id", "")))
			return
