extends Node

signal hover_target_changed(target: Node)
signal interaction_menu_requested(target: Node, screen_position: Vector2)
signal interaction_action_requested(target: Node, action_id: StringName)
signal interaction_pointer_capture_changed(is_captured: bool)
signal interaction_ui_cancel_requested()
signal examined_output(target_domain: StringName, target_data: Resource, output: Dictionary)
