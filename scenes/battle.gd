extends Node2D

const BASE_HP := 10
const BASE_DAMAGE := 5
const SEED := 12345

@onready var runner: SimRunner = $SimRunner
@onready var view: BattleView = $BattleView
@onready var status_label: Label = $HUD/Status

var sim: BattleSim


func _ready() -> void:
	runner.ticked.connect(_on_ticked)
	view.setup(runner)
	_reset_and_start()


func _reset_and_start() -> void:
	sim = BattleSim.new(SEED, BASE_HP, BASE_DAMAGE)
	runner.setup(sim)
	view.reset_view()
	_queue_autostart()
	_update_hud(sim.get_snapshot())


func _queue_autostart() -> void:
	# M1 debug battle: player has a small advantage so a win is reachable.
	for i in range(3):
		sim.queue_spawn(BattleSim.PLAYER, 0, "swordsman")
	for i in range(2):
		sim.queue_spawn(BattleSim.PLAYER, 1, "swordsman")
	for i in range(2):
		sim.queue_spawn(BattleSim.ENEMY, 0, "swordsman")
	sim.queue_spawn(BattleSim.ENEMY, 1, "swordsman")


func _on_ticked(snapshot: Dictionary) -> void:
	_update_hud(snapshot)


func _update_hud(snapshot: Dictionary) -> void:
	var hp: Array = snapshot.get("base_hp", [0, 0])
	var max_hp := int(snapshot.get("base_hp_max", BASE_HP))
	var player_units := 0
	var enemy_units := 0
	for u in snapshot.get("units", []):
		if int(u.get("team", 0)) == BattleSim.PLAYER:
			player_units += 1
		else:
			enemy_units += 1

	var result := ""
	if bool(snapshot.get("finished", false)):
		var winner := int(snapshot.get("winner", -1))
		if winner < 0:
			result = "  |  DRAW"
		elif winner == BattleSim.PLAYER:
			result = "  |  PLAYER WIN"
		else:
			result = "  |  ENEMY WIN"

	status_label.text = (
		"P base %d/%d   E base %d/%d   |   units P %d  E %d   |   tick %d%s\n"
		+ "1/2 sword P/E   3/4 archer P/E   5/6 sword P/E lane2   |   R reset   Esc quit"
	) % [int(hp[0]), max_hp, int(hp[1]), max_hp, player_units, enemy_units, int(snapshot.get("tick", 0)), result]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_1:
			_spawn(BattleSim.PLAYER, 0, "swordsman")
		KEY_2:
			_spawn(BattleSim.ENEMY, 0, "swordsman")
		KEY_3:
			_spawn(BattleSim.PLAYER, 0, "archer")
		KEY_4:
			_spawn(BattleSim.ENEMY, 0, "archer")
		KEY_5:
			_spawn(BattleSim.PLAYER, 1, "swordsman")
		KEY_6:
			_spawn(BattleSim.ENEMY, 1, "swordsman")
		KEY_R:
			_reset_and_start()
		KEY_ESCAPE:
			get_tree().quit()


func _spawn(team: int, lane: int, def_id: String) -> void:
	if sim == null:
		return
	sim.queue_spawn(team, lane, def_id)
