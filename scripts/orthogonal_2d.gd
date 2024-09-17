class_name OrthogonalScreen
extends Screen

var camera_offset := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.velocity.length() > 64:
		match main.control_mode:
			MeshCreator.CONTROL_MODE.MOVE:
				var axis := Vector3.UP
				if event.index == 0: axis = Vector3(event.relative.y, event.relative.x, 0).normalized()
				elif event.index >= 1: axis = Vector3(0, 0, event.relative.y).normalized()
				var angle := 0.1 if event.index <= 1 else 0.0
				for i in main.selecting.size():
					match i:
						MeshCreator.CLASSES.VERTEX:
							main.current_surface.rotate_vertex(main.selecting[i], axis, angle)
							WorkerThreadPool.add_task(main.current_surface.redraw_edge)
						MeshCreator.CLASSES.BONE:
							main.rotate_bone(main.selecting[i], axis, angle)
							WorkerThreadPool.add_task(main.redraw_skeleton)
				for i in main.selecting_g.size():
					match i:
						Geometry.CLASSES.POINT:
							main.current_surface.geometry.rotate_point(main.selecting_g[Geometry.CLASSES.POINT], axis, angle)
						Geometry.CLASSES.LINE:
							if main.pcg.rotation_mode.has(0):
								main.current_surface.geometry.line_rotate_basis(main.selecting_g[Geometry.CLASSES.LINE], axis, angle)
							if main.pcg.rotation_mode.has(1):
								main.current_surface.geometry.line_rotate_direction(main.selecting_g[Geometry.CLASSES.LINE], axis, angle)
						Geometry.CLASSES.CIRCLE:
							main.current_surface.geometry.rotate_circle(main.selecting_g[Geometry.CLASSES.CIRCLE], angle)
				for i in main.selecting: if i.size(): return
				for i in main.selecting_g: if i.size(): return
				if main.pc.canvas_input:
					main.canvas.rotate_object_local(axis, angle)
					main.pc.update_canvas_transform()
				if main.pc.layer_input:
					main.current_surface.rotate_layer(main.current_surface.current_layer, axis, angle, main.pc.layer_inherit)
					main.pc.update_layer_transform()
					WorkerThreadPool.add_task(main.current_surface.redraw_edge)
				return
	
	super._input(event)


func _process(_delta: float) -> void:
	main.orthogonal_camera.transform = main.canvas.transform.translated_local(Vector3(camera_offset.x, camera_offset.y, 100))
	queue_redraw()


func _draw() -> void:
	if main.int32.size():
		var az := [main.connection_point.get_instance_transform(main.int32[0]).origin, main.connection_point.get_instance_transform(main.int32[-1]).origin]
		for i in main.int32.size() - 1:
			var ij := [main.connection_point.get_instance_transform(main.int32[i]).origin, main.connection_point.get_instance_transform(main.int32[i+1]).origin]
			if not main.orthogonal_camera.is_position_behind(ij[0]):
				draw_line(main.orthogonal_camera.unproject_position(ij[0]), main.orthogonal_camera.unproject_position(ij[1]), Color.VIOLET, 2, true)
				draw_circle(main.orthogonal_camera.unproject_position(ij[0]), 8, Color.DARK_VIOLET)
		if not main.orthogonal_camera.is_position_behind(az[1]):
			draw_circle(main.orthogonal_camera.unproject_position(az[1]), 8, Color.DARK_VIOLET)
		draw_line(main.orthogonal_camera.unproject_position(az[1]), main.orthogonal_camera.unproject_position(az[0]), Color.VIOLET, 2, true)
	var color: PackedColorArray
	if Geometry2D.triangulate_polygon(point2d):
		color.resize(point2d.size())
		color.fill(Color(Color.AQUA, 0.4))
		draw_polygon(point2d, color)
	if point2d.size() >= 2:
		draw_polyline(point2d, Color(Color.AQUA, 0.4), 2, true)
