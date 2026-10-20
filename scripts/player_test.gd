extends Node2D

@export_group("Test Dummy")
@export_range(0.1, 30.0, 0.1) var dummy_respawn_delay: float = 3.0

var dummy_template: Node2D
var respawn_timer: Timer

@onready var training_dummy: Node2D = $TrainingDummy


func _ready() -> void:
	# Preserve the original placement and Inspector settings.
	# This template remains outside the scene tree.
	dummy_template = training_dummy.duplicate() as Node2D

	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	add_child(respawn_timer)
	respawn_timer.timeout.connect(_respawn_dummy)

	training_dummy.connect("died", _on_dummy_died)


func _on_dummy_died() -> void:
	respawn_timer.start(dummy_respawn_delay)


func _respawn_dummy() -> void:
	if is_instance_valid(training_dummy):
		return

	training_dummy = dummy_template.duplicate() as Node2D
	training_dummy.name = &"TrainingDummy"
	add_child(training_dummy)
	training_dummy.connect("died", _on_dummy_died)


func _exit_tree() -> void:
	# Release the template when leaving the test level.
	if is_instance_valid(dummy_template):
		dummy_template.free()
