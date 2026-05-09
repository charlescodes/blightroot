class_name InteractionController
extends Node

const InteractionTargetScript := preload("res://src/interaction/interaction_target.gd")
const InteractionActionResolverScript := preload("res://src/interaction/interaction_action_resolver.gd")

@export var camera_path: NodePath = ^"../CameraRig/PitchPivot/Camera3D"
@export_range(1.0, 500.0, 1.0) var max_ray_distance_m: float = 100.0
@export_flags_3d_physics var collision_mask: int = 1

var _camera: Camera3D
var _current_target: InteractionTargetScript
var _is_interaction_pointer_captured: bool = false

func _ready() -> void:
	_camera = _resolve_camera()
	var event_bus := _get_event_bus()
	if event_bus == null:
		return
	if not event_bus.is_connected(&"interaction_action_requested", _handle_interaction_action_requested):
		event_bus.connect(&"interaction_action_requested", _handle_interaction_action_requested)
	if not event_bus.is_connected(&"interaction_pointer_capture_changed", _handle_interaction_pointer_capture_changed):
		event_bus.connect(&"interaction_pointer_capture_changed", _handle_interaction_pointer_capture_changed)

func _input(event: InputEvent) -> void:
	if not _is_interaction_pointer_captured:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_request_interaction_ui_cancel()
			get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if _is_interaction_pointer_captured:
		return

	if _should_pause_hover():
		clear_hover()
		return

	if _camera == null:
		_camera = _resolve_camera()
		if _camera == null:
			clear_hover()
			return

	_set_hover_target(_raycast_interaction_target())

func _unhandled_input(event: InputEvent) -> void:
	if _is_interaction_pointer_captured:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_request_menu_for_current_target(mouse_event.position)

func clear_hover() -> void:
	_set_hover_target(null)

func is_interaction_pointer_captured() -> bool:
	return _is_interaction_pointer_captured

func _raycast_interaction_target() -> InteractionTargetScript:
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_position)
	var ray_end := ray_origin + (_camera.project_ray_normal(mouse_position) * max_ray_distance_m)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null

	return _find_interaction_target(result.get("collider") as Object)

func _find_interaction_target(collider: Object) -> InteractionTargetScript:
	var node := collider as Node
	while node != null:
		if node is InteractionTargetScript:
			return node

		node = node.get_parent()

	return null

func _set_hover_target(target: InteractionTargetScript) -> void:
	if _current_target == target:
		return

	if _current_target != null:
		_current_target.set_hovered(false)

	_current_target = target

	if _current_target != null:
		_current_target.set_hovered(true)

	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"hover_target_changed", _current_target)

func _request_menu_for_current_target(screen_position: Vector2) -> void:
	if _current_target == null or not _current_target.is_interaction_enabled():
		return

	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"interaction_menu_requested", _current_target, screen_position)
	get_viewport().set_input_as_handled()

func _handle_interaction_action_requested(target: Node, action_id: StringName) -> void:
	if action_id != InteractionActionResolverScript.ACTION_EXAMINE:
		return
	if not InteractionActionResolverScript.can_examine(target):
		return

	var target_domain: StringName = &""
	if target.has_method("get_target_domain"):
		var target_domain_value: Variant = target.call("get_target_domain")
		target_domain = target_domain_value if target_domain_value is StringName else StringName(str(target_domain_value))

	var target_data: Resource
	if target.has_method("get_target_data"):
		target_data = target.call("get_target_data") as Resource

	var output := InteractionActionResolverScript.build_examine_output(target)
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"examined_output", target_domain, target_data, output)

func _handle_interaction_pointer_capture_changed(is_captured: bool) -> void:
	_is_interaction_pointer_captured = is_captured

func _request_interaction_ui_cancel() -> void:
	var event_bus := _get_event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"interaction_ui_cancel_requested")

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

func _get_event_bus() -> Node:
	return get_node_or_null("/root/EventBus")
