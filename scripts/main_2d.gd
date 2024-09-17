class_name PerspectiveScreen
extends Screen

var debug_string: Array[Dictionary]
var debug_segment: Array[Dictionary]

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.velocity.length() > 64:
		match main.control_mode:
			MeshCreator.CONTROL_MODE.MOVE:
				var offset := Vector3.ZERO
				if event.index == 0: offset = Vector3(event.relative.x, -event.relative.y, 0) * 0.02
				elif event.index == 1: offset = Vector3(0, 0, event.relative.y) * 0.02
				for i in main.selecting.size():
					match i:
						MeshCreator.CLASSES.BONE:
							main.translate_bone(main.selecting[i], offset)
							WorkerThreadPool.add_task(main.redraw_skeleton)
						MeshCreator.CLASSES.VERTEX:
							main.current_surface.translate_vertex(main.selecting[i], offset)
							WorkerThreadPool.add_task(main.current_surface.redraw_edge)
				for i in main.selecting_g.size():
					match i:
						Geometry.CLASSES.POINT:
							main.current_surface.geometry.translate_point(main.selecting_g[Geometry.CLASSES.POINT], offset)
						Geometry.CLASSES.LINE:
							main.current_surface.geometry.translate_line(main.selecting_g[Geometry.CLASSES.LINE], offset.x)
						Geometry.CLASSES.CIRCLE:
							main.current_surface.geometry.circle_translate_value(main.selecting_g[Geometry.CLASSES.CIRCLE], offset.x)
				for i in main.selecting: if i.size(): return
				for i in main.selecting_g: if i.size(): return
				if main.pc.canvas_input:
					main.canvas.translate_object_local(offset)
					main.pc.update_canvas_transform()
				if main.pc.layer_input:
					main.current_surface.translate_layer(main.current_surface.current_layer, offset, main.pc.layer_inherit)
					main.pc.update_layer_transform()
					(main.current_surface.redraw_edge).call()
				return
	
	super._input(event)


func _process(_delta: float) -> void:
	queue_redraw()

var deb := Vector3.ZERO
func _draw() -> void:
	var x := get_viewport_rect().size * 0.5
	if main.int32.size():
		var az := [main.connection_point.get_instance_transform(main.int32[0]).origin, main.connection_point.get_instance_transform(main.int32[-1]).origin]
		for i in range(main.int32.size()-1):
			var ij := [main.connection_point.get_instance_transform(main.int32[i]).origin, main.connection_point.get_instance_transform(main.int32[i+1]).origin]
			if not main.perspective_camera.is_position_behind(ij[0]):
				draw_line(main.perspective_camera.unproject_position(ij[0]), main.perspective_camera.unproject_position(ij[1]), Color.VIOLET, 2, true)
				draw_circle(main.perspective_camera.unproject_position(ij[0]), 8, Color.DARK_VIOLET)
		if not main.perspective_camera.is_position_behind(az[1]):
			draw_circle(main.perspective_camera.unproject_position(az[1]), 8, Color.DARK_VIOLET)
		draw_line(main.perspective_camera.unproject_position(az[1]), main.perspective_camera.unproject_position(az[0]), Color.VIOLET, 2, true)
	
	var color: PackedColorArray
	if point2d.size() >= 2:
		draw_polyline(point2d, Color(Color.AQUA, 0.4), 2, true)
		if Geometry2D.triangulate_polygon(point2d):
			color.resize(point2d.size())
			color.fill(Color(Color.AQUA, 0.4))
			draw_polygon(point2d, color)
	
	for i in debug_string:
		if main.perspective_camera.is_position_behind(i["origin"]): continue
		draw_string(SystemFont.new(), main.perspective_camera.unproject_position(i["pos"]), i["string"], 0, -1,  16, i["color"])
	for i in debug_segment:
		if main.perspective_camera.is_position_behind(i["origin"]): continue
		if i.get("dashed"):
			draw_dashed_line(main.perspective_camera.unproject_position(i["origin"]),
			main.perspective_camera.unproject_position(i["end"]),
			i["color"],
			i["width"],
			i["dash"],
			true, true)
		else:
			draw_line(main.perspective_camera.unproject_position(i["origin"]),
			main.perspective_camera.unproject_position(i["end"]),
			i["color"], i["width"],
			true)
