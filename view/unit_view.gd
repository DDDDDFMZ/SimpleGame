class_name UnitView
extends Node2D

var data: Dictionary = {}
var selected: bool = false


func update_data(p_data: Dictionary) -> void:
	data = p_data
	var pos_value: Variant = data.get("pos", [0.0, 0.0])
	if pos_value is Array and pos_value.size() >= 2:
		position = Vector2(float(pos_value[0]), float(pos_value[1]))
	else:
		position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	if bool(data.get("waiting", false)):
		position += Vector2(0.0, -8.0)
	queue_redraw()


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()


func _draw() -> void:
	if data.is_empty():
		return
	var team := int(data.get("team", 0))
	var color := Color("#3B6EA5") if team == 0 else Color("#A53B3B")
	var bar_color := Color("#6FA8DC") if team == 0 else Color("#E06666")

	draw_rect(Rect2(-7.0, -10.0, 14.0, 20.0), color)
	draw_rect(Rect2(-7.0, -10.0, 14.0, 20.0), Color(0.0, 0.0, 0.0, 0.45), false, 1.0)
	if bool(data.get("is_elite", false)):
		draw_rect(Rect2(-8.0, -11.0, 16.0, 22.0), Color("#D9A441"), false, 1.5)
	if bool(data.get("is_target", false)):
		draw_rect(Rect2(-9.0, -12.0, 18.0, 24.0), Color("#F0C75E"), false, 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, -19.0), Vector2(4.0, -15.0), Vector2(0.0, -11.0), Vector2(-4.0, -15.0),
		]), Color("#F0C75E"))
	if selected:
		draw_arc(Vector2(0.0, 0.0), 12.0, 0.0, TAU, 16, Color("#D9A441"), 1.5)
	if bool(data.get("waiting", false)):
		draw_arc(Vector2(0.0, 0.0), 9.0, 0.0, TAU, 12, Color("#8A8498"), 1.0)

	var attack_type := String(data.get("attack_type", "melee"))
	var glyph_color := Color(1.0, 1.0, 1.0, 0.8)
	match attack_type:
		"melee":
			draw_line(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), glyph_color, 1.5)
		"ranged":
			draw_circle(Vector2(0.0, 0.0), 2.5, glyph_color)
		"siege":
			draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), glyph_color)

	var max_hp := maxf(1.0, float(data.get("max_hp", 1.0)))
	var ratio := clampf(float(data.get("hp", 0.0)) / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-8.0, -14.0, 16.0, 3.0), Color(0.0, 0.0, 0.0, 0.7))
	if ratio > 0.0:
		draw_rect(Rect2(-8.0, -14.0, 16.0 * ratio, 3.0), bar_color)
