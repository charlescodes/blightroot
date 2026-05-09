extends SceneTree

const EventBusScript := preload("res://src/core/event_bus.gd")
const HexDataScript := preload("res://src/grid/hex_data.gd")
const HexGridManagerScript := preload("res://src/grid/hex_grid_manager.gd")
const HexViewScript := preload("res://src/grid/hex_view.gd")
const CameraRigScript := preload("res://src/camera/camera_rig.gd")
const InteractionTargetScript := preload("res://src/interaction/interaction_target.gd")
const HoverHighlighterScript := preload("res://src/interaction/hover_highlighter.gd")
const InteractionControllerScript := preload("res://src/interaction/interaction_controller.gd")
const InteractionActionResolverScript := preload("res://src/interaction/interaction_action_resolver.gd")
const InteractionMenuScript := preload("res://src/ui/interaction_menu.gd")
const InteractionLogPanelScript := preload("res://src/ui/interaction_log_panel.gd")
const WorldObjectDataScript := preload("res://src/objects/world_object_data.gd")
const BlockoutObjectViewScript := preload("res://src/objects/blockout_object_view.gd")

func _init() -> void:
	if not _run_smoke_checks():
		quit(1)
		return

	print("Smoke Test Passed: Compilation successful")
	quit()

func _run_smoke_checks() -> bool:
	var event_bus := EventBusScript.new()
	for signal_name in [
		"hover_target_changed",
		"interaction_menu_requested",
		"interaction_action_requested",
		"interaction_pointer_capture_changed",
		"interaction_ui_cancel_requested",
		"examined_output",
	]:
		if not event_bus.has_signal(signal_name):
			return _fail("EventBus is missing %s signal." % signal_name)
	event_bus.free()

	if ProjectSettings.get_setting("autoload/EventBus", "") != "*res://src/core/event_bus.gd":
		return _fail("EventBus autoload is not configured.")

	if not InputMap.has_action("toggle_interaction_log"):
		return _fail("toggle_interaction_log input action is missing.")

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
	var interaction_target := hex_view.get_node_or_null("InteractionTarget") as InteractionTargetScript
	if interaction_target == null:
		return _fail("HexView did not create an InteractionTarget child.")
	if not interaction_target.is_in_group(InteractionTargetScript.GROUP_NAME):
		return _fail("InteractionTarget did not join the expected group.")
	if interaction_target.target_domain != &"hex":
		return _fail("HexView InteractionTarget has the wrong domain.")
	if not (interaction_target.target_data is HexDataScript):
		return _fail("HexView InteractionTarget does not carry HexData.")
	var collision_shape := interaction_target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return _fail("InteractionTarget did not create a collision shape.")
	if not is_equal_approx(hex_view.rotation.y, HexViewScript.HEX_MESH_Y_ROTATION_RADIANS):
		return _fail("HexView mesh rotation is not aligned to flat-top axial spacing.")
	var hex_highlighter := interaction_target.get_node_or_null("HoverHighlighter") as HoverHighlighterScript
	if hex_highlighter == null:
		return _fail("HexView did not create a HoverHighlighter.")
	if _has_action(InteractionActionResolverScript.get_actions(interaction_target), InteractionActionResolverScript.ACTION_EXAMINE):
		return _fail("Hex interaction target should not expose Examine yet.")
	hex_view.free()

	var highlight_material: StandardMaterial3D = HoverHighlighterScript.build_highlight_material()
	if highlight_material.albedo_color.a >= 1.0:
		return _fail("HoverHighlighter did not build a transparent material.")
	highlight_material = null

	var mesh := MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	mesh.material_override = StandardMaterial3D.new()
	var highlighter := HoverHighlighterScript.new()
	highlighter.root_path = ^".."
	mesh.add_child(highlighter)
	get_root().add_child(mesh)
	highlighter.set_highlighted(true)
	var shell := mesh.get_node_or_null("HoverShell") as MeshInstance3D
	if shell == null:
		return _fail("HoverHighlighter did not create a shell mesh.")
	var shell_material := shell.material_override as StandardMaterial3D
	if shell_material == null or shell_material.albedo_color.a >= 1.0:
		return _fail("HoverHighlighter shell is not using a transparent material.")
	if shell.get_child_count() != 0:
		return _fail("HoverHighlighter shell should not create collision or helper children.")
	highlighter.clear_highlight()
	if mesh.get_node_or_null("HoverShell") != null:
		return _fail("HoverHighlighter did not remove shell meshes after clearing.")
	mesh.free()

	var interaction_controller := InteractionControllerScript.new()
	get_root().add_child(interaction_controller)
	if not interaction_controller.has_method("clear_hover"):
		return _fail("InteractionController is missing clear_hover().")
	if not interaction_controller.has_method("is_interaction_pointer_captured"):
		return _fail("InteractionController is missing pointer capture state access.")
	var root_event_bus := get_root().get_node_or_null("EventBus")
	if root_event_bus != null:
		root_event_bus.emit_signal(&"interaction_pointer_capture_changed", true)
		if not interaction_controller.is_interaction_pointer_captured():
			return _fail("InteractionController did not pause for interaction pointer capture.")
		root_event_bus.emit_signal(&"interaction_pointer_capture_changed", false)
		if interaction_controller.is_interaction_pointer_captured():
			return _fail("InteractionController did not resume after pointer capture release.")
	interaction_controller.free()

	var pc_size := Vector3(0.5, 1.83, 0.5)
	var pc_data := WorldObjectDataScript.new(
		&"pc_001",
		&"player_character",
		0,
		0,
		0,
		pc_size,
		Color(0.1, 0.25, 1.0, 1.0),
		true
	)
	if not pc_data.is_valid_cube():
		return _fail("WorldObjectData did not preserve q + r + s == 0.")
	if pc_data.size_m != pc_size:
		return _fail("Player character dimensions are incorrect.")

	var pc_view := BlockoutObjectViewScript.new()
	pc_view.object_data = pc_data
	get_root().add_child(pc_view)
	if not is_equal_approx(pc_view.position.x, 0.0) or not is_equal_approx(pc_view.position.z, 0.0):
		return _fail("Player character did not land on hex origin x/z.")

	var pc_body := pc_view.get_node_or_null("Body") as MeshInstance3D
	if pc_body == null:
		return _fail("BlockoutObjectView did not create Body mesh.")
	var pc_body_offset := Vector3(0.0, pc_size.y * 0.5, 0.0)
	if pc_body.position != pc_body_offset:
		return _fail("Player character mesh is not centered above its feet.")

	var pc_mesh := pc_body.mesh as BoxMesh
	if pc_mesh == null or pc_mesh.size != pc_size:
		return _fail("Player character mesh dimensions are incorrect.")
	if not is_equal_approx(pc_body.position.y - (pc_size.y * 0.5), 0.0):
		return _fail("Player character feet are not level with y=0.")

	var pc_interaction_target := pc_view.get_node_or_null("InteractionTarget") as InteractionTargetScript
	if pc_interaction_target == null:
		return _fail("Player character did not create an InteractionTarget.")
	if pc_interaction_target.target_domain != &"world_object":
		return _fail("Player character InteractionTarget has the wrong domain.")
	if not (pc_interaction_target.target_data is WorldObjectDataScript):
		return _fail("Player character InteractionTarget does not carry WorldObjectData.")
	if not _has_action(InteractionActionResolverScript.get_actions(pc_interaction_target), InteractionActionResolverScript.ACTION_EXAMINE):
		return _fail("World object interaction target should expose Examine.")
	var examine_output := InteractionActionResolverScript.build_examine_output(pc_interaction_target)
	if examine_output.get("domain") != &"world_object":
		return _fail("Examine output has the wrong domain.")
	if examine_output.get("object_kind") != &"player_character":
		return _fail("Examine output has the wrong object kind.")
	if examine_output.get("object_id") != &"pc_001":
		return _fail("Examine output has the wrong object id.")
	var pc_collision_shape := pc_interaction_target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if pc_collision_shape == null or pc_collision_shape.position != pc_body_offset:
		return _fail("Player character collision shape is missing or not centered above its feet.")
	var pc_shape := pc_collision_shape.shape as BoxShape3D
	if pc_shape == null or pc_shape.size != pc_size:
		return _fail("Player character collision dimensions are incorrect.")
	if pc_interaction_target.get_node_or_null("HoverHighlighter") == null:
		return _fail("Player character did not create a HoverHighlighter.")
	pc_view.free()

	var interaction_menu := InteractionMenuScript.new()
	interaction_menu.free()
	var interaction_log_panel := InteractionLogPanelScript.new()
	interaction_log_panel.free()

	var main_scene := load("res://scenes/main.tscn") as PackedScene
	if main_scene == null:
		return _fail("Main scene did not load.")
	var main := main_scene.instantiate()
	get_root().add_child(main)
	var main_interaction_controller := main.get_node_or_null("InteractionController") as InteractionControllerScript
	if main_interaction_controller == null:
		return _fail("Main scene is missing InteractionController.")
	var interaction_ui := main.get_node_or_null("InteractionUI") as CanvasLayer
	if interaction_ui == null:
		return _fail("Main scene is missing InteractionUI CanvasLayer.")
	var main_interaction_menu := interaction_ui.get_node_or_null("InteractionMenu") as InteractionMenuScript
	if main_interaction_menu == null:
		return _fail("Main scene is missing InteractionMenu.")
	if interaction_ui.get_node_or_null("InteractionLogPanel") == null:
		return _fail("Main scene is missing InteractionLogPanel.")
	if main.get_node_or_null("SunLight") == null:
		return _fail("Main scene is missing SunLight.")
	if main.get_node_or_null("PlayerCharacter") == null:
		return _fail("Main scene is missing PlayerCharacter.")
	var npc := main.get_node_or_null("NPC") as BlockoutObjectViewScript
	if npc == null:
		return _fail("Main scene is missing NPC.")
	if npc.object_data == null or npc.object_data.object_kind != &"non_player_character":
		return _fail("NPC object data is missing or has the wrong kind.")
	if npc.object_data.key() != Vector3i(1, 0, -1):
		return _fail("NPC is not assigned to the adjacent hex.")
	if npc.object_data.color != Color(0.45, 0.45, 0.45, 1.0):
		return _fail("NPC is not using the expected gray color.")
	var npc_interaction_target := npc.get_node_or_null("InteractionTarget") as InteractionTargetScript
	if npc_interaction_target == null:
		return _fail("NPC did not create an InteractionTarget.")
	if npc_interaction_target.target_domain != &"world_object":
		return _fail("NPC InteractionTarget has the wrong domain.")
	if not (npc_interaction_target.target_data is WorldObjectDataScript):
		return _fail("NPC InteractionTarget does not carry WorldObjectData.")
	if root_event_bus != null:
		root_event_bus.emit_signal(&"interaction_menu_requested", npc_interaction_target, Vector2.ZERO)
		if not main_interaction_menu.visible:
			return _fail("InteractionMenu did not open from a menu request.")
		if not main_interaction_controller.is_interaction_pointer_captured():
			return _fail("InteractionController did not capture pointer when the menu opened.")
		root_event_bus.emit_signal(&"interaction_ui_cancel_requested")
		if main_interaction_menu.visible:
			return _fail("InteractionMenu did not close from a cancel request.")
		if main_interaction_controller.is_interaction_pointer_captured():
			return _fail("InteractionController did not release pointer capture after cancel.")
	main.free()

	var camera_distance: float = CameraRigScript.camera_distance_for_height(7.0, deg_to_rad(-55.0))
	if not camera_distance > 7.0:
		return _fail("Camera rig distance should exceed its vertical height at an angled pitch.")

	return true

func _has_action(actions: Array[Dictionary], action_id: StringName) -> bool:
	for action in actions:
		if action.get("id") == action_id:
			return true

	return false

func _fail(message: String) -> bool:
	push_error(message)
	return false
