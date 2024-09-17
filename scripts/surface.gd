class_name MeshSurface
extends Area3D

signal layer_created
signal layer_removed(idx: int)

@export var geometry: Geometry
@export var mesh: ArrayMesh
@export var vertex_area: Area3D
@export var shape: ConcavePolygonShape3D
@export var material: StandardMaterial3D

var main: MeshCreator
var current_layer := 0
var layer: Transform3D:
	set(x): layer_array[current_layer] = x
	get: return layer_array[current_layer]
var layer_array := [Transform3D.IDENTITY] as Array[Transform3D]
var layer_face := {0: [] as PackedInt32Array}
var layer_visible := PackedInt32Array([0])
var vertex_shape: Array[SphereShape3D]
var surface_array := range(Mesh.ARRAY_MAX).map(func (_x): return null)
var edge_array := range(Mesh.ARRAY_MAX).map(func (_x): return null)
var aurface_data := {Mesh.ARRAY_VERTEX: PackedVector3Array(), Mesh.ARRAY_TEX_UV: PackedVector2Array(), Mesh.ARRAY_COLOR: PackedColorArray()}


func _init() -> void:
	surface_array[Mesh.ARRAY_VERTEX] = [] as PackedVector3Array
	surface_array[Mesh.ARRAY_TEX_UV] = [] as PackedVector2Array
	surface_array[Mesh.ARRAY_COLOR] = [] as PackedColorArray
	surface_array[Mesh.ARRAY_BONES] = [] as PackedInt32Array
	surface_array[Mesh.ARRAY_WEIGHTS] = [] as PackedFloat32Array
	
	edge_array[Mesh.ARRAY_VERTEX] = [] as PackedVector3Array
	edge_array[Mesh.ARRAY_TEX_UV] = [] as PackedVector2Array
	edge_array[Mesh.ARRAY_COLOR] = [] as PackedColorArray
	
	vertex_shape.resize(2056 * 4)
	for i in vertex_shape.size():
		vertex_shape[i] = SphereShape3D.new()
		PhysicsServer3D.shape_set_data(vertex_shape[i].get_rid(), 0.1)



func _ready() -> void:
	PhysicsServer3D.area_set_space(get_rid(), main.class_world[MeshCreator.CLASSES.SURFACE].space)
	PhysicsServer3D.area_set_space($Vertex.get_rid(), main.class_world[MeshCreator.CLASSES.VERTEX].space)
	$Mesh.material_override = material
	$Mesh.skeleton = main.skeleton.get_path()
	$Mesh.skin = main.skin


func add_layer() -> void:
	layer_array.append(Transform3D.IDENTITY)
	layer_face.merge({layer_array.size() - 1: [] as PackedInt32Array})
	layer_visible.append(layer_face.size() - 1)
	
	layer_created.emit()


func layer_vertex_resize(layer_idx := current_layer) -> Error:
	PhysicsServer3D.area_clear_shapes(vertex_area.get_rid())
	for i in layer_face[layer_idx].size():
		for j in 3:
			PhysicsServer3D.area_add_shape(vertex_area.get_rid(),vertex_shape[i * 3 + j].get_rid(), Transform3D(Basis.IDENTITY, surface_array[Mesh.ARRAY_VERTEX][layer_face[layer_idx][i] * 3 + j]))
	return OK


func remove_layer(index: int) -> Error:
	if layer_face.size() == 1: return FAILED
	current_layer = clamp(current_layer, 0, layer_array.size() - 2)
	layer_array.remove_at(index)
	remove_face(layer_face[index])
	layer_face.erase(index)
	while layer_visible.has(index):
		layer_visible.remove_at(layer_visible.find(index))
	for i in layer_visible.size():
		if layer_visible[i] >= index:
			layer_visible[i] -= 1
	var k := layer_face.keys()
	var lf: Dictionary
	k.sort()
	for i in k:
		lf.merge({lf.size(): layer_face[i]})
	layer_face = lf
	
	layer_removed.emit(index)
	
	return OK


func layer_attach_face(index: int, face: PackedInt32Array) -> void:
	for i in face:
		if not layer_face[index].has(i):
			layer_face[index].append(i)


