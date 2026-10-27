extends Control

const GRID_SIZE = 26
var active_color: Color = Color(1, 0, 0) #RED DEFAULT
var is_painting = false #Tracking mouse movement to paint
var is_erasing = false #Tracking mouse movement to erase

var cells: Dictionary = {}

@onready var grid = $CenterContainer/PanelContainer/MarginContainer/VSplitContainer/Drawing/GridContainer
@onready var painting: Node2D = $"../../Painting"


# Called when the node enters the scene tree for the first time.
func _ready():
	build_cell_lookup()

func build_cell_lookup():
	cells.clear()
	var children = grid.get_children()
	for i in children.size():
		var coord = char(65 + i % GRID_SIZE) + str(i / GRID_SIZE + 1)
		children[i].set_meta("coord", coord)
		cells[coord] = children[i]

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_painting = event.pressed
			if event.pressed:
				apply_color_at(event.position, active_color)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_erasing = event.pressed
			if event.pressed:
				apply_color_at(event.position, Color.WHITE)
	
	elif event is InputEventMouseMotion:
		if is_painting:
			apply_color_at(event.position, active_color)
		elif is_erasing:
			apply_color_at(event.position, Color.WHITE)

func apply_color_at(pos: Vector2, color: Color):
	var cell = get_cell_at_mouse_position(pos)
	if cell and !cell.modulate.is_equal_approx(color):
		cell.modulate = color

func get_cell_at_mouse_position(mouse_pos: Vector2) -> TextureButton:
	for cell in grid.get_children():
		if cell.get_global_rect().has_point(mouse_pos):
			return cell
	return null


func _on_reset_pressed():
	if GameManager.data.painting.colors.size() > 0:
		GameManager.data.painting.load_to_grid(grid.get_children())


func _on_save_close_pressed():
	GameManager.data.painting.create_from_grid(grid.get_children())
	self.hide()


func _on_red_pressed():
	active_color = Color(1,0,0)


func _on_orange_pressed():
	active_color = Color(1.0, 0.502, 0.0, 1.0)


func _on_yellow_pressed():
	active_color = Color(1.0, 0.867, 0.0, 1.0)


func _on_green_pressed():
	active_color = Color(0.0, 1.0, 0.167, 1.0)


func _on_blue_pressed():
	active_color = Color(0.0, 0.5, 1.0, 1.0)


func _on_purple_pressed():
	active_color = Color(0.717, 0.0, 1.0, 1.0)

#yada yada
