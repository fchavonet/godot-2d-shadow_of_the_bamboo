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

const ATTACK_ACTIVE_FRAMES: Array[Vector2i] = [
	Vector2i(1, 2),
	Vector2i(0, 1),
	Vector2i(0, 3),
]

const ROLL_HITBOX_POSITION := Vector2(0.0, -8.0)
const ROLL_HITBOX_SIZE := Vector2(16.0, 16.0)

@export var move_speed: float = 90.0
@export var roll_speed: float = 180.0
@export var jump_speed: float = 250.0
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10
@export_range(0.0, 2.0) var glide_hold_time: float = 0.2
@export_range(1.0, 300.0) var glide_fall_speed: float = 60.0
@export_range(1.0, 300.0) var wall_slide_speed: float = 40.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var glide_hold_timer: float = 0.0
var is_gliding: bool = false

var is_rolling: bool = false
var roll_direction: float = 1.0
var has_air_rolled: bool = false

var is_attacking: bool = false
var combo_index: int = 0
var attack_queued: bool = false
var hit_targets: Array[Area2D] = []
var hitbox_refresh_pending: bool = false
var is_wall_sliding: bool = false

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var sprite_base_position: Vector2 = animated_sprite.position
@onready var attack_hitbox: Area2D = $Visuals/AttackHitbox
@onready var attack_collision: CollisionShape2D = $Visuals/AttackHitbox/CollisionShape2D


func _ready() -> void:
	# Keep shape changes local to this player instance.
	attack_collision.shape = attack_collision.shape.duplicate()
	animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	is_wall_sliding = false

	# A buffered jump can leave the previous floor contact valid until movement.
	var grounded := is_on_floor() and velocity.y >= 0.0

	if grounded:
		coyote_timer = coyote_time
		has_air_rolled = false
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
		velocity += get_gravity() * delta

	var can_roll := grounded or not has_air_rolled

	if can_roll and not is_attacking and not is_rolling:
		if Input.is_action_just_pressed("roll"):
			start_roll()

	if is_rolling:
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		velocity.x = roll_direction * roll_speed
		move_and_slide()
		check_attack_hits()
		return

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
		check_attack_hits()
		return

	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		perform_jump()

	update_glide(delta, grounded)

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed

	if direction != 0.0:
		visuals.scale.x = direction

	# Limit descent using the previous physics step's wall contact.
	update_wall_slide(direction)

	move_and_slide()

	# Resolve buffered input as soon as movement detects a landing.
	if not grounded and is_on_floor() and jump_buffer_timer > 0.0:
		perform_jump()

	# Refresh the state after movement for landings and new wall contacts.
	update_wall_slide(direction)
	update_animation(direction)


func perform_jump() -> void:
	velocity.y = -jump_speed

	# Consume both timers to prevent another jump during the same airtime.
	coyote_timer = 0.0
	jump_buffer_timer = 0.0

	# A buffered tap released before landing should produce a short jump.
	if not Input.is_action_pressed("jump"):
		velocity.y *= jump_cut_multiplier
		
func update_glide(delta: float, grounded: bool) -> void:
	is_gliding = false

	# Only count held input while descending.
	if grounded or velocity.y <= 0.0 or not Input.is_action_pressed("jump"):
		glide_hold_timer = 0.0
		return

	glide_hold_timer = minf(
		glide_hold_timer + delta,
		glide_hold_time
	)

	if glide_hold_timer < glide_hold_time:
		return

	is_gliding = true
	velocity.y = minf(velocity.y, glide_fall_speed)

	# Preserve the normal ascent and only limit downward speed.
	if velocity.y < 0.0:
		return

	is_gliding = true
	velocity.y = minf(velocity.y, glide_fall_speed)
	
	
func update_wall_slide(direction: float) -> void:
	is_wall_sliding = false

	if is_on_floor() or not is_on_wall() or velocity.y <= 0.0:
		return

	var wall_normal := get_wall_normal()

	# The wall normal points away from the wall.
	if direction * wall_normal.x >= 0.0:
		return

	is_wall_sliding = true
	is_gliding = false
	glide_hold_timer = 0.0
	velocity.y = minf(velocity.y, wall_slide_speed)


func update_animation(direction: float) -> void:
	set_wall_slide_visual(is_wall_sliding)

	if not is_on_floor() or velocity.y < 0.0:
		if is_wall_sliding:
			animated_sprite.play("wall_slide")
		elif is_gliding:
			animated_sprite.play("glide")
		elif velocity.y < 0.0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")
	elif direction != 0.0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")


func start_roll() -> void:
	is_gliding = false
	glide_hold_timer = 0.0

	is_rolling = true
	has_air_rolled = true
	roll_direction = signf(visuals.scale.x)

	hit_targets.clear()
	hitbox_refresh_pending = true

	attack_collision.position = ROLL_HITBOX_POSITION

	var rectangle := attack_collision.shape as RectangleShape2D
	rectangle.size = ROLL_HITBOX_SIZE

	set_wall_slide_visual(false)
	animated_sprite.play("roll")


func start_attack() -> void:
	is_gliding = false
	glide_hold_timer = 0.0

	is_attacking = true
	combo_index = 0
	attack_queued = false
	play_combo_attack()


func play_combo_attack() -> void:
	hit_targets.clear()
	hitbox_refresh_pending = true

	attack_collision.position = ATTACK_POSITIONS[combo_index]

	var rectangle := attack_collision.shape as RectangleShape2D
	rectangle.size = ATTACK_SIZES[combo_index]

	animated_sprite.flip_h = false
	animated_sprite.play(ATTACK_ANIMATIONS[combo_index])


func check_attack_hits() -> void:
	# Let physics refresh overlaps after changing the hitbox.
	if hitbox_refresh_pending:
		hitbox_refresh_pending = false
		return

	# Rolls stay active throughout the animation; combo strikes use frame windows.
	if not is_rolling:
		var active_frames := ATTACK_ACTIVE_FRAMES[combo_index]
		var current_frame := animated_sprite.frame

		if current_frame < active_frames.x or current_frame > active_frames.y:
			return

	for target in attack_hitbox.get_overlapping_areas():
		if target in hit_targets:
			continue

		if not target.has_method("take_hit"):
			continue

		# Register the target before applying the hit.
		hit_targets.append(target)
		target.call("take_hit")


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"roll":
		is_rolling = false
		return

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

func set_wall_slide_visual(enabled: bool) -> void:
	animated_sprite.flip_h = enabled
	animated_sprite.position = sprite_base_position

	# Mirror the offset too, so the artwork flips around the Player origin.
	if enabled:
		animated_sprite.position.x = -sprite_base_position.x
