class_name SimUnit
extends RefCounted

var id: int
var team: int
var lane: int
var def_id: String
var def: Dictionary
var x: float

var hp: float
var max_hp: float
var damage: float
var attack_interval: float
var attack_range: float
var speed: float
var attack_type: String
var armor_type: String
var passive: String
var projectile_speed: float
var aggro_range: float

var attack_cd: float = 0.0
var target_id: int = -1
var state: String = "advance"
var alive: bool = true
var slot: int = 0
var charge_used: bool = false
var stationary_time: float = 0.0


func _init(p_id: int, p_team: int, p_lane: int, p_def_id: String, p_def: Dictionary, p_x: float) -> void:
	id = p_id
	team = p_team
	lane = p_lane
	def_id = p_def_id
	def = p_def
	x = p_x

	max_hp = float(def.get("hp", 100.0))
	hp = max_hp
	damage = float(def.get("damage", 10.0))
	attack_interval = float(def.get("attack_interval", 1.0))
	attack_range = float(def.get("range", 24.0))
	speed = float(def.get("speed", 50.0))
	attack_type = String(def.get("attack_type", "melee"))
	armor_type = String(def.get("armor_type", "light"))
	passive = String(def.get("passive", ""))
	projectile_speed = float(def.get("projectile_speed", 0.0))
	aggro_range = maxf(100.0, attack_range + 20.0)
