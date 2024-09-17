class_name MeshCreator
extends Node

enum TASK_GROUP{REDRAW_SURFACE, REDRAW_SURFACE_EDGE, REDRAW_SKELETON}
enum INPUT_REQUEST{TRANSLATE, ROTATE, TRANSLATE_ORTHOGONAL}
enum CONTROL_MODE{ADD, CONNECT, SELECT, DESELECT, MOVE, PAINT, ERASE}
enum CLASSES{GEOMETRY, SURFACE, VERTEX, BONE}
enum VERTEX_DATA{UV, COLOR, BONE, WEIGHT, INDEX}

@export var debug_mesh: MeshInstance3D
var debug_segment_data: Dictionary
@export var canvas: MeshInstance3D
@export var skeleton: Skeleton3D
@export var skeleton_shape: Area3D
@export var skeleton_mesh:  ArrayMesh
@export var skeleton_bone: ArrayMesh
@export var skeleton_aabb: ArrayMesh 
@export var selected_bone: MultiMesh
@export var connection_point: MultiMesh
@export var surface_edge: ArrayMesh
@export var selected_vertex: MultiMesh
@export var perspective_screen: PerspectiveScreen
@export var perspective_camera: Camera3D
@export var orthogonal_screen: OrthogonalScreen
@export var orthogonal_camera: Camera3D
@export var pc: ControlPanel
@export var pcg: GeometryControl

var input_request := {INPUT_REQUEST.TRANSLATE: -1, INPUT_REQUEST.ROTATE: -1, INPUT_REQUEST.TRANSLATE_ORTHOGONAL: 1}
var control_mode := CONTROL_MODE.ADD
var instance_mode := CLASSES.GEOMETRY
var focus_mode := PackedInt32Array([CLASSES.VERTEX])
var paint_mode := PackedInt32Array([VERTEX_DATA.COLOR])

var class_world: Array[World3D]
var skin := Skin.new()
var current_surface: MeshSurface
var int32: PackedInt32Array
var selecting: Array[PackedInt32Array]
var selecting_g: Array[PackedInt32Array]


func _init() -> void:
	selecting.resize(MeshCreator.CLASSES.size())
	selecting_g.resize(Geometry.CLASSES.size())
	for i in CLASSES.size(): class_world.append(World3D.new())


func _ready() -> void:
	PhysicsServer3D.area_set_space($World/Node3D/Shape/Skeleton.get_rid(), class_world[CLASSES.BONE].space)
	add_bone(Vector3.ZERO)
	
	pc._on_surface_add_pressed()


func _process(delta: float) -> void:
	$World/Node3D/CBasis.transform = Transform3D(canvas.transform.basis * 0.5, canvas.transform.origin)
	$World/Node3D/PBasis.transform = Transform3D(current_surface.layer.basis * 0.5, current_surface.layer.origin)
	
	$Label.text = str(str(selecting_g).replace("],", "],\n"))


func debug():
	var arr := ArrayMesh.new()
	for i in debug_segment_data:
		var sa: Array
		sa.resize(Mesh.ARRAY_MAX)
		sa[Mesh.ARRAY_VERTEX] = PackedVector3Array()
		sa[Mesh.ARRAY_VERTEX] = debug_segment_data[i]["segment"]
		sa[Mesh.ARRAY_TEX_UV] = PackedVector2Array(range(debug_segment_data[i]["segment"].size()))
		sa[Mesh.ARRAY_COLOR] = PackedColorArray(range(debug_segment_data[i]["segment"].size()))
		sa[Mesh.ARRAY_COLOR].fill(debug_segment_data[i].get("color", Color.WHITE))
		
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, sa)
		arr.surface_set_name(arr.get_surface_count() - 1, str(i))
	
	debug_mesh.mesh = arr


func clear_debug(key := ""):
	var dm := debug_mesh.mesh.duplicate() as ArrayMesh
	var sa: Array
	var san: PackedStringArray
	for i in dm.get_surface_count():
		if dm.surface_get_name(i) == key or key == "":
			continue
		sa.append(dm.surface_get_arrays(i))
		san.append(dm.surface_get_name(i))
	dm.clear_surfaces()
	for i in sa.size():
		dm.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, sa[i])
		dm.surface_set_name(i, san[i])
	debug_mesh.mesh = dm


func skeleton_make_mesh() -> void:
	var tree: Dictionary
	for i in skeleton.get_bone_count(): tree.merge({i: skeleton.get_bone_children(i)})
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_uv(Vector2.ZERO)
	for i in tree:
		for j in tree[i]:
			st.set_color(Color.WHITE)
			st.set_bones([i, 0, 0, 0])
			st.set_weights([1.0, 0, 0, 0])
			st.add_vertex(Vector3.ZERO)
			
			st.set_color(Color.YELLOW)
			st.set_bones([j, 0, 0, 0])
			st.set_weights([1.0, 0, 0, 0])
			st.add_vertex(Vector3.ZERO)
		for j in skeleton_bone.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			st.set_color(Color.WHITE)
			st.set_bones([i, 0, 0, 0])
			st.set_weights([1.0, 0, 0, 0])
			st.add_vertex(j)
	
	if st.commit_to_arrays()[Mesh.ARRAY_VERTEX]:
		var skin2 := Skin.new()
		for i in skin.get_bind_count():
			skin2.add_named_bind(skin.get_bind_name(i), Transform3D.IDENTITY)
		$World/Node3D/SkeletonMesh.skin = skin2
		skeleton_mesh.clear_surfaces()
		skeleton_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, st.commit_to_arrays())


