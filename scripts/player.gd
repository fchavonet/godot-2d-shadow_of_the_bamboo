extends CharacterBody2D

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

var jump_coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var glide_hold_timer: float = 0.0
var is_gliding: bool = false

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D


func _physics_process(delta: float) -> void:
	if is_on_floor():
		jump_coyote_timer = jump_coyote_time
	else:
		jump_coyote_timer = maxf(jump_coyote_timer - delta, 0.0)
		velocity += get_gravity() * delta

	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	var jump_pressed := Input.is_action_just_pressed("jump")

	if jump_pressed:
		jump_buffer_timer = jump_buffer_time

	var wants_to_jump := jump_pressed or jump_buffer_timer > 0.0
	var can_jump := is_on_floor() or jump_coyote_timer > 0.0
	var jumped_this_frame := false

	if wants_to_jump and can_jump:
		velocity.y = - jump_speed
		jump_coyote_timer = 0.0
		jump_buffer_timer = 0.0
		jumped_this_frame = true

		if not Input.is_action_pressed("jump"):
			velocity.y *= jump_cut_multiplier

	if (
		Input.is_action_just_released("jump")
		and velocity.y < 0.0
		and not jumped_this_frame
	):
		velocity.y *= jump_cut_multiplier

	is_gliding = false

	if Input.is_action_pressed("jump") and not is_on_floor():
		glide_hold_timer += delta
	else:
		glide_hold_timer = 0.0

	if (
		not is_on_floor()
		and velocity.y > 0.0
		and Input.is_action_pressed("jump")
		and glide_hold_timer >= glide_hold_time
	):
		is_gliding = true
		velocity.y = minf(velocity.y, glide_fall_speed)

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed

	if direction != 0.0:
		visuals.scale.x = signf(direction)

	move_and_slide()
	update_animation(direction)


func update_animation(direction: float) -> void:
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
