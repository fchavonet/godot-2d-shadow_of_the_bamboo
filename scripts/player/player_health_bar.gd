extends Node2D

@export_group("Layout")
@export_range(1, 16, 1) var point_size: int = 2
@export_range(0, 8, 1) var point_spacing: int = 1
@export_range(1, 20, 1) var points_per_row: int = 5
@export_range(0, 8, 1) var row_spacing: int = 1

@export_group("Colors")
@export var full_color: Color = Color.WHITE
@export var empty_color: Color = Color(0.25, 0.25, 0.25, 1.0)
@export var critical_color: Color = Color(1.0, 0.15, 0.15, 1.0)

@export_group("Critical Health")
@export_range(0.0, 1.0, 0.01) var critical_health_ratio: float = 0.2
@export var critical_blink: bool = true
@export_range(0.05, 1.0, 0.05) var blink_interval: float = 0.25

var current_health: int = 0
var maximum_health: int = 0
var blink_timer: float = 0.0
var is_critical: bool = false


func _process(delta: float) -> void:
	if is_critical and critical_blink:
		blink_timer = fmod(blink_timer + delta, blink_interval * 2.0)
		queue_redraw()


func set_health(current: int, maximum: int) -> void:
	maximum_health = maxi(maximum, 0)
	current_health = clampi(current, 0, maximum_health)
	var was_critical := is_critical
	is_critical = (
		current_health > 0
		and float(current_health) / float(maxi(maximum_health, 1)) <= critical_health_ratio
	)
	if is_critical != was_critical:
		blink_timer = 0.0
	queue_redraw()


func _draw() -> void:
	if maximum_health <= 0:
		return

	var columns := maxi(points_per_row, 1)
	var rows := ceili(float(maximum_health) / float(columns))
	var filled_color := critical_color if is_critical else full_color
	if is_critical and critical_blink and blink_timer >= blink_interval:
		filled_color.a *= 0.3

	for index in maximum_health:
		var row := floori(float(index) / float(columns))
		var column := index % columns
		var row_points := mini(columns, maximum_health - row * columns)
		var row_width := row_points * point_size + (row_points - 1) * point_spacing
		# Center each row on whole pixels. Extra rows extend upward.
		var x := floorf(-float(row_width) / 2.0) + column * (point_size + point_spacing)
		var y := -point_size - (rows - 1 - row) * (point_size + row_spacing)
		var color := filled_color if index < current_health else empty_color
		draw_rect(Rect2(Vector2(x, y), Vector2(point_size, point_size)), color)
