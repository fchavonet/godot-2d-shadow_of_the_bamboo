extends Area2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	var receiver := area.get_parent()

	# Falling out of the level bypasses health and invulnerability.
	if receiver != null and receiver.has_method("die"):
		receiver.call("die")
