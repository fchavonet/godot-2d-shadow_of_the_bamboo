extends Area2D

var hit_count: int = 0
var flash_tween: Tween

@onready var visual: MeshInstance2D = $MeshInstance2D
@onready var base_color: Color = visual.self_modulate


func take_hit() -> void:
	hit_count += 1
	print("Training dummy hit count: ", hit_count)

	# Restart the flash cleanly when hits arrive close together.
	if flash_tween != null:
		flash_tween.kill()

	visual.self_modulate = Color.WHITE
	flash_tween = create_tween()
	flash_tween.tween_property(
		visual,
		"self_modulate",
		base_color,
		0.15
	)
