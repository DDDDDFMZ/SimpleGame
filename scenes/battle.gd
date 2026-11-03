extends Node2D

enum PauseMode { NONE, MENU, GUIDE, RESULT }

const SEED := 12345

@onready var runner: SimRunner = $SimRunner
@onready var view: BattleView = $BattleView
@onready var camera: CameraRig = $CameraRig
@onready var hud: BattleHUD = $HUD/Root

var sim: BattleSim
var level_data: Dictionary = {}
var active_route: int = 0
var follow_camera: bool = true
var selected_ids: Array = []
var drag_world_start := Vector2.ZERO
var result_recorded := false
var pause_mode: int = PauseMode.NONE
var guide_return_mode: int = PauseMode.NONE
var last_pointer_world := Vector2.ZERO


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
	hud.zoom_requested.connect(_on_zoom_requested)
	hud.pause_action.connect(_on_pause_action)
	hud.station_order_changed.connect(_on_station_order_changed)
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
	active_route = 0
	follow_camera = true
	selected_ids.clear()
	result_recorded = false
	pause_mode = PauseMode.NONE
	sim = BattleSim.new(SEED, 20, 1, level_data, true, GameState.profile(), GameState.game_data)
	runner.setup(sim)
	runner.paused = false
	view.reset_view()
	view.set_active_route(active_route)
	view.set_selected(selected_ids)
	camera.set_world_size(Vector2(sim.world_width, sim.world_height))
	camera.set_zoom_level(CameraRig.DEFAULT_ZOOM)
	camera.focus_base(BattleSim.PLAYER, sim.get_snapshot())
	hud.close_panel()
	hud.set_guide(false)
	hud.set_paused(false)
	hud.set_pause_menu(false)
	hud.set_selection(selected_ids)
	hud.set_camera(camera.camera_pos(), camera.zoom_level, follow_camera)
	hud.update_snapshot(sim.get_snapshot(), active_route)


func _process(delta: float) -> void:
	if pause_mode != PauseMode.NONE or sim == null or sim.is_finished():
		return
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_W):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		pan.y += 1.0
	if pan != Vector2.ZERO:
		follow_camera = false
		camera.pan(pan.normalized() * 600.0 * delta)
		hud.set_camera(camera.camera_pos(), camera.zoom_level, follow_camera)


func _on_ticked(snapshot: Dictionary) -> void:
	_clean_selection(snapshot)
	if follow_camera and pause_mode == PauseMode.NONE:
		camera.focus_route(snapshot, active_route)
	hud.set_camera(camera.camera_pos(), camera.zoom_level, follow_camera)
	hud.set_selection(selected_ids)
	hud.update_snapshot(snapshot, active_route)

	if bool(snapshot.get("finished", false)) and not result_recorded:
		result_recorded = true
		pause_mode = PauseMode.RESULT
		runner.paused = true
		if GameState.endless_mode:
			GameState.record_endless(int(snapshot.get("score", 0)), int(snapshot.get("wave_index", 0)))
		else:
			GameState.record_result(int(snapshot.get("contract", 0)), int(snapshot.get("stars", 0)), snapshot.get("guild_usage", {}))


func _route_count() -> int:
	if sim == null:
		return 0
	return sim.player_spawns.size()


func _route_id(index: int) -> String:
	if sim == null:
		return ""
	var list: Array = sim.player_spawns
	if index < 0 or index >= list.size():
		return ""
	return String(list[index].get("id", ""))


func _on_hud_spawn(def_id: String) -> void:
	if sim != null and pause_mode == PauseMode.NONE and not sim.is_finished():
		sim.queue_spawn(BattleSim.PLAYER, active_route, def_id)


func _on_guild_action(guild_id: String) -> void:
	if sim != null and pause_mode == PauseMode.NONE:
		sim.queue_guild_action(guild_id)


func _on_promote() -> void:
	if sim != null and pause_mode == PauseMode.NONE:
		sim.queue_promote()


func _on_minimap_clicked(world_pos: Vector2) -> void:
	if pause_mode != PauseMode.NONE:
		return
	follow_camera = false
	camera.jump_to(world_pos)
	hud.set_camera(camera.camera_pos(), camera.zoom_level, follow_camera)
	if sim != null:
		hud.update_snapshot(sim.get_snapshot(), active_route)


