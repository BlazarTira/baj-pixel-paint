extends Control

@onready var sign_in_button = $SignInButton
@onready var sign_out_button = $SignOutButton
@onready var sign_in_panel = $SignInPanel
@onready var twitch_code_label = $SignInPanel/VBoxContainer/TwitchCodeLabel
@onready var connection_status = $ConnectionStatus


# Called when the node enters the scene tree for the first time.
func _ready():
	Tentacle.connections.OnConnectPrompt.connect(_on_connect_prompt)
	Tentacle.connections.OnConnectResult.connect(_on_connect_result)
	Tentacle.connections.OnConnectionChanged.connect(_on_connection_changed)
	update_button(TclPlatformConnectionStatus)

func _on_sign_in_button_pressed():
	sign_in_to_twitch()

func _on_sign_out_button_pressed():
	sign_out_of_twitch()

# Hook this up to your sign-in button.
func sign_in_to_twitch() -> void:
	Tentacle.connections.connect_platform(TclStreamPlatform.Value.TWITCH)

func _on_connect_prompt(prompt: TclPlatformConnectionPrompt) -> void:
	OS.shell_open(prompt.url)
	if prompt.user_code != null:
		# Show this on screen in your menu, so the player can type it.
		sign_in_panel.show()
		twitch_code_label.text = prompt.user_code
		print("Enter %s if the page asks for a code" % prompt.user_code)

func _on_connect_result(result: TclPlatformConnectionResult) -> void:
	if result.outcome == TclPlatformConnectionOutcome.Value.ERROR:
		push_warning("Signing in failed: %s" % result.message)

func _on_connection_changed(connection: TclPlatformConnection) -> void:
	if connection.platform != TclStreamPlatform.Value.TWITCH:
		return
	var account := "nobody"
	if connection.account != null:
		sign_in_panel.hide()
		account = connection.account.display_name
	update_button(connection.status)
	print("%s: %s, signed in as %s" % [
		TclStreamPlatform.to_wire(connection.platform),
		TclPlatformConnectionStatus.to_wire(connection.status),
		account,
	])

func sign_out_of_twitch() -> void:
	Tentacle.connections.disconnect_platform(TclStreamPlatform.Value.TWITCH)

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func update_button(status):
	match status:
		TclPlatformConnectionStatus.Value.DISCONNECTED:
			sign_in_button.show()
			sign_in_button.disabled = false
			sign_out_button.hide()
			connection_status.play("Disconnected")
		TclPlatformConnectionStatus.Value.CONNECTING:
			sign_in_button.show()
			sign_in_button.disabled = true
			sign_out_button.hide()
			connection_status.play("Connecting")
		TclPlatformConnectionStatus.Value.CONNECTED:
			sign_in_button.hide()
			sign_out_button.show()
			connection_status.play("Connected")
