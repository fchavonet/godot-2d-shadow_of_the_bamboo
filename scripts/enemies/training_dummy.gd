extends Node2D

signal health_changed(current: int, maximum: int)
signal died

const DAMAGE_NUMBER_SCENE: PackedScene = preload(
	"res://scenes/effects/damage_number.tscn"
)


const GEM_SCENE: PackedScene = preload("res://scenes/collectibles/gem.tscn")


@export_group("Gem Drops")
@export_range(0, 100, 1) var gem_drop_min: int = 2
@export_range(0, 100, 1) var gem_drop_max: int = 5
@export var gem_drop_offset: Vector2 = Vector2(0.0, -8.0)
@export_range(0.0, 300.0, 1.0) var gem_spread_speed: float = 60.0
@export_range(0.0, 300.0, 1.0) var gem_launch_speed: float = 100.0

@export_group("Health")
@export_range(1, 1000, 1) var max_health: int = 10

@export_group("Feedback")
@export var damage_number_offset: Vector2 = Vector2(0.0, -34.0)


var health: int = 0
var is_dead: bool = false


@onready var animated_sprite: AnimatedSprite2D = $Visuals/Sprite
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	health = max_health
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(&"idle")
	health_changed.emit(health, max_health)


func _on_animation_finished() -> void:
	if is_dead:
		return

	if animated_sprite.animation == &"hit":
		animated_sprite.play(&"idle")


# Health and damage

func receive_hit(damage: int) -> void:
	if is_dead or damage <= 0:
		return

	health = maxi(health - damage, 0)

	show_damage_number(damage)
	health_changed.emit(health, max_health)

	if health == 0:
		die()
		return

	# Restart the reaction for each hit, including rapid combo hits.
	animated_sprite.stop()
	animated_sprite.play(&"hit")


func die() -> void:
	if is_dead:
		return

	is_dead = true

	# Stop dealing damage immediately and remove the target from detection.
	hurtbox.set("enabled", false)
	hurtbox.set_deferred("collision_layer", 0)
	hurtbox.set_deferred("collision_mask", 0)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)

	# Gems are released once, on the lethal hit.
	drop_gems()
	var frames := animated_sprite.sprite_frames
	if (
		frames != null
		and frames.has_animation(&"death")
		and frames.get_frame_count(&"death") > 0
		and not frames.get_animation_loop(&"death")
		and frames.get_animation_speed(&"death") > 0.0
		and animated_sprite.speed_scale > 0.0
	):
		animated_sprite.stop()
		animated_sprite.play(&"death")
	else:
		push_warning("TrainingDummy: configure a non-looping death animation.")
		queue_free()
	died.emit()


# Damage feedback

func show_damage_number(amount: int) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate() as Node2D

	# Keep the number alive even when the target is removed.
	get_tree().current_scene.add_child(damage_number)

	damage_number.global_position = global_position + damage_number_offset
	damage_number.display(amount)


# Gem drops

func drop_gems() -> void:
	var minimum := mini(gem_drop_min, gem_drop_max)
	var maximum := maxi(gem_drop_min, gem_drop_max)
	var count := randi_range(minimum, maximum)
	var level := get_tree().current_scene

	for index in count:
		var gem := GEM_SCENE.instantiate() as CharacterBody2D
		# Gems belong to the level and survive the enemy's removal.
		level.add_child(gem)
		gem.global_position = global_position + gem_drop_offset
		gem.launch(Vector2(
			randf_range(-gem_spread_speed, gem_spread_speed),
			- randf_range(gem_launch_speed * 0.7, gem_launch_speed)
		))
