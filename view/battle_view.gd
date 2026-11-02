class_name BattleView
extends Node2D

const LANE_Y := [110.0, 250.0]
const WORLD_W := 1600.0
const VIEW_H := 360.0
const PLAYER_BASE_X := 80.0
const ENEMY_BASE_X := 1520.0

var runner: SimRunner
var unit_views: Dictionary = {}
var last_snapshot: Dictionary = {}
var active_lane: int = 0
var selected_ids: Array = []
var drag_world_rect: Rect2 = Rect2()
var drag_active: bool = false
var font: Font


func _ready() -> void:
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	font = system_font


func setup(p_runner: SimRunner) -> void:
	runner = p_runner
	if not runner.ticked.is_connected(_on_ticked):
		runner.ticked.connect(_on_ticked)


func set_active_lane(lane: int) -> void:
	active_lane = clampi(lane, 0, maxi(0, _lane_count() - 1))
	queue_redraw()


func set_drag_rect(rect: Rect2, active: bool) -> void:
	drag_world_rect = rect
	drag_active = active
	queue_redraw()


func set_selected(ids: Array) -> void:
	selected_ids = ids.duplicate()
	for id in unit_views.keys():
		unit_views[id].set_selected(selected_ids.has(id))
	queue_redraw()


func reset_view() -> void:
	for view in unit_views.values():
		view.queue_free()
	unit_views.clear()
	last_snapshot = {}
	drag_active = false
	drag_world_rect = Rect2()
	queue_redraw()


func _on_ticked(snapshot: Dictionary) -> void:
	last_snapshot = snapshot
	_sync_units(snapshot.get("units", []))
	queue_redraw()


func _lane_count() -> int:
	var map: Dictionary = last_snapshot.get("map", {})
	var routes: Array = map.get("routes", [])
	if routes.is_empty():
		return LANE_Y.size()
	return mini(routes.size(), LANE_Y.size())


func lane_y(lane: int) -> float:
	var map: Dictionary = last_snapshot.get("map", {})
	var routes: Array = map.get("routes", [])
	if lane >= 0 and lane < routes.size():
		return float(routes[lane].get("y", LANE_Y[clampi(lane, 0, LANE_Y.size() - 1)]))
	return float(LANE_Y[clampi(lane, 0, LANE_Y.size() - 1)])


func _sync_units(units_data: Array) -> void:
	var seen := {}
	for data in units_data:
		var id := int(data.get("id", -1))
		if id < 0:
			continue
		seen[id] = true
		var view: UnitView = unit_views.get(id)
		if view == null:
			view = UnitView.new()
			add_child(view)
			unit_views[id] = view
		var lane := clampi(int(data.get("lane", 0)), 0, maxi(0, _lane_count() - 1))
		view.update_data(data, lane_y(lane))
		view.set_selected(selected_ids.has(id))

	for id in unit_views.keys():
		if not seen.has(id):
			unit_views[id].queue_free()
			unit_views.erase(id)