func layer_detach_face(index: int, face: PackedInt32Array) -> void:
	for i in face:
		while layer_face[index].has(i):
			layer_face[index].remove_at(layer_face[index].find(i))
	
	var a: PackedInt32Array
	for i in layer_face:
		for j in face.size():
			if layer_face[i].has(face[j]):
				if not a.has(face[j]):
					a.append(face[j])
	for i in a:
		while face.has(i):
			face.remove_at(face.find(i))
	if a.size():
		add_layer()
		layer_attach_face(layer_face.size()-1, a)


func set_layer_transform(idx: int, pos: Vector3, rot: Vector3, inherit := true) -> void:
	var preset := layer_array[idx]
	layer_array[idx] = Transform3D(Basis.from_euler(rot), pos)
	
	if inherit:
		for i in layer_face[idx]:
			for j in 3:
				var vtx = surface_array[Mesh.ARRAY_VERTEX][i * 3 + j]
				vtx -= preset.origin
				vtx *= preset.basis
				vtx = preset.translated_local(vtx).origin
				surface_array[Mesh.ARRAY_VERTEX][i * 3 + j] = vtx


func translate_layer(idx: int, offset: Vector3, inherit := true) -> void:
	var preset := layer_array[idx]
	layer_array[idx] = preset.translated_local(offset)
	
	if inherit:
		for i in layer_face[idx]:
			for j in 3:
				var vtx = surface_array[Mesh.ARRAY_VERTEX][i * 3 + j]
				vtx -= preset.origin
				vtx *= preset.basis
				vtx = layer_array[idx].translated_local(vtx).origin
				surface_array[Mesh.ARRAY_VERTEX][i * 3 + j] = vtx


func rotate_layer(idx: int, axis: Vector3, angle: float, inherit:= true) -> void:
	var preset := layer_array[idx]
	layer_array[idx] = preset.rotated_local(axis, angle)
	
	if inherit:
		for i in layer_face[idx]:
			for j in 3:
				var vtx = surface_array[Mesh.ARRAY_VERTEX][i * 3 + j]
				vtx -= preset.origin
				vtx *= preset.basis
				vtx = layer_array[idx].translated_local(vtx).origin
				surface_array[Mesh.ARRAY_VERTEX][i * 3 + j] = vtx


func add_face(face: PackedVector3Array, layer_idx := current_layer) -> Error:
	if layer_idx < 0 or not face.size() >= 3 or face.size() % 3 > 0: return FAILED
	for i in face.size():
		PhysicsServer3D.area_add_shape(vertex_area.get_rid(), vertex_shape[PhysicsServer3D.area_get_shape_count(vertex_area.get_rid())].get_rid(), Transform3D(Basis.IDENTITY, face[i]))
	while not layer_face.has(layer_idx):
		add_layer()
	for i in face.size() / 3:
		layer_face[layer_idx].append(surface_array[Mesh.ARRAY_VERTEX].size() / 3 + i)
	
	surface_array[Mesh.ARRAY_VERTEX].append_array(face)
	surface_array[Mesh.ARRAY_COLOR].append_array(range(face.size()).map(func (_x): return Color.WHITE))
	surface_array[Mesh.ARRAY_TEX_UV].append_array(range(face.size()).map(func (_x): return Vector2.ZERO))
	
	edge_array[Mesh.ARRAY_VERTEX].append_array(range(face.size() * 3).map(func (_x): return Vector3.ZERO))
	edge_array[Mesh.ARRAY_COLOR].append_array(range(face.size() * 3).map(func (_x): return Color.WEB_GRAY))
	edge_array[Mesh.ARRAY_TEX_UV].append_array(range(face.size() * 3).map(func (_x): return Vector2.ZERO))
	
	for i in face:
		surface_array[Mesh.ARRAY_BONES].append_array([0, 0, 0, 0])
		surface_array[Mesh.ARRAY_WEIGHTS].append_array([1.0, 0, 0, 0])
	
	layer_vertex_resize(layer_idx)
	return OK


func translate_vertex(idx: PackedInt32Array, offset: Vector3, layer_idx := current_layer) -> void:
	var bas := layer_array[layer_idx].basis
	for i in idx:
		surface_array[Mesh.ARRAY_VERTEX][i] = Transform3D(bas, surface_array[Mesh.ARRAY_VERTEX][i]).translated_local(offset).origin


