extends Control

const GRID_SIZE = 26
const MAX_LOG_ENTRIES = 50

var active_color: Color = Color(1, 0, 0) #RED DEFAULT
var is_painting = false #Tracking mouse movement to paint
var is_erasing = false #Tracking mouse movement to erase

var cells: Dictionary = {}

@onready var grid = %DrawingGrid
@onready var painting: Node2D = $"../../Painting"
@onready var log_scroll = %LogScroll
@onready var log_list = %LogList


# Called when the node enters the scene tree for the first time.
func _ready():
	build_cell_lookup()

func build_cell_lookup():
	cells.clear()
	var children = grid.get_children()
	for i in children.size():
		var coord = char(65 + i / GRID_SIZE) + str(i % GRID_SIZE + 1)
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

func erase_cell(coord: String, who: String = "") -> bool:
	coord = coord.strip_edges().to_upper()
	if !cells.has(coord):
		return false
	var cell = cells[coord]
	
	if !cell.modulate.is_equal_approx(Color.WHITE):
		cell.modulate = Color.WHITE
		add_log_entry(who, coord)
	return true

func add_log_entry(who: String, coord: String):
	var entry = RichTextLabel.new()
	entry.bbcode_enabled = true
	entry.fit_content = true
	entry.scroll_active = false
	entry.text = "[b]%s[/b] erased %s" % [who.replace("[", "[lb]"), coord]
	log_list.add_child(entry)
	
	if log_list.get_child_count() > MAX_LOG_ENTRIES:
		log_list.get_child(0).queue_free()
	
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


func _on_reset_pressed():
	for cell in grid.get_children():
		cell.modulate = Color.WHITE


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
