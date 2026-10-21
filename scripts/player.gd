extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal died
signal respawned
signal energy_changed(current: int, maximum: int)
signal energy_collected
signal evil_mode_changed(active: bool)

const GOOD_SPRITE_FRAMES: SpriteFrames = preload("res://assets/player/good/good_frames.tres")
const EVIL_SPRITE_FRAMES: SpriteFrames = preload("res://assets/player/evil/evil_frames.tres")

const PROTECTOR_SPRITE_FRAMES: SpriteFrames = preload(
	"res://assets/player/protector/protector_frames.tres"
)
const PROTECTOR_SPRITE_POSITION := Vector2(32.5, -17.5)
const PROTECTOR_BODY_POSITION := Vector2(0.0, -16.0)
const PROTECTOR_UI_OFFSET := Vector2(12.0, -18.0)
# Head movement relative to the first frame of Protector idle.
const PROTECTOR_IDLE_UI_OFFSETS: Array[float] = [
	0.0, 0.0, 0.0, -1.0, -2.0, -3.0,
	-4.0, -4.0, -4.0, -3.0, -2.0, -1.0,
]
# Walk uses the same reference height as Protector idle.
const PROTECTOR_WALK_UI_OFFSETS: Array[float] = [
	-1.0, 0.0, -1.0, -2.0, -3.0, -2.0,
	-1.0, 0.0, -1.0, -2.0, -3.0, -2.0,
]
# Good and Evil share the same head movement, relative to idle frame zero.
const SMALL_IDLE_UI_OFFSETS: Array[float] = [
	0.0, -1.0, -1.0, -1.0, 0.0, 0.0, 1.0, 1.0, 0.0,
]
const SMALL_RUN_UI_OFFSETS: Array[float] = [
	2.0, 1.0, -1.0, 0.0, 2.0, 1.0, -1.0, 0.0,
]
const TRANSFORM_FLASH_FRAME: int = 2

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

const DEATH_DISSOLVE_SHADER: Shader = preload("res://shaders/player_death_dissolve.gdshader")

const WALL_SLIDE_VISUAL_OFFSET := Vector2(-1.0, 0.0)

const ROLL_HITBOX_POSITION := Vector2(0.0, -8.0)
const ROLL_HITBOX_SIZE := Vector2(16.0, 16.0)

const HURTBOX_COLLISION_MASK: int = 4
const MAX_HIT_QUERY_RESULTS: int = 32


@export_group("Health")
@export_range(1, 100, 1) var max_health: int = 5
@export_range(0.0, 3.0, 0.05) var hurt_invulnerability_time: float = 0.8

@export_range(0.01, 0.5, 0.01) var hurt_flash_interval: float = 0.08

@export_group("Knockback")
@export_range(0.0, 300.0, 1.0) var hurt_knockback_speed: float = 100.0
@export_range(0.0, 300.0, 1.0) var hurt_knockback_jump_speed: float = 100.0
@export_range(0.0, 1.0, 0.01) var hurt_control_lock_time: float = 0.2

@export_group("Respawn")
@export var auto_respawn: bool = true
@export_range(0.0, 2.0, 0.05) var instant_death_respawn_delay: float = 0.3
@export_range(1.0, 15.0, 0.5) var death_fall_timeout: float = 5.0
@export_range(0.0, 5.0, 0.05) var respawn_delay: float = 0.8
@export_range(0.0, 5.0, 0.05) var respawn_invulnerability_time: float = 1.0

@export_group("Death Effect")
@export_range(0.0, 3.0, 0.1) var death_dissolve_delay: float = 1.0
@export_range(0.0, 2.0, 0.05) var death_dissolve_duration: float = 0.5

@export_group("Transformation Energy")
@export_range(1, 1000, 1) var max_energy: int = 20

@export_group("Evil Mode")
@export_range(0.1, 120.0, 0.1) var evil_duration: float = 10.0

