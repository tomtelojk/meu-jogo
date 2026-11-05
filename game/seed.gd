class_name ForestSeed
extends Area2D

var seed_data: Dictionary
var elapsed: float = 0.0
var gathered: bool = false

func setup(data: Dictionary) -> void:
	seed_data = data
	position = data.position
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	set_meta("interaction", data.merged({"kind": "seed", "label": "Recolher semente"}))
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 63.0
	shape.shape = circle
	add_child(shape)
	name = "Seed_" + data.id

func gather() -> void:
	gathered = true
	hide()
	set_deferred("monitorable", false)

func _process(delta: float) -> void:
	if gathered:
		return
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	if gathered:
		return
	draw_set_transform(Vector2(0, 4), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 20, Color(0.15, 0.2, 0.13, 0.35))
	draw_arc(Vector2.ZERO, 28, 0, TAU, 40, Color(0.91, 0.85, 0.58, 0.65), 1.0)
	draw_set_transform(Vector2.ZERO)
	for i in range(8, 0, -1):
		draw_circle(Vector2(0, -20), i * 6.0, Color(0.96, 0.82, 0.46, 0.013))
	var bob := Vector2(0, -23 + sin(elapsed * 2.3 + position.x) * 4)
	draw_set_transform(bob, -0.3)
	draw_rect(Rect2(-6, -1, 12, 12), Color("86733d"))
	draw_rect(Rect2(-5, -3, 10, 13), Color("e9c976"))
	draw_rect(Rect2(-4, -3, 5, 8), Color("ffedb4"))
	draw_rect(Rect2(1, -10, 7, 4), Color("b8c888"))
	draw_rect(Rect2(0, -7, 2, 6), Color("b8c888"))
	draw_rect(Rect2(4, -11, 6, 3), Color("d7df9f"))
	draw_set_transform(Vector2.ZERO)
	for i in 3:
		var angle := elapsed * 0.7 + i * 2.1 + position.x
		draw_rect(Rect2(Vector2(cos(angle) * 23, -22 + sin(angle * 1.4) * 25), Vector2(2, 2)), Color(1, 0.92, 0.64, 0.65))
