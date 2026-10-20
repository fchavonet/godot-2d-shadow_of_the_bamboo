extends Area2D

@export_group("Damage")
@export var enabled: bool = true
@export var instant_kill: bool = false
@export var death_animation: bool = false
@export_range(1, 1000, 1) var damage: int = 1


func _physics_process(_delta: float) -> void:
	if not enabled:
		return

	var hit_targets: Array[int] = []

	for area in get_overlapping_areas():
		var target := area.get_parent()

		if target == null or target == get_parent():
			continue

		var target_id := target.get_instance_id()

		if hit_targets.has(target_id):
			continue

		hit_targets.append(target_id)

		if instant_kill:
			if target.has_method("receive_fatal_hit"):
				target.call("receive_fatal_hit", global_position, death_animation)
		elif target.has_method("receive_hit"):
			target.call("receive_hit", damage, global_position)
