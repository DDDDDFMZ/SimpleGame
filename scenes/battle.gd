extends Node2D

const SEED := 12345
const UNIT_ORDER := ["swordsman", "spearman", "knight", "archer", "rogue", "catapult", "mage", "cleric"]
const CAMERA_DEFAULT_X := 320.0

@onready var runner: SimRunner = $SimRunner
@onready var view: BattleView = $BattleView
@onready var camera: CameraRig = $CameraRig
@onready var hud: BattleHUD = $HUD/Root

var sim: BattleSim
var level_data: Dictionary = {}
var active_lane: int = 0
var follow_camera: bool = true
var selected_ids: Array = []
var drag_world_start := Vector2.ZERO
var result_recorded := false
var paused_before_guide: bool = false


func _ready() -> void:
	runner.ticked.connect(_on_ticked)
	view.setup(runner)
	hud.spawn_requested.connect(_on_hud_spawn)
	hud.guild_action_requested.connect(_on_guild_action)
	hud.promote_requested.connect(_on_promote)
	hud.minimap_clicked.connect(_on_minimap_clicked)
	hud.minimap_select.connect(_on_minimap_select)
	hud.minimap_order.connect(_on_minimap_order)
	hud.drag_started.connect(_on_drag_started)
	hud.drag_updated.connect(_on_drag_updated)
	hud.drag_finished.connect(_on_drag_finished)
	hud.world_right_click.connect(_on_world_right_click)
	hud.result_action.connect(_on_result_action)
	hud.selection_changed.connect(_on_hud_selection_changed)
	_reset_and_start()


func _load_level() -> Dictionary:
	var path := GameState.get_endless_path() if GameState.endless_mode else GameState.get_level_path(GameState.selected_contract)
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read level: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _reset_and_start() -> void:
	level_data = _load_level()
	active_lane = 0
	follow_camera = true
	selected_ids.clear()
	result_recorded = false
	sim = BattleSim.new(SEED, 20, 1, level_data, true, GameState.profile(), GameState.game_data)
	runner.setup(sim)
	view.reset_view()
	view.set_active_lane(active_lane)
	view.set_selected(selected_ids)
	camera.set_world_width(sim.world_width)
	camera.jump_to(CAMERA_DEFAULT_X)
	hud.close_panel()
	hud.set_guide(false)
	hud.set_paused(false)
	hud.set_selection(selected_ids)
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
	hud.set_selection(selected_ids)
	hud.update_snapshot(snapshot, active_lane)

	if bool(snapshot.get("finished", false)) and not result_recorded:
		result_recorded = true
		if GameState.endless_mode:
			GameState.record_endless(int(snapshot.get("score", 0)), int(snapshot.get("wave_index", 0)))
		else:
			GameState.record_result(int(snapshot.get("contract", 0)), int(snapshot.get("stars", 0)), snapshot.get("guild_usage", {}))


func _on_hud_spawn(def_id: String) -> void:
	if sim != null:
		sim.queue_spawn(BattleSim.PLAYER, active_lane, def_id)


func _on_guild_action(guild_id: String) -> void:
	if sim != null:
		sim.queue_guild_action(guild_id)


func _on_promote() -> void:
	if sim != null:
		sim.queue_promote()


func _on_minimap_clicked(lane: int, world_x: float) -> void:
	active_lane = clampi(lane, 0, 1)
	view.set_active_lane(active_lane)
	follow_camera = false
	camera.jump_to(world_x)
	hud.set_camera(camera.camera_x(), follow_camera)
	if sim != null:
		hud.update_snapshot(sim.get_snapshot(), active_lane)


func _on_minimap_select(lane: int, x1: float, x2: float, additive: bool) -> void:
	if sim == null:
		return
	active_lane = clampi(lane, 0, 1)
	view.set_active_lane(active_lane)
	var snapshot := sim.get_snapshot()
	if not additive:
		selected_ids.clear()
	for u in snapshot.get("units", []):
		if int(u.get("team", 1)) != BattleSim.PLAYER or int(u.get("lane", -1)) != active_lane:
			continue
		var x := float(u.get("x", 0.0))
		if x >= x1 and x <= x2:
			var id := int(u.get("id", -1))
			if id >= 0 and not selected_ids.has(id):
				selected_ids.append(id)
	_update_selection_view()
	hud.update_snapshot(snapshot, active_lane)


func _on_minimap_order(lane: int, world_x: float, shift: bool) -> void:
	if sim == null:
		return
	active_lane = clampi(lane, 0, 1)
	view.set_active_lane(active_lane)
	if shift:
		sim.queue_set_advance_line(active_lane, world_x)
	elif not selected_ids.is_empty():
		sim.queue_move_squad(selected_ids, world_x)


func _on_drag_started(screen_pos: Vector2) -> void:
	drag_world_start = _screen_to_world(screen_pos)
	view.set_drag_rect(Rect2(drag_world_start, Vector2.ZERO), true)


func _on_drag_updated(screen_pos: Vector2) -> void:
	var end := _screen_to_world(screen_pos)
	view.set_drag_rect(Rect2(drag_world_start, end - drag_world_start).abs(), true)


