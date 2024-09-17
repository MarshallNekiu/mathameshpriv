class_name Geometry
extends Area3D

enum CLASSES{POINT, LINE, CIRCLE}

var data: Array[Dictionary]
@export var surface: MeshSurface
@export var mmbasis: MultiMesh
@export var mmpoint: MultiMesh
@export var mmvalue: MultiMesh
@export var line: MeshInstance3D
@export var mmcircle: MultiMesh


func _process(delta: float) -> void:
	recalculate.call_deferred()


func add_point(t: Transform3D) -> void:
	t.origin = t.origin.snappedf(0.5)
	var shape := SphereShape3D.new()
	shape.radius = 0.1
	PhysicsServer3D.area_add_shape(get_rid(), shape.get_rid(), t)
	
	data.append({"class": CLASSES.POINT, "shape": shape})


func translate_point(idx: PackedInt32Array, offset: Vector3):
	for i in idx:
		var x := PhysicsServer3D.area_get_shape_transform(get_rid(), i)
		PhysicsServer3D.area_set_shape_transform(get_rid(), i, x.translated(offset))


func rotate_point(idx: PackedInt32Array, axis: Vector3, angle: float) -> void:
	for i in idx:
		var p := PhysicsServer3D.area_get_shape_transform(get_rid(), i)
		p = Transform3D(p.basis.rotated(axis, angle), p.origin)
		PhysicsServer3D.area_set_shape_transform(get_rid(), i, p)


func add_line(from: int, to := -1):
	var shape := SphereShape3D.new()
	shape.radius = 0.1
	var a := PhysicsServer3D.area_get_shape_transform(get_rid(), from)
	var b := PhysicsServer3D.area_get_shape_transform(get_rid(), to if to >= 0 else from)
	
	PhysicsServer3D.area_add_shape(get_rid(), shape.get_rid())
	
	data.append({"class": CLASSES.LINE, "shape": shape, "from": from, "to": to,
	"basis": a.basis if to == -1 else direction_basis(a.basis, a.origin.direction_to(b.origin)), "direction": Vector3.RIGHT, "length": 0.5})


func direction_basis(bas: Basis, dir: Vector3, up := Vector3.UP, model_front := false):
	bas = bas.looking_at(dir, up, model_front)
	for i in 3:
		if abs(bas[i].dot(dir)) > 0.9:
			return Basis(bas[i], bas[i -1], bas[i - 2])
	for i in 3:
		OS.alert(str(abs(bas[i].dot(dir))))
	return bas


func translate_line(idx: PackedInt32Array, offset: float):
	for i in idx:
		var a := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].from)
		if data[i].to == -1:
			data[i].length += offset
			continue
		var b := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].to)
		var d := a.origin.direction_to(b.origin) * a.origin.distance_to(b.origin)
		var l := clampf((d.length() * data[i].length + offset) / d.length(), 0.0, 1.0)
		data[i].length = l


func line_rotate_basis(idx: PackedInt32Array, axis: Vector3, angle: float) -> void:
	for i in idx:
		var bas := data[i].basis as Basis
		var a := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].from)
		bas = bas.rotated(axis * a.basis, angle)
		data[i].basis = bas


func line_rotate_direction(idx: PackedInt32Array, axis: Vector3, angle: float) -> void:
	for i in idx:
		var dir := data[i].direction as Vector3
		dir = dir.rotated(axis, angle)
		data[i].direction = dir


func add_circle(from: int, to: int):
	var shape := SphereShape3D.new()
	shape.radius = 0.1
	PhysicsServer3D.area_add_shape(get_rid(), shape.get_rid(), PhysicsServer3D.area_get_shape_transform(get_rid(), to))
	

	data.append({"class": CLASSES.CIRCLE, "from": from, "to": to, "angle": 0.0, "value": 0.0, "offset": Vector2.ZERO, "transform": Transform3D.IDENTITY, "shape": shape})
	circle_translate_value([data.size() - 1], deg_to_rad(90))


func circle_translate_value(idx: PackedInt32Array, offset:float):
	var mmic := mmcircle
	for i in idx:
		var a := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i]["from"])
		var b := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i]["to"])
		var d := a.origin.direction_to(b.origin) * a.origin.distance_to(b.origin)
		data[i].value = deg_to_rad(rad_to_deg(data[i].value) + rad_to_deg(offset))
		var bas := Basis.IDENTITY.looking_at(d.normalized()).rotated(d.normalized(), data[i].angle)
		PhysicsServer3D.area_set_shape_transform(get_rid(), i, Transform3D(bas,
		bas.z * a.origin.distance_to(b.origin)).rotated(bas.y, data[i].value).translated(a.origin))


