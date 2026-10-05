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
	Vector2i(0, 4),
]

const JAB_HIT_FRAMES: Array[int] = [0, 2, 4]
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
@export var wall_jump_speed: float = 150.0
@export_range(0.01, 0.5) var wall_jump_control_delay: float = 0.12
@export_range(1, 100) var max_health: int = 5
@export_range(0.1, 3.0) var invulnerability_duration: float = 1.0
@export var knockback_speed: float = 120.0
@export var knockback_lift: float = 120.0
@export_range(0.05, 1.0) var hurt_duration: float = 0.18

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var glide_hold_timer: float = 0.0
var is_gliding: bool = false

var is_wall_sliding: bool = false
var wall_jump_timer: float = 0.0
var wall_jump_direction: float = 0.0
var has_wall_jump_momentum: bool = false

var is_rolling: bool = false
var roll_direction: float = 1.0
var has_air_rolled: bool = false

var is_attacking: bool = false
var is_air_attack: bool = false
var combo_index: int = 0
var attack_queued: bool = false
var hit_targets: Array[Area2D] = []
var last_jab_hit_frame: int = -1
var hitbox_refresh_pending: bool = false
var invulnerability_timer: float = 0.0
var hurt_timer: float = 0.0

@onready var health: int = max_health
@onready var visuals: Node2D = $Visuals
@onready var base_visual_alpha: float = visuals.modulate.a
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var sprite_base_position: Vector2 = animated_sprite.position
@onready var attack_hitbox: Area2D = $Visuals/AttackHitbox
@onready var attack_collision: CollisionShape2D = $Visuals/AttackHitbox/CollisionShape2D


func _ready() -> void:
	# Keep shape changes local to this player instance.
	attack_collision.shape = attack_collision.shape.duplicate()
	animated_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	update_invulnerability(delta)

	is_wall_sliding = false
	wall_jump_timer = maxf(wall_jump_timer - delta, 0.0)

	# Buffered jumps can leave the previous floor contact valid until movement.
	var grounded := is_on_floor() and velocity.y >= 0.0

	if grounded:
		coyote_timer = coyote_time
		has_air_rolled = false
		wall_jump_timer = 0.0
		wall_jump_direction = 0.0
		has_wall_jump_momentum = false
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
		velocity += get_gravity() * delta
		
	if hurt_timer > 0.0:
		hurt_timer = maxf(hurt_timer - delta, 0.0)
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		move_and_slide()
		update_animation(0.0)
		return

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

	if Input.is_action_just_pressed("attack"):
		if not is_attacking:
			start_attack(not grounded)
		elif (
			grounded
			and not is_air_attack
			and combo_index < ATTACK_ANIMATIONS.size() - 1
		):
			attack_queued = true

	if is_attacking:
		# Preserve horizontal momentum while airborne.
		if grounded:
			velocity.x = 0.0

		# Keep variable jump height during attacks.
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= jump_cut_multiplier

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

	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			perform_jump()
		elif not grounded and is_on_wall() and wall_jump_timer <= 0.0:
			perform_wall_jump()

	update_glide(delta, grounded)

	var direction := Input.get_axis("move_left", "move_right")

	if wall_jump_timer > 0.0:
		direction = wall_jump_direction
	else:
		var holding_previous_direction := (
			wall_jump_direction != 0.0
			and direction * wall_jump_direction < 0.0
		)

		if holding_previous_direction:
			# Prevent the held input from cancelling the rebound.
			direction = wall_jump_direction
			velocity.x = direction * wall_jump_speed
		else:
			wall_jump_direction = 0.0

			# Preserve rebound momentum until the player steers again.
			if direction != 0.0 or not has_wall_jump_momentum:
				has_wall_jump_momentum = false
				velocity.x = direction * move_speed

		if direction != 0.0:
			visuals.scale.x = signf(direction)

	update_wall_slide(direction)
	move_and_slide()

	# Consume buffered input when movement finds a new floor or wall contact.
	if jump_buffer_timer > 0.0:
		if not grounded and is_on_floor():
			perform_jump()
		elif not is_on_floor() and is_on_wall() and wall_jump_timer <= 0.0:
			perform_wall_jump()

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


func perform_wall_jump() -> void:
	wall_jump_direction = signf(get_wall_normal().x)

	perform_jump()
	velocity.x = wall_jump_direction * wall_jump_speed
	wall_jump_timer = wall_jump_control_delay
	has_wall_jump_momentum = true

	is_wall_sliding = false
	is_gliding = false
	glide_hold_timer = 0.0

	visuals.scale.x = wall_jump_direction
	set_wall_slide_visual(false)


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


