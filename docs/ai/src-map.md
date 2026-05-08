# AI Source Map For `src`

> Generated from source by `scripts/generate-src-map.py`. Do not edit by hand.

## Summary

- Scripts: 4
- Classes: 4
- Folders: 3
- Dependency edges: 3

## Folder Map

| Folder | Role | Scripts |
| --- | --- | --- |
| `src` | source root |  |
| `src/camera` | camera state and camera rig behavior | `camera_rig.gd` |
| `src/grid` |  | `hex_data.gd`, `hex_grid_manager.gd`, `hex_view.gd` |

## Class And Base Index

| Class | Extends | Role | Script |
| --- | --- | --- | --- |
| `CameraRig` | `Node3D` | 3D scene node | `src/camera/camera_rig.gd` |
| `HexData` | `Resource` | Godot script | `src/grid/hex_data.gd` |
| `HexGridManager` | `Node3D` | 3D scene node | `src/grid/hex_grid_manager.gd` |
| `HexView` | `MeshInstance3D` | Godot script | `src/grid/hex_view.gd` |

## Dependency Overview

Most referenced source scripts:
- `src/grid/hex_data.gd` referenced by 2 script(s)
- `src/grid/hex_view.gd` referenced by 1 script(s)

Per-script source dependencies:
- `src/grid/hex_grid_manager.gd`: `HexDataScript` -> `src/grid/hex_data.gd`, `HexViewScript` -> `src/grid/hex_view.gd`
- `src/grid/hex_view.gd`: `HexDataScript` -> `src/grid/hex_data.gd`

## Subsystem Notes

- `src/camera`: camera state and camera rig behavior.

## Per-Script Inventory

### `src/camera/camera_rig.gd`

- Identity: `CameraRig`
- Extends: `Node3D`
- Role: 3D scene node
- Lines: 119
- Instantiations:
  - line 106: `Node3D.new()` -> `unresolved/builtin`
  - line 116: `Camera3D.new()` -> `unresolved/builtin`
- Members:
  - line 4: `@export pitch_pivot_path: NodePath = ^"PitchPivot"` (public)
  - line 5: `@export camera_path: NodePath = ^"PitchPivot/Camera3D"` (public)
  - line 6: `@export_range(1.0, 50.0, 0.5) start_height_m: float = 7.0` (public)
  - line 7: `@export_range(1.0, 50.0, 0.5) min_height_m: float = 2.0` (public)
  - line 8: `@export_range(1.0, 50.0, 0.5) max_height_m: float = 18.0` (public)
  - line 9: `@export_range(0.25, 5.0, 0.25) height_step_m: float = 1.0` (public)
  - line 10: `@export_range(-180.0, 180.0, 1.0, "degrees") start_yaw_degrees: float = 45.0` (public)
  - line 11: `@export_range(-89.0, -5.0, 1.0, "degrees") start_pitch_degrees: float = -55.0` (public)
  - line 12: `@export_range(-89.0, -5.0, 1.0, "degrees") min_pitch_degrees: float = -80.0` (public)
  - line 13: `@export_range(-89.0, -5.0, 1.0, "degrees") max_pitch_degrees: float = -20.0` (public)
  - line 14: `@export_range(0.001, 0.1, 0.001) pan_speed_m_per_pixel: float = 0.015` (public)
  - line 15: `@export_range(0.001, 0.02, 0.001) look_sensitivity: float = 0.005` (public)
  - line 17: `_height_m: float = 0.0` (private)
  - line 18: `_yaw: float = 0.0` (private)
  - line 19: `_pitch: float = 0.0` (private)
  - line 20: `_is_panning: bool = false` (private)
  - line 21: `_is_looking: bool = false` (private)
  - line 22: `_pitch_pivot: Node3D` (private)
  - line 23: `_camera: Camera3D` (private)
- Methods:
  - lines 25-33: `func _ready() -> void:` (instance, private)
  - lines 34-39: `func _unhandled_input(event: InputEvent) -> void:` (instance, private)
  - lines 40-45: `func _notification(what: int) -> void:` (instance, private)
  - lines 46-49: `func set_height_m(value: float) -> void:` (instance, public)
  - lines 50-53: `static func camera_distance_for_height(height_m: float, pitch_radians: float) -> float:` (static, public)
  - lines 54-71: `func _handle_mouse_button(event: InputEventMouseButton) -> void:` (instance, private)
  - lines 72-85: `func _handle_mouse_motion(event: InputEventMouseMotion) -> void:` (instance, private)
  - lines 86-92: `func _pan_ground_focus(mouse_delta: Vector2) -> void:` (instance, private)
  - lines 93-100: `func _apply_camera_transform() -> void:` (instance, private)
  - lines 101-110: `func _get_or_create_pitch_pivot() -> Node3D:` (instance, private)
  - lines 111-119: `func _get_or_create_camera() -> Camera3D:` (instance, private)

