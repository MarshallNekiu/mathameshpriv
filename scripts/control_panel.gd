class_name ControlPanel
extends HBoxContainer

@export var main: MeshCreator
@export var orb_line: PackedVector3Array
@export var orb_line_material: Material

var camera_align_layer := true
var canvas_input := true
var layer_input := false
var layer_inherit := true
var focus_connectable := true
var uv := false


func _ready() -> void:
	var a := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_uv(Vector2.ZERO)
	st.set_color(Color.WHITE)
	for i in orb_line.size() - 1:
		st.add_vertex(orb_line[i])
		st.add_vertex(orb_line[i + 1])
	
	a.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ($SVC/SV/Translate/Mesh.mesh as SphereMesh).get_mesh_arrays())
	a.surface_set_material(0, $SVC/SV/Translate/Mesh.get_surface_override_material(0))
	a.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, st.commit_to_arrays())
	a.surface_set_material(1, orb_line_material)
	
	$SVC/SV/Translate/Mesh.mesh = a
	$SVC2/SV/Rotate/Mesh.mesh = a


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.is_released():
			if main.input_request[MeshCreator.INPUT_REQUEST.TRANSLATE] == event.index: main.input_request[MeshCreator.INPUT_REQUEST.TRANSLATE] = -1
			elif main.input_request[MeshCreator.INPUT_REQUEST.ROTATE] == event.index: main.input_request[MeshCreator.INPUT_REQUEST.ROTATE] = -1
	elif event is InputEventScreenDrag:
		if event.velocity.distance_to(Vector2.ZERO) > 64:
			if main.input_request[main.INPUT_REQUEST.TRANSLATE] == event.index:
				$SVC/SV/Translate.apply_torque(5 * Vector3(event.relative.normalized().y, event.relative.normalized().x, 0))
			if main.input_request[main.INPUT_REQUEST.ROTATE] == event.index:
				$SVC2/SV/Rotate.apply_torque($SVC2/SV/Rotate.basis * 2 * -Vector3(event.relative.normalized().y, event.relative.normalized().x, 0))


func _process(_delta: float) -> void:
	if main.input_request[MeshCreator.INPUT_REQUEST.TRANSLATE] >= 0:
		main.perspective_camera.translate_object_local(0.02 * -$SVC/SV/Translate.basis.z)
	else: $SVC/SV/Translate.apply_torque($SVC/SV/Translate.basis.z.cross(Vector3.BACK) * 5)
	
	$SVC/SV/Translate.apply_torque($SVC/SV/Translate.basis.z.cross($SVC/SV/Translate.basis.z.snapped(Vector3.ONE)))
	$SVC/SV/Translate.apply_torque($SVC/SV/Translate.basis.z * angle_difference($SVC/SV/Translate.rotation.z, 0))
	
	$SVC2/SV/Rotate.apply_torque(main.perspective_camera.basis.z * angle_difference($SVC2/SV/Rotate.rotation.z, main.current_surface.layer.basis.get_euler().z))
	
	main.perspective_camera.rotation = $SVC2/SV/Rotate.rotation


func _on_svc_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.is_pressed():
			main.input_request[main.INPUT_REQUEST.TRANSLATE] = event.index


func _on_svc_2_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.is_pressed():
			main.input_request[main.INPUT_REQUEST.ROTATE] =  event.index


func _on_surface_add_pressed() -> void:
	main.add_surface()
	update_surface_max_value()


func _on_surface_remove_pressed() -> void:
	if main.get_surface_count() > 1:
		main.current_surface.queue_free.call_deferred()
		update_surface_max_value(main.get_surface_count() - 2)


func update_surface_max_value(value := main.get_surface_count() - 1):
	$Trigger/Current/Surface/Focus.max_value = value
	_on_surface_focus_value_changed($Trigger/Current/Surface/Focus.value)


func _on_surface_focus_value_changed(value: float) -> void:
	if main.current_surface: main.current_surface.current_layer = -1
	main.current_surface = main.get_surface(int(value))
	update_layer_max_value()


func _on_layer_add_pressed() -> void:
	main.current_surface.add_layer()
	update_layer_max_value()
	WorkerThreadPool.add_task(main.current_surface.redraw_surface)


func _on_layer_remove_pressed() -> void:
	main.current_surface.remove_layer(int($Trigger/Current/Layer/Focus.value))
	update_layer_max_value()


func update_layer_max_value():
	$Trigger/Current/Layer/Focus.max_value = main.current_surface.layer_face.size() - 1
	main.current_surface.current_layer = $Trigger/Current/Layer/Focus.value


func _on_layer_value_changed(value: float) -> void:
	main.current_surface.current_layer = int(value)
	main.current_surface.layer_vertex_resize()
	update_layer_transform()
	WorkerThreadPool.add_task(main.current_surface.redraw_surface)


func _on_instance_mode_item_selected(index: int) -> void:
	main.control_mode = [MeshCreator.CONTROL_MODE.ADD, MeshCreator.CONTROL_MODE.CONNECT][index]


func _on_instance_mode_pressed() -> void:
	main.control_mode = [MeshCreator.CONTROL_MODE.ADD, MeshCreator.CONTROL_MODE.CONNECT][$Trigger/Instance/Mode.selected]


func _on_instance_class_item_selected(index: int) -> void:
	main.instance_mode = [MeshCreator.CLASSES.VERTEX, MeshCreator.CLASSES.BONE][index]