func _draw() -> void:
	var map: Dictionary = last_snapshot.get("map", {})
	var routes: Array = map.get("routes", [])
	var world_w := float(map.get("world_width", last_snapshot.get("world_width", WORLD_W)))
	var world_h := float(map.get("world_height", last_snapshot.get("world_height", VIEW_H)))
	var player_base := float(last_snapshot.get("player_base_x", PLAYER_BASE_X))
	var enemy_base := float(last_snapshot.get("enemy_base_x", ENEMY_BASE_X))
	var lane_count := _lane_count()
	if routes.is_empty():
		routes = _default_routes(world_h)

	# Background and world bound.
	draw_rect(Rect2(0.0, 0.0, world_w, world_h), Color("#1E1A2B"))
	draw_rect(Rect2(0.0, 0.0, world_w, world_h), Color("#2A2635"), false, 1.0)

	# Roads are drawn as width segments so the map data is visible at a glance.
	for i in range(mini(routes.size(), lane_count)):
		var route: Dictionary = routes[i]
		var y := float(route.get("y", LANE_Y[i]))
		var segments: Array = route.get("segments", [])
		for segment in segments:
			var from_x := float(segment.get("from", player_base))
			var to_x := float(segment.get("to", enemy_base))
			var width := float(segment.get("width", 80.0))
			var road := Rect2(from_x, y - width * 0.5, to_x - from_x, width)
			draw_rect(road, Color("#302C3D"))
			draw_rect(road, Color("#3E3A4A"), false, 1.0)
			if i == active_lane:
				draw_rect(road, Color("#D9A441"), false, 2.0)
		draw_line(Vector2(player_base, y), Vector2(enemy_base, y), Color(0.35, 0.33, 0.42, 0.8), 1.0)
		var route_font: Font = font if font != null else ThemeDB.fallback_font
		if route_font != null:
			draw_string(route_font, Vector2(player_base + 10.0, y - float(route.get("segments", [{"width": 80}])[0].get("width", 80.0)) * 0.5 + 11.0), String(route.get("name_cn", route.get("name", "第%d路" % (i + 1)))), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))

	# Base gates.
	var min_y := 320.0
	var max_y := 40.0
	for route in routes:
		min_y = minf(min_y, float(route.get("y", 180.0)) - 44.0)
		max_y = maxf(max_y, float(route.get("y", 180.0)) + 44.0)
	draw_rect(Rect2(player_base - 30.0, min_y, 30.0, max_y - min_y), Color("#2B4A6F"))
	draw_rect(Rect2(enemy_base, min_y, 30.0, max_y - min_y), Color("#6F2B2B"))
	var gate_font: Font = font if font != null else ThemeDB.fallback_font
	if gate_font != null:
		draw_string(gate_font, Vector2(player_base - 27.0, min_y + 12.0), "我方", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#D7E8FA"))
		draw_string(gate_font, Vector2(enemy_base + 1.0, min_y + 12.0), "敌方", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#F4D2D2"))

	# Advance lines.
	var lines: Array = last_snapshot.get("advance_lines", [92.0, 92.0])
	for i in range(mini(lines.size(), routes.size())):
		var line_x := float(lines[i])
		var y := float(routes[i].get("y", LANE_Y[clampi(i, 0, LANE_Y.size() - 1)]))
		var width := float(routes[i].get("segments", [{"width": 80.0}])[0].get("width", 80.0))
		draw_line(Vector2(line_x, y - width * 0.5 + 4.0), Vector2(line_x, y + width * 0.5 - 4.0), Color("#D9A441") if i == active_lane else Color(0.85, 0.65, 0.25, 0.45), 1.0)
		draw_circle(Vector2(line_x, y - width * 0.5 + 2.0), 2.0, Color("#D9A441"))

	# Projectiles are cheap to draw directly; no per-projectile node needed yet.
	for p in last_snapshot.get("projectiles", []):
		var lane := clampi(int(p.get("lane", 0)), 0, maxi(0, lane_count - 1))
		var color := Color("#D9A441") if int(p.get("team", 0)) == 0 else Color("#E06666")
		draw_circle(Vector2(float(p.get("x", 0.0)), lane_y(lane)), 2.0, color)

	if drag_active:
		draw_rect(drag_world_rect, Color(0.42, 0.66, 0.89, 0.14))
		draw_rect(drag_world_rect, Color("#6FA8DC"), false, 1.0)


func _default_routes(world_h: float) -> Array:
	var result: Array = []
	for i in range(LANE_Y.size()):
		var width := 80.0
		var y := float(LANE_Y[i])
		if y + width * 0.5 > world_h:
			y = world_h - width * 0.5
		result.append({
			"id": i,
			"name": "Lane %d" % (i + 1),
			"name_cn": "第%d路" % (i + 1),
			"y": y,
			"segments": [{"from": PLAYER_BASE_X, "to": ENEMY_BASE_X, "width": width}],
		})
	return result
