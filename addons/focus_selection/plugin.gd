@tool
extends EditorPlugin

var focus_button: Button

func _enter_tree() -> void:
	focus_button = Button.new()
	focus_button.text = "Focus"
	focus_button.pressed.connect(_on_focus_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, focus_button)

func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, focus_button)
	focus_button.queue_free()

func _on_focus_pressed() -> void:
	var selection := get_editor_interface().get_selection()
	var selected_nodes := selection.get_selected_nodes()
	if selected_nodes.is_empty():
		return

	var node: Node3D = selected_nodes[0]
	if not node is Node3D:
		return

	var viewport_3d := get_editor_interface().get_editor_viewport_3d(0)
	if not viewport_3d:
		return

	var camera: Camera3D = viewport_3d.get_camera_3d()
	if not camera:
		return

	var target_pos: Vector3 = node.global_position
	var bounds_radius: float = _get_approximate_radius(node)
	var distance: float = max(bounds_radius * 2.5, 1.5)   # padding so it's not edge-to-edge

	var current_dir: Vector3 = -camera.global_transform.basis.z
	camera.global_position = target_pos - current_dir * distance
	camera.look_at(target_pos, Vector3.UP)

# Estimates a rough bounding radius for the node, by checking its own mesh
# AABB (if it's a MeshInstance3D) and recursively checking children too -
# covers both single-mesh selections and parent nodes made of several child meshes.
func _get_approximate_radius(node: Node3D) -> float:
	var result := _collect_aabb(node, node.global_transform)

	if not result["found"]:
		return 1.0   # fallback for nodes with no mesh data at all

	var size: Vector3 = result["aabb"].size
	return max(size.x, max(size.y, size.z)) * 0.5

func _collect_aabb(node: Node3D, root_transform: Transform3D) -> Dictionary:
	var combined: AABB = AABB()
	var found := false

	if node is MeshInstance3D and node.mesh:
		var local_aabb: AABB = node.mesh.get_aabb()
		var world_aabb: AABB = node.global_transform * local_aabb
		if not found:
			combined = world_aabb
			found = true
		else:
			combined = combined.merge(world_aabb)

	for child in node.get_children():
		if child is Node3D:
			var child_result := _collect_aabb(child, root_transform)
			if child_result["found"]:
				if not found:
					combined = child_result["aabb"]
					found = true
				else:
					combined = combined.merge(child_result["aabb"])

	return {"aabb": combined, "found": found}
