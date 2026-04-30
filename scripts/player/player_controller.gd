class_name PlayerController
extends CharacterBody2D

@export var speed := 130.0
@export var walk_frames_per_second := 8.0
@export_range(1.0, 1.5, 0.25) var world_camera_zoom := 1.0

var movement_bounds := Rect2()
var has_movement_bounds := false
var _facing_row := 0
var _walk_time := 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("player")
	_apply_camera_zoom()

func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector * speed
	move_and_slide()
	if has_movement_bounds:
		global_position = global_position.clamp(movement_bounds.position, movement_bounds.end)
	_update_animation(input_vector, _delta)


func set_movement_bounds(bounds: Rect2) -> void:
	movement_bounds = bounds
	has_movement_bounds = bounds.size.x > 0.0 and bounds.size.y > 0.0


func configure_camera_limits(bounds: Rect2) -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.zoom = Vector2(world_camera_zoom, world_camera_zoom)
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)


func _apply_camera_zoom() -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.zoom = Vector2(world_camera_zoom, world_camera_zoom)


func _update_animation(input_vector: Vector2, delta: float) -> void:
	if sprite == null:
		return

	if input_vector.length() > 0.05:
		_facing_row = _direction_row(input_vector)
		_walk_time += delta
		var step := int(floor(_walk_time * walk_frames_per_second)) % 4
		sprite.frame = _facing_row * 4 + step
	else:
		_walk_time = 0.0
		sprite.frame = _facing_row * 4


func _direction_row(input_vector: Vector2) -> int:
	if abs(input_vector.x) > abs(input_vector.y):
		return 1 if input_vector.x < 0.0 else 2
	return 3 if input_vector.y < 0.0 else 0
