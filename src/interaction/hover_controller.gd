class_name HoverController
extends Node

const HoverTargetScript := preload("res://src/interaction/hover_target.gd")

@export var camera_path: NodePath = ^"../CameraRig/PitchPivot/Camera3D"
@export_range(1.0, 500.0, 1.0) var max_ray_distance_m: float = 100.0
@export_flags_3d_physics var collision_mask: int = 1

var _camera: Camera3D
var _current_target: HoverTargetScript

func _ready() -> void:
	_camera = _resolve_camera()

func _physics_process(_delta: float) -> void:
	if _should_pause_hover():
		clear_hover()
		return

	if _camera == null:
		_camera = _resolve_camera()
		if _camera == null:
			clear_hover()
			return

	_set_hover_target(_raycast_hover_target())

func clear_hover() -> void:
	_set_hover_target(null)

func _raycast_hover_target() -> HoverTargetScript:
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_position)
	var ray_end := ray_origin + (_camera.project_ray_normal(mouse_position) * max_ray_distance_m)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null

	return _find_hover_target(result.get("collider") as Object)

func _find_hover_target(collider: Object) -> HoverTargetScript:
	var node := collider as Node
	while node != null:
		if node is HoverTargetScript:
			return node

		node = node.get_parent()

	return null

func _set_hover_target(target: HoverTargetScript) -> void:
	if _current_target == target:
		return

	if _current_target != null:
		_current_target.set_hovered(false)

	_current_target = target

	if _current_target != null:
		_current_target.set_hovered(true)

func _resolve_camera() -> Camera3D:
	var configured_camera := get_node_or_null(camera_path) as Camera3D
	if configured_camera != null:
		return configured_camera

	return get_viewport().get_camera_3d()

func _should_pause_hover() -> bool:
	return (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	)
