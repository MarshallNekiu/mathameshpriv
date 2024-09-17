class_name GeometryControl
extends GridContainer

@export var main: MeshCreator

var instance_mode := Geometry.CLASSES.POINT
var rotation_mode := [0]


func _on_instance_mode_item_selected(index: int) -> void:
	main.control_mode = [MeshCreator.CONTROL_MODE.ADD, MeshCreator.CONTROL_MODE.CONNECT][index]


func _on_instance_class_item_selected(index: int) -> void:
	instance_mode = [
		Geometry.CLASSES.POINT, Geometry.CLASSES.LINE, Geometry.CLASSES.CIRCLE
	][index]


func _on_move_pressed() -> void:
	main.control_mode = MeshCreator.CONTROL_MODE.MOVE


func _on_focus_mode_item_selected(index: int) -> void:
	main.control_mode = [MeshCreator.CONTROL_MODE.SELECT, MeshCreator.CONTROL_MODE.DESELECT][index]


func _on_rotation_mode_changed() -> void:
	rotation_mode.clear()
	if $VBC/Rotation.button_pressed: rotation_mode.append(0)
	if $VBC/Direction.button_pressed: rotation_mode.append(1)
	


func _on_reverse_pressed() -> void:
	for i in main.selecting_g.size():
		if not i == Geometry.CLASSES.POINT:
			main.current_surface.geometry.reverse(main.selecting_g[i])


func _on_rest_pressed() -> void:
	for i in main.selecting_g.size():
		main.current_surface.geometry.rest(main.selecting_g[i])
