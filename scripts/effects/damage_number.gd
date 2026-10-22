extends Node2D

@export_group("Motion")
@export var rise_distance: float = 24.0
@export var horizontal_spread: float = 8.0
@export_range(0.1, 2.0, 0.05) var lifetime: float = 0.6

@onready var value_label: Label = $Value


func display(amount: int) -> void:
	value_label.text = str(amount)

	var drift := randf_range(-horizontal_spread, horizontal_spread)
	var destination := position + Vector2(drift, -rise_distance)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		self, "position", destination, lifetime
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self, "modulate:a", 0.0, lifetime * 0.5
	).set_delay(lifetime * 0.5)

	tween.chain().tween_callback(queue_free)
