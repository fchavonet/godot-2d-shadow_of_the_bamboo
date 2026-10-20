extends CharacterBody2D

@export_group("Energy")
@export_range(1, 100, 1) var energy_value: int = 1

@export_group("Drop")
@export_range(0.0, 2.0, 0.05) var magnet_delay: float = 0.35

@export_group("Magnet")
@export_range(1.0, 500.0, 1.0) var attraction_speed: float = 120.0
@export_range(1.0, 2000.0, 1.0) var attraction_acceleration: float = 600.0
@export_range(0.1, 10.0, 0.1) var collection_distance: float = 3.0

var magnet_delay_timer: float = 0.0
var target: Node2D = null
var attraction_current_speed: float = 0.0
var is_collected: bool = false

@onready var magnet_area: Area2D = $MagnetArea


func _physics_process(delta: float) -> void:
	if is_collected:
		return

	if is_instance_valid(target):
		if bool(target.get("is_dead")):
			target = null
			attraction_current_speed = 0.0
	else:
		target = null

	magnet_delay_timer = maxf(magnet_delay_timer - delta, 0.0)
	if target == null and magnet_delay_timer <= 0.0:
		find_target()

	if is_instance_valid(target):
		update_attraction(delta)
		return

	# Gravity and collisions apply until attraction begins.
	if not is_on_floor() or velocity.y < 0.0:
		velocity += get_gravity() * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

	move_and_slide()


func find_target() -> void:
	# Polling also detects a player who respawns inside the magnet area.
	for area in magnet_area.get_overlapping_areas():
		var candidate := area.get_parent() as Node2D

		if candidate == null or candidate == self:
			continue

		if not candidate.has_method("collect_energy"):
			continue

		if bool(candidate.get("is_dead")):
			continue

		target = candidate
		attraction_current_speed = 0.0
		return


func update_attraction(delta: float) -> void:
	# Aim at the center of the player's hurtbox rather than their feet.
	var target_position := target.global_position
	var collision := target.get_node_or_null(
		"Hurtbox/CollisionShape2D"
	) as CollisionShape2D

	if collision != null:
		target_position = collision.global_position

	attraction_current_speed = move_toward(
		attraction_current_speed,
		attraction_speed,
		attraction_acceleration * delta
	)

	# Attracted gems pass through scenery and cannot overshoot the target.
	velocity = Vector2.ZERO
	global_position = global_position.move_toward(
		target_position,
		attraction_current_speed * delta
	)

	if global_position.distance_to(target_position) <= collection_distance:
		collect()


func collect() -> void:
	if is_collected or not is_instance_valid(target):
		return

	if bool(target.get("is_dead")):
		target = null
		attraction_current_speed = 0.0
		return

	is_collected = true
	target.call("collect_energy", energy_value)
	queue_free()


func launch(initial_velocity: Vector2) -> void:
	magnet_delay_timer = magnet_delay
	velocity = initial_velocity
	target = null
	attraction_current_speed = 0.0
