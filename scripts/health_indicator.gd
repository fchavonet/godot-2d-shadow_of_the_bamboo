extends Node2D

@export_range(0.1, 5.0) var display_duration: float = 2.0
@export_range(0.05, 1.0) var fade_duration: float = 0.2

@export_range(1, 8) var block_size: int = 1
@export_range(0, 4) var block_spacing: int = 1
@export var filled_color: Color = Color.WHITE
@export var empty_color: Color = Color(0.25, 0.25, 0.25, 1.0)
@export var anchor: Node2D

var current_health: int = 0
var maximum_health: int = 0
var visibility_tween: Tween


func _ready() -> void:
	hide()

	var character := get_parent()

	if character.has_signal("health_changed"):
		character.connect("health_changed", _on_health_changed)


func _process(_delta: float) -> void:
	# Follow the visual anchor without inheriting its flipped scale.
	if is_instance_valid(anchor):
		global_position = anchor.global_position

	if (
		Input.is_action_just_pressed("show_ui")
		or Input.is_action_just_released("show_ui")
	):
		display_health()


func _draw() -> void:
	if maximum_health <= 0:
		return

	var total_width := (
		maximum_health * block_size
		+ (maximum_health - 1) * block_spacing
	)

	# Keep local coordinates on whole pixels.
	var start_x := -floorf(total_width * 0.5)

	for index in range(maximum_health):
		var block_position := Vector2(
			start_x + index * (block_size + block_spacing),
			0.0
		)

		var color := filled_color if index < current_health else empty_color

		draw_rect(
			Rect2(block_position, Vector2(block_size, block_size)),
			color
		)


func _on_health_changed(current: int, maximum: int) -> void:
	maximum_health = maxi(maximum, 0)
	current_health = clampi(current, 0, maximum_health)
	queue_redraw()

	# Hide full health unless the player is checking it.
	if (
		current_health >= maximum_health
		and not Input.is_action_pressed("show_ui")
	):
		if visibility_tween != null:
			visibility_tween.kill()

		hide()
		return

	display_health()


func display_health() -> void:
	if visibility_tween != null:
		visibility_tween.kill()

	# Never display the indicator while the player has no health.
	if maximum_health <= 0 or current_health <= 0:
		hide()
		return

	modulate.a = 1.0
	show()

	# Start the hide delay only after the button is released.
	if Input.is_action_pressed("show_ui"):
		return

	visibility_tween = create_tween()
	visibility_tween.tween_interval(display_duration)
	visibility_tween.tween_property(
		self, "modulate:a", 0.0, fade_duration
	)
	visibility_tween.tween_callback(hide)
