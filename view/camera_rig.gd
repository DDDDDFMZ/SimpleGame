class_name CameraRig
extends Camera2D

const DEFAULT_X := 320.0
const MIN_X := 320.0
const MAX_X := 1280.0
const WORLD_W := 1600.0
const VIEW_H := 360.0


func _ready() -> void:
	position = Vector2(DEFAULT_X, VIEW_H * 0.5)
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	limit_left = 0
	limit_top = 0
	limit_right = int(WORLD_W)
	limit_bottom = int(VIEW_H)


func focus_lane(snapshot: Dictionary, lane: int) -> void:
	var focus_x := DEFAULT_X
	var lines: Array = snapshot.get("advance_lines", [DEFAULT_X, DEFAULT_X])
	if lane >= 0 and lane < lines.size():
		focus_x = float(lines[lane])

	for u in snapshot.get("units", []):
		if int(u.get("team", 1)) == 0 and int(u.get("lane", -1)) == lane:
			focus_x = maxf(focus_x, float(u.get("x", focus_x)))

	position.x = clampf(focus_x + 120.0, MIN_X, MAX_X)


func jump_to(world_x: float) -> void:
	position.x = clampf(world_x, MIN_X, MAX_X)
	if has_method("reset_smoothing"):
		reset_smoothing()


func pan(delta_x: float) -> void:
	position.x = clampf(position.x + delta_x, MIN_X, MAX_X)


func camera_x() -> float:
	return position.x
