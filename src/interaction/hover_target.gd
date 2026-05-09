class_name HoverTarget
extends Area3D

const HoverHighlighterScript := preload("res://src/interaction/hover_highlighter.gd")
const GROUP_NAME: StringName = &"hover_targets"

@export var highlight_root_path: NodePath = ^".."
@export var highlighter_path: NodePath = ^"HoverHighlighter"

var _is_hovered: bool = false

func _init() -> void:
	_configure_pickable()

func _enter_tree() -> void:
	_configure_pickable()

func set_hovered(is_hovered: bool) -> void:
	if _is_hovered == is_hovered:
		return

	_is_hovered = is_hovered
	var highlighter := _get_highlighter()
	if highlighter != null:
		highlighter.set_highlighted(is_hovered)

func get_hover_root() -> Node3D:
	var root := get_node_or_null(highlight_root_path) as Node3D
	if root != null:
		return root

	return get_parent() as Node3D

func _configure_pickable() -> void:
	add_to_group(GROUP_NAME)
	input_ray_pickable = true
	monitorable = true

func _get_highlighter() -> HoverHighlighterScript:
	return get_node_or_null(highlighter_path) as HoverHighlighterScript