func _on_minimap_select(world_rect: Rect2, additive: bool) -> void:
	if sim == null or pause_mode != PauseMode.NONE:
		return
	var snapshot := sim.get_snapshot()
	if not additive:
		selected_ids.clear()
	for u in snapshot.get("units", []):
		if int(u.get("team", 1)) != BattleSim.PLAYER:
			continue
		var pos := _unit_pos(u)
		if world_rect.grow(10.0).has_point(pos):
			var id := int(u.get("id", -1))
			if id >= 0 and not selected_ids.has(id):
				selected_ids.append(id)
	_update_selection_view()
	hud.update_snapshot(snapshot, active_route)


func _on_minimap_order(world_pos: Vector2, shift: bool) -> void:
	if sim == null or pause_mode != PauseMode.NONE:
		return
	if shift:
		sim.queue_set_rally(active_route, world_pos)
	elif not selected_ids.is_empty():
		sim.queue_move_squad(selected_ids, world_pos)


func _on_drag_started(screen_pos: Vector2) -> void:
	if pause_mode != PauseMode.NONE:
		return
	drag_world_start = _screen_to_world(screen_pos)
	last_pointer_world = drag_world_start
	view.set_drag_rect(Rect2(drag_world_start, Vector2.ZERO), true)


func _on_drag_updated(screen_pos: Vector2) -> void:
	last_pointer_world = _screen_to_world(screen_pos)
	view.set_drag_rect(Rect2(drag_world_start, last_pointer_world - drag_world_start).abs(), true)


func _on_drag_finished(screen_pos: Vector2, additive: bool) -> void:
	if pause_mode != PauseMode.NONE:
		view.set_drag_rect(Rect2(), false)
		return
	var end := _screen_to_world(screen_pos)
	var rect := Rect2(drag_world_start, end - drag_world_start).abs()
	view.set_drag_rect(Rect2(), false)
	if sim == null:
		return
	var snapshot := sim.get_snapshot()
	var threshold := 6.0 / maxf(0.1, camera.zoom_level)
	if rect.size.length() < threshold:
		_select_at(end, additive, snapshot)
	else:
		if not additive:
			selected_ids.clear()
		for u in snapshot.get("units", []):
			if int(u.get("team", 1)) != BattleSim.PLAYER:
				continue
			if rect.has_point(_unit_pos(u)):
				var id := int(u.get("id", -1))
				if id >= 0 and not selected_ids.has(id):
					selected_ids.append(id)
		_update_selection_view()


func _select_at(world_pos: Vector2, additive: bool, snapshot: Dictionary) -> void:
	var best_id := -1
	var best_dist := INF
	var hit_radius := 16.0 / maxf(0.1, camera.zoom_level)
	for u in snapshot.get("units", []):
		if int(u.get("team", 1)) != BattleSim.PLAYER:
			continue
		var dist := _unit_pos(u).distance_to(world_pos)
		if dist <= hit_radius and dist < best_dist:
			best_dist = dist
			best_id = int(u.get("id", -1))
	if not additive:
		selected_ids.clear()
	if best_id >= 0 and not selected_ids.has(best_id):
		selected_ids.append(best_id)
	_update_selection_view()


func _on_world_right_click(screen_pos: Vector2, shift: bool) -> void:
	if sim == null or pause_mode != PauseMode.NONE:
		return
	var world_pos := _screen_to_world(screen_pos)
	if shift:
		sim.queue_set_rally(active_route, world_pos)
	elif not selected_ids.is_empty():
		sim.queue_move_squad(selected_ids, world_pos)


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
	if sim == null:
		return
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


func _on_station_order_changed(order: Array) -> void:
	if sim != null:
		sim.set_station_order(order)
		GameState.set_station_order(order)
		hud.update_snapshot(sim.get_snapshot(), active_route)


func _unit_pos(unit: Dictionary) -> Vector2:
	var value: Variant = unit.get("pos", [])
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(float(unit.get("x", 0.0)), float(unit.get("y", 0.0)))


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _on_zoom_requested(delta: float) -> void:
	if pause_mode == PauseMode.RESULT:
		return
	camera.zoom_by(delta)
	hud.set_camera(camera.camera_pos(), camera.zoom_level, follow_camera)


