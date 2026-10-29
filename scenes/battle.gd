extends Node2D

const LEVELS := [
	"res://data/levels/level_01.json",
	"res://data/levels/level_02.json",
	"res://data/levels/level_03.json",
]
const SEED := 12345
const UNIT_ORDER := ["swordsman", "spearman", "archer", "mage", "knight", "catapult"]
const CAMERA_DEFAULT_X := 320.0

@onready var runner: SimRunner = $SimRunner
@onready var view: BattleView = $BattleView
@onready var camera: CameraRig = $CameraRig
@onready var hud: BattleHUD = $HUD/Root

var sim: BattleSim
var level_data: Dictionary = {}
var level_index: int = 0
var active_lane: int = 0
var follow_camera: bool = true
var selected_ids: Array = []


func _ready() -> void:
	runner.ticked.connect(_on_ticked)
	view.setup(runner)
	hud.spawn_requested.connect(_on_hud_spawn)
	hud.build_requested.connect(_on_hud_build)
	hud.lane_requested.connect(_on_hud_lane)
	hud.minimap_clicked.connect(_on_minimap_clicked)
	hud.world_clicked.connect(_on_world_clicked)
	hud.world_drag.connect(_on_world_drag)
	hud.world_right_click.connect(_on_world_right_click)
	_reset_and_start()


