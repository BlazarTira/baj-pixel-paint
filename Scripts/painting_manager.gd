class_name PaintingResource
extends Resource

#Store the color value of all pixels in an array
@export var colors: Array[Color]

#Function to create a drawing resource from the grid
func create_from_grid(grid_buttons: Array):
	colors.resize(grid_buttons.size())
	for i in range (grid_buttons.size()):
		colors[i] = grid_buttons[i].modulate
	

#Function to load drawing data into a grid
func load_to_grid(grid_buttons: Array):
	for i in range(grid_buttons.size()):
		grid_buttons[i].modulate = colors[i]
