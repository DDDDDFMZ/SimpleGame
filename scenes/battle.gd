extends Node2D

const LEVEL_PATH := "res://data/levels/level_01.json"
const SEED := 12345
const UNIT_ORDER := ["swordsman", "spearman", "archer", "mage", "knight", "catapult"]

@onready var runner: SimRunner = $SimRunner
@onready var view: BattleView = $BattleView
@onready var hud: BattleHUD = $HUD/Root

var sim: BattleSim
var level_data: Dictionary = {}
var active_lane: int = 0


func _ready() -> void:
	level_data = _load_level()
	runner.ticked.connect(_on_ticked)
	view.setup(runner)
	hud.spawn_requested.connect(_on_hud_spawn)
	hud.build_requested.connect(_on_hud_build)
	hud.lane_requested.connect(_on_hud_lane)
	_reset_and_start()


func _load_level() -> Dictionary:
	var text := FileAccess.get_file_as_string(LEVEL_PATH)
	if text.is_empty():
		push_error("Cannot read level: " + LEVEL_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid level JSON: " + LEVEL_PATH)
		return {}
	return parsed


func _reset_and_start() -> void:
	active_lane = 0
	sim = BattleSim.new(SEED, 20, 1, level_data)
	runner.setup(sim)
	view.reset_view()
	view.set_active_lane(active_lane)
	hud.close_panel()
	hud.update_snapshot(sim.get_snapshot(), active_lane)


func _on_ticked(snapshot: Dictionary) -> void:
	hud.update_snapshot(snapshot, active_lane)


func _on_hud_spawn(def_id: String) -> void:
	if sim != null:
		sim.queue_spawn(BattleSim.PLAYER, active_lane, def_id)


func _on_hud_build(slot: int) -> void:
	if sim != null:
		sim.queue_build(slot)


func _on_hud_lane(lane: int) -> void:
	_set_lane(lane)


func _set_lane(lane: int) -> void:
	active_lane = clampi(lane, 0, 1)
	view.set_active_lane(active_lane)
	if sim != null:
		hud.update_snapshot(sim.get_snapshot(), active_lane)


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
		KEY_R:
			_reset_and_start()
		KEY_SPACE:
			if sim != null and not sim.is_finished():
				runner.paused = not runner.paused
		KEY_ESCAPE:
			get_tree().quit()


func _spawn_by_index(index: int, other_lane: bool) -> void:
	if index < 0 or index >= UNIT_ORDER.size() or sim == null:
		return
	var lane := 1 - active_lane if other_lane else active_lane
	sim.queue_spawn(BattleSim.PLAYER, lane, UNIT_ORDER[index])
