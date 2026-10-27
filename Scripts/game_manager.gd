extends Node

@export var data: SaveData = SaveData.new()
@onready var canvas = get_tree().current_scene.get_node("%Canvas")

func _input(event):
	if event.is_action_pressed("paint"):
		canvas.show()
