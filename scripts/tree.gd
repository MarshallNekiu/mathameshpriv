class_name TreeDock
extends ScrollContainer

@export var main: MeshCreator

var skeleton_branch: Array[GraphNode]
var grab:GraphNode


func _ready() -> void:
	$HBC/Skeleton.gui_input.connect(_on_graph_node_gui_input.bind($HBC/Skeleton))


func _on_mesh_child_entered_tree(node: MeshSurface) -> void:
	var new_branch := load("res://scenes/branch_s.tscn").instantiate() as GraphNode
	new_branch.set_meta("node", node)
	new_branch.name = node.name
	
	node.renamed.connect(func (): new_branch.name = node.name)
	node.tree_exited.connect(new_branch.queue_free)
	node.layer_created.connect((func (x): new_branch.get_node("Layer/VBC").add_child(x.duplicate())).bind(new_branch.get_node("Layer/VBC").get_child(0).duplicate()))
	node.layer_removed.connect(func (x): new_branch.get_node("Layer/VBC").get_child(x).queue_free())
	new_branch.get_node("Layer/VBC").child_order_changed.connect(func ():
		if not get_tree(): return 
		for i in new_branch.get_node("Layer/VBC").get_children():
			i.get_node("Index").text = str(i.get_index()))
	new_branch.get_node("Layer/VBC").child_entered_tree.connect(func (a):
		a.get_node("Visible").toggled.connect(func (x):
			if x: node.layer_visible.append(a.get_index())
			else: while node.layer_visible.has(a.get_index()):
				node.layer_visible.remove_at(node.layer_visible.find(a.get_index()))
			node.redraw_surface()))
	$HBC/Mesh.add_child(new_branch)
	new_branch.owner = owner


func _on_shape_skeleton_child_entered_tree(node: CollisionShape3D) -> void:
	var new_branch := load("res://scenes/branch_b.tscn").instantiate() as GraphNode
	new_branch.set_meta("node", node)
	
	node.renamed.connect(func (): main.skeleton.set_bone_name(node.get_index(), node.name))
	node.renamed.connect(func (): main.skin.set_bind_name(node.get_index(), node.name))
	
	node.tree_exited.connect(func ():
		skeleton_branch.erase(new_branch)
		new_branch.queue_free())
	new_branch.gui_input.connect(_on_graph_node_gui_input.bind(new_branch))
	new_branch.tree_entered.connect(main.skeleton_make_mesh,CONNECT_DEFERRED)
	new_branch.tree_entered.connect(WorkerThreadPool.add_task.bind(main.redraw_skeleton),CONNECT_DEFERRED)
	
	$HBC/Skeleton.add_child(new_branch)
	new_branch.get_node("Control/HBC/Index").text = str(main.skeleton.get_bone_count())
	new_branch.owner = owner
	
	skeleton_branch.append(new_branch)
	
	WorkerThreadPool.add_task.bind(main.redraw_skeleton).call_deferred()


func _on_graph_node_gui_input(event: InputEvent, node: GraphNode) -> void:
	if event is InputEventScreenTouch:
		if event.double_tap and event.is_pressed():
			if is_instance_valid(grab):
				if not node == grab and not node.find_parent(grab.name):
					grab.reparent(node)
					if node == $HBC/Skeleton:
						main.skeleton.set_bone_parent(grab.get_ID(), -1)
					else:
						main.skeleton.set_bone_parent(grab.get_ID(), node.get_ID())
				grab.selected = false
				grab = null
			elif not node == $HBC/Skeleton:
				grab = node
				grab.selected = true


func _on_mesh_child_order_changed() -> void:
	if not get_tree(): return
	for i: TreeBranch in $HBC/Mesh.get_children():
		i.get_node("Control/HBC/Index").text = str(i.get_index())
