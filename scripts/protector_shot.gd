extends Node2D

# Visible leading edge in the original 140 x 30 sprite frames.
const BLAST_REACH_PIXELS: Array[float] = [48.0, 68.0, 77.0, 97.0, 105.0, 125.0]
const BLAST_FULL_REACH: float = 132.0
const MAX_HIT_QUERY_RESULTS: int = 64

# Clip source pixels at the obstacle without stretching the animation.
const WALL_CLIP_SHADER_CODE: String = """
shader_type canvas_item;
uniform float clip_x = 100000.0;
varying float sprite_x;
void vertex() {
	sprite_x = VERTEX.x;
}
void fragment() {
	if (sprite_x >= clip_x) {
		COLOR.a = 0.0;
	}
}
"""

@export_group("Damage")
@export_range(1, 100, 1) var damage: int = 3

@export_group("World Collision")
@export_flags_2d_physics var world_collision_mask: int = 1

var hit_targets: Array[int] = []
var full_hitbox_size: Vector2
var hitbox_start: Vector2
var hitbox_shape: RectangleShape2D
var wall_distance: float = INF
var trace_start_x: float = 0.0
var source_body: CollisionObject2D
var clip_material: ShaderMaterial

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_collision: CollisionShape2D = $Hitbox/CollisionShape2D


func _ready() -> void:
	# Each shot owns its shape and shader parameters.
	hitbox_shape = hitbox_collision.shape.duplicate() as RectangleShape2D
	hitbox_collision.shape = hitbox_shape
	full_hitbox_size = hitbox_shape.size
	hitbox_start = hitbox_collision.position - Vector2(full_hitbox_size.x * 0.5, 0.0)
	trace_start_x = hitbox_start.x

	var clip_shader := Shader.new()
	clip_shader.code = WALL_CLIP_SHADER_CODE
	clip_material = ShaderMaterial.new()
	clip_material.shader = clip_shader
	animated_sprite.material = clip_material

	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(update_hitbox)
	animated_sprite.stop()
	animated_sprite.play(&"blast")
	animated_sprite.set_frame_and_progress(0, 0.0)
	update_hitbox()


func configure_shot(shooter: CollisionObject2D, shot_transform: Transform2D) -> void:
	global_transform = shot_transform
	source_body = shooter
	# Trace from the player's center so a muzzle beyond a nearby wall cannot bypass it.
	trace_start_x = minf(hitbox.to_local(shooter.global_position).x, hitbox_start.x)
	update_wall_limit()
	update_hitbox()


func _physics_process(_delta: float) -> void:
	update_wall_limit()
	update_hitbox()
	if is_damage_active():
		apply_damage()


func update_wall_limit() -> void:
	# Trace the full visual length, including the harmless smoke at the end.
	var texture := animated_sprite.sprite_frames.get_frame_texture(&"blast", 0)
	var sprite_end := animated_sprite.offset.x + texture.get_width()
	if animated_sprite.centered:
		sprite_end -= texture.get_width() * 0.5
	var visual_end := hitbox.to_local(animated_sprite.to_global(Vector2(sprite_end, 0.0))).x
	var end_x := maxf(hitbox_start.x + full_hitbox_size.x, visual_end)

	var query := PhysicsRayQueryParameters2D.new()
	query.from = hitbox.to_global(Vector2(trace_start_x, hitbox_start.y))
	query.to = hitbox.to_global(Vector2(end_x, hitbox_start.y))
	query.collision_mask = world_collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	if is_instance_valid(source_body):
		query.exclude = [source_body.get_rid()]

	var result := get_world_2d().direct_space_state.intersect_ray(query)
	wall_distance = INF
	clip_material.set_shader_parameter("clip_x", 100000.0)
	if result.is_empty():
		return

	var wall_position := hitbox.to_local(result["position"])
	wall_distance = maxf(wall_position.x - hitbox_start.x, 0.0)
	var clip_position := animated_sprite.to_local(
		hitbox.to_global(Vector2(hitbox_start.x + wall_distance, hitbox_start.y))
	)
	clip_material.set_shader_parameter("clip_x", clip_position.x)


func is_damage_active() -> bool:
	return (
		animated_sprite.animation == &"blast"
		and animated_sprite.frame < BLAST_REACH_PIXELS.size()
		and wall_distance > 0.0
	)


func update_hitbox() -> void:
	var active := is_damage_active()
	if active:
		var reach_ratio := BLAST_REACH_PIXELS[animated_sprite.frame] / BLAST_FULL_REACH
		var width := minf(full_hitbox_size.x * reach_ratio, wall_distance)
		hitbox_shape.size = Vector2(width, full_hitbox_size.y)
		hitbox_collision.position = hitbox_start + Vector2(width * 0.5, 0.0)

	# From frame 6 onward, only harmless smoke remains.
	hitbox_collision.set_deferred("disabled", not active)


func apply_damage() -> void:
	if not is_damage_active():
		return

	# Query the resized shape directly, without waiting for Area2D overlaps.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hitbox_shape
	query.transform = hitbox_collision.global_transform
	query.collision_mask = hitbox.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := get_world_2d().direct_space_state.intersect_shape(
		query, MAX_HIT_QUERY_RESULTS
	)
	for result in results:
		var area := result["collider"] as Area2D
		if area == null:
			continue

		var target := area.get_parent()
		if target == null or not target.has_method("receive_hit"):
			continue

		var target_id := target.get_instance_id()
		if hit_targets.has(target_id):
			continue

		# One impact per enemy for the entire lifetime of this shot.
		hit_targets.append(target_id)
		target.call("receive_hit", damage)


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"blast":
		queue_free()
