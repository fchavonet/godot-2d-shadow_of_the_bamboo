extends CharacterBody2D

@export var move_speed: float = 90.0
@export var jump_speed: float = 250.0
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_attacking: bool = false

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D


func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	# A buffered jump can leave the previous floor contact valid until movement.
	var grounded := is_on_floor() and velocity.y >= 0.0

	if grounded:
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
		velocity += get_gravity() * delta
		
	if grounded and not is_attacking and Input.is_action_just_pressed("attack"):
		start_attack()

	if is_attacking:
		velocity.x = 0.0
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		move_and_slide()
		return

	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		perform_jump()

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed

	if direction != 0.0:
		visuals.scale.x = direction

	move_and_slide()

	# Resolve buffered input as soon as movement detects a landing.
	if not grounded and is_on_floor() and jump_buffer_timer > 0.0:
		perform_jump()

	update_animation(direction)


func perform_jump() -> void:
	velocity.y = -jump_speed

	# Consume both timers to prevent another jump during the same airtime.
	coyote_timer = 0.0
	jump_buffer_timer = 0.0

	# A buffered tap released before landing should still produce a short jump.
	if not Input.is_action_pressed("jump"):
		velocity.y *= jump_cut_multiplier


func update_animation(direction: float) -> void:
	if not is_on_floor() or velocity.y < 0.0:
		if velocity.y < 0.0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")
	elif direction != 0.0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")


func start_attack() -> void:
	is_attacking = true
	animated_sprite.play("attack")


func _on_animation_finished() -> void:
	if animated_sprite.animation == "attack":
		is_attacking = false