func update_wall_slide(direction: float) -> void:
	is_wall_sliding = false

	if wall_jump_timer > 0.0:
		return

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


func start_roll() -> void:
	has_wall_jump_momentum = false
	wall_jump_direction = 0.0
	wall_jump_timer = 0.0

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


func start_attack(from_air: bool) -> void:
	is_gliding = false
	glide_hold_timer = 0.0

	is_attacking = true
	# Landing must not turn an airborne strike into a combo.
	is_air_attack = from_air
	combo_index = 0
	attack_queued = false
	play_combo_attack()


func play_combo_attack() -> void:
	last_jab_hit_frame = -1
	hit_targets.clear()
	hitbox_refresh_pending = true

	attack_collision.position = ATTACK_POSITIONS[combo_index]

	var rectangle := attack_collision.shape as RectangleShape2D
	rectangle.size = ATTACK_SIZES[combo_index]

	set_wall_slide_visual(false)
	animated_sprite.play(ATTACK_ANIMATIONS[combo_index])


func check_attack_hits() -> void:
	# Let physics refresh overlaps after changing the hitbox.
	if hitbox_refresh_pending:
		hitbox_refresh_pending = false
		return

	if not is_rolling:
		var active_frames := ATTACK_ACTIVE_FRAMES[combo_index]
		var current_frame := animated_sprite.frame

		if current_frame < active_frames.x or current_frame > active_frames.y:
			return

		if ATTACK_ANIMATIONS[combo_index] == &"jabs":
			if current_frame not in JAB_HIT_FRAMES:
				return

			# Each jab can hit a target once, even across multiple physics ticks.
			if current_frame != last_jab_hit_frame:
				last_jab_hit_frame = current_frame
				hit_targets.clear()

	for target in attack_hitbox.get_overlapping_areas():
		if target in hit_targets:
			continue

		if not target.has_method("take_hit"):
			continue

		hit_targets.append(target)
		target.call("take_hit")


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


func set_wall_slide_visual(enabled: bool) -> void:
	animated_sprite.flip_h = enabled
	animated_sprite.position = sprite_base_position

	# Mirror the offset too, so the artwork flips around the Player origin.
	if enabled:
		animated_sprite.position.x = -sprite_base_position.x


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"roll":
		is_rolling = false
		return

	if not is_attacking:
		return

	if animated_sprite.animation != ATTACK_ANIMATIONS[combo_index]:
		return

	if (
		attack_queued
		and not is_air_attack
		and combo_index < ATTACK_ANIMATIONS.size() - 1
	):
		attack_queued = false
		combo_index += 1
		play_combo_attack()
	else:
		is_attacking = false
		is_air_attack = false
		combo_index = 0
		attack_queued = false
		

func take_damage(amount: int, source_position: Vector2) -> void:
	if amount <= 0 or health <= 0 or invulnerability_timer > 0.0:
		return

	health = maxi(health - amount, 0)
	print("Player health: %d/%d" % [health, max_health])

	if health == 0:
		print("Player defeated")
		return

	invulnerability_timer = invulnerability_duration
	update_invulnerability(0.0)
	apply_knockback(source_position)
	
	
func apply_knockback(source_position: Vector2) -> void:
	var push_direction := signf(global_position.x - source_position.x)

	# Fall back to backward knockback when both centers are aligned.
	if is_zero_approx(push_direction):
		push_direction = -signf(visuals.scale.x)

	# Cancel the current action and any queued combo strike.
	is_attacking = false
	is_air_attack = false
	attack_queued = false
	combo_index = 0
	is_rolling = false
	hit_targets.clear()
	last_jab_hit_frame = -1
	hitbox_refresh_pending = false

	is_gliding = false
	glide_hold_timer = 0.0
	is_wall_sliding = false
	wall_jump_timer = 0.0
	wall_jump_direction = 0.0
	has_wall_jump_momentum = false

	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	hurt_timer = hurt_duration

	velocity = Vector2(
		push_direction * knockback_speed,
		-knockback_lift
	)

	update_animation(0.0)


func update_invulnerability(delta: float) -> void:
	if invulnerability_timer <= 0.0:
		return

	invulnerability_timer = maxf(invulnerability_timer - delta, 0.0)

	var alpha_factor: float = 1.0

	if invulnerability_timer > 0.0:
		var elapsed := invulnerability_duration - invulnerability_timer

		# Alternate opacity every 0.08 seconds while protected.
		if int(elapsed / 0.08) % 2 == 0:
			alpha_factor = 0.35

	visuals.modulate.a = base_visual_alpha * alpha_factor
