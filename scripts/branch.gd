@tool
class_name TreeBranch
extends GraphNode

@export var indexed := true:
	set(x):
		indexed = x
		$Control/HBC/Index.visible = x
@export var named := true:
	set(x):
		named = x
		$Control/HBC/Name.visible = x


func _ready() -> void:
	$Control/HBC/Name.text = get_meta("node", self).name
	name = $Control/HBC/Name.text


func get_ID() -> int:
	return $Control/HBC/Index.text.to_int()


func _on_hbc_resized() -> void:
	custom_minimum_size = $Control/HBC.size + Vector2(8, 0)


func _on_name_text_submitted(new_text: String) -> void:
	get_meta("node", self).name = new_text
	$Control/HBC/Name.text = get_meta("node", self).name
	name = $Control/HBC/Name.text


func _on_name_focus_exited() -> void:
	$Control/HBC/Name.text = get_meta("node", self).name
	name = $Control/HBC/Name.text




func _on_node_selected() -> void:
	await get_tree().create_timer(1).timeout
	selected = false
