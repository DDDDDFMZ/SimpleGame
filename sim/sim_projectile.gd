class_name SimProjectile
extends RefCounted

var id: int
var team: int
var pos: Vector2 = Vector2.ZERO
var target_id: int = -1
var speed: float = 0.0
var damage: float = 0.0
var source_damage: float = 0.0
var attack_type: String = "ranged"
var source_passive: String = ""
var done: bool = false
