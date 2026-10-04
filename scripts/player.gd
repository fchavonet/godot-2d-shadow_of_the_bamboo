extends CharacterBody2D

@export var move_speed: float = 90.0
@export var jump_speed: float = 250.0

@onready var visuals: Node2D = $Visuals
@onready var animated_sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_speed

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed

	if direction != 0.0:
		visuals.scale.x = direction

	move_and_slide()
	update_animation(direction)


func update_animation(direction: float) -> void:
	if not is_on_floor():
		if velocity.y < 0.0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")
	elif direction != 0.0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")
