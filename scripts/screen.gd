class_name Screen
extends Node2D

@export var main: MeshCreator

var point2d: PackedVector2Array
var geometry_connector := -1


func _input(event: InputEvent) -> void:
	var camera := get_viewport().get_camera_3d()
	if event is InputEventScreenTouch:
		if event.is_pressed():
			match main.control_mode:
				MeshCreator.CONTROL_MODE.ADD:
					match main.pcg.instance_mode:
						Geometry.CLASSES.POINT:
							var target = plane_intersect_ray(event.position)
							if not target == null:
								main.current_surface.geometry.add_point(Transform3D(Basis.IDENTITY, target))
						Geometry.CLASSES.LINE:
							var target := cast_ray2(event.position, MeshCreator.CLASSES.GEOMETRY)
							if target.size():
								main.current_surface.geometry.add_line(target.shape)
				MeshCreator.CONTROL_MODE.CONNECT:
							var target := cast_ray2(event.position, MeshCreator.CLASSES.GEOMETRY)
							if target.size():
								if geometry_connector == -1:
									geometry_connector = target["shape"]
								elif not geometry_connector == target["shape"]:
									match main.pcg.instance_mode:
										Geometry.CLASSES.LINE:
											main.current_surface.geometry.add_line(geometry_connector, target["shape"])
										Geometry.CLASSES.CIRCLE:
											main.current_surface.geometry.add_circle(geometry_connector, target["shape"])
									geometry_connector = -1
				MeshCreator.CONTROL_MODE.CONNECT:
					if main.connection_point.visible_instance_count + (main.selected_vertex.visible_instance_count if main.pc.focus_connectable else 0) >= 3:
						var p := Plane(main.canvas.basis.z, main.canvas.transform.origin)
						var found := false
						for i in main.connection_point.visible_instance_count:
							var t := main.connection_point.get_instance_transform(i)
							if not p.is_point_over(t.origin): continue
							if main.int32.size():
								if camera.is_position_behind(t.origin): continue
								if camera.unproject_position(t.origin).distance_to(event.position) < 32:
									if camera.unproject_position(main.connection_point.get_instance_transform(main.int32[-1]).origin).distance_to(event.position) >= 32:
										main.int32.append(i)
										found = true
										break
							elif camera.is_position_behind(t.origin): continue
							elif camera.unproject_position(main.connection_point.get_instance_transform(i).origin).distance_to(event.position) < 32:
								main.int32.append(i)
								found = true
								break
						if main.pc.focus_connectable and not found:
							for i in main.selected_vertex.visible_instance_count:
								var t := main.current_surface.surface_array[Mesh.ARRAY_VERTEX][main.selecting[MeshCreator.CLASSES.VERTEX][i]] as Vector3
								if not p.is_point_over(t): continue
								if main.int32.size():
									if camera.is_position_behind(t): continue
									if camera.unproject_position(t).distance_to(event.position) < 32:
										if camera.unproject_position(main.connection_point.get_instance_transform(main.int32[-1]).origin).distance_to(event.position) >= 32:
											main.connection_point.visible_instance_count += 1
											main.connection_point.set_instance_transform(main.connection_point.visible_instance_count - 1, Transform3D(Basis.IDENTITY, t))
											main.int32.append(main.connection_point.visible_instance_count - 1)
											break
								elif camera.is_position_behind(t): continue
								elif camera.unproject_position(main.connection_point.get_instance_transform(i).origin).distance_to(event.position) < 32:
									main.connection_point.visible_instance_count += 1
									main.connection_point.set_instance_transform(main.connection_point.visible_instance_count - 1, Transform3D(Basis.IDENTITY, t))
									main.int32.append(main.connection_point.visible_instance_count - 1)
									break
				MeshCreator.CONTROL_MODE.SELECT:
					if main.pc.uv:
						var target := cast_ray(event.position, MeshCreator.CLASSES.SURFACE)
						if target.size():
							main.current_surface.unwrap_cofaces(target["face_index"])
				
					if event.double_tap:
						main.selecting.clear()
						main.selecting.resize(MeshCreator.CLASSES.size())
						main.selecting_g.clear()
						main.selecting_g.resize(Geometry.CLASSES.size())
					if main.instance_mode == MeshCreator.CLASSES.GEOMETRY:
						var target := cast_ray2(event.position, MeshCreator.CLASSES.GEOMETRY)
						if target.size() and not main.selecting_g[main.current_surface.geometry.data[target.shape].class].has(target.shape):
							main.selecting_g[main.current_surface.geometry.data[target.shape].class].append(target.shape)
					elif main.focus_mode.has(MeshCreator.CLASSES.SURFACE):
						var target :=  cast_ray(event.position, MeshCreator.CLASSES.SURFACE)
						if target.size() and not main.selecting[MeshCreator.CLASSES.SURFACE].has(target["face_index"]):
							main.selecting[MeshCreator.CLASSES.SURFACE].append(target["face_index"])
							WorkerThreadPool.add_task(main.current_surface.redraw_edge)
						
					point2d = [event.position]
				MeshCreator.CONTROL_MODE.DESELECT:
					if event.double_tap:
						main.selecting.clear()
						main.selecting.resize(MeshCreator.CLASSES.size())
					if main.focus_mode.has(MeshCreator.CLASSES.SURFACE):
						var target := cast_ray(event.position, MeshCreator.CLASSES.SURFACE)
						if target.size() and main.selecting[MeshCreator.CLASSES.SURFACE].has(main.current_surface.layer_face[main.current_surface.current_layer][target["face_index"]]):
							main.selecting[MeshCreator.CLASSES.SURFACE].remove_at(main.selecting[MeshCreator.CLASSES.SURFACE].find(main.current_surface.layer_face[main.current_surface.current_layer][target["face_index"]]))
							WorkerThreadPool.add_task(main.current_surface.redraw_edge)
					point2d = [event.position]
		elif event.is_released():
			main.current_surface.geometry.recalculate()
			match main.control_mode:
				MeshCreator.CONTROL_MODE.ADD:
					var target = Plane(main.canvas.basis.z, main.canvas.transform.origin).intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
					if not target == null:
						match main.instance_mode:
							MeshCreator.CLASSES.VERTEX:
								target = cast_ray(event.position, MeshCreator.CLASSES.SURFACE).get("position", target)
								main.connection_point.visible_instance_count += 1
								main.connection_point.set_instance_transform(main.connection_point.visible_instance_count-1, Transform3D(Basis.IDENTITY, target))
							MeshCreator.CLASSES.BONE:
								main.add_bone(target)
								WorkerThreadPool.add_task(main.redraw_skeleton)
				MeshCreator.CONTROL_MODE.CONNECT:
					if main.int32.size() >= 3:
						var vtx: Array
						for i in range(1, main.int32.size()-1):
							vtx.append_array([main.connection_point.get_instance_transform(main.int32[0]).origin,
							main.connection_point.get_instance_transform(main.int32[i]).origin,
							main.connection_point.get_instance_transform(main.int32[i+1]).origin])
						await main.current_surface.add_face(vtx)
						main.current_surface.redraw_surface()
					main.int32.clear()
				MeshCreator.CONTROL_MODE.SELECT:
					if main.focus_mode.has(MeshCreator.CLASSES.VERTEX):
						var vertex := ([cast_ray(point2d[0])] if point2d.size() == 1 else cast_polygon(point2d)).filter(func (x):
							return x.size()).map(func (x): return main.current_surface.layer_vertex_to_surface([x["shape"]])[0]) as PackedInt32Array
						for i in vertex:
							if not main.selecting[MeshCreator.CLASSES.VERTEX].has(i):
								main.selecting[MeshCreator.CLASSES.VERTEX].append(i)
						for i in main.selecting.size(): main.selecting[i].sort()
					if main.focus_mode.has(MeshCreator.CLASSES.BONE):
						var bone := [cast_ray(point2d[0], MeshCreator.CLASSES.BONE)] if point2d.size() == 1 else cast_polygon(point2d, MeshCreator.CLASSES.BONE, main.skeleton.get_bone_count())
						for i in bone:
							if i.size() and not main.selecting[MeshCreator.CLASSES.BONE].has(i["shape"]):
								main.selecting[MeshCreator.CLASSES.BONE].append(i["shape"])
					main.selected_vertex.visible_instance_count = main.selecting[MeshCreator.CLASSES.VERTEX].size()
					for i in main.selecting[MeshCreator.CLASSES.VERTEX].size():
						var vtx = (main.selecting[MeshCreator.CLASSES.VERTEX][i])
						if not main.selecting[MeshCreator.CLASSES.SURFACE].has((vtx - vtx % 3) / 3):
							main.selecting[MeshCreator.CLASSES.SURFACE].append((vtx - vtx % 3) / 3)
					main.selected_bone.visible_instance_count = main.selecting[MeshCreator.CLASSES.BONE].size()
					point2d.clear()
					WorkerThreadPool.add_task(main.redraw_skeleton)
					WorkerThreadPool.add_task(main.current_surface.redraw_edge)
				MeshCreator.CONTROL_MODE.DESELECT:
					if main.focus_mode.has(MeshCreator.CLASSES.VERTEX):
						var vertex := ([cast_ray(point2d[0])] if point2d.size() == 1 else cast_polygon(point2d)).filter(func (x):
							return x.size()).map(func (x): return main.current_surface.layer_vertex_to_surface([x["shape"]])[0]) as PackedInt32Array
						for i in vertex:
							if main.selecting[MeshCreator.CLASSES.VERTEX].has(i):
								main.selecting[MeshCreator.CLASSES.VERTEX].remove_at(main.selecting[MeshCreator.CLASSES.VERTEX].find(i))
							if main.selecting[MeshCreator.CLASSES.SURFACE].has((i - i % 3) / 3):
								main.selecting[MeshCreator.CLASSES.SURFACE].remove_at(main.selecting[MeshCreator.CLASSES.SURFACE].find((i - i % 3) / 3))
						for i in main.selecting.size(): main.selecting[i].sort()
					if main.focus_mode.has(MeshCreator.CLASSES.BONE):
						var bone := [cast_ray(point2d[0], MeshCreator.CLASSES.BONE)] if point2d.size() == 1 else cast_polygon(point2d, MeshCreator.CLASSES.BONE, main.skeleton.get_bone_count())
						for i in bone:
							if i.size() and not main.selecting[MeshCreator.CLASSES.BONE].has(i["shape"]):
								main.selecting[MeshCreator.CLASSES.BONE].append(i["shape"])
					main.selected_vertex.visible_instance_count = main.selecting[MeshCreator.CLASSES.VERTEX].size()
					main.selected_bone.visible_instance_count = main.selecting[MeshCreator.CLASSES.BONE].size()
					point2d.clear()
					WorkerThreadPool.add_task(main.redraw_skeleton)
					WorkerThreadPool.add_task(main.current_surface.redraw_edge)
				MeshCreator.CONTROL_MODE.MOVE:
					WorkerThreadPool.add_task(main.redraw_skeleton)
					main.current_surface.redraw_surface()
	elif event is InputEventScreenDrag:
		match main.control_mode:
			MeshCreator.CONTROL_MODE.ADD:
				var target = Plane(main.canvas.basis.z, main.canvas.transform.origin).intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
				if not target == null:
					match main.instance_mode:
						MeshCreator.CLASSES.VERTEX:
							target = cast_ray(event.position, MeshCreator.CLASSES.SURFACE).get("position", target)
							if main.connection_point.visible_instance_count:
								if camera.unproject_position(main.connection_point.get_instance_transform(main.connection_point.visible_instance_count-1).origin).distance_to(camera.unproject_position(target)) >= 64:
									main.connection_point.visible_instance_count += 1
									main.connection_point.set_instance_transform(main.connection_point.visible_instance_count-1, Transform3D(Basis.IDENTITY, target))
							else:
								main.connection_point.visible_instance_count += 1
								main.connection_point.set_instance_transform(main.connection_point.visible_instance_count-1, Transform3D(Basis.IDENTITY, target))
			MeshCreator.CONTROL_MODE.SELECT:
				if main.focus_mode.has(MeshCreator.CLASSES.SURFACE):
					var target := cast_ray(event.position, MeshCreator.CLASSES.SURFACE)
					if target.size() and not main.selecting[MeshCreator.CLASSES.SURFACE].has(main.current_surface.layer_face[main.current_surface.current_layer][target["face_index"]]):
						main.selecting[MeshCreator.CLASSES.SURFACE].append(main.current_surface.layer_face[main.current_surface.current_layer][target["face_index"]])
						WorkerThreadPool.add_task(main.current_surface.redraw_edge)
					return
				if point2d.size():
					if point2d[-1].distance_to(event.position) >= 16:
						point2d.append(event.position)
				else:
					point2d.append(event.position)
			MeshCreator.CONTROL_MODE.DESELECT:
				if main.focus_mode.has(MeshCreator.CLASSES.SURFACE):
					var target := cast_ray(event.position, MeshCreator.CLASSES.SURFACE)
					if target.size() and main.selecting[MeshCreator.CLASSES.SURFACE].has(main.current_surface.layer_face[main.current_surface.current_layer][target["face_index"]]):
						main.selecting[MeshCreator.CLASSES.SURFACE].remove_at(main.selecting[MeshCreator.CLASSES.SURFACE].find(main.current_surface.layer_face[main.current_surface.current_layer][target["face_index"]]))
						WorkerThreadPool.add_task(main.current_surface.redraw_edge)
					return
				if point2d.size():
					if point2d[-1].distance_to(event.position) >= 16:
						point2d.append(event.position)
				else:
					point2d.append(event.position)
			MeshCreator.CONTROL_MODE.CONNECT:
				if main.connection_point.visible_instance_count + (main.selecting[MeshCreator.CLASSES.VERTEX].size() if main.pc.focus_connectable else 0) >= 3:
					var p := Plane(main.canvas.basis.z, main.canvas.transform.origin)
					var found := false
					for i in main.connection_point.visible_instance_count:
						var t := main.connection_point.get_instance_transform(i)
						if not p.is_point_over(t.origin): continue
						if main.int32.size():
							if camera.is_position_behind(t.origin): continue
							if camera.unproject_position(t.origin).distance_to(event.position) < 32:
								if camera.unproject_position(main.connection_point.get_instance_transform(main.int32[-1]).origin).distance_to(event.position) >= 32:
									main.int32.append(i)
									found = true
									break
						elif camera.is_position_behind(t.origin): continue
						elif camera.unproject_position(main.connection_point.get_instance_transform(i).origin).distance_to(event.position) < 32:
							main.int32.append(i)
							found = true
							break
					if main.pc.focus_connectable and not found:
						for i in main.selecting[MeshCreator.CLASSES.VERTEX].size():
							var v := main.current_surface.surface_array[Mesh.ARRAY_VERTEX][main.selecting[MeshCreator.CLASSES.VERTEX][i]] as Vector3
							if not p.is_point_over(v): continue
							if main.int32.size():
								if camera.unproject_position(v).distance_to(event.position) < 32:
									if camera.is_position_behind(v): continue
									if camera.unproject_position(main.connection_point.get_instance_transform(main.int32[-1]).origin).distance_to(event.position) >= 32:
										main.connection_point.visible_instance_count += 1
										main.connection_point.set_instance_transform(main.connection_point.visible_instance_count - 1, Transform3D(Basis.IDENTITY, v))
										main.int32.append(main.connection_point.visible_instance_count - 1)
										break
							elif camera.is_position_behind(v): continue
							elif camera.unproject_position(main.connection_point.get_instance_transform(i).origin).distance_to(event.position) < 32:
								main.connection_point.visible_instance_count += 1
								main.connection_point.set_instance_transform(main.connection_point.visible_instance_count - 1, Transform3D(Basis.IDENTITY, v))
								main.int32.append(main.connection_point.visible_instance_count - 1)
								break