### `src/grid/hex_data.gd`

- Identity: `HexData`
- Extends: `Resource`
- Role: Godot script
- Lines: 38
- Members:
  - line 4: `@export q: int = 0` (public)
  - line 5: `@export r: int = 0` (public)
  - line 6: `@export s: int = 0` (public)
  - line 7: `@export terrain_id: StringName = &"grass"` (public)
  - line 8: `@export is_walkable: bool = true` (public)
- Methods:
  - lines 10-25: `func _init( p_q: int = 0, p_r: int = 0, p_s: int = 0, p_terrain_id: StringName = &"grass", p_is_walkable: bool = true ) -> void:` (instance, private)
  - lines 26-30: `func set_axial(p_q: int, p_r: int) -> void:` (instance, public)
  - lines 31-33: `func cube_coords() -> Vector3i:` (instance, public)
  - lines 34-36: `func key() -> Vector3i:` (instance, public)
  - lines 37-38: `func is_valid_cube() -> bool:` (instance, public)

### `src/grid/hex_grid_manager.gd`

- Identity: `HexGridManager`
- Extends: `Node3D`
- Role: 3D scene node
- Lines: 50
- Dependencies:
  - line 4: `HexDataScript` preload -> `src/grid/hex_data.gd`
  - line 5: `HexViewScript` preload -> `src/grid/hex_view.gd`
- Instantiations:
  - line 35: `HexDataScript.new()` -> `HexData`
  - line 42: `HexViewScript.new()` -> `HexView`
- Constants:
  - line 4: `HexDataScript = preload("res://src/grid/hex_data.gd")`
  - line 5: `HexViewScript = preload("res://src/grid/hex_view.gd")`
- Members:
  - line 7: `@export_range(1, 128, 1) width: int = 6` (public)
  - line 8: `@export_range(1, 128, 1) length: int = 6` (public)
  - line 9: `@export default_terrain_id: StringName = &"grass"` (public)
  - line 10: `@export default_walkable: bool = true` (public)
  - line 11: `@export generate_on_ready: bool = true` (public)
- Methods:
  - lines 13-16: `func _ready() -> void:` (instance, private)
  - lines 17-22: `func build_grid() -> Dictionary:` (instance, public)
  - lines 23-39: `static func generate_hex_data( map_width: int, map_length: int, terrain_id: StringName = &"grass", is_walkable: bool = true ) -> Dictionary:` (static, public)
  - lines 40-46: `static func instantiate_hex_views(hexes: Dictionary, parent: Node3D) -> void:` (static, public)
  - lines 47-50: `func clear_hex_views() -> void:` (instance, public)

### `src/grid/hex_view.gd`

- Identity: `HexView`
- Extends: `MeshInstance3D`
- Role: Godot script
- Lines: 56
- Dependencies:
  - line 4: `HexDataScript` preload -> `src/grid/hex_data.gd`
- Instantiations:
  - line 41: `CylinderMesh.new()` -> `unresolved/builtin`
  - line 50: `StandardMaterial3D.new()` -> `unresolved/builtin`
- Constants:
  - line 4: `HexDataScript = preload("res://src/grid/hex_data.gd")`
  - line 6: `HEX_SIDE_TO_SIDE_M: float = 1.0`
  - line 7: `HEX_RADIUS_M: float = HEX_SIDE_TO_SIDE_M / sqrt(3.0)`
  - line 8: `DEFAULT_HEIGHT_M: float = 0.08`
- Members:
  - line 10: `@export hex_data: HexDataScript:` (public)
  - line 15: `@export tile_height_m: float = DEFAULT_HEIGHT_M:` (public)
- Methods:
  - lines 21-24: `func _ready() -> void:` (instance, private)
  - lines 25-29: `static func axial_to_world(p_q: int, p_r: int, p_y: float = 0.0) -> Vector3:` (static, public)
  - lines 30-37: `func apply_data() -> void:` (instance, public)
  - lines 38-48: `func _configure_mesh() -> void:` (instance, private)
  - lines 49-56: `func _apply_material() -> void:` (instance, private)