func _load_level(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read level: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid level JSON: " + path)
		return {}
	return parsed


func _reset_and_start() -> void:
	level_data = _load_level(LEVELS[level_index])
	active_lane = 0
	follow_camera = true
	selected_ids.clear()
	sim = BattleSim.new(SEED, 20, 1, level_data)
	runner.setup(sim)
	view.reset_view()
	view.set_active_lane(active_lane)
	view.set_selected(selected_ids)
	camera.jump_to(CAMERA_DEFAULT_X)
	hud.close_panel()
	hud.set_camera(camera.camera_x(), follow_camera)
	hud.update_snapshot(sim.get_snapshot(), active_lane)


func _process(delta: float) -> void:
	var pan := 0.0
	if Input.is_key_pressed(KEY_A):
		pan -= 1.0
	if Input.is_key_pressed(KEY_D):
		pan += 1.0
	if pan != 0.0:
		follow_camera = false
		camera.pan(pan * 600.0 * delta)
		hud.set_camera(camera.camera_x(), follow_camera)


func _on_ticked(snapshot: Dictionary) -> void:
	_clean_selection(snapshot)
	if follow_camera:
		camera.focus_lane(snapshot, active_lane)
	hud.set_camera(camera.camera_x(), follow_camera)
	hud.update_snapshot(snapshot, active_lane)


func _on_hud_spawn(def_id: String) -> void:
	if sim != null:
		sim.queue_spawn(BattleSim.PLAYER, active_lane, def_id)


func _on_hud_build(slot: int) -> void:
	if sim != null:
		sim.queue_build(slot)


func _on_hud_lane(lane: int) -> void:
	_set_lane(lane)


func _on_minimap_clicked(lane: int, world_x: float) -> void:
	active_lane = clampi(lane, 0, 1)
	view.set_active_lane(active_lane)
	follow_camera = false
	camera.jump_to(world_x)
	hud.set_camera(camera.camera_x(), follow_camera)
	if sim != null:
		hud.update_snapshot(sim.get_snapshot(), active_lane)


func _set_lane(lane: int) -> void:
	active_lane = clampi(lane, 0, 1)
	view.set_active_lane(active_lane)
	follow_camera = true
	if sim != null:
		var snapshot := sim.get_snapshot()
		camera.focus_lane(snapshot, active_lane)
		hud.set_camera(camera.camera_x(), follow_camera)
		hud.update_snapshot(snapshot, active_lane)


func _on_world_clicked(screen_pos: Vector2, additive: bool) -> void:
	if sim == null:
		return
	var world_pos := _screen_to_world(screen_pos)
	var snapshot := sim.get_snapshot()
	var best_id := -1
	var best_dist := INF
	for u in snapshot.get("units", []):
		if int(u.get("team", 1)) != BattleSim.PLAYER:
			continue
		var lane := clampi(int(u.get("lane", 0)), 0, BattleView.LANE_Y.size() - 1)
		var unit_pos := Vector2(float(u.get("x", 0.0)), BattleView.LANE_Y[lane])
		var dist := unit_pos.distance_to(world_pos)
		if dist <= 24.0 and dist < best_dist:
			best_dist = dist
			best_id = int(u.get("id", -1))

	if not additive:
		selected_ids.clear()
	if best_id >= 0 and not selected_ids.has(best_id):
		selected_ids.append(best_id)
	_update_selection_view()


func _on_world_drag(rect: Rect2, additive: bool) -> void:
	if sim == null:
		return
	var a := _screen_to_world(rect.position)
	var b := _screen_to_world(rect.position + rect.size)
	var world_rect := Rect2(a, b - a).abs()
	var snapshot := sim.get_snapshot()
	if not additive:
		selected_ids.clear()

	for u in snapshot.get("units", []):
		if int(u.get("team", 1)) != BattleSim.PLAYER:
			continue
		var lane := clampi(int(u.get("lane", 0)), 0, BattleView.LANE_Y.size() - 1)
		var unit_pos := Vector2(float(u.get("x", 0.0)), BattleView.LANE_Y[lane])
		if world_rect.has_point(unit_pos):
			var id := int(u.get("id", -1))
			if id >= 0 and not selected_ids.has(id):
				selected_ids.append(id)
	_update_selection_view()


func _on_world_right_click(screen_pos: Vector2, shift: bool) -> void:
	if sim == null:
		return
	var world_pos := _screen_to_world(screen_pos)
	if shift:
		sim.queue_set_advance_line(active_lane, world_pos.x)
		return
	if not selected_ids.is_empty():
		sim.queue_move_squad(selected_ids, world_pos.x)


func _clean_selection(snapshot: Dictionary) -> void:
	var alive := {}
	for u in snapshot.get("units", []):
		if int(u.get("team", 1)) == BattleSim.PLAYER:
			alive[int(u.get("id", -1))] = true

	var filtered: Array = []
	for id in selected_ids:
		if alive.has(id):
			filtered.append(id)
	if filtered.size() != selected_ids.size():
		selected_ids = filtered
		_update_selection_view()


func _update_selection_view() -> void:
	view.set_selected(selected_ids)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _spawn_by_index(index: int, other_lane: bool) -> void:
	if index < 0 or index >= UNIT_ORDER.size() or sim == null:
		return
	var lane := 1 - active_lane if other_lane else active_lane
	sim.queue_spawn(BattleSim.PLAYER, lane, UNIT_ORDER[index])


func _selected_hold() -> void:
	if sim != null and not selected_ids.is_empty():
		sim.queue_hold_squad(selected_ids)


func _selected_return() -> void:
	if sim != null and not selected_ids.is_empty():
		sim.queue_return_squad(selected_ids)


func _next_level() -> void:
	level_index = (level_index + 1) % LEVELS.size()
	_reset_and_start()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			var index: int = event.keycode - KEY_1
			_spawn_by_index(index, event.alt_pressed)
		KEY_Q:
			_set_lane(0)
		KEY_E:
			_set_lane(1)
		KEY_B:
			hud.toggle_panel()
		KEY_H:
			_selected_hold()
		KEY_R:
			if event.ctrl_pressed:
				_reset_and_start()
			else:
				_selected_return()
		KEY_F:
			follow_camera = not follow_camera
			if follow_camera and sim != null:
				camera.focus_lane(sim.get_snapshot(), active_lane)
			hud.set_camera(camera.camera_x(), follow_camera)
		KEY_N:
			_next_level()
		KEY_HOME:
			follow_camera = false
			camera.jump_to(CAMERA_DEFAULT_X)
			hud.set_camera(camera.camera_x(), follow_camera)
		KEY_SPACE:
			if sim != null and not sim.is_finished():
				runner.paused = not runner.paused
		KEY_ESCAPE:
			get_tree().quit()