func rotate_vertex(idx: PackedInt32Array, axis: Vector3, angle: float, layer_idx := current_layer) -> void:
	if not axis: return
	var t := layer_array[layer_idx]
	for i in idx:
		surface_array[Mesh.ARRAY_VERTEX][i] = Transform3D(t.basis, surface_array[Mesh.ARRAY_VERTEX][i] - t.origin).rotated(axis, angle).origin + t.origin


func layer_get_vertex_face(vtx: int) -> int:
	return layer_face[current_layer][(vtx - (vtx % 3)) / 3]


func layer_vertex_to_surface(vtx: PackedInt32Array) -> PackedInt32Array:
	var vertex: PackedInt32Array
	for i in vtx.size():
		vertex.append(layer_get_vertex_face(vtx[i]) * 3 + (vtx[i] % 3))
	return vertex


func remove_face(index: PackedInt32Array, layer_idx := current_layer) -> Error:
	index.sort()
	var sa := surface_array.duplicate(true)
	var ev := edge_array.duplicate(true)
	var lf := layer_face.duplicate(true)
	for i in index.size():
		for j in 3:
			sa[Mesh.ARRAY_VERTEX].remove_at(index[i] * 3 - i * 3)
			sa[Mesh.ARRAY_TEX_UV].remove_at(index[i] * 3 - i * 3)
			sa[Mesh.ARRAY_COLOR].remove_at(index[i] * 3 - i * 3)
			for k in 3:
				ev[Mesh.ARRAY_VERTEX].remove_at(index[i] * 3 * 2 - i * 3 * 2)
				ev[Mesh.ARRAY_TEX_UV].remove_at(index[i] * 3  * 2 - i * 3 * 2)
				ev[Mesh.ARRAY_COLOR].remove_at(index[i] * 3 * 2 - i * 3 * 2)
			for k in range(4):
				sa[Mesh.ARRAY_BONES].remove_at(index[i] * 3 * 4 - i * 3 * 4)
				sa[Mesh.ARRAY_WEIGHTS].remove_at(index[i] * 3 * 4 - i * 3 * 4)
		for j in lf:
			lf[j].sort()
			for k in lf[j].size():
				if lf[j][k] >= index[i] - i:
					lf[j][k] -= 1
	var lf2: Dictionary
	for i in lf:
		lf2.merge({i: [] as PackedInt32Array})
		for j in lf[i]:
			if not lf2[i].has(j) and j >= 0:
				lf2[i].append(j)
	
	layer_face = lf2
	surface_array = sa
	edge_array = ev
	
	layer_vertex_resize(layer_idx)
	return OK


