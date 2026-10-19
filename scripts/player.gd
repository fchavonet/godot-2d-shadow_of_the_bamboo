extends CharacterBody2D

const ATTACK_ANIMATIONS: Array[StringName] = [
	&"attack_1",
	&"attack_2",
	&"attack_3",
]

const ATTACK_ACTIVE_FRAMES: Array[Vector2i] = [
	Vector2i(1, 2),
	Vector2i(0, 1),
	Vector2i(3, 7),
]

const ATTACK_THREE_HIT_FRAMES: Array[int] = [3, 5, 7]

const ATTACK_POSITIONS: Array[Vector2] = [
	Vector2(18.0, -8.0),
	Vector2(20.5, -8.0),
	Vector2(25.5, -8.0),
]

const ATTACK_SIZES: Array[Vector2] = [
	Vector2(25.5, 16.0),
	Vector2(30.0, 16.0),
	Vector2(40.5, 16.0),
]

const ROLL_HITBOX_POSITION := Vector2(0.0, -8.0)
const ROLL_HITBOX_SIZE := Vector2(16.0, 16.0)

const HURTBOX_COLLISION_MASK: int = 2
const MAX_HIT_QUERY_RESULTS: int = 32


@export_group("Movement")
@export var move_speed: float = 90.0

@export_group("Jump")
@export var jump_speed: float = 250.0
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
@export_range(0.0, 0.3, 0.01) var jump_coyote_time: float = 0.1
@export_range(0.0, 0.3, 0.01) var jump_buffer_time: float = 0.1

@export_group("Glide")
@export_range(0.0, 1.0, 0.01) var glide_hold_time: float = 0.2
@export_range(1.0, 300.0, 1.0) var glide_fall_speed: float = 60.0

@export_group("Roll")
@export var roll_speed: float = 180.0
@export_range(1, 100, 1) var roll_damage: int = 1

@export_group("Combat")
@export_range(1, 100, 1) var attack_damage: int = 1


var jump_coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var glide_hold_timer: float = 0.0
var is_gliding: bool = false

var is_rolling: bool = false
var roll_direction: float = 1.0
var has_air_rolled: bool = false

var is_attacking: bool = false
var is_air_attack: bool = false
var attack_combo_index: int = 0
var attack_queued: bool = false

var attack_hit_phase: int = -1
var attack_hit_targets: Array[int] = []


@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var attack_collision: CollisionShape2D = (
	$Visuals/AttackHitbox/CollisionShape2D
)


func _ready() -> void:
	# Each player instance owns its collision shape.
	attack_collision.shape = attack_collision.shape.duplicate()
	attack_collision.set_deferred("disabled", true)

	animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor() and velocity.y >= 0.0

	if grounded:
		jump_coyote_timer = jump_coyote_time
		has_air_rolled = false
	else:
		jump_coyote_timer = maxf(jump_coyote_timer - delta, 0.0)
		velocity += get_gravity() * delta

	update_roll_input(grounded)

	if is_rolling:
		update_roll()
		move_and_slide()
		update_roll_hitbox()
		apply_hit_damage(roll_damage)
		return

	var jumped_this_frame := update_jump(delta, grounded)

	if jumped_this_frame:
		grounded = false

	update_glide(delta, grounded)
	update_attack_input(grounded)

	var direction := Input.get_axis("move_left", "move_right")
	update_horizontal_movement(direction, grounded)

	move_and_slide()

	update_animation(direction)
	update_attack_hitbox()
	check_attack_hits()


# Jump and glide

func update_jump(delta: float, grounded: bool) -> bool:
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	var jump_pressed := Input.is_action_just_pressed("jump")

	if jump_pressed:
		jump_buffer_timer = jump_buffer_time

	var wants_to_jump := jump_pressed or jump_buffer_timer > 0.0
	var can_jump := grounded or jump_coyote_timer > 0.0
	var jumped_this_frame := false

	if wants_to_jump and can_jump and not is_attacking:
		velocity.y = - jump_speed
		jump_coyote_timer = 0.0
		jump_buffer_timer = 0.0
		jumped_this_frame = true

		# A buffered tap still produces a short jump.
		if not Input.is_action_pressed("jump"):
			velocity.y *= jump_cut_multiplier

	if (
		Input.is_action_just_released("jump")
		and velocity.y < 0.0
		and not jumped_this_frame
	):
		velocity.y *= jump_cut_multiplier

	return jumped_this_frame


func update_glide(delta: float, grounded: bool) -> void:
	is_gliding = false

	if (
		Input.is_action_pressed("jump")
		and not grounded
		and not is_attacking
	):
		glide_hold_timer += delta
	else:
		glide_hold_timer = 0.0

	if (
		not grounded
		and velocity.y > 0.0
		and Input.is_action_pressed("jump")
		and glide_hold_timer >= glide_hold_time
		and not is_attacking
	):
		is_gliding = true
		velocity.y = minf(velocity.y, glide_fall_speed)


func update_horizontal_movement(direction: float, grounded: bool) -> void:
	if is_attacking:
		jump_buffer_timer = 0.0

		if grounded:
			velocity.x = 0.0

		# Air attacks preserve horizontal momentum.
		return

	velocity.x = direction * move_speed

	if direction != 0.0:
		visuals.scale.x = signf(direction)


