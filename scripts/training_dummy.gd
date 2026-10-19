extends Node2D

@export_group("Feedback")
@export_range(0.01, 0.5, 0.01) var hit_flash_duration: float = 0.1

var hit_count: int = 0
var hit_flash_timer: float = 0.0

@onready var visual: ColorRect = $Visual
@onready var base_color: Color = visual.color


func _process(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)

		if hit_flash_timer == 0.0:
			visual.color = base_color


func receive_hit() -> void:
	hit_count += 1
	hit_flash_timer = hit_flash_duration
	visual.color = Color.WHITE

	print("%s | Hit count: %d" % [name, hit_count])
