extends Node2D

signal health_changed(current: int, maximum: int)
signal died

@export_group("Health")
@export_range(1, 1000, 1) var max_health: int = 10

@export_group("Feedback")
@export_range(0.01, 0.5, 0.01) var hit_flash_duration: float = 0.1

var health: int = 0
var hit_count: int = 0
var hit_flash_timer: float = 0.0
var is_dead: bool = false

@onready var visual: ColorRect = $Visual
@onready var base_color: Color = visual.color


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func _process(delta: float) -> void:
	if is_dead:
		return

	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(hit_flash_timer - delta, 0.0)

		if hit_flash_timer == 0.0:
			visual.color = base_color


func receive_hit(damage: int) -> void:
	if is_dead or damage <= 0:
		return

	hit_count += 1
	health = maxi(health - damage, 0)
	health_changed.emit(health, max_health)

	print(
		"%s | Hit count: %d | Health: %d/%d"
		% [name, hit_count, health, max_health]
	)

	if health == 0:
		die()
		return

	hit_flash_timer = hit_flash_duration
	visual.color = Color.WHITE


func die() -> void:
	if is_dead:
		return

	is_dead = true
	died.emit()

	print("%s | Defeated" % name)

	queue_free()