# Roll

func update_roll_input(grounded: bool) -> void:
	if not Input.is_action_just_pressed("roll"):
		return

	if is_rolling or is_attacking:
		return

	if not grounded and has_air_rolled:
		return

	start_roll(not grounded)


func start_roll(air_roll: bool) -> void:
	is_rolling = true
	roll_direction = signf(visuals.scale.x)

	if air_roll:
		has_air_rolled = true

	is_gliding = false
	glide_hold_timer = 0.0
	jump_buffer_timer = 0.0
	jump_coyote_timer = 0.0

	attack_hit_phase = -1
	attack_hit_targets.clear()

	animated_sprite.play("roll")


func update_roll() -> void:
	jump_coyote_timer = 0.0
	jump_buffer_timer = 0.0
	glide_hold_timer = 0.0
	is_gliding = false

	velocity.x = roll_direction * roll_speed


func update_roll_hitbox() -> void:
	attack_collision.position = ROLL_HITBOX_POSITION

	var attack_shape := attack_collision.shape as RectangleShape2D
	attack_shape.size = ROLL_HITBOX_SIZE

	attack_collision.set_deferred("disabled", false)


func finish_roll() -> void:
	is_rolling = false
	attack_hit_phase = -1
	attack_hit_targets.clear()

	attack_collision.set_deferred("disabled", true)


# Attack and combo

func update_attack_input(grounded: bool) -> void:
	if not Input.is_action_just_pressed("attack"):
		return

	if not is_attacking:
		start_attack(not grounded)
	elif (
		grounded
		and not is_air_attack
		and attack_combo_index < ATTACK_ANIMATIONS.size() - 1
	):
		attack_queued = true


func start_attack(air_attack: bool) -> void:
	is_attacking = true
	is_air_attack = air_attack
	attack_combo_index = 0
	attack_queued = false

	is_gliding = false
	glide_hold_timer = 0.0
	jump_buffer_timer = 0.0
	jump_coyote_timer = 0.0

	attack_hit_phase = -1
	attack_hit_targets.clear()

	animated_sprite.play(ATTACK_ANIMATIONS[attack_combo_index])


func finish_attack() -> void:
	is_attacking = false
	is_air_attack = false
	attack_combo_index = 0
	attack_queued = false

	attack_hit_phase = -1
	attack_hit_targets.clear()

	attack_collision.set_deferred("disabled", true)


# Hit detection

func is_attack_hit_active() -> bool:
	if not is_attacking:
		return false

	if animated_sprite.animation != ATTACK_ANIMATIONS[attack_combo_index]:
		return false

	var current_frame := animated_sprite.frame

	if attack_combo_index == 2:
		return ATTACK_THREE_HIT_FRAMES.has(current_frame)

	var active_frames := ATTACK_ACTIVE_FRAMES[attack_combo_index]

	return (
		current_frame >= active_frames.x
		and current_frame <= active_frames.y
	)


func update_attack_hitbox() -> void:
	if is_attacking:
		attack_collision.position = ATTACK_POSITIONS[attack_combo_index]

		var attack_shape := attack_collision.shape as RectangleShape2D
		attack_shape.size = ATTACK_SIZES[attack_combo_index]

	attack_collision.set_deferred("disabled", not is_attack_hit_active())


func check_attack_hits() -> void:
	if not is_attack_hit_active():
		return

	var impact_index: int = 0

	if attack_combo_index == 2:
		impact_index = ATTACK_THREE_HIT_FRAMES.find(animated_sprite.frame)

	var current_phase := attack_combo_index * 3 + impact_index

	if current_phase != attack_hit_phase:
		attack_hit_phase = current_phase
		attack_hit_targets.clear()

	apply_hit_damage(attack_damage)


func apply_hit_damage(damage: int) -> void:
	# Query the current shape directly after movement and resizing.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_collision.shape
	query.transform = attack_collision.global_transform
	query.collision_mask = HURTBOX_COLLISION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var space_state := get_world_2d().direct_space_state
	var results := space_state.intersect_shape(query, MAX_HIT_QUERY_RESULTS)

	for result in results:
		var hurtbox := result["collider"] as Area2D

		if hurtbox == null:
			continue

		var target := hurtbox.get_parent()

		if target == null or not target.has_method("receive_hit"):
			continue

		var target_id := target.get_instance_id()

		if attack_hit_targets.has(target_id):
			continue

		# Each target can receive damage once per impact.
		attack_hit_targets.append(target_id)
		target.call("receive_hit", damage)


# Animation

func update_animation(direction: float) -> void:
	if is_attacking or is_rolling:
		return

	if not is_on_floor():
		if is_gliding:
			animated_sprite.play("glide")
		elif velocity.y < 0.0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")
	elif direction != 0.0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"roll":
		finish_roll()
		return

	if not is_attacking:
		return

	if animated_sprite.animation != ATTACK_ANIMATIONS[attack_combo_index]:
		return

	if (
		attack_queued
		and not is_air_attack
		and is_on_floor()
		and attack_combo_index < ATTACK_ANIMATIONS.size() - 1
	):
		attack_combo_index += 1
		attack_queued = false
		animated_sprite.play(ATTACK_ANIMATIONS[attack_combo_index])
	else:
		finish_attack()
