class_name ForestJoystick
extends Control

signal vector_changed(value: Vector2)
var direction := Vector2.ZERO
var finger: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(108, 108)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var center := size / 2.0
	draw_circle(center, 52, Color(0.88, 0.91, 0.78, 0.1))
	draw_arc(center, 52, 0, TAU, 64, Color(0.88, 0.91, 0.78, 0.3), 1.0)
	draw_circle(center + direction * 34, 20, Color(0.88, 0.91, 0.78, 0.35))
	draw_arc(center + direction * 34, 20, 0, TAU, 40, Color(0.95, 0.94, 0.83, 0.5), 1)

func reset() -> void:
	finger = -1
	direction = Vector2.ZERO
	vector_changed.emit(direction)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			_move(event.position)
		elif not event.pressed and event.index == finger:
			reset()
		accept_event()
	elif event is InputEventScreenDrag and event.index == finger:
		_move(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			finger = -2
			_move(event.position)
		else:
			reset()
		accept_event()
	elif event is InputEventMouseMotion and finger == -2:
		_move(event.position)
		accept_event()

func _move(point: Vector2) -> void:
	direction = ((point - size / 2.0) / 34.0).limit_length(1.0)
	if direction.length() < 0.12:
		direction = Vector2.ZERO
	vector_changed.emit(direction)
	queue_redraw()
