extends Node2D

@onready var canvas = %Canvas
@onready var erase_timer = $Erase_Cooldown
@onready var bomb_timer = $Bomb_Cooldown
@onready var guide_timer = $HideGuide_Cooldown
@onready var erase_cooldown_bar = $CanvasLayer/Cooldown_Bar
@onready var bomb_cooldown_bar = $CanvasLayer/Bomb_Cooldown_Bar
@onready var guide_cooldown_bar = $CanvasLayer/HideGuide_Cooldown_Bar
@onready var pause_menu = %PauseMenu

var can_erase: bool = true
var can_bomb: bool = true
var can_hide_guide: bool = true
var coord_regex = RegEx.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	coord_regex.compile("^[A-Z]([1-9]|1[0-9]|2[0-6])$")
	Tentacle.OnChatCommand.connect(_on_chat_command)
	Tentacle.OnChatMessage.connect(_on_chat_message)
	erase_timer.timeout.connect(_on_erase_timeout)
	bomb_timer.timeout.connect(_on_bomb_timeout)
	
	if GameManager.erase_cooldown_time > 0:
		erase_timer.wait_time = GameManager.erase_cooldown_time
		erase_cooldown_bar.max_value = erase_timer.wait_time
		erase_cooldown_bar.value = erase_timer.wait_time
		erase_cooldown_bar.show()
	else:
		erase_cooldown_bar.max_value = 1.0
		erase_cooldown_bar.value = 1.0
		erase_cooldown_bar.hide()
	
	if GameManager.bomb_cooldown_time > 0:
		bomb_timer.wait_time = GameManager.bomb_cooldown_time
		bomb_cooldown_bar.max_value = bomb_timer.wait_time
		bomb_cooldown_bar.value = bomb_timer.wait_time
		bomb_cooldown_bar.show()
	else:
		bomb_cooldown_bar.max_value = 1.0
		bomb_cooldown_bar.value = 1.0
		bomb_cooldown_bar.hide()
	
	guide_timer.wait_time = GameManager.guide_cooldown_time
	guide_cooldown_bar.max_value = guide_timer.wait_time
	guide_cooldown_bar.value = guide_timer.wait_time
	canvas.guide_return.connect(on_guide_returned)
	
	pause_menu.hide()

func _process(delta):
	if erase_timer.time_left > 0:
		erase_cooldown_bar.value = erase_timer.time_left
	if bomb_timer.time_left > 0:
		bomb_cooldown_bar.value = bomb_timer.time_left
	if guide_timer.time_left > 0:
		guide_cooldown_bar.value = guide_timer.time_left

func _on_chat_command(message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer):
	if get_tree().paused:
		return
	var command = TclJson.as_string(message.command)
	match command:
		"bomb":
			if !can_bomb:
				return
			var parts = str(message.text).strip_edges().split(" ", false)
			if parts.size() < 2:
				return
			var coord = parts[1].to_upper()
			if coord_regex.search(coord) == null:
				return
			if canvas.bomb_cell(coord, viewer.display_name):
				can_bomb = false
				bomb_timer.start()
		"guide":
			if !can_hide_guide:
				return
			if canvas.hide_guide(GameManager.guide_hide_time, viewer.display_name):
				can_hide_guide = false
				#guide_timer.start(GameManager.guide_cooldown_time)
		_:
			try_erase(command, viewer.display_name)

func _on_chat_message(message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer):
	if get_tree().paused:
		return
	
	var text = str(message.text).strip_edges()
	if text.begins_with("!"):
		return
	
	try_erase(text, viewer.display_name)

func try_erase(raw: String, viewer_name: String):
	if !can_erase:
		return
	var coord = raw.strip_edges().to_upper()
	if coord_regex.search(coord) == null:
		return
	if canvas.erase_cell(coord, viewer_name):
		if GameManager.erase_cooldown_time > 0:
			can_erase = false
			erase_timer.start()

func _on_erase_timeout():
	can_erase = true
	erase_cooldown_bar.value = erase_cooldown_bar.max_value

func _on_bomb_timeout():
	can_bomb = true
	bomb_cooldown_bar.value = bomb_cooldown_bar.max_value

func on_guide_returned():
	guide_timer.start(GameManager.guide_cooldown_time)

func _on_hide_guide_cooldown_timeout():
	can_hide_guide = true
	guide_cooldown_bar.value = guide_cooldown_bar.max_value