@export_group("Protector")
@export_range(1.0, 300.0, 1.0) var protector_move_speed: float = 55.0

@export_group("Transformation Flash")
@export_range(0.5, 4.0, 0.1) var transform_flash_scale: float = 1.5
@export_range(0.0, 0.3, 0.01) var transform_flash_hold: float = 0.06
@export_range(0.01, 0.3, 0.01) var transform_flash_fade: float = 0.1

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

@export_group("Wall Movement")
@export_range(1.0, 300.0, 1.0) var wall_slide_speed: float = 40.0
@export var wall_jump_speed: float = 100.0
@export_range(0.01, 0.5, 0.01) var wall_jump_control_delay: float = 0.12

@export_group("Roll")
@export var roll_speed: float = 180.0
@export_range(1, 100, 1) var roll_damage: int = 1

@export_group("Combat")
@export_range(1, 100, 1) var attack_damage: int = 1


var is_protector: bool = false
var is_transforming: bool = false
var is_reverting: bool = false
var revert_animation_finished: bool = false
var transform_flash_timer: float = 0.0
var transform_flash: Sprite2D
var small_body_shape: Shape2D
var small_hurtbox_shape: Shape2D
var small_body_position: Vector2
var small_hurtbox_position: Vector2
var small_ui_position: Vector2
var protector_shape: CapsuleShape2D

var is_evil: bool = false
var evil_timer: float = 0.0
var current_energy: int = 0
var current_health: int = 0
var hurt_invulnerability_timer: float = 0.0

var hurt_control_timer: float = 0.0
var hurt_flash_timer: float = 0.0
var is_dead: bool = false
var is_environmental_death: bool = false
var saved_camera_process_mode: ProcessMode = Node.PROCESS_MODE_INHERIT
var death_dissolve_material: ShaderMaterial
var death_dissolve_delay_timer: float = 0.0
var death_dissolve_elapsed: float = 0.0
var death_dissolve_finished: bool = false
var death_animation_finished: bool = false
var death_fall_timer: float = 0.0
var respawn_timer: float = 0.0
var respawn_position: Vector2
var respawn_facing: float = 1.0

var jump_coyote_timer: float = 0.0
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
var attack_combo_index: int = 0
var attack_queued: bool = false

var attack_hit_phase: int = -1
var attack_hit_targets: Array[int] = []


@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_collision: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var player_ui: Node2D = $UI
@onready var player_camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var sprite_base_modulate: Color = animated_sprite.modulate
@onready var sprite_base_position: Vector2 = animated_sprite.position
@onready var attack_collision: CollisionShape2D = (
	$Visuals/AttackHitbox/CollisionShape2D
)


func _ready() -> void:
	small_body_shape = body_collision.shape
	small_hurtbox_shape = hurtbox_collision.shape
	small_body_position = body_collision.position
	small_hurtbox_position = hurtbox_collision.position
	small_ui_position = player_ui.position
	protector_shape = CapsuleShape2D.new()
	protector_shape.radius = 12.0
	protector_shape.height = 32.0

	# A separate flash can cover the switch to the larger sprite.
	transform_flash = Sprite2D.new()
	transform_flash.name = &"TransformFlash"
	transform_flash.position = sprite_base_position
	transform_flash.z_index = 1
	transform_flash.hide()
	visuals.add_child(transform_flash)

	animated_sprite.sprite_frames = GOOD_SPRITE_FRAMES
	animated_sprite.play(&"idle")

	# Keep shader parameters independent for each player instance.
	death_dissolve_material = ShaderMaterial.new()
	death_dissolve_material.shader = DEATH_DISSOLVE_SHADER
	animated_sprite.material = death_dissolve_material
	reset_death_dissolve()

	current_health = max_health
	respawn_position = global_position
	respawn_facing = signf(visuals.scale.x)

	# Each player instance owns its collision shape.
	attack_collision.shape = attack_collision.shape.duplicate()
	attack_collision.set_deferred("disabled", true)

	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_player_visual_changed)
	animated_sprite.animation_changed.connect(_on_player_visual_changed)
	health_changed.emit(current_health, max_health)
	energy_changed.emit(current_energy, max_energy)


