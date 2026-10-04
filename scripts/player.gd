extends CharacterBody2D

const ATTACK_ANIMATIONS: Array[StringName] = [
	&"quick_attack_left",
	&"quick_attack_right",
	&"jabs",
]

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

@export var move_speed: float = 90.0
@export var jump_speed: float = 250.0
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_attacking: bool = false
var combo_index: int = 0
var attack_queued: bool = false

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var attack_collision: CollisionShape2D = $Visuals/AttackHitbox/CollisionShape2D

func _ready() -> void:
	# Keep shape changes local to this player instance.
	attack_collision.shape = attack_collision.shape.duplicate()
	animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	# A buffered jump can leave the previous floor contact valid until movement.
	var grounded := is_on_floor() and velocity.y >= 0.0

	if grounded:
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
		velocity += get_gravity() * delta
		
	if grounded and Input.is_action_just_pressed("attack"):
		if not is_attacking:
			start_attack()
		elif combo_index < ATTACK_ANIMATIONS.size() - 1:
			attack_queued = true

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
	combo_index = 0
	attack_queued = false
	play_combo_attack()


func play_combo_attack() -> void:
	attack_collision.position = ATTACK_POSITIONS[combo_index]

	var rectangle := attack_collision.shape as RectangleShape2D
	rectangle.size = ATTACK_SIZES[combo_index]

	animated_sprite.play(ATTACK_ANIMATIONS[combo_index])


func _on_animation_finished() -> void:
	if not is_attacking:
		return

	if animated_sprite.animation != ATTACK_ANIMATIONS[combo_index]:
		return

	if attack_queued and combo_index < ATTACK_ANIMATIONS.size() - 1:
		attack_queued = false
		combo_index += 1
		play_combo_attack()
	else:
		is_attacking = false
		combo_index = 0
		attack_queued = false
