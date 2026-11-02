class_name CameraRig
extends Camera2D

const DEFAULT_X := 320.0
const MIN_X := 320.0
const WORLD_W := 1600.0
const VIEW_W := 640.0
const VIEW_H := 360.0

var world_width: float = WORLD_W


func _ready() -> void:
	position = Vector2(DEFAULT_X, VIEW_H * 0.5)
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	limit_left = 0
	limit_top = 0
	_apply_limits()


func set_world_width(width: float) -> void:
	world_width = maxf(VIEW_W, width)
	_apply_limits()
	position.x = clampf(position.x, _min_x(), _max_x())


func _min_x() -> float:
	return minf(MIN_X, maxf(VIEW_W * 0.5, world_width - VIEW_W * 0.5))


func _max_x() -> float:
	return maxf(_min_x(), world_width - VIEW_W * 0.5)


func _apply_limits() -> void:
	limit_right = int(world_width)
	limit_bottom = int(VIEW_H)


func focus_lane(snapshot: Dictionary, lane: int) -> void:
	var focus_x := DEFAULT_X
	var lines: Array = snapshot.get("advance_lines", [DEFAULT_X, DEFAULT_X])
	if lane >= 0 and lane < lines.size():
		focus_x = float(lines[lane])

	for u in snapshot.get("units", []):
		if int(u.get("team", 1)) == 0 and int(u.get("lane", -1)) == lane:
			focus_x = maxf(focus_x, float(u.get("x", focus_x)))

	position.x = clampf(focus_x + 120.0, _min_x(), _max_x())


func jump_to(world_x: float) -> void:
	position.x = clampf(world_x, _min_x(), _max_x())
	if has_method("reset_smoothing"):
		reset_smoothing()


func pan(delta_x: float) -> void:
	position.x = clampf(position.x + delta_x, _min_x(), _max_x())


func camera_x() -> float:
	return position.x
