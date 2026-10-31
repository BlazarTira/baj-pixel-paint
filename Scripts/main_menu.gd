extends Control

@onready var sign_in_button = $SignInButton
@onready var sign_out_button = $SignOutButton
@onready var sign_in_panel = $SignInPanel
@onready var twitch_code_button = $SignInPanel/VBoxContainer/TwitchCodeButton
@onready var clipboard_notice = $SignInPanel/VBoxContainer/ClipboardNotice
@onready var connection_status = $ConnectionStatus
@onready var user_label = $UserLabel

@onready var play_button = $PlayButton
@onready var settings_button = $SettingsButton
@onready var how_to_play_button = $HowToPlayButton
@onready var tentacle_button = $TentacleButton
@onready var credits_button = $CreditsButton

@onready var settings_menu = $SettingsMenu
@onready var HTP_menu = $HowToPlay
@onready var credits_menu = $Credits


# Called when the node enters the scene tree for the first time.
func _ready():
	Tentacle.connections.OnConnectPrompt.connect(_on_connect_prompt)
	Tentacle.connections.OnConnectResult.connect(_on_connect_result)
	Tentacle.connections.OnConnectionChanged.connect(_on_connection_changed)
	var connection = Tentacle.connections.get_connection(TclStreamPlatform.Value.TWITCH)
	update_button(connection)
	
	sign_in_panel.hide()
	clipboard_notice.text = ""
	settings_menu.hide()
	HTP_menu.hide()
	credits_menu.hide()
	
	Music.play_main_theme()

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
		twitch_code_button.text = prompt.user_code
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
	update_button(connection)
	print("%s: %s, signed in as %s" % [
		TclStreamPlatform.to_wire(connection.platform),
		TclPlatformConnectionStatus.to_wire(connection.status),
		account,
	])

func sign_out_of_twitch() -> void:
	Tentacle.connections.disconnect_platform(TclStreamPlatform.Value.TWITCH)

func _on_play_button_pressed():
	await Fade.fade(1.0, 0.5).finished
	get_tree().change_scene_to_file("res://Scenes/game.tscn")
	Fade.fade(0.0, 0.5)

func update_button(connection: TclPlatformConnection):
	var status = TclPlatformConnectionStatus.Value.DISCONNECTED
	if connection != null:
		status = connection.status
	
	if status == TclPlatformConnectionStatus.Value.CONNECTED and connection.account != null:
		user_label.text = "Welcome\n%s!" % connection.account.display_name
	else:
		user_label.text = ""
	
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


func _on_settings_button_pressed():
	settings_menu.show()
	play_button.disabled = true
	settings_button.disabled = true
	how_to_play_button.disabled = true
	credits_button.disabled = true
	sign_in_button.disabled = true
	sign_out_button.disabled = true
	tentacle_button.disabled = true
	

func _on_how_to_play_button_pressed():
	HTP_menu.show()
	play_button.disabled = true
	settings_button.disabled = true
	how_to_play_button.disabled = true
	credits_button.disabled = true
	sign_in_button.disabled = true
	sign_out_button.disabled = true
	tentacle_button.disabled = true

func _on_credits_button_pressed():
	credits_menu.show()
	play_button.disabled = true
	settings_button.disabled = true
	how_to_play_button.disabled = true
	credits_button.disabled = true
	sign_in_button.disabled = true
	sign_out_button.disabled = true
	tentacle_button.disabled = true

func _on_close_settings_button_pressed():
	settings_menu.hide()
	play_button.disabled = false
	settings_button.disabled = false
	how_to_play_button.disabled = false
	credits_button.disabled = false
	sign_in_button.disabled = false
	sign_out_button.disabled = false
	tentacle_button.disabled = false

func _on_close_htp_button_pressed():
	HTP_menu.hide()
	play_button.disabled = false
	settings_button.disabled = false
	how_to_play_button.disabled = false
	credits_button.disabled = false
	sign_in_button.disabled = false
	sign_out_button.disabled = false
	tentacle_button.disabled = false

func _on_close_credits_pressed():
	credits_menu.hide()
	play_button.disabled = false
	settings_button.disabled = false
	how_to_play_button.disabled = false
	credits_button.disabled = false
	sign_in_button.disabled = false
	sign_out_button.disabled = false
	tentacle_button.disabled = false


func _on_tentacle_button_pressed():
	OS.shell_open("https://tentacle.live")


func _on_twitch_code_button_pressed():
	DisplayServer.clipboard_set(twitch_code_button.text)
	clipboard_notice.text = "Copied to Clipboard!"
	await get_tree().create_timer(3.0).timeout
	clipboard_notice.text = ""


func _on_tira_pressed():
	OS.shell_open("https://bsky.app/profile/tirablazar.bsky.social")


func _on_fantym_pressed():
	OS.shell_open("https://thesyreuthorder.bandcamp.com/track/rosa-orchid-demo")
