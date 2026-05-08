extends SceneTree

const HexDataScript := preload("res://src/grid/hex_data.gd")
const HexGridManagerScript := preload("res://src/grid/hex_grid_manager.gd")
const HexViewScript := preload("res://src/grid/hex_view.gd")
const CameraRigScript := preload("res://src/camera/camera_rig.gd")

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

	var camera_distance: float = CameraRigScript.camera_distance_for_height(7.0, deg_to_rad(-55.0))
	if not camera_distance > 7.0:
		return _fail("Camera rig distance should exceed its vertical height at an angled pitch.")

	return true

func _fail(message: String) -> bool:
	push_error(message)
	return false
