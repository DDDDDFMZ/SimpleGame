class_name SimUnit
extends RefCounted

var id: int
var team: int
var def_id: String
var def: Dictionary
var pos: Vector2 = Vector2.ZERO
var x: float = 0.0
var y: float = 0.0

var node_id: String = ""
var edge_id: String = ""
var edge_s: float = 0.0
var edge_dir: int = 1
var path: Array = []
var path_index: int = 0
var goal_node: String = ""
var goal_dirty: bool = true
var forced_entry: String = ""
var route_id: String = ""
var station_rank: int = 0
var station_slot: int = -1
var waiting: bool = false
var wait_node: String = ""
var wait_edge: String = ""
var wait_path_index: int = 0
var wait_time: float = 0.0

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
var is_elite: bool = false
var is_target: bool = false
var spawn_wave: int = 0
var manual_order: bool = false
var target_point: Vector2 = Vector2.ZERO
var target_edge_id: String = ""
var target_edge_s: float = -1.0
var hold_position: bool = false
var at_base: bool = false
var combat_cooldown: float = 0.0
var heal_cd: float = 0.0
var heal_amount: float = 0.0
var heal_interval: float = 0.0
var heal_range: float = 0.0


func _init(p_id: int, p_team: int, p_def_id: String, p_def: Dictionary, p_pos: Vector2, p_elite: bool = false, p_target: bool = false) -> void:
	id = p_id
	team = p_team
	def_id = p_def_id
	def = p_def
	pos = p_pos
	x = p_pos.x
	y = p_pos.y
	is_elite = p_elite
	is_target = p_target

	max_hp = float(def.get("hp", 100.0))
	if is_elite:
		max_hp *= 1.5
	hp = max_hp
	damage = float(def.get("damage", 10.0))
	attack_interval = float(def.get("attack_interval", 1.0))
	attack_range = float(def.get("range", 24.0))
	speed = float(def.get("speed", 50.0))
	attack_type = String(def.get("attack_type", "melee"))
	armor_type = String(def.get("armor_type", "light"))
	passive = String(def.get("passive", ""))
	projectile_speed = float(def.get("projectile_speed", 0.0))
	aggro_range = maxf(110.0, attack_range + 30.0)
	heal_amount = float(def.get("heal_amount", 0.0))
	heal_interval = float(def.get("heal_interval", 0.0))
	heal_range = float(def.get("heal_range", 0.0))


func set_position(new_pos: Vector2) -> void:
	pos = new_pos
	x = new_pos.x
	y = new_pos.y