func _set_route(index: int) -> void:
	var count := _route_count()
	if count <= 0:
		return
	active_route = posmod(index, count)
	view.set_active_route(active_route)
	follow_camera = true
	if sim != null:
		var snapshot := sim.get_snapshot()
		camera.focus_route(snapshot, active_route)
		hud.set_camera(camera.camera_pos(), camera.zoom_level, follow_camera)
		hud.update_snapshot(snapshot, active_route)


func _spawn_by_index(index: int, other_route: bool) -> void:
	if index < 0 or index >= 8 or sim == null:
		return
	var route := (active_route + 1) % maxi(1, _route_count()) if other_route else active_route
	sim.queue_spawn(BattleSim.PLAYER, route, _catalog_id(index))


func _catalog_id(index: int) -> String:
	if sim == null:
		return ""
	var catalog: Array = sim.get_snapshot().get("catalog", [])
	if index < 0 or index >= catalog.size():
		return ""
	return String(catalog[index].get("id", ""))


func _set_pause_mode(mode: int) -> void:
	pause_mode = mode
	runner.paused = mode != PauseMode.NONE or (sim != null and sim.is_finished())
	hud.set_paused(mode == PauseMode.MENU)
	hud.set_pause_menu(mode == PauseMode.MENU)
	hud.set_guide(mode == PauseMode.GUIDE)
	if mode != PauseMode.NONE:
		view.set_drag_rect(Rect2(), false)


func _on_pause_action(action: String) -> void:
	match action:
		"resume":
			_set_pause_mode(PauseMode.NONE)
		"guide":
			guide_return_mode = PauseMode.MENU
			_set_pause_mode(PauseMode.GUIDE)
		"backup":
			var backup_path := GameState.backup_progress("pause")
			hud.set_pause_status("已备份当前进度" if backup_path != "" else "暂无存档可备份")
		"station_order":
			hud.open_station_order()
		"restart":
			_set_pause_mode(PauseMode.NONE)
			_reset_and_start()
		"levels":
			get_tree().change_scene_to_file("res://main/level_select.tscn")


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
	if sim != null and sim.is_finished():
		return
	if pause_mode == PauseMode.GUIDE:
		if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
			hud.change_guide_page(-1 if event.keycode == KEY_LEFT else 1)
			return
		if event.keycode == KEY_F1 or event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
			_set_pause_mode(guide_return_mode)
			return
		return
	if pause_mode == PauseMode.MENU:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
			_set_pause_mode(PauseMode.NONE)
		elif event.keycode == KEY_F1:
			guide_return_mode = PauseMode.MENU
			_set_pause_mode(PauseMode.GUIDE)
		return
	if pause_mode == PauseMode.RESULT:
		return

	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			var index: int = event.keycode - KEY_1
			_spawn_by_index(index, event.alt_pressed)
		KEY_Q:
			_set_route(active_route - 1)
		KEY_E:
			_set_route(active_route + 1)
		KEY_B:
			hud.toggle_panel()
		KEY_H:
			if not selected_ids.is_empty():
				sim.queue_hold_squad(selected_ids)
		KEY_R:
			if event.ctrl_pressed:
				_set_pause_mode(PauseMode.MENU)
			elif not selected_ids.is_empty():
				sim.queue_return_squad(selected_ids)
		KEY_F:
			follow_camera = not follow_camera
			if follow_camera and sim != null:
				camera.focus_route(sim.get_snapshot(), active_route)
			hud.set_camera(camera.camera_pos(), camera.zoom_level, follow_camera)
		KEY_F1:
			guide_return_mode = PauseMode.NONE
			_set_pause_mode(PauseMode.GUIDE)
		KEY_F2:
			hud.toggle_checklist()
		KEY_HOME:
			follow_camera = false
			camera.focus_base(BattleSim.PLAYER, sim.get_snapshot())
			hud.set_camera(camera.camera_pos(), camera.zoom_level, follow_camera)
		KEY_MINUS:
			camera.zoom_by(-CameraRig.ZOOM_STEP)
			hud.set_camera(camera.camera_pos(), camera.zoom_level, follow_camera)
		KEY_EQUAL:
			camera.zoom_by(CameraRig.ZOOM_STEP)
			hud.set_camera(camera.camera_pos(), camera.zoom_level, follow_camera)
		KEY_SPACE:
			if sim != null and not sim.is_finished():
				_set_pause_mode(PauseMode.MENU)
		KEY_ESCAPE:
			if not hud.panel_open:
				_set_pause_mode(PauseMode.MENU)
			else:
				hud.close_panel()