func _physics_process(delta: float) -> void:
	if is_dead:
		update_death_movement(delta)
		return

	update_evil_mode(delta)

	hurt_invulnerability_timer = maxf(hurt_invulnerability_timer - delta, 0.0)
	hurt_flash_timer += delta
	update_hurt_visual()

	# Damage recovery takes priority over attacks, rolling and movement.
	if hurt_control_timer > 0.0:
		hurt_control_timer = maxf(hurt_control_timer - delta, 0.0)
		if not is_on_floor() or velocity.y < 0.0:
			velocity += get_gravity() * delta
		move_and_slide()
		update_animation(0.0)
		return

	if Input.is_action_just_pressed("transform"):
		try_start_protector_transform()

	if is_transforming:
		update_protector_transform(delta)
		return

	if is_protector:
		update_protector_movement(delta)
		return

	is_wall_sliding = false
	wall_jump_timer = maxf(wall_jump_timer - delta, 0.0)

	var grounded := is_on_floor() and velocity.y >= 0.0

	if grounded:
		jump_coyote_timer = jump_coyote_time
		has_air_rolled = false
		wall_jump_timer = 0.0
		wall_jump_direction = 0.0
		has_wall_jump_momentum = false
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
	update_wall_slide(direction, grounded)

	move_and_slide()

	# Clear wall slide when landing or leaving the wall.
	if is_on_floor() or not is_on_wall():
		is_wall_sliding = false

	update_animation(direction)
	update_attack_hitbox()
	check_attack_hits()


# Jump

func update_jump(delta: float, grounded: bool) -> bool:
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	var jump_pressed := Input.is_action_just_pressed("jump")

	if jump_pressed:
		jump_buffer_timer = jump_buffer_time

	var wants_to_jump := jump_pressed or jump_buffer_timer > 0.0
	var can_ground_jump := grounded or jump_coyote_timer > 0.0
	var can_wall_jump := (
		not grounded
		and is_on_wall()
		and wall_jump_timer <= 0.0
	)

	var jumped_this_frame := false

	if wants_to_jump and not is_attacking:
		if can_wall_jump:
			wall_jump_direction = signf(get_wall_normal().x)
			wall_jump_timer = wall_jump_control_delay
			has_wall_jump_momentum = true

			velocity.x = wall_jump_direction * wall_jump_speed
			velocity.y = - jump_speed
			visuals.scale.x = wall_jump_direction

			jumped_this_frame = true
		elif can_ground_jump:
			velocity.y = - jump_speed
			jumped_this_frame = true

	if jumped_this_frame:
		jump_coyote_timer = 0.0
		jump_buffer_timer = 0.0
		glide_hold_timer = 0.0
		is_gliding = false
		is_wall_sliding = false

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


# Glide

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


# Horizontal movement and wall slide

func update_horizontal_movement(direction: float, grounded: bool) -> void:
	if is_attacking:
		jump_buffer_timer = 0.0
		if grounded:
			velocity.x = 0.0
		return

	# Gliding restores horizontal control after a wall jump.
	if is_gliding:
		wall_jump_timer = 0.0
		wall_jump_direction = 0.0
		has_wall_jump_momentum = false

	# Preserve the initial push away from the wall.
	if wall_jump_timer > 0.0:
		velocity.x = wall_jump_direction * wall_jump_speed
		return

	# A direction held toward the previous wall must not cancel the rebound.
	var holding_previous_direction := (
		not grounded
		and wall_jump_direction != 0.0
		and direction * wall_jump_direction < 0.0
	)

	if holding_previous_direction:
		velocity.x = wall_jump_direction * wall_jump_speed
		visuals.scale.x = wall_jump_direction
		return

	wall_jump_direction = 0.0

	# Releasing input preserves momentum; steering again restores control.
	if has_wall_jump_momentum and not grounded:
		if direction == 0.0:
			return
		has_wall_jump_momentum = false

	velocity.x = direction * move_speed

	if direction != 0.0:
		visuals.scale.x = signf(direction)