func rotate_circle(idx: PackedInt32Array, angle: float):
	for i in idx:
		data[i].angle = deg_to_rad(rad_to_deg(data[i].angle) + rad_to_deg(angle))


func recalculate():
	for i in data.size():
		match data[i].class:
			CLASSES.LINE:
				var a := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].from)
				if data[i].to == -1:
					PhysicsServer3D.area_set_shape_transform(get_rid(), i, Transform3D(a.basis * data[i].basis, a.origin + a.basis * data[i].direction * data[i].length))
					continue
				var b := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].to)
				
				PhysicsServer3D.area_set_shape_transform(get_rid(), i, Transform3D(data[i].basis, a.origin.lerp(b.origin, data[i].length)))
			CLASSES.CIRCLE:
				var a := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].from)
				var b := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].to)
				var d := a.origin.direction_to(b.origin) * a.origin.distance_to(b.origin)
				var bas := Basis.IDENTITY.looking_at(d.normalized()).rotated(d.normalized(), data[i].angle)
				PhysicsServer3D.area_set_shape_transform(get_rid(), i, Transform3D(bas,
				bas.z * a.origin.distance_to(b.origin)).rotated(bas.y, data[i].value).translated(a.origin))
	redraw()


func redraw():
	var mmip := mmpoint
	var mmipc := 0
	var mmiv := mmvalue
	var mmivc := 0
	var mmic := mmcircle
	var mmicc := 0
	var im := ImmediateMesh.new()
	var l := 0
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for i in data.size():
		match data[i].class:
			CLASSES.POINT:
				mmip.set_instance_transform(i, PhysicsServer3D.area_get_shape_transform(get_rid(), i))
				mmipc += 1
			CLASSES.LINE:
				var a := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].from)
				var b := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].to if data[i].to >= 0 else i)
				var c := PhysicsServer3D.area_get_shape_transform(get_rid(), i)
				
				mmiv.set_instance_transform(mmivc, c)
				mmivc += 1
				im.surface_add_vertex(a.origin)
				im.surface_add_vertex(b.origin)
				l += 1
			CLASSES.CIRCLE:
				var a := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].from)
				var b := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].to)
				var d := a.origin.direction_to(b.origin) * a.origin.distance_to(b.origin)
				var bas := Basis.IDENTITY.looking_at(d.normalized()).rotated(d.normalized(), data[i].angle).scaled(Vector3.ONE * d.length() * 2)
				mmic.set_instance_transform(mmicc, Transform3D(bas, a.origin))
				mmiv.set_instance_transform(mmivc, PhysicsServer3D.area_get_shape_transform(get_rid(), i))
				mmicc += 1
				mmivc += 1
	
	var mmibc := 0
	for i in surface.main.selecting_g:
		for j in i:
			mmbasis.set_instance_transform(mmibc, PhysicsServer3D.area_get_shape_transform(get_rid(), j))
			mmibc += 1
	mmbasis.visible_instance_count = mmibc
	mmip.visible_instance_count = mmipc
	mmiv.visible_instance_count = mmivc
	mmic.visible_instance_count = mmicc
	if l:
		im.surface_end()
		line.mesh = im


func reverse(idx: PackedInt32Array) -> void:
	for i in idx:
		if data[i].to >= 0:
			var to := data[i].to as int
			data[i].to = data[i].from
			data[i].from = to
		match data[i].class:
			CLASSES.LINE:
				var a := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].from)
				var b := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].to)
				data[i].basis *= b.basis.inverse()
				data[i].basis *= a.basis


func rest(idx: PackedInt32Array) -> void:
	for i in idx:
		match data[i].class:
			CLASSES.POINT:
				PhysicsServer3D.area_set_shape_transform(get_rid(), i, Transform3D(Basis.IDENTITY, PhysicsServer3D.area_get_shape_transform(get_rid(), i).origin))
			CLASSES.LINE:
				var a := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].from)
				var b := PhysicsServer3D.area_get_shape_transform(get_rid(), data[i].to if data[i].to >= 0 else data[i].from)
				data[i].basis =  a.basis if data[i].to == -1 else direction_basis(a.basis, a.origin.direction_to(b.origin))
				data[i].direction = Vector3.RIGHT
				data[i].length = 0.5
			CLASSES.CIRCLE:
				pass
