extends SceneTree

const HexDataScript := preload("res://src/grid/hex_data.gd")
const HexGridManagerScript := preload("res://src/grid/hex_grid_manager.gd")
const HexViewScript := preload("res://src/grid/hex_view.gd")
const CameraRigScript := preload("res://src/camera/camera_rig.gd")
const HoverTargetScript := preload("res://src/interaction/hover_target.gd")
const OutlineHighlighterScript := preload("res://src/interaction/outline_highlighter.gd")
const HoverControllerScript := preload("res://src/interaction/hover_controller.gd")

func _init() -> void:
	if not _run_smoke_checks():
		quit(1)
		return

	print("Smoke Test Passed: Compilation successful")
	quit()

func _run_smoke_checks() -> bool:
	var hexes: Dictionary = HexGridManagerScript.generate_hex_data(2, 3)
	if hexes.size() != 6:
		return _fail("Expected 6 generated hexes, got %d." % hexes.size())

	var origin_key := Vector3i(0, 0, 0)
	if not hexes.has(origin_key):
		return _fail("Generated grid is missing the origin hex.")

	var origin: HexDataScript = hexes[origin_key]
	if not origin.is_valid_cube():
		return _fail("Origin hex violates q + r + s == 0.")

	var center: Vector3 = HexViewScript.axial_to_world(0, 0)
	var east: Vector3 = HexViewScript.axial_to_world(1, 0)
	if not is_equal_approx(center.distance_to(east), HexViewScript.HEX_SIDE_TO_SIDE_M):
		return _fail("Adjacent hex center spacing is not 1 meter.")

	var hex_view := HexViewScript.new()
	hex_view.hex_data = HexDataScript.new(0, 0, 0)
	get_root().add_child(hex_view)
	var hover_target := hex_view.get_node_or_null("HoverTarget") as HoverTargetScript
	if hover_target == null:
		return _fail("HexView did not create a HoverTarget child.")
	if not hover_target.is_in_group(HoverTargetScript.GROUP_NAME):
		return _fail("HoverTarget did not join the expected group.")
	var collision_shape := hover_target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return _fail("HoverTarget did not create a collision shape.")
	hex_view.free()

	var outline_material: ShaderMaterial = OutlineHighlighterScript.build_outline_material()
	if outline_material.shader == null:
		return _fail("OutlineHighlighter did not build an outline shader material.")
	outline_material = null

	var mesh := MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	mesh.material_override = StandardMaterial3D.new()
	var highlighter := OutlineHighlighterScript.new()
	highlighter.root_path = ^".."
	mesh.add_child(highlighter)
	get_root().add_child(mesh)
	highlighter.set_highlighted(true)
	if mesh.material_override == null or mesh.material_override.next_pass == null:
		return _fail("OutlineHighlighter did not apply next_pass to material_override.")
	highlighter.clear_highlight()
	if mesh.material_override == null or mesh.material_override.next_pass != null:
		return _fail("OutlineHighlighter did not restore material_override after clearing.")
	mesh.free()

	var hover_controller := HoverControllerScript.new()
	if not hover_controller.has_method("clear_hover"):
		return _fail("HoverController is missing clear_hover().")
	hover_controller.free()

	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		return _fail("Main scene did not load.")
	var main := main_scene.instantiate()
	if main.get_node_or_null("HoverController") == null:
		return _fail("Main scene is missing HoverController.")
	if main.get_node_or_null("SunLight") == null:
		return _fail("Main scene is missing SunLight.")
	main.free()

	var camera_distance: float = CameraRigScript.camera_distance_for_height(7.0, deg_to_rad(-55.0))
	if not camera_distance > 7.0:
		return _fail("Camera rig distance should exceed its vertical height at an angled pitch.")

	return true

func _fail(message: String) -> bool:
	push_error(message)
	return false