func add_surface(surface_name := "Surface") -> void:
	var new_surface_shape := load("res://scenes/surface.tscn").instantiate() as MeshSurface
	new_surface_shape.name = surface_name
	new_surface_shape.set("main", self)
	
	$World/Node3D/Shape/Mesh.add_child(new_surface_shape, true)
	new_surface_shape.owner = self


func get_surface(index: int) -> MeshSurface: return $World/Node3D/Shape/Mesh.get_child(index)


func get_surface_count() -> int: return $World/Node3D/Shape/Mesh.get_child_count()


func get_surface_index(surface_name: String) -> int: return $World/Node3D/Shape/Mesh.find_child(surface_name).get_index()


func set_surface_name(index: int, new_name: String) -> void: $World/Node3D/Shape/Mesh.get_child(index).name = new_name


func add_bone(coord: Vector3, bone_name := "Bone") -> void:
	var new_bone := CollisionShape3D.new()
	new_bone.name = bone_name
	new_bone.shape = BoxShape3D.new()
	new_bone.shape.size *= 0.1
	$World/Node3D/Shape/Skeleton.add_child(new_bone, true)
	
	skeleton.add_bone(new_bone.name)
	skeleton.set_bone_pose_position(skeleton.get_bone_count()-1, coord)
	
	skin.add_named_bind(new_bone.name, Transform3D(Basis.IDENTITY, coord))
	
	new_bone.set.bind("position", coord).call_deferred()
	set_bone_rest.bind([skeleton.get_bone_count()-1]).call_deferred()


func set_bone_pose(bone: int, pose: Transform3D) -> void:
	skeleton.set_bone_global_pose(bone, pose)
	for i in PhysicsServer3D.area_get_shape_count(skeleton_shape.get_rid()):
		PhysicsServer3D.area_set_shape_transform(skeleton_shape.get_rid(), i, skeleton.get_bone_global_pose(i))


func translate_bone(bone: PackedInt32Array, offset: Vector3) -> void:
	for i in bone:
		skeleton.set_bone_global_pose(i, Transform3D(skeleton.get_bone_global_pose(i).basis, skeleton.get_bone_global_pose(i).origin + offset))
	for i in PhysicsServer3D.area_get_shape_count(skeleton_shape.get_rid()):
		PhysicsServer3D.area_set_shape_transform(skeleton_shape.get_rid(), i, skeleton.get_bone_global_pose(i))


func rotate_bone(bone: PackedInt32Array, axis: Vector3, angle: float) -> void:
	if not axis: return
	for i in bone:
		skeleton.set_bone_pose_rotation(i, Basis(skeleton.get_bone_pose_rotation(i)).rotated(axis, angle).get_rotation_quaternion())
	for i in PhysicsServer3D.area_get_shape_count(skeleton_shape.get_rid()):
		PhysicsServer3D.area_set_shape_transform(skeleton_shape.get_rid(), i, skeleton.get_bone_global_pose(i))


func set_bone_rest(bone := selecting[CLASSES.BONE]):
	for i in bone:
		skeleton.set_bone_rest(i, skeleton.get_bone_pose(i))
		skin.set_bind_pose(i, skeleton.get_bone_global_pose(i).inverse())


func redraw_skeleton() -> void:
	var st := SurfaceTool.new()
	
	var box := BoxMesh.new()
	box.size *= 0.1
	var x := [Vector3.ZERO, Vector3.ZERO]
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in skin.get_bind_count():
		var p := PhysicsServer3D.area_get_shape_transform(skeleton_shape.get_rid(), i).origin as Vector3
		for j in range(3):
			if p[j]  > x[0][j]:
				x[0][j] = p[j]
			elif p[j] < x[1][j]:
				x[1][j] = p[j]
			box.size[j] = x[0][j] - x[1][j]
	for i in box.get_faces():
		st.set_uv(Vector2.ZERO)
		st.set_color(Color(1, 1, 1, 0.15))
		st.add_vertex(i + x[0].lerp(x[1], 0.5))
	
	for i in selecting[CLASSES.BONE].size():
		selected_bone.set_instance_transform(i, PhysicsServer3D.area_get_shape_transform(skeleton_shape.get_rid(), selecting[CLASSES.BONE][i]))
	
	RenderingServer.mesh_clear(skeleton_aabb.get_rid())
	RenderingServer.mesh_add_surface_from_arrays(skeleton_aabb.get_rid(), RenderingServer.PRIMITIVE_TRIANGLE_STRIP, st.commit_to_arrays())


func _on_file_dialog_confirmed() -> void:
	var node := Node3D.new()
	node.name = "Node3D"
	var sk = skeleton.duplicate()
	var mesh := MeshInstance3D.new()
	var arr := ArrayMesh.new()
	for i: MeshSurface in $World/Node3D/Shape/Mesh.get_children():
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, i.surface_array)
		arr.surface_set_material(arr.get_surface_count()-1, i.material)
		arr.surface_set_name(arr.get_surface_count()-1, i.name)
	mesh.mesh = arr
	mesh.skeleton = NodePath("..")
	mesh.skin = skin
	
	var animation := AnimationPlayer.new()
	
	skeleton.add_child(mesh, true)
	node.add_child(sk, true)
	node.add_child(animation, true)
	
	sk.owner = node
	mesh.owner = node
	animation.owner = node
	
	var packer := PackedScene.new()
	packer.pack(node)
	
	FileAccess.open($FileDialog.current_path, FileAccess.WRITE)
	ResourceSaver.save(packer, $FileDialog.current_path)
	
	node.queue_free()


func _on_component_submitted(mesh: Mesh) -> void:
	await current_surface.add_face(mesh.get_faces())
	current_surface.redraw_surface()
