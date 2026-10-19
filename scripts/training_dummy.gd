extends Node2D

signal health_changed(current: int, maximum: int)
signal died

const DAMAGE_NUMBER_SCENE: PackedScene = preload(
	"res://scenes/damage_number.tscn"
)

@export_group("Health")
@export_range(1, 1000, 1) var max_health: int = 10

@export_group("Feedback")
@export_range(0.01, 0.5, 0.01) var hit_flash_duration: float = 0.1
@export var damage_number_offset: Vector2 = Vector2(0.0, -28.0)

var health: int = 0
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

	health = maxi(health - damage, 0)

	show_damage_number(damage)
	health_changed.emit(health, max_health)

	if health == 0:
		die()
		return

	hit_flash_timer = hit_flash_duration
	visual.color = Color.WHITE


func show_damage_number(amount: int) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D

	# Keep the number alive even when the target is removed.
	get_tree().current_scene.add_child(damage_number)

	damage_number.global_position = global_position + damage_number_offset
	damage_number.display(amount)


func die() -> void:
	if is_dead:
		return

	is_dead = true
	died.emit()
	queue_free()
