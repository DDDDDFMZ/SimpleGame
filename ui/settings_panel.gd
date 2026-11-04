class_name SettingsPanel
extends Control

signal closed
signal station_order_changed(order: Array)

const PANEL_RECT := Rect2(80.0, 34.0, 480.0, 292.0)
const TAB_RECTS := [
	Rect2(98.0, 72.0, 104.0, 22.0),
	Rect2(208.0, 72.0, 104.0, 22.0),
	Rect2(318.0, 72.0, 104.0, 22.0),
]
const TAB_NAMES := ["显示", "站位顺序", "操作"]
const ZOOM_CHOICES := [0.6, 0.8, 1.0, 1.2]
const SCALE_CHOICES := [1.0, 1.25, 1.5]

var font: Font
var tab: int = 0
var station_order: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	font = system_font
	queue_redraw()


func open(p_tab: int = 0) -> void:
	tab = clampi(p_tab, 0, TAB_NAMES.size() - 1)
	var default_order: Array = GameState.default_station_order()
	station_order = SettingsService.station_order(default_order)
	visible = true
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos: Vector2 = event.position
	for i in range(TAB_RECTS.size()):
		if TAB_RECTS[i].has_point(pos):
			tab = i
			queue_redraw()
			accept_event()
			return
	if Rect2(PANEL_RECT.position.x + 14.0, 296.0, 120.0, 20.0).has_point(pos):
		SettingsService.reset_defaults(GameState.default_station_order())
		station_order = SettingsService.station_order(GameState.default_station_order())
		station_order_changed.emit(station_order.duplicate())
		queue_redraw()
		accept_event()
		return
	if Rect2(PANEL_RECT.position.x + 346.0, 296.0, 120.0, 20.0).has_point(pos):
		close()
		accept_event()
		return
	if tab == 0:
		_handle_display_click(pos)
	elif tab == 1:
		_handle_station_click(pos)
	accept_event()


func _handle_display_click(pos: Vector2) -> void:
	if Rect2(314.0, 118.0, 26.0, 22.0).has_point(pos):
		_change_zoom(-1)
	elif Rect2(434.0, 118.0, 26.0, 22.0).has_point(pos):
		_change_zoom(1)
	elif Rect2(314.0, 152.0, 26.0, 22.0).has_point(pos):
		_change_scale(-1)
	elif Rect2(434.0, 152.0, 26.0, 22.0).has_point(pos):
		_change_scale(1)
	elif Rect2(314.0, 186.0, 146.0, 22.0).has_point(pos):
		SettingsService.set_fullscreen(not SettingsService.is_fullscreen())
		queue_redraw()


func _change_zoom(delta: int) -> void:
	var current := SettingsService.get_default_zoom()
	var index := 0
	for i in range(ZOOM_CHOICES.size()):
		if absf(float(ZOOM_CHOICES[i]) - current) < 0.01:
			index = i
			break
	index = clampi(index + delta, 0, ZOOM_CHOICES.size() - 1)
	SettingsService.set_default_zoom(float(ZOOM_CHOICES[index]))
	queue_redraw()


func _change_scale(delta: int) -> void:
	var current := SettingsService.get_window_scale()
	var index := 0
	for i in range(SCALE_CHOICES.size()):
		if absf(float(SCALE_CHOICES[i]) - current) < 0.01:
			index = i
			break
	index = clampi(index + delta, 0, SCALE_CHOICES.size() - 1)
	SettingsService.set_window_scale(float(SCALE_CHOICES[index]))
	queue_redraw()


func _handle_station_click(pos: Vector2) -> void:
	for i in range(mini(station_order.size(), 8)):
		if Rect2(100.0, 104.0 + i * 19.0, 360.0, 17.0).has_point(pos):
			return
		if Rect2(470.0, 105.0 + i * 19.0, 20.0, 16.0).has_point(pos):
			_move_station(i, -1)
			return
		if Rect2(494.0, 105.0 + i * 19.0, 20.0, 16.0).has_point(pos):
			_move_station(i, 1)
			return


func _move_station(index: int, delta: int) -> void:
	var other := index + delta
	if other < 0 or other >= station_order.size():
		return
	var temp: Variant = station_order[index]
	station_order[index] = station_order[other]
	station_order[other] = temp
	SettingsService.set_station_order(station_order, GameState.default_station_order())
	station_order_changed.emit(station_order.duplicate())
	queue_redraw()


