extends Node2D

@onready var canvas = %Canvas
@onready var erase_timer = $Erase_Cooldown

var can_erase: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	Tentacle.OnChatCommand.connect(_on_chat_command)
	erase_timer.timeout.connect(_on_timer_timeout)


func _on_chat_command(message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer):
	var command = TclJson.as_string(message.command)
	match command:
		_:
			if !can_erase:
				Tentacle.send_chat_message("Can't erase yet!")
			else:
				canvas.erase_cell(command, viewer.display_name)
				can_erase = false
				erase_timer.start()

func _on_timer_timeout():
	can_erase = true
