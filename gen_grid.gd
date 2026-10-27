@tool
extends EditorScript

const GRID_SIZE = 26
const GRID_PATH = "CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Drawing/GridContainer"

func _run():
	var root = get_scene()
	var grid = root.get_node(GRID_PATH)
	
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	
	grid.columns = GRID_SIZE
	var tex = load("res://Assets/Canvas.png")
	
	for i in GRID_SIZE * GRID_SIZE:
		var cell = TextureButton.new()
		cell.name = "Cell%d" % i
		cell.custom_minimum_size = Vector2(16, 16)
		cell.stretch_mode = TextureButton.STRETCH_SCALE
		cell.ignore_texture_size = true
		cell.texture_normal = tex
		grid.add_child(cell)
		cell.owner = root