func _on_drag_finished(screen_pos: Vector2, additive: bool) -> void:
	var end := _screen_to_world(screen_pos)
	var rect := Rect2(drag_world_start, end - drag_world_start).abs()
	view.set_drag_rect(Rect2(), false)
	if sim == null:
		return
	var snapshot := sim.get_snapshot()
	if rect.size.length() < 4.0:
		_select_at(end, additive, snapshot)
	else:
		if not additive:
			selected_ids.clear()
		for u in snapshot.get("units", []):
			if int(u.get("team", 1)) != BattleSim.PLAYER:
				continue
			var lane := clampi(int(u.get("lane", 0)), 0, 1)
			var pos := Vector2(float(u.get("x", 0.0)), view.lane_y(lane))
			if rect.has_point(pos):
				var id := int(u.get("id", -1))
				if id >= 0 and not selected_ids.has(id):
					selected_ids.append(id)
		_update_selection_view()


func _select_at(world_pos: Vector2, additive: bool, snapshot: Dictionary) -> void:
	var best_id := -1
	var best_dist := INF
	for u in snapshot.get("units", []):
		if int(u.get("team", 1)) != BattleSim.PLAYER:
			continue
		var lane := clampi(int(u.get("lane", 0)), 0, 1)
		var pos := Vector2(float(u.get("x", 0.0)), view.lane_y(lane))
		var dist := pos.distance_to(world_pos)
		if dist <= 24.0 and dist < best_dist:
			best_dist = dist
			best_id = int(u.get("id", -1))
	if not additive:
		selected_ids.clear()
	if best_id >= 0 and not selected_ids.has(best_id):
		selected_ids.append(best_id)
	_update_selection_view()


func _on_world_right_click(screen_pos: Vector2, shift: bool) -> void:
	if sim == null:
		return
	var world_pos := _screen_to_world(screen_pos)
	if shift:
		sim.queue_set_advance_line(active_lane, world_pos.x)
	elif not selected_ids.is_empty():
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
	hud.set_selection(selected_ids)


func _on_hud_selection_changed(ids: Array) -> void:
	var valid := {}
	for u in sim.get_snapshot().get("units", []):
		if int(u.get("team", 1)) == BattleSim.PLAYER:
			valid[int(u.get("id", -1))] = true
	var filtered: Array = []
	for id in ids:
		if valid.has(int(id)) and not filtered.has(int(id)):
			filtered.append(int(id))
	selected_ids = filtered
	_update_selection_view()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _spawn_by_index(index: int, other_lane: bool) -> void:
	if index < 0 or index >= UNIT_ORDER.size() or sim == null:
		return
	var lane := 1 - active_lane if other_lane else active_lane
	sim.queue_spawn(BattleSim.PLAYER, lane, UNIT_ORDER[index])


func _set_lane(lane: int) -> void:
	active_lane = clampi(lane, 0, 1)
	view.set_active_lane(active_lane)
	follow_camera = true
	if sim != null:
		var snapshot := sim.get_snapshot()
		camera.focus_lane(snapshot, active_lane)
		hud.set_camera(camera.camera_x(), follow_camera)
		hud.update_snapshot(snapshot, active_lane)


func _on_result_action(action: String) -> void:
	match action:
		"retry":
			_reset_and_start()
		"next":
			if GameState.endless_mode:
				get_tree().change_scene_to_file("res://main/level_select.tscn")
				return
			var next_contract := GameState.selected_contract + 1
			if GameState.selected_contract < GameState.get_max_contract() and GameState.select_contract(next_contract):
				_reset_and_start()
			else:
				get_tree().change_scene_to_file("res://main/level_select.tscn")
		"levels":
			get_tree().change_scene_to_file("res://main/level_select.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if hud.guide_open and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT):
		hud.change_guide_page(-1 if event.keycode == KEY_LEFT else 1)
		return

	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			var index: int = event.keycode - KEY_1
			_spawn_by_index(index, event.alt_pressed)
		KEY_Q:
			_set_lane(0)
		KEY_E:
			_set_lane(1)
		KEY_B:
			hud.toggle_panel()
		KEY_H:
			if not selected_ids.is_empty():
				sim.queue_hold_squad(selected_ids)
		KEY_R:
			if event.ctrl_pressed:
				_reset_and_start()
			elif not selected_ids.is_empty():
				sim.queue_return_squad(selected_ids)
		KEY_F:
			follow_camera = not follow_camera
			if follow_camera and sim != null:
				camera.focus_lane(sim.get_snapshot(), active_lane)
			hud.set_camera(camera.camera_x(), follow_camera)
		KEY_F1:
			if not hud.guide_open:
				paused_before_guide = runner.paused
				runner.paused = true
			else:
				runner.paused = paused_before_guide
			hud.toggle_guide()
		KEY_F2:
			hud.toggle_checklist()
		KEY_HOME:
			follow_camera = false
			camera.jump_to(CAMERA_DEFAULT_X)
			hud.set_camera(camera.camera_x(), follow_camera)
		KEY_SPACE:
			if sim != null and not sim.is_finished():
				runner.paused = not runner.paused
				hud.set_paused(runner.paused)
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://main/level_select.tscn")