func _on_focus_mode_item_selected(index: int) -> void:
	main.control_mode = [MeshCreator.CONTROL_MODE.SELECT, MeshCreator.CONTROL_MODE.DESELECT][index]


func _on_focus_mode_pressed() -> void:
	main.control_mode = [MeshCreator.CONTROL_MODE.SELECT, MeshCreator.CONTROL_MODE.DESELECT][$Trigger/Focus/Mode.selected]


func _on_focus_class_toggled(_toggled_on: bool) -> void:
	var new: PackedInt32Array
	for i: CheckButton in $Trigger/Focus/Class.get_children():
		if i.button_pressed:
			if new.has(MeshCreator.CLASSES.SURFACE):
				i.set_pressed_no_signal(false)
				break
			new.append(i.get_index())
	main.focus_mode = new


func _on_move_pressed() -> void:
	main.control_mode = MeshCreator.CONTROL_MODE.MOVE


func _on_remove_pressed() -> void:
	main.selecting[MeshCreator.CLASSES.VERTEX].clear()
	main.current_surface.remove_face(main.selecting[MeshCreator.CLASSES.SURFACE])
	main.selecting[MeshCreator.CLASSES.SURFACE].clear()
	main.current_surface.redraw_surface()


func _on_paint_mode_item_selected(index: int) -> void:
	main.control_mode = [MeshCreator.CONTROL_MODE.PAINT, MeshCreator.CONTROL_MODE.ERASE][index]
	if main.control_mode == MeshCreator.CONTROL_MODE.PAINT:
		for i in main.selecting[MeshCreator.CLASSES.VERTEX]:
			if main.paint_mode.has(MeshCreator.VERTEX_DATA.COLOR):
				main.current_surface.surface_array[Mesh.ARRAY_COLOR][i] = $Trigger/Paint/HBC/Color.color
			if main.paint_mode.has(MeshCreator.VERTEX_DATA.BONE):
				main.current_surface.surface_array[Mesh.ARRAY_BONES][i * 4] = int($Trigger/Paint/HBC2/Bone.value)
	
	main.current_surface.redraw_surface()


func _on_paint_check_toggled(_toggled_on: bool) -> void:
	var mode: PackedInt32Array
	if $Trigger/Paint/HBC/Check.button_pressed:
		mode.append(MeshCreator.VERTEX_DATA.COLOR)
	if $Trigger/Paint/HBC2/Check.button_pressed:
		mode.append(MeshCreator.VERTEX_DATA.BONE)
	main.paint_mode = mode


func _on_submit_pressed() -> void:
	main.connection_point.visible_instance_count = 0


func _on_zoom_value_changed(value: float) -> void:
	main.orthogonal_camera.size = value


func _on_fov_value_changed(value: float) -> void:
	main.perspective_camera.fov = value


func _on_perspective_camera_transform_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_orthogonal_camera_transform_value_changed(value: float) -> void:
	pass # Replace with function body.


func update_canvas_transform() -> void:
	for i in range(3):
		$"Trigger/Transform/Canvas&Layer/Canvas/Position".get_child(i).set_value_no_signal(main.canvas.position[i])
		$"Trigger/Transform/Canvas&Layer/Canvas/Rotation".get_child(i).set_value_no_signal(main.canvas.rotation_degrees[i])


func _on_canvas_transform_value_changed(value: float) -> void:
	var pos: Vector3
	var rot: Vector3
	for i in range(3):
		pos[i] = $"Trigger/Transform/Canvas&Layer/Canvas/Position".get_child(i).value
		rot[i] = deg_to_rad($"Trigger/Transform/Canvas&Layer/Canvas/Rotation".get_child(i).value)
	main.canvas.position = pos
	main.canvas.rotation = rot


func _on_canvas_align_pressed() -> void:
	main.canvas.transform = main.current_surface.layer
	update_canvas_transform()


func update_layer_transform() -> void:
	for i in range(3):
		$"Trigger/Transform/Canvas&Layer/Layer/Position".get_child(i).set_value_no_signal(main.current_surface.layer.origin[i])
		$"Trigger/Transform/Canvas&Layer/Layer/Rotation".get_child(i).set_value_no_signal(rad_to_deg(main.current_surface.layer.basis.get_euler()[i]))


func _on_layer_transform_value_changed(value: float) -> void:
	var pos: Vector3
	var rot: Vector3
	for i in range(3):
		pos[i] = $"Trigger/Transform/Canvas&Layer/Layer/Position".get_child(i).value
		rot[i] = deg_to_rad($"Trigger/Transform/Canvas&Layer/Layer/Rotation".get_child(i).value)
	main.current_surface.set_layer_transform(main.current_surface.current_layer, pos, rot, layer_inherit)



func canvas_input_setter(toggled_on: bool) -> void:
	canvas_input = toggled_on


func layer_input_setter(toggled_on: bool) -> void:
	layer_input = toggled_on


func layer_inherit_setter(toggled_on: bool) -> void:
	layer_inherit = toggled_on


func _on_focus_connectable_toggled(toggled_on: bool) -> void:
	focus_connectable = toggled_on


func _on_uv_toggled(toggled_on: bool) -> void:
	uv = toggled_on
	if uv:
		main.current_surface.face_data.resize(main.current_surface.surface_array[Mesh.ARRAY_VERTEX].size() / 3)
		for i in main.current_surface.face_data.size():
			main.current_surface.face_data[i] = main.current_surface.get_face_data(i)
