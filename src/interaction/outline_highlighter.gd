class_name OutlineHighlighter
extends Node

const OUTLINE_SHADER: Shader = preload("res://src/interaction/outline_inverted_hull.gdshader")

@export var root_path: NodePath = ^".."
@export var outline_color: Color = Color(1.0, 0.9, 0.05, 1.0)
@export_range(0.001, 0.15, 0.001) var outline_width_m: float = 0.055

var _is_highlighted: bool = false
var _outline_material: ShaderMaterial
var _tracked_surfaces: Array[Dictionary] = []

func set_highlighted(is_highlighted: bool) -> void:
	if _is_highlighted == is_highlighted:
		return

	if is_highlighted:
		_apply_highlight()
	else:
		clear_highlight()

func clear_highlight() -> void:
	for record in _tracked_surfaces:
		var mesh_instance := record.get("mesh") as MeshInstance3D
		if mesh_instance == null:
			continue

		var kind := record.get("kind", &"") as StringName
		if kind == &"material_override":
			var previous_material_override := record.get("previous_material_override") as Material
			mesh_instance.material_override = previous_material_override
		else:
			var surface_index := int(record.get("surface", 0))
			var previous_surface_override := record.get("previous_surface_override") as Material
			mesh_instance.set_surface_override_material(surface_index, previous_surface_override)

	_tracked_surfaces.clear()
	_is_highlighted = false

static func build_outline_material(
	color: Color = Color(1.0, 0.9, 0.05, 1.0),
	width_m: float = 0.055
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("outline_color", color)
	material.set_shader_parameter("outline_width", width_m)
	return material

func _apply_highlight() -> void:
	clear_highlight()

	var root := get_node_or_null(root_path)
	if root == null:
		return

	_outline_material = build_outline_material(outline_color, outline_width_m)
	_apply_to_meshes(root)
	_is_highlighted = not _tracked_surfaces.is_empty()

func _apply_to_meshes(root: Node) -> void:
	if root is MeshInstance3D:
		_apply_to_mesh(root)

	for child in root.get_children():
		_apply_to_meshes(child)

func _apply_to_mesh(mesh_instance: MeshInstance3D) -> void:
	var mesh_resource := mesh_instance.mesh
	if mesh_resource == null:
		return

	if mesh_instance.material_override != null:
		var highlighted_override := _with_outline(mesh_instance.material_override)
		if highlighted_override == null:
			return

		_tracked_surfaces.append({
			"kind": &"material_override",
			"mesh": mesh_instance,
			"previous_material_override": mesh_instance.material_override,
		})
		mesh_instance.material_override = highlighted_override
		return

	for surface_index in range(mesh_resource.get_surface_count()):
		var previous_override := mesh_instance.get_surface_override_material(surface_index)
		var source_material := previous_override
		if source_material == null:
			source_material = mesh_resource.surface_get_material(surface_index)

		var highlighted_material := _with_outline(source_material)
		if highlighted_material == null:
			continue

		_tracked_surfaces.append({
			"kind": &"surface_override",
			"mesh": mesh_instance,
			"surface": surface_index,
			"previous_surface_override": previous_override,
		})

		mesh_instance.set_surface_override_material(surface_index, highlighted_material)

func _with_outline(source_material: Material) -> Material:
	var highlighted_material: Material
	if source_material == null:
		highlighted_material = StandardMaterial3D.new()
	else:
		highlighted_material = source_material.duplicate() as Material

	if highlighted_material != null:
		highlighted_material.next_pass = _outline_material

	return highlighted_material