func update_wall_slide(direction: float, grounded: bool) -> void:
	if grounded or is_attacking or is_rolling:
		return

	if wall_jump_timer > 0.0:
		return

	if not is_on_wall() or velocity.y <= 0.0:
		return

	var wall_normal := get_wall_normal()
	var pushing_into_wall := direction * wall_normal.x < 0.0

	if not pushing_into_wall:
		return

	is_wall_sliding = true
	is_gliding = false
	glide_hold_timer = 0.0
	has_wall_jump_momentum = false

	velocity.y = minf(velocity.y, wall_slide_speed)


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
	set_wall_slide_visual(false)
	is_rolling = true
	roll_direction = signf(visuals.scale.x)

	wall_jump_timer = 0.0
	wall_jump_direction = 0.0
	has_wall_jump_momentum = false

	if air_roll:
		has_air_rolled = true

	is_gliding = false
	is_wall_sliding = false
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
	is_wall_sliding = false

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
	set_wall_slide_visual(false)
	is_attacking = true
	is_air_attack = air_attack
	attack_combo_index = 0
	attack_queued = false

	is_gliding = false
	is_wall_sliding = false
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

		if target == null or target == self or not target.has_method("receive_hit"):
			continue

		var target_id := target.get_instance_id()

		if attack_hit_targets.has(target_id):
			continue

		# Each target can receive damage once per impact.
		attack_hit_targets.append(target_id)
		target.call("receive_hit", damage)


# Animation

func update_animation(direction: float) -> void:
	if is_transforming:
		return

	if is_protector:
		animated_sprite.position = PROTECTOR_SPRITE_POSITION
		animated_sprite.flip_h = false
		if is_on_floor() and direction != 0.0:
			animated_sprite.play(&"walk")
		else:
			animated_sprite.play(&"idle")
		return

	set_wall_slide_visual(is_wall_sliding and not is_attacking and not is_rolling)

	if is_attacking or is_rolling:
		return

	if not is_on_floor():
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
	if is_protector:
		animated_sprite.flip_h = false
		animated_sprite.position = PROTECTOR_SPRITE_POSITION
		return

	animated_sprite.flip_h = enabled
	animated_sprite.position = sprite_base_position

	if enabled:
		animated_sprite.position.x = - sprite_base_position.x
		animated_sprite.position += WALL_SLIDE_VISUAL_OFFSET


func _on_animation_finished() -> void:
	if is_dead:
		if animated_sprite.animation == &"death":
			death_animation_finished = true
		return

	if is_reverting and animated_sprite.animation == &"transform":
		revert_animation_finished = true
		return

	if hurt_control_timer > 0.0 or is_transforming:
		return

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

# Health and damage

func receive_fatal_hit(
	_source_position: Vector2 = Vector2.INF,
	death_animation: bool = false
) -> void:
	if is_environmental_death:
		return

	# A death zone also takes over a body falling after a combat death.
	var was_dead := is_dead
	var applied_damage := current_health
	reset_death_dissolve()
	is_dead = true
	is_environmental_death = true
	current_health = 0
	reset_action_state()
	velocity = Vector2.ZERO
	hurt_control_timer = 0.0
	hurt_invulnerability_timer = 0.0
	hurt_flash_timer = 0.0
	death_fall_timer = 0.0
	death_animation_finished = true
	respawn_timer = instant_death_respawn_delay
	animated_sprite.stop()
	animated_sprite.modulate = sprite_base_modulate

	if (
		death_animation
		and animated_sprite.sprite_frames.has_animation(&"death")
		and animated_sprite.sprite_frames.get_frame_count(&"death") > 0
		and not animated_sprite.sprite_frames.get_animation_loop(&"death")
	):
		death_animation_finished = false
		show()
		visuals.show()
		animated_sprite.play(&"death")
	elif death_animation and is_protector:
		# Use the Protector's final pose until its death animation is available.
		show()
		visuals.show()
	else:
		# Invalid or looping death animations fall back to instant disappearance.
		death_dissolve_finished = true
		hide()

	# Freeze camera updates without disabling the active camera.
	if player_camera != null:
		saved_camera_process_mode = player_camera.process_mode
		player_camera.process_mode = Node.PROCESS_MODE_DISABLED

	health_changed.emit(current_health, max_health)
	if applied_damage > 0:
		damaged.emit(applied_damage)
	if not was_dead:
		died.emit()


