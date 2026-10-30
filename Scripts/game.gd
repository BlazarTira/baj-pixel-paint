extends Node2D

@onready var canvas = %Canvas
@onready var erase_timer = $Erase_Cooldown
@onready var cooldown_bar = $CanvasLayer/Cooldown_Bar
@onready var pause_menu = %PauseMenu

var can_erase: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	Tentacle.OnChatCommand.connect(_on_chat_command)
	erase_timer.timeout.connect(_on_timer_timeout)
	
	erase_timer.wait_time = GameManager.cooldown_time
	cooldown_bar.max_value = erase_timer.wait_time
	cooldown_bar.value = erase_timer.wait_time
	
	pause_menu.hide()

func _process(delta):
	if erase_timer.time_left > 0:
		cooldown_bar.value = erase_timer.time_left

func _on_chat_command(message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer):
	if get_tree().paused:
		return
	var command = TclJson.as_string(message.command)
	match command:
		_:
			if can_erase:
				canvas.erase_cell(command, viewer.display_name)
				can_erase = false
				erase_timer.start()

func _on_timer_timeout():
	can_erase = true
	cooldown_bar.value = cooldown_bar.max_value
