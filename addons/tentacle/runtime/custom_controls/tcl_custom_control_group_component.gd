@icon("res://addons/tentacle/icons/group.svg")
class_name TclCustomControlGroupComponent
extends Node

## Groups the custom controls beneath it in Tentacle's panel.
##
## Put controls under one of these and they are filed under its name. The group is
## **resolved from the nearest enclosing container** rather than typed onto each
## control, which is the point: moving a control between groups is dragging it in the
## scene tree, and a group rename reaches every control under it at once.

# Unreal's UTclCustomControlGroupComponent and Unity's TclCustomControlGroupComponent.

## The group's name in Tentacle's panel.
@export var group_name: String = "":
	set(value):
		group_name = value
		_apply_to_children()


## Renames the group, updating every control under it.
func set_group_name(new_name: String) -> void:
	group_name = new_name


## Pushes this group's name onto every control beneath it.
##
## Walks the whole subtree rather than only direct children, because a group's
## controls are usually organised into nodes of their own. A nested group wins for its
## own subtree, matching what [code]_resolve_group[/code] on the control does.
func _apply_to_children() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		_apply_to_subtree(child)


func _apply_to_subtree(node: Node) -> void:
	if node is TclCustomControlGroupComponent:
		# A nested group owns its own subtree.
		return
	if node is TclCustomControlComponent:
		(node as TclCustomControlComponent).set_group(group_name)
	for child in node.get_children():
		_apply_to_subtree(child)