func _draw() -> void:
	if font == null:
		return
	draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), Color(0.0, 0.0, 0.0, 0.64))
	draw_rect(PANEL_RECT, Color(0.06, 0.05, 0.09, 0.99))
	draw_rect(PANEL_RECT, Color("#D9A441"), false, 1.5)
	draw_string(font, Vector2(100.0, 58.0), "设置", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#E8D5A9"))
	draw_string(font, Vector2(370.0, 56.0), "设置文件：%s" % SettingsService.settings_path, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	for i in range(TAB_RECTS.size()):
		draw_rect(TAB_RECTS[i], Color("#3B3348") if i == tab else Color("#252232"))
		draw_rect(TAB_RECTS[i], Color("#D9A441") if i == tab else Color("#4A4658"), false, 1.0)
		_center_text_in(TAB_NAMES[i], TAB_RECTS[i], 8, Color("#E8D5A9") if i == tab else Color("#8A8498"))
	if tab == 0:
		_draw_display()
	elif tab == 1:
		_draw_station()
	else:
		_draw_controls()
	draw_rect(Rect2(PANEL_RECT.position.x + 14.0, 296.0, 120.0, 20.0), Color("#252232"))
	draw_rect(Rect2(PANEL_RECT.position.x + 346.0, 296.0, 120.0, 20.0), Color("#252232"))
	_center_text_in("恢复默认设置", Rect2(PANEL_RECT.position.x + 14.0, 296.0, 120.0, 20.0), 7, Color("#E06666"))
	_center_text_in("关闭", Rect2(PANEL_RECT.position.x + 346.0, 296.0, 120.0, 20.0), 8, Color("#E8D5A9"))


func _draw_display() -> void:
	_draw_row("默认镜头缩放", "%.1f×" % SettingsService.get_default_zoom(), 118.0)
	_draw_row("窗口缩放", "%.2f×（%d×%d）" % [SettingsService.get_window_scale(), int(1280 * SettingsService.get_window_scale()), int(720 * SettingsService.get_window_scale())], 152.0)
	var fs := "开" if SettingsService.is_fullscreen() else "关"
	draw_string(font, Vector2(118.0, 201.0), "全屏", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
	draw_rect(Rect2(314.0, 186.0, 146.0, 22.0), Color("#252232"))
	draw_rect(Rect2(314.0, 186.0, 146.0, 22.0), Color("#4A4658"), false, 1.0)
	_center_text_in(fs, Rect2(314.0, 186.0, 146.0, 22.0), 8, Color("#6FA8DC") if fs == "开" else Color("#8A8498"))
	draw_string(font, Vector2(118.0, 238.0), "默认缩放用于每场战斗开始；窗口缩放/全屏立即应用。", HORIZONTAL_ALIGNMENT_LEFT, 390.0, 7, Color("#8A8498"))


func _draw_row(label: String, value: String, y: float) -> void:
	draw_string(font, Vector2(118.0, y + 15.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
	draw_rect(Rect2(314.0, y, 26.0, 22.0), Color("#252232"))
	draw_rect(Rect2(434.0, y, 26.0, 22.0), Color("#252232"))
	_center_text_in("<", Rect2(314.0, y, 26.0, 22.0), 9, Color("#E8D5A9"))
	_center_text_in(">", Rect2(434.0, y, 26.0, 22.0), 9, Color("#E8D5A9"))
	draw_rect(Rect2(342.0, y, 90.0, 22.0), Color("#1A1724"))
	_center_text_in(value, Rect2(342.0, y, 90.0, 22.0), 8, Color("#6FA8DC"))


func _draw_station() -> void:
	# Reuse a compact 8-row list; the current selection is implicit by row.
	var lookup := {}
	if GameState.game_data != null:
		for def_id in GameState.game_data.unit_order:
			var def: Dictionary = GameState.game_data.unit_defs[String(def_id)]
			lookup[String(def_id)] = String(def.get("display_name_cn", def.get("display_name", def_id)))
	for i in range(mini(station_order.size(), 8)):
		var y := 104.0 + i * 19.0
		draw_rect(Rect2(100.0, y, 406.0, 17.0), Color("#1A1724") if i % 2 == 0 else Color("#211D2C"))
		draw_rect(Rect2(100.0, y, 406.0, 17.0), Color("#4A4658"), false, 1.0)
		draw_string(font, Vector2(108.0, y + 12.0), "%d  %s" % [i + 1, String(lookup.get(String(station_order[i]), station_order[i]))], HORIZONTAL_ALIGNMENT_LEFT, 330.0, 8, Color("#E8D5A9"))
		draw_rect(Rect2(470.0, y + 1.0, 20.0, 15.0), Color("#252232"))
		draw_rect(Rect2(494.0, y + 1.0, 20.0, 15.0), Color("#252232"))
		_center_text_in("↑", Rect2(470.0, y + 1.0, 20.0, 15.0), 8, Color("#B8B0C8"))
		_center_text_in("↓", Rect2(494.0, y + 1.0, 20.0, 15.0), 8, Color("#B8B0C8"))
	draw_string(font, Vector2(118.0, 276.0), "站位顺序影响排队入路与集结点前后站位，不影响战斗数值。", HORIZONTAL_ALIGNMENT_LEFT, 390.0, 7, Color("#8A8498"))


func _draw_controls() -> void:
	var lines: Array = [
		"1-8 / Alt+1-8  当前路线 / 下一路线招募",
		"Q/E  切换出生路线   左键/拖框 选中   Shift 加选",
		"右键 移动    Shift+右键 设集结点    H 驻守    R 归线",
		"滚轮 / - / = 缩放    F 跟随    WASD 平移    Home 回基地",
		"B 协会    Space 暂停菜单    F1 指南    F2 首局步骤",
		"O 设置    S（关卡选择）存档    Esc 关闭",
	]
	for i in range(lines.size()):
		draw_string(font, Vector2(110.0, 118.0 + i * 24.0), String(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, 420.0, 8, Color("#B8B0C8"))


func _center_text_in(text: String, rect: Rect2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + rect.size.y * 0.5 + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