func receive_hit(damage: int, source_position: Vector2 = Vector2.INF) -> void:
	if damage <= 0 or is_dead or is_rolling or hurt_invulnerability_timer > 0.0:
		return

	var applied_damage := mini(damage, current_health)
	current_health -= applied_damage
	reset_action_state()

	# Without a source position, recoil opposite to the facing direction.
	var knockback_direction := -signf(visuals.scale.x)
	if source_position != Vector2.INF:
		var separation := global_position.x - source_position.x
		if not is_zero_approx(separation):
			knockback_direction = signf(separation)

	velocity = Vector2(
		knockback_direction * hurt_knockback_speed,
		- hurt_knockback_jump_speed
	)

	if current_health <= 0:
		die()
	else:
		hurt_control_timer = hurt_control_lock_time
		hurt_invulnerability_timer = hurt_invulnerability_time
		hurt_flash_timer = 0.0

		animated_sprite.play(&"idle" if is_protector else &"fall")
		update_hurt_visual()

	health_changed.emit(current_health, max_health)
	damaged.emit(applied_damage)
	if is_dead:
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or is_dead or current_health >= max_health:
		return

	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func update_hurt_visual() -> void:
	animated_sprite.modulate = sprite_base_modulate
	if hurt_invulnerability_timer <= 0.0:
		return

	var flash_index := int(hurt_flash_timer / hurt_flash_interval)
	if flash_index % 2 == 0:
		animated_sprite.modulate.a = sprite_base_modulate.a * 0.3


func reset_action_state() -> void:
	var was_reverting := is_reverting
	is_reverting = false
	revert_animation_finished = false
	is_transforming = false
	transform_flash_timer = 0.0
	if is_instance_valid(transform_flash):
		transform_flash.hide()
	# Damage may interrupt the return, but must not leave Evil active at zero.
	if was_reverting:
		finish_evil_mode(true)
	finish_attack()
	finish_roll()
	is_gliding = false
	is_wall_sliding = false
	glide_hold_timer = 0.0
	jump_buffer_timer = 0.0
	jump_coyote_timer = 0.0
	wall_jump_timer = 0.0
	wall_jump_direction = 0.0
	has_wall_jump_momentum = false
	set_wall_slide_visual(false)


func die() -> void:
	reset_death_dissolve()
	is_dead = true
	death_fall_timer = 0.0
	hurt_control_timer = 0.0
	hurt_invulnerability_timer = 0.0
	death_animation_finished = false
	respawn_timer = respawn_delay
	animated_sprite.modulate = sprite_base_modulate
	visuals.show()

	if (
		animated_sprite.sprite_frames.has_animation(&"death")
		and animated_sprite.sprite_frames.get_frame_count(&"death") > 0
		and not animated_sprite.sprite_frames.get_animation_loop(&"death")
	):
		animated_sprite.play(&"death")
	elif is_protector:
		# Until a Protector death animation is imported, hold its final pose.
		animated_sprite.pause()
		death_animation_finished = true
	else:
		# Keep respawning functional if the animation has not been configured.
		animated_sprite.stop()
		visuals.hide()
		death_animation_finished = true
		death_dissolve_finished = true
		push_warning("Player: configure a non-looping death animation.")


