class_name BattleView
extends Node2D

const VIEW_W := 640.0
const VIEW_H := 360.0

var runner: SimRunner
var unit_views: Dictionary = {}
var last_snapshot: Dictionary = {}
var active_route: int = 0
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


func set_active_route(index: int) -> void:
	active_route = maxi(0, index)
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
		view.update_data(data)
		view.set_selected(selected_ids.has(id))

	for id in unit_views.keys():
		if not seen.has(id):
			unit_views[id].queue_free()
			unit_views.erase(id)


func _draw() -> void:
	var map: Dictionary = last_snapshot.get("map", {})
	var world_w := float(last_snapshot.get("world_width", map.get("world_width", 1600.0)))
	var world_h := float(last_snapshot.get("world_height", map.get("world_height", 900.0)))
	draw_rect(Rect2(0.0, 0.0, world_w, world_h), Color("#1A2024"))
	draw_rect(Rect2(0.0, 0.0, world_w, world_h), Color("#26323A"), false, 2.0)
	_draw_grid(world_w, world_h)

	var nodes: Array = map.get("nodes", [])
	var edges: Array = map.get("edges", [])
	var route_paths := _route_paths()
	var active_path: Array = []
	var routes: Array = last_snapshot.get("routes", [])
	if active_route >= 0 and active_route < routes.size():
		active_path = routes[active_route].get("path", [])

	for edge in edges:
		var edge_id := String(edge.get("id", ""))
		var points := _points(edge.get("points", []))
		if points.size() < 2:
			continue
		var width := float(edge.get("width", 80.0))
		var road_color := Color("#39453B")
		var border_color := Color("#59665A")
		if active_path.has(edge_id):
			road_color = Color("#4A4230")
			border_color = Color("#D9A441")
		for i in range(1, points.size()):
			draw_line(points[i - 1], points[i], border_color, width + 4.0)
			draw_line(points[i - 1], points[i], road_color, width)
			draw_line(points[i - 1], points[i], Color(0.62, 0.58, 0.45, 0.35), 1.0)

	for node in nodes:
		var node_type := String(node.get("type", ""))
		var pos := _point(node.get("pos", []))
		var team := int(node.get("team", -1))
		if node_type == "base":
			var color := Color("#3B6EA5") if team == 0 else Color("#A53B3B")
			draw_circle(pos, 26.0, color)
			draw_circle(pos, 30.0, Color("#D9A441") if team == 0 else Color("#E06666"), false, 2.0)
			draw_string(font, pos + Vector2(-28.0, -36.0), String(node.get("name_cn", "营地")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, color)
		else:
			draw_circle(pos, 9.0, Color("#2A3230"))
			draw_circle(pos, 9.0, Color("#6B7A69"), false, 1.0)

	for route in routes:
		var rally: Dictionary = route.get("rally", {})
		var rally_pos := _point(rally.get("pos", []))
		if rally_pos != Vector2.ZERO:
			var is_active := active_route < routes.size() and String(route.get("id", "")) == String(routes[active_route].get("id", ""))
			var color := Color("#D9A441") if is_active else Color("#8A8498")
			draw_circle(rally_pos, 7.0, color, false, 2.0)
			draw_line(rally_pos + Vector2(0, -6), rally_pos + Vector2(0, 6), color, 1.0)
			draw_line(rally_pos + Vector2(-6, 0), rally_pos + Vector2(6, 0), color, 1.0)

	for p in last_snapshot.get("projectiles", []):
		var pos := _point(p.get("pos", []))
		var color := Color("#D9A441") if int(p.get("team", 0)) == 0 else Color("#E06666")
		draw_circle(pos, 3.0, color)

	if drag_active:
		draw_rect(drag_world_rect, Color(0.42, 0.66, 0.89, 0.14))
		draw_rect(drag_world_rect, Color("#6FA8DC"), false, 1.0)


func _draw_grid(world_w: float, world_h: float) -> void:
	for x in range(0, int(world_w) + 1, 100):
		draw_line(Vector2(x, 0), Vector2(x, world_h), Color(0.2, 0.24, 0.25, 0.35), 1.0)
	for y in range(0, int(world_h) + 1, 100):
		draw_line(Vector2(0, y), Vector2(world_w, y), Color(0.2, 0.24, 0.25, 0.35), 1.0)


func _route_paths() -> Array:
	var result: Array = []
	for route in last_snapshot.get("routes", []):
		result.append(route.get("path", []))
	return result


func _point(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _points(values: Variant) -> Array:
	var result: Array = []
	if values is Array:
		for value in values:
			result.append(_point(value))
	return result
