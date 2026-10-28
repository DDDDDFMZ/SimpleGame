class_name SimRunner
extends Node

signal ticked(snapshot: Dictionary)

const TICK_HZ := 20.0
const MAX_STEPS_PER_FRAME := 5

var sim: BattleSim
var paused: bool = false

var _accumulator: float = 0.0


func setup(p_sim: BattleSim) -> void:
	sim = p_sim
	_accumulator = 0.0
	paused = false


func _physics_process(delta: float) -> void:
	if sim == null or paused:
		return

	_accumulator += delta
	var step := 1.0 / TICK_HZ
	var steps := 0

	while _accumulator >= step and steps < MAX_STEPS_PER_FRAME:
		sim.tick()
		_accumulator -= step
		steps += 1
		ticked.emit(sim.get_snapshot())
		if sim.is_finished():
			paused = true
			break