func update_death_movement(delta: float) -> void:
	if is_environmental_death:
		# Stay in place through the animation and dissolution.
		if not death_animation_finished:
			return
		if not update_death_dissolve(delta):
			return
		hide()
		if auto_respawn:
			respawn_timer = maxf(respawn_timer - delta, 0.0)
			if respawn_timer <= 0.0:
				respawn()
		return

	# Normal combat deaths keep gravity and recoil until landing.
	if is_on_floor() and velocity.y >= 0.0:
		velocity.x = 0.0
	velocity += get_gravity() * delta
	move_and_slide()

	if is_on_floor():
		velocity.x = 0.0
		death_fall_timer = 0.0
	else:
		death_fall_timer += delta
		respawn_timer = respawn_delay

	# Retain the recovery safeguard for bottomless falls.
	if auto_respawn and death_fall_timer >= death_fall_timeout:
		respawn()
		return

	if is_on_floor() and death_animation_finished:
		if not update_death_dissolve(delta):
			return
		if auto_respawn:
			respawn_timer = maxf(respawn_timer - delta, 0.0)
			if respawn_timer <= 0.0:
				respawn()


# Death dissolution

func reset_death_dissolve() -> void:
	death_dissolve_delay_timer = death_dissolve_delay
	death_dissolve_elapsed = 0.0
	death_dissolve_finished = false
	death_dissolve_material.set_shader_parameter("dissolve_amount", 0.0)
	death_dissolve_material.set_shader_parameter("noise_seed", randf_range(0.0, 1000.0))


func update_death_dissolve(delta: float) -> bool:
	if death_dissolve_finished:
		return true

	# Hold the final death frame before dissolving.
	if death_dissolve_delay_timer > 0.0:
		death_dissolve_delay_timer = maxf(death_dissolve_delay_timer - delta, 0.0)
		return false

	death_dissolve_elapsed += delta
	var progress := 1.0
	if death_dissolve_duration > 0.0:
		progress = clampf(death_dissolve_elapsed / death_dissolve_duration, 0.0, 1.0)
	death_dissolve_material.set_shader_parameter("dissolve_amount", progress)

	if progress >= 1.0:
		death_dissolve_finished = true
		visuals.hide()

	# Start the respawn countdown on the next physics tick.
	return false


func set_respawn_position(new_position: Vector2) -> void:
	# A level or checkpoint can update the spawn without changing this script.
	respawn_position = new_position


func respawn() -> void:
	# Keep the Evil death animation, but always respawn in Good form.
	if is_evil:
		finish_evil_mode(true)
	reset_death_dissolve()
	var restore_camera := is_environmental_death
	is_environmental_death = false
	reset_action_state()
	global_position = respawn_position
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	current_health = max_health
	is_dead = false
	death_fall_timer = 0.0
	death_animation_finished = false
	has_air_rolled = false
	hurt_control_timer = 0.0
	respawn_timer = 0.0
	hurt_invulnerability_timer = respawn_invulnerability_time
	hurt_flash_timer = 0.0
	visuals.scale.x = respawn_facing
	visuals.show()
	animated_sprite.play("idle")
	update_hurt_visual()
	health_changed.emit(current_health, max_health)
	respawned.emit()
	show()

	if restore_camera and player_camera != null:
		player_camera.process_mode = saved_camera_process_mode


# Transformation energy

