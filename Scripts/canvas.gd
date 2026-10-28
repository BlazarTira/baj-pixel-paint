extends Control


enum State {WAITING, DRAWING, RESULTS}
var state = State.WAITING
const ROUND_TIME = 10.0

const GRID_SIZE = 26
const MAX_LOG_ENTRIES = 50

var active_color: Color = Color(1, 0, 0)
var is_painting = false
var is_erasing = false

var cells: Dictionary = {}

#vars for the template stuff (template images gotta be 26x26 pixels and only the colors on the side buttons)
@export var templates: Array[Texture2D] = []
var template: Array[Color] = []
var template_index := -1

#vars for the little preview image in the bottom left
@onready var drawing_preview: TextureRect = %DrawingPreview
var preview_image: Image
var preview_texture: ImageTexture

#vars for the drawing guide that sits over the canvas
@onready var guide_overlay: TextureRect = %GuideOverlay
@export_range(0.0, 1.0) var washout: float = 0.6
var guide_image: Image
var guide_texture: ImageTexture

#any of the @onready vars that I don't feel like grouping
@onready var grid = %DrawingGrid
#@onready var painting: Node2D = $"../../Painting"
@onready var log_scroll = %LogScroll
@onready var log_list = %LogList
@onready var round_timer = %RoundTimer
@onready var time_label = %TimeLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var countdown_timer = $CountdownTimer
@onready var count_down_label = $CountDownLabel


func _ready():
	build_cell_lookup()
	start_countdown()

func build_cell_lookup():
	cells.clear()
	var children = grid.get_children()
	for i in children.size():
		var coord = char(65 + i / GRID_SIZE) + str(i % GRID_SIZE + 1)
		children[i].set_meta("coord", coord)
		cells[coord] = children[i]

func start_countdown():
	state = State.WAITING
	result_panel.hide()
	reset_board()
	guide_overlay.texture = null
	count_down_label.show()
	countdown_timer.start()

func load_template(tex: Texture2D):
	var img = tex.get_image()
	assert(img.get_width() == GRID_SIZE and img.get_height() == GRID_SIZE, "Template has to be 26x26 jackass")
	template.clear()
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			template.append(img.get_pixel(x,y))

func start_round(template_tex: Texture2D):
	load_template(template_tex)
	reset_board()
	build_preview()
	build_guide()
	state = State.DRAWING
	round_timer.start(ROUND_TIME)

func start_next_round():
	if templates.is_empty():
		return
	if templates.size() == 1:
		template_index = 0
	else:
		var next = template_index
		while next == template_index:
			next = randi() % templates.size()
		template_index = next
	start_round(templates[template_index])

func build_preview():
	preview_image = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	preview_image.fill(Color.WHITE)
	preview_texture = ImageTexture.create_from_image(preview_image)
	drawing_preview.texture = preview_texture

func build_guide():
	guide_image = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	guide_texture = ImageTexture.create_from_image(guide_image)
	guide_overlay.texture = guide_texture
	for i in template.size():
		fix_guide_pixel(i)
	guide_texture.update(guide_image)

func fix_guide_pixel(i: int):
	var temp = template[i]
	var cell = grid.get_child(i)
	var show_guide = !colors_match(temp, Color.WHITE) and colors_match(cell.modulate, Color.WHITE)
	if show_guide:
		guide_image.set_pixel(i % GRID_SIZE, i / GRID_SIZE, Color(temp.r, temp.g, temp.b).lerp(Color.WHITE, washout))
	else:
		guide_image.set_pixel(i % GRID_SIZE, i / GRID_SIZE, Color(0,0,0,0))

func _process(_delta):
	var first = grid.get_child(0)
	var pitch = Vector2(
		grid.get_child(1).global_position.x - first.global_position.x,
		grid.get_child(GRID_SIZE).global_position.y - first.global_position.y
	)
	guide_overlay.global_position = first.global_position
	guide_overlay.size = pitch * GRID_SIZE
	
	if state == State.DRAWING:
		time_label.text = str(ceili(round_timer.time_left))
	if state == State.WAITING:
		count_down_label.text = str(ceili(countdown_timer.time_left))

func _input(event):
	if state != State.DRAWING:
		return
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
		set_cell_color(cell, color)

func get_cell_at_mouse_position(mouse_pos: Vector2) -> TextureButton:
	for cell in grid.get_children():
		if cell.get_global_rect().has_point(mouse_pos):
			return cell
	return null

func set_cell_color(cell: Control, color: Color):
	cell.modulate = color
	var index = cell.get_index()
	if guide_image:
		fix_guide_pixel(index)
		guide_texture.update(guide_image)
	if preview_image:
		preview_image.set_pixel(index % GRID_SIZE, index / GRID_SIZE, color)
		preview_texture.update(preview_image)

func erase_cell(coord: String, viewer: String = "") -> bool:
	if state != State.DRAWING:
		return false
	coord = coord.strip_edges().to_upper()
	if !cells.has(coord):
		return false
	var cell = cells[coord]
	
	if !cell.modulate.is_equal_approx(Color.WHITE):
		set_cell_color(cell, Color.WHITE)
		add_log_entry(viewer, coord)
	return true

func add_log_entry(viewer: String, coord: String):
	var entry = RichTextLabel.new()
	entry.bbcode_enabled = true
	entry.fit_content = true
	entry.scroll_active = false
	entry.add_theme_color_override("default_color", Color.BLACK)
	entry.add_theme_color_override("font_outline_color", Color.WHITE)
	entry.add_theme_constant_override("outline_size", 6)
	entry.text = "[center][b]%s[/b] erased %s[/center]" % [viewer.replace("[", "[lb]"), coord]
	log_list.add_child(entry)
	
	if log_list.get_child_count() > MAX_LOG_ENTRIES:
		log_list.get_child(0).queue_free()
	
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)

func colors_match(a: Color, b: Color) -> bool:
	return abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b) < 0.05

func get_score() -> float:
	var cell_nodes = grid.get_children()
	var needed = 0
	var correct = 0
	var wrong = 0
	for i in cell_nodes.size():
		var is_white_target = colors_match(template[i], Color.WHITE)
		var painted = !colors_match(cell_nodes[i].modulate, Color.WHITE)
		if !is_white_target:
			needed += 1
			if colors_match(cell_nodes[i].modulate, template[i]):
				correct += 1
		elif painted:
			wrong += 1
	if needed == 0:
		return 0.0
	return clampf(float(correct - wrong) / needed, 0.0, 1.0)

func reset_board():
	for cell in grid.get_children():
		cell.modulate = Color.WHITE
	for entry in log_list.get_children():
		entry.queue_free()
	if preview_image:
		preview_image.fill(Color.WHITE)
		preview_texture.update(preview_image)


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


func _on_round_timer_timeout():
	state = State.RESULTS
	is_painting = false
	is_erasing = false
	time_label.text = "0"
	var percent = roundi(get_score() * 100.0)
	result_label.text = "You got %d%% done!" % percent
	result_panel.show()

func _on_new_round_button_pressed():
	start_countdown()

func _on_countdown_timer_timeout():
	count_down_label.hide()
	start_next_round()