func cast_ray(point: Vector2, focus := MeshCreator.CLASSES.VERTEX, canvas := main.canvas.transform) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	var target = Plane(canvas.basis.z, canvas.origin).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if target == null: return {}
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collide_with_areas = true
	ray.from = camera.project_ray_origin(point)
	ray.to = target
	
	return main.class_world[focus].direct_space_state.intersect_ray(ray)


func cast_ray2(point: Vector2, mask: int, canvas := main.canvas.transform) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	var target = Plane(canvas.basis.z, canvas.origin).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if target == null: return {}
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = pow(2, mask)
	ray.collide_with_areas = true
	ray.from = camera.project_ray_origin(point)
	ray.to = target
	
	return camera.get_world_3d().direct_space_state.intersect_ray(ray)


func plane_intersect_ray(point: Vector2, mat := main.canvas.transform) -> Variant:
	var camera := get_viewport().get_camera_3d()
	return Plane(mat.basis.z, mat.origin).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))


func cast_polygon(points: PackedVector2Array, focus := MeshCreator.CLASSES.VERTEX, max_result := main.current_surface.layer_face[main.current_surface.current_layer].size() * 3 as int, canvas := main.canvas.transform) -> Array[Dictionary]:
	var camera := get_viewport().get_camera_3d()
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.collide_with_areas = true
	shape.shape = ConvexPolygonShape3D.new()
	var polygon: Array[PackedVector2Array]
	if Geometry2D.triangulate_polygon(points):
		polygon = Geometry2D.decompose_polygon_in_convex(points)
	var result := [] as Array[Dictionary]
	for i in polygon:
		var p := PackedVector3Array([camera.global_position])
		for j in i:
			p.append_array([Plane(canvas.basis.z, canvas.origin).intersects_ray(camera.project_ray_origin(j), camera.project_ray_normal(j))].filter(func (x): return not x == null))
		shape.shape.points = p
		var mapped := [] as Array[Dictionary]
		mapped.append_array(main.class_world[focus].direct_space_state.intersect_shape(shape, max_result))
		result.append_array(mapped)
	return result