func collect_energy(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	# Gems cannot refill a stored charge or extend Protector mode.
	if is_evil:
		energy_collected.emit()
		return

	var previous_energy := current_energy
	current_energy = mini(current_energy + amount, max_energy)

	if current_energy != previous_energy:
		energy_changed.emit(current_energy, max_energy)

	if current_energy >= max_energy:
		start_evil_mode()

	energy_collected.emit()


# Evil transformation

func start_evil_mode() -> void:
	if is_dead or is_evil or current_energy < max_energy:
		return

	is_evil = true
	evil_timer = evil_duration
	set_player_sprite_frames(EVIL_SPRITE_FRAMES)
	evil_mode_changed.emit(true)


func update_evil_mode(delta: float) -> void:
	# Keep the full charge until the player actually becomes Protector.
	if not is_evil or not is_protector or is_reverting:
		return

	evil_timer = maxf(evil_timer - delta, 0.0)
	if evil_timer <= 0.0:
		finish_evil_mode()


func finish_evil_mode(force_immediate: bool = false) -> void:
	if not is_evil:
		return

	if not force_immediate and not is_dead:
		if is_reverting:
			return
		if is_protector:
			start_protector_return()
			return

	is_reverting = false
	revert_animation_finished = false
	if is_protector or is_transforming:
		restore_small_form()
	is_evil = false
	evil_timer = 0.0
	current_energy = 0
	set_player_sprite_frames(GOOD_SPRITE_FRAMES)
	energy_changed.emit(current_energy, max_energy)
	evil_mode_changed.emit(false)


func set_player_sprite_frames(frames: SpriteFrames) -> void:
	# Preserve the current action and frame so an attack is not restarted.
	var animation_name := animated_sprite.animation
	var frame_index := animated_sprite.frame
	var frame_progress := animated_sprite.frame_progress
	var was_playing := animated_sprite.is_playing()

	animated_sprite.sprite_frames = frames

	if not frames.has_animation(animation_name):
		animation_name = &"idle"
		frame_index = 0
		frame_progress = 0.0

	animated_sprite.play(animation_name)
	var last_frame := maxi(frames.get_frame_count(animation_name) - 1, 0)
	animated_sprite.set_frame_and_progress(
		clampi(frame_index, 0, last_frame), frame_progress
	)

	if not was_playing:
		animated_sprite.pause()


# Protector transformation

func can_fit_protector() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = protector_shape
	query.transform = global_transform * Transform2D(0.0, PROTECTOR_BODY_POSITION)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func try_start_protector_transform() -> void:
	if (
		is_dead or not is_evil or is_protector or is_transforming
		or is_attacking or is_rolling or hurt_control_timer > 0.0
		or not is_on_floor() or velocity.y < 0.0
	):
		return

	if (
		not EVIL_SPRITE_FRAMES.has_animation(&"transform")
		or EVIL_SPRITE_FRAMES.get_frame_count(&"transform") <= TRANSFORM_FLASH_FRAME
		or EVIL_SPRITE_FRAMES.get_animation_loop(&"transform")
	):
		push_warning("Player: configure three non-looping transform frames in Evil.")
		return

	if not can_fit_protector():
		return

	reset_action_state()
	is_transforming = true
	velocity = Vector2.ZERO
	animated_sprite.play(&"transform")


func update_protector_transform(delta: float) -> void:
	velocity.x = 0.0
	velocity += get_gravity() * delta
	move_and_slide()

	if is_reverting:
		update_transform_flash(delta)
		if revert_animation_finished and transform_flash_timer <= 0.0:
			finish_evil_mode(true)
		return

	if is_protector:
		update_transform_flash(delta)
		if transform_flash_timer <= 0.0:
			is_transforming = false
		return

	# Recheck clearance at the actual switch, in case the scenery moved.
	if not is_on_floor():
		cancel_protector_transform()
		return

	if animated_sprite.animation == &"transform" and animated_sprite.frame >= TRANSFORM_FLASH_FRAME:
		if can_fit_protector():
			enter_protector_form()
		else:
			cancel_protector_transform()


func enter_protector_form() -> void:
	# Start the full duration only after the transformation succeeds.
	evil_timer = evil_duration
	is_protector = true
	body_collision.shape = protector_shape
	body_collision.position = PROTECTOR_BODY_POSITION
	hurtbox_collision.set_deferred("shape", protector_shape)
	hurtbox_collision.set_deferred("position", PROTECTOR_BODY_POSITION)
	update_player_ui_position()

	start_transform_flash()

	animated_sprite.sprite_frames = PROTECTOR_SPRITE_FRAMES
	animated_sprite.position = PROTECTOR_SPRITE_POSITION
	animated_sprite.flip_h = false
	animated_sprite.play(&"idle")


func cancel_protector_transform() -> void:
	is_transforming = false
	transform_flash.hide()
	update_animation(0.0)


func update_protector_movement(delta: float) -> void:
	# Protector can walk and fall, but has no jump, glide, roll or attacks yet.
	velocity += get_gravity() * delta

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * protector_move_speed

	if direction != 0.0:
		visuals.scale.x = signf(direction)

	update_player_ui_position()
	move_and_slide()
	update_animation(direction)


func restore_small_form() -> void:
	is_protector = false
	reset_action_state()
	body_collision.shape = small_body_shape
	body_collision.position = small_body_position
	hurtbox_collision.set_deferred("shape", small_hurtbox_shape)
	hurtbox_collision.set_deferred("position", small_hurtbox_position)
	player_ui.position = small_ui_position
	animated_sprite.position = sprite_base_position
	animated_sprite.flip_h = false

func update_player_ui_position() -> void:
	var ui_offset := Vector2.ZERO
	var frame_offsets: Array[float] = []

	if is_protector:
		ui_offset = Vector2(
			PROTECTOR_UI_OFFSET.x * signf(visuals.scale.x),
			PROTECTOR_UI_OFFSET.y
		)

		if animated_sprite.sprite_frames == PROTECTOR_SPRITE_FRAMES:
			match animated_sprite.animation:
				&"idle":
					frame_offsets = PROTECTOR_IDLE_UI_OFFSETS
				&"walk":
					frame_offsets = PROTECTOR_WALK_UI_OFFSETS
	elif (
		animated_sprite.sprite_frames == GOOD_SPRITE_FRAMES
		or animated_sprite.sprite_frames == EVIL_SPRITE_FRAMES
	):
		match animated_sprite.animation:
			&"idle":
				frame_offsets = SMALL_IDLE_UI_OFFSETS

	if animated_sprite.frame < frame_offsets.size():
		ui_offset.y += frame_offsets[animated_sprite.frame]

	player_ui.position = small_ui_position + ui_offset


func _on_player_visual_changed() -> void:
	# Follow the displayed frame, independently of the animation speed.
	update_player_ui_position()


# Shared flash and reverse transition

func start_transform_flash() -> void:
	transform_flash.texture = EVIL_SPRITE_FRAMES.get_frame_texture(
		&"transform", TRANSFORM_FLASH_FRAME
	)
	# Scale around the player's feet, preserving whole source pixels.
	var flash_scale := float(transform_flash_scale)
	transform_flash.scale = Vector2.ONE * flash_scale
	transform_flash.position = sprite_base_position * flash_scale
	transform_flash.modulate = Color.WHITE
	transform_flash_timer = transform_flash_hold + transform_flash_fade
	transform_flash.show()


func update_transform_flash(delta: float) -> void:
	transform_flash_timer = maxf(transform_flash_timer - delta, 0.0)
	transform_flash.modulate.a = clampf(
		transform_flash_timer / maxf(transform_flash_fade, 0.001), 0.0, 1.0
	)
	if transform_flash_timer <= 0.0:
		transform_flash.hide()


func start_protector_return() -> void:
	# Reverse the three transition frames beneath the enlarged flash.
	restore_small_form()
	is_transforming = true
	is_reverting = true
	revert_animation_finished = false
	velocity.x = 0.0
	evil_timer = 0.0
	current_energy = 0
	energy_changed.emit(current_energy, max_energy)

	animated_sprite.sprite_frames = EVIL_SPRITE_FRAMES
	animated_sprite.play_backwards(&"transform")
	start_transform_flash()
