class_name CameraRig
extends Camera2D

const VIEW_W := 640.0
const VIEW_H := 360.0
const MIN_ZOOM := 0.5
const MAX_ZOOM := 1.5
const ZOOM_STEP := 0.1
const DEFAULT_ZOOM := 0.75

var world_size: Vector2 = Vector2(1600.0, 900.0)
var zoom_level: float = DEFAULT_ZOOM


func _ready() -> void:
	position = world_size * 0.5
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	limit_left = 0
	limit_top = 0
	_apply_limits()
	_apply_zoom()


func set_world_size(size: Vector2) -> void:
	world_size = Vector2(maxf(VIEW_W, size.x), maxf(VIEW_H, size.y))
	_apply_limits()
	position = _clamp_position(position)


func set_zoom_level(value: float) -> void:
	zoom_level = clampf(snappedf(value, ZOOM_STEP), MIN_ZOOM, MAX_ZOOM)
	_apply_zoom()
	position = _clamp_position(position)


func zoom_by(delta: float) -> void:
	set_zoom_level(zoom_level + delta)


func _apply_zoom() -> void:
	zoom = Vector2(zoom_level, zoom_level)


func _apply_limits() -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(world_size.x)
	limit_bottom = int(world_size.y)


func _half_view() -> Vector2:
	return Vector2(VIEW_W, VIEW_H) / (2.0 * zoom_level)


func _clamp_position(value: Vector2) -> Vector2:
	var half := _half_view()
	var min_x := minf(half.x, maxf(0.0, world_size.x - half.x))
	var max_x := maxf(min_x, world_size.x - half.x)
	var min_y := minf(half.y, maxf(0.0, world_size.y - half.y))
	var max_y := maxf(min_y, world_size.y - half.y)
	return Vector2(clampf(value.x, min_x, max_x), clampf(value.y, min_y, max_y))


func focus_route(snapshot: Dictionary, route_index: int) -> void:
	var focus := position
	var routes: Array = snapshot.get("routes", [])
	if route_index >= 0 and route_index < routes.size():
		var rally: Dictionary = routes[route_index].get("rally", {})
		var rally_pos: Variant = rally.get("pos", [])
		if rally_pos is Array and rally_pos.size() >= 2:
			focus = Vector2(float(rally_pos[0]), float(rally_pos[1]))
		var route_id := String(routes[route_index].get("id", ""))
		for u in snapshot.get("units", []):
			if int(u.get("team", 1)) == 0 and String(u.get("route_id", "")) == route_id:
				var unit_pos: Variant = u.get("pos", [])
				if unit_pos is Array and unit_pos.size() >= 2:
					var candidate := Vector2(float(unit_pos[0]), float(unit_pos[1]))
					if candidate.distance_to(focus) > 30.0:
						focus = candidate
	position = _clamp_position(focus + Vector2(80.0, 0.0))


func focus_base(team: int, snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		var key := "player_base_x" if team == 0 else "enemy_base_x"
		var key_y := "player_base_y" if team == 0 else "enemy_base_y"
		position = _clamp_position(Vector2(float(snapshot.get(key, world_size.x * 0.5)), float(snapshot.get(key_y, world_size.y * 0.5))))
	else:
		position = _clamp_position(world_size * 0.5)


func jump_to(value: Variant) -> void:
	var target := world_size * 0.5
	if value is Vector2:
		target = value
	elif value is Array and value.size() >= 2:
		target = Vector2(float(value[0]), float(value[1]))
	else:
		target = Vector2(float(value), position.y)
	position = _clamp_position(target)
	if has_method("reset_smoothing"):
		reset_smoothing()


func pan(delta: Vector2) -> void:
	position = _clamp_position(position + delta)


func camera_pos() -> Vector2:
	return position


func camera_x() -> float:
	return position.x


func camera_rect() -> Rect2:
	var half := _half_view()
	return Rect2(position - half, half * 2.0)
