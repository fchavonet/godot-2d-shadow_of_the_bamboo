extends Area2D

@export_range(1, 100) var damage: int = 1


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	# The hurtbox belongs directly to the character receiving damage.
	var receiver := area.get_parent()

	if receiver != null and receiver.has_method("take_damage"):
		receiver.call("take_damage", damage)