func redraw_surface(layer_idx := current_layer) -> void:
	var a := ArrayMesh.new()
	var sa := surface_array.duplicate(true)
	if sa[Mesh.ARRAY_VERTEX].is_empty() or layer_visible.is_empty():
		RenderingServer.mesh_clear(mesh.get_rid())
		PhysicsServer3D.shape_set_data(shape.get_rid(), {"faces": [], "backface_collision": false})
		return
	
	for i in sa.size():
		if sa[i] == null: continue
		else: sa[i].clear()
	
	for x in layer_visible:
		for i in layer_face[x]:
			for j in 3:
				sa[Mesh.ARRAY_VERTEX].append(surface_array[Mesh.ARRAY_VERTEX][i * 3 + j])
				sa[Mesh.ARRAY_TEX_UV].append(surface_array[Mesh.ARRAY_TEX_UV][i * 3 + j])
				sa[Mesh.ARRAY_COLOR].append(surface_array[Mesh.ARRAY_COLOR][i * 3 + j])
				for k in 4:
					sa[Mesh.ARRAY_BONES].append(surface_array[Mesh.ARRAY_BONES][(i * 3 + j) * 4 + k])
					sa[Mesh.ARRAY_WEIGHTS].append(surface_array[Mesh.ARRAY_WEIGHTS][(i * 3 + j) * 4 + k])
	
	if sa[Mesh.ARRAY_VERTEX].size():
		for i in sa[Mesh.ARRAY_VERTEX].size():
			sa[Mesh.ARRAY_VERTEX][i] = sa[Mesh.ARRAY_VERTEX][i].snapped(Vector3.ONE * 0.1)
		a.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sa)
		var st := SurfaceTool.new()
		st.create_from(a, 0)
		st.generate_normals()
		st.generate_tangents()
		RenderingServer.mesh_clear(mesh.get_rid())
		RenderingServer.mesh_add_surface_from_arrays(mesh.get_rid(), RenderingServer.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	
	WorkerThreadPool.add_task(redraw_edge.bind(layer_idx))


func redraw_edge(layer_idx := current_layer) -> void:
	if not main.get("current_surface") == self: return
	var sa := surface_array.duplicate(true)
	#S.alert(str(edge_array[Mesh.ARRAY_VERTEX].size()))
	var ea := edge_array.duplicate(true)
	ea[Mesh.ARRAY_COLOR].fill(Color(Color.WEB_GRAY, 0.2))
	var st := SurfaceTool.new()
	var lf := layer_face.duplicate(true)
	var p: PackedVector3Array
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_uv(Vector2.ZERO)
	for i in lf[layer_idx].size():
		var color := Color(Color.GREEN, 0.3) if not main.selecting[MeshCreator.CLASSES.SURFACE].has(lf[layer_idx][i]) else Color.TOMATO
		var vtx := [sa[Mesh.ARRAY_VERTEX][lf[layer_idx][i] * 3],  sa[Mesh.ARRAY_VERTEX][lf[layer_idx][i] * 3 + 1], sa[Mesh.ARRAY_VERTEX][lf[layer_idx][i] * 3 + 2]]
		
		for j in 3:
			PhysicsServer3D.area_set_shape_transform(vertex_area.get_rid(), i * 3 + j, Transform3D(Basis.IDENTITY, sa[Mesh.ARRAY_VERTEX][lf[layer_idx][i] * 3 + j]))
			p.append(sa[Mesh.ARRAY_VERTEX][lf[layer_idx][i] * 3 + j])
			ea[Mesh.ARRAY_VERTEX][lf[layer_idx][i] * 3 * 2 + j*2] = vtx[j]
			ea[Mesh.ARRAY_COLOR][lf[layer_idx][i] * 3 * 2 + j*2] = color
			ea[Mesh.ARRAY_VERTEX][lf[layer_idx][i] * 3 * 2 + (j*2+1)] = (vtx + [vtx[0]])[j + 1]
			ea[Mesh.ARRAY_COLOR][lf[layer_idx][i] * 3 * 2 + (j*2+1)] = color

	if p.size() >= 3 and p.size() % 3 == 0:
		PhysicsServer3D.shape_set_data(shape.get_rid(), {"faces": p, "backface_collision": false})
	
	for i in main.selecting[MeshCreator.CLASSES.VERTEX].size():
		main.selected_vertex.set_instance_transform(i, Transform3D(Basis.IDENTITY, surface_array[Mesh.ARRAY_VERTEX][main.selecting[MeshCreator.CLASSES.VERTEX][i]]))
	for i in ea[Mesh.ARRAY_VERTEX].size():
		ea[Mesh.ARRAY_VERTEX][i] = ea[Mesh.ARRAY_VERTEX][i].snapped(Vector3.ONE * 0.1)
	edge_array = ea
	if ea[Mesh.ARRAY_VERTEX]:
		#OS.alert(str(ea[Mesh.ARRAY_VERTEX].size()))
		var av = ea[Mesh.ARRAY_VERTEX].duplicate()
		av.resize(2056)
		#main.edgeshader.set_shader_parameter("array_vertex", av)
		#ea[Mesh.ARRAY_VERTEX].fill(Vector3.ZERO)
		
		RenderingServer.mesh_clear(main.surface_edge.get_rid())
		RenderingServer.mesh_add_surface_from_arrays(main.surface_edge.get_rid(), RenderingServer.PRIMITIVE_LINES, ea)


var face_data: Array[Dictionary]


func get_mdt() -> MeshDataTool:
	var sa := surface_array[Mesh.ARRAY_VERTEX].duplicate() as PackedVector3Array
	var mdt := MeshDataTool.new()
	if sa.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_uv(Vector2.ZERO)
		st.set_color(Color.WHITE)
		for i in sa:
			st.add_vertex(i)
		st.generate_normals()
		st.generate_tangents()
		mdt.create_from_surface(st.commit(), 0)
	return mdt


func get_covertex_face(face: int) -> PackedInt32Array:
	return []


func map_surface_layer(index: int) -> Dictionary:
	return {}


func unwrap_cofaces(face: int) -> void:
	var mdt := get_mdt()
	var sa := surface_array[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var data0 := get_face_data(face, mdt)
	main.perspective_screen.debug_segment.clear()
	main.perspective_screen.debug_string.clear()
	var debug_sg: Array[Dictionary]
	var debug_st: Array[Dictionary]
	var done := PackedInt32Array([face])
	
	for vf_index: int in 3:
		var v := face * 3 + vf_index
		for v2 in sa.size():
			if not sa[v] == sa[v2]: continue
			var v2_face := (v2 - v2 % 3) / 3
			if v2_face in done: continue
			var v2f_index := v2 % 3
			if false and not v2f_index == 0: continue
			var data1 := get_face_data(v2_face, mdt)
			debug_sg.append({"origin": data1["incentre"], "end": data1["incentre"] + data1["normal"] * data1["incircle_radius"], "color": Color(Color.MAGENTA, 0.4)})
			
			var bas0 := data0["basis"][vf_index] as Basis
			var bas1 := data1["basis"][v2f_index] as Basis
			var angle := data1["normal"].signed_angle_to(data0["normal"], bas0.x) as float
			
			if data1["normal"].rotated(bas0.x, angle) == data0["normal"]:
				for i in 3:
					var iv := sa[v2_face * 3 + i] - sa[v]
					iv = iv.rotated(bas0.x, angle)
					sa[v2_face * 3 + i] = iv + sa[v]
				done.append(v2_face)
			
			debug_st.append({"pos": data1["incentre"] + data1["normal"] * data1["incircle_radius"], "string": str(int(rad_to_deg(angle)))})
			for i in 8:
				debug_sg.append({"origin": data1["incentre"] + (data1["basis"][0].x.rotated(data1["normal"], deg_to_rad((360.0 / 8) * i)) * data1["incircle_radius"]).rotated(data1["bisector"][v2f_index].normalized(), deg_to_rad(90)),
				"end": data1["incentre"] + (data1["basis"][0].x.rotated(data1["normal"], deg_to_rad((360.0 / 8) * i + (360.0 / 8))) * data1["incircle_radius"]).rotated(data1["bisector"][v2f_index].normalized(), deg_to_rad(90)), "color": Color(Color.DARK_MAGENTA, 0.4)})
				debug_sg.append({"origin": data1["incentre"] + data1["basis"][0].x.rotated(data1["normal"], deg_to_rad((360.0 / 8) * i)) * data1["incircle_radius"],
				"end": data1["incentre"] + data1["basis"][0].x.rotated(data1["normal"], deg_to_rad((360.0 / 8) * i + (360.0 / 8))) * data1["incircle_radius"], "color": Color(Color.DARK_MAGENTA, 0.4)})
	
	for i in 3:
		debug_sg.append({"origin": data0["vertex"][i], "end": data0["vertex"][i] + data0["bisector"][i], "color": Color(Color.YELLOW, 0.4)})
	debug_sg.append({"origin": data0["incentre"], "end": data0["incentre"] + data0["normal"] * data0["incircle_radius"], "color": Color(Color.MAGENTA, 0.4)})
	for i in 8:
		debug_sg.append({"origin": data0["incentre"] + (data0["basis"][0].x.rotated(data0["normal"], deg_to_rad((360.0 / 8) * i)) * data0["incircle_radius"]).rotated(data0["bisector"][0].normalized(), deg_to_rad(90)),
		"end": data0["incentre"] + (data0["basis"][0].x.rotated(data0["normal"], deg_to_rad((360.0 / 8) * i + (360.0 / 8))) * data0["incircle_radius"]).rotated(data0["bisector"][0].normalized(), deg_to_rad(90)), "color": Color(Color.DARK_MAGENTA, 0.4)})
		debug_sg.append({"origin": data0["incentre"] + data0["basis"][0].x.rotated(data0["normal"], deg_to_rad((360.0 / 8) * i)) * data0["incircle_radius"],
		"end": data0["incentre"] + data0["basis"][0].x.rotated(data0["normal"], deg_to_rad((360.0 / 8) * i + (360.0 / 8))) * data0["incircle_radius"], "color": Color(Color.DARK_MAGENTA, 0.4)})
	
	for i in debug_sg.size():
		debug_sg[i].get_or_add("origin", Vector3.ZERO)
		debug_sg[i].get_or_add("dashed", false)
		debug_sg[i].get_or_add("color", Color.WHITE)
		debug_sg[i].get_or_add("width", 2.0)
		debug_sg[i].get_or_add("dash", 2.0)
	for i in debug_st.size():
		debug_st[i].get_or_add("origin", Vector3.ZERO)
		debug_st[i].get_or_add("color", Color.WHITE)
	
	main.perspective_screen.debug_segment = debug_sg
	main.perspective_screen.debug_string = debug_st
	surface_array[Mesh.ARRAY_VERTEX] = sa
	WorkerThreadPool.add_task(redraw_surface)


func get_face_data(face: int, mdt := get_mdt()) -> Dictionary:
	var normal := mdt.get_face_normal(face)
	var vertex: PackedVector3Array
	for i in [0, 1, 2, 0, 2]:
		vertex.append(mdt.get_vertex(mdt.get_face_vertex(face, i)))
	var bas: Array[Basis]
	for i in 3:
		var x := vertex[i].direction_to(vertex[i + 1])
		bas.append(Basis(x, -x.cross(normal), normal))
	var bisector: PackedVector3Array
	var vertex_lenght: PackedFloat32Array
	for i in 3:
		vertex_lenght.append(vertex[i].distance_to(vertex[i + 1]))
		var dir := vertex[i].direction_to(vertex[i + 1])
		var angle := dir.signed_angle_to(vertex[i].direction_to(vertex[i - 1]), normal)
		bisector.append(dir.rotated(normal, angle * 0.5))
		var bis := bas[0].inverse() * bisector[i]
		var v1 := bas[0].inverse() * (vertex[i + 1] - vertex[i])
		var v2 := bas[0].inverse() * (vertex[i - 1] - vertex[i])
		var intersection = Geometry2D.line_intersects_line(Vector2.ZERO, Vector2(bis.x, bis.y), Vector2(v1.x, v1.y),  Vector2(v1.x, v1.y).direction_to(Vector2(v2.x, v2.y)))
		if intersection:
			bisector[i] *= Vector2.ZERO.distance_to(intersection)
	var incentre = Geometry3D.get_closest_points_between_segments(vertex[0], vertex[0] + bisector[0], vertex[1], vertex[1] + bisector[1])[0]
	var incircle_radius = incentre.distance_to(Geometry3D.get_closest_point_to_segment(incentre, vertex[0], vertex[1]))
	var bas2: Array[Basis]
	for i in 3:
		bas2.append(Basis(
			vertex[i].direction_to(vertex[i + 1]) * vertex[i].distance_to(vertex[i + 1]),
			vertex[i - 1].direction_to(vertex[i]) * vertex[i].distance_to(vertex[i - 1]),
			normal * incircle_radius))
	
	return {"normal": normal, "vertex": vertex.slice(0, 3), "basis": bas, "basis2": bas2, "bisector": bisector, "incentre": incentre, "incircle_radius": incircle_radius, "vertex_lenght": vertex_lenght}


func get_face_in_plane(mdt: MeshDataTool, plane: Plane) -> PackedInt32Array:
	var face: PackedInt32Array
	for i in mdt.get_face_count():
		var a := mdt.get_face_vertex(i, 0)
		var b := mdt.get_face_vertex(i, 1)
		var c := mdt.get_face_vertex(i, 2)
		var vtx := [mdt.get_vertex(a), mdt.get_vertex(b), mdt.get_vertex(c)]
		if not vtx.map(func (x): return plane.has_point(x)).has(false):
			face.append(i)
	return face
