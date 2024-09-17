class_name ComponentLoader
extends SubViewport

signal submitted(mesh: Mesh)
var mesh: Mesh


func _process(delta: float) -> void:
	match $VBC/Primitive.get_item_text($VBC/Primitive.selected):
		"Box":
			mesh = BoxMesh.new()
			for i in 3:
				mesh.size[i] = $VBC/VBC/Cube/Size.get_child(i).value
		"Sphere":
			mesh = SphereMesh.new()
			mesh.radius = $VBC/VBC/Sphere/Size/Radius.value
			mesh.height = $VBC/VBC/Sphere/Size/Height.value
			mesh.radial_segments = $VBC/VBC/Sphere/Size/Radius.value
			mesh.rings = $VBC/VBC/Sphere/Subdivision/Ring.value
			mesh.is_hemisphere = $VBC/VBC/Sphere/Hemisphere.button_pressed
		"Cylinder":
			mesh = CylinderMesh.new()
			mesh.bottom_radius = $VBC/VBC/Cylinder/BottomRadiua.value
			mesh.height = $VBC/VBC/Cylinder/Height.value
			mesh.radial_segments = $VBC/VBC/Cylinder/RadialSegment.value
			mesh.rings = $VBC/VBC/Cylinder/Ring.value
			mesh.top_radius = $VBC/VBC/Cylinder/TopRadius.value
			mesh.cap_bottom = $VBC/VBC/Cylinder/CapBottom.button_pressed
			mesh.cap_top = $VBC/VBC/Cylinder/CapTop.button_pressed
		"Torus":
			mesh = TorusMesh.new()
			mesh.inner_radius = $VBC/VBC/Torus/InnerRadius.value
			mesh.outer_radius = $VBC/VBC/Torus/OuterRadius.value
			mesh.rings = $VBC/VBC/Torus/Ring.value
			mesh.ring_segments = $VBC/VBC/Torus/RingSegment.value
	$MeshInstance3D.mesh = mesh


func _on_submit_pressed() -> void:
	submitted.emit(mesh)


func _on_close_requested() -> void:
	queue_free()


func _on_primitive_item_selected(index: int) -> void:
	for i in $VBC/VBC.get_children():
		i.visible = false
	$VBC/VBC.get_child(index).visible = true
