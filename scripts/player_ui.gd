extends Node2D

@export_group("Visibility")
@export_range(0.1, 10.0, 0.1) var display_time: float = 2.0
@export_range(0.0, 2.0, 0.05) var death_display_time: float = 0.4
@export var toggle_action: StringName = &"toggle_health_bar"

var display_timer: float = 0.0

@onready var player: Node = get_parent()
@onready var health_bar: Node2D = $HealthBar
@onready var energy_bar: ProgressBar = $EnergyBar


func _ready() -> void:
	# Only this parent controls the visibility of the two bars.
	health_bar.show()
	energy_bar.show()
	energy_bar.show_percentage = false
	energy_bar.min_value = 0.0
	energy_bar.step = 1.0
	energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	player.connect("health_changed", _on_health_changed)
	player.connect("energy_changed", _on_energy_changed)
	player.connect("damaged", _on_damaged)
	player.connect("energy_collected", show_temporarily)
	player.connect("died", _on_died)
	player.connect("respawned", _on_respawned)

	# Initialize without depending on the player's ready signal order.
	_on_health_changed(int(player.get("current_health")), int(player.get("max_health")))
	_on_energy_changed(int(player.get("current_energy")), int(player.get("max_energy")))
	update_visibility()


func _process(delta: float) -> void:
	display_timer = maxf(display_timer - delta, 0.0)
	update_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if bool(player.get("is_dead")):
		return

	if event.is_action_pressed(toggle_action) and not event.is_echo():
		show_temporarily()
		get_viewport().set_input_as_handled()


func show_temporarily() -> void:
	if bool(player.get("is_dead")):
		return

	display_timer = display_time
	update_visibility()


func update_visibility() -> void:
	var keep_visible := (
		not bool(player.get("is_dead"))
		and bool(health_bar.get("is_critical"))
	)
	visible = display_timer > 0.0 or keep_visible


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.set_health(current, maximum)
	update_visibility()


func _on_energy_changed(current: int, maximum: int) -> void:
	energy_bar.max_value = maxi(maximum, 1)
	energy_bar.value = clampi(current, 0, maxi(maximum, 0))


func _on_damaged(_amount: int) -> void:
	# The died signal handles the brief display after a fatal hit.
	if not bool(player.get("is_dead")):
		show_temporarily()


func _on_died() -> void:
	display_timer = death_display_time
	update_visibility()


func _on_respawned() -> void:
	display_timer = 0.0
	update_visibility()
