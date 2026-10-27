class_name TclSignInController
extends RefCounted

## The logic of a sign-in button for one platform, with no look of its own, for a button
## of your own design: call [method press] when it is pressed, and show what
## [signal OnStateChanged] hands you. Made by
## [method Tentacle_Connections.create_sign_in_controller].
##
## Pressing does what the label says: Connect signs the player in and opens the sign-in
## page, Cancel abandons a sign-in in progress, Disconnect signs the account out, and
## Sign in again signs the player in again. It only opens the page for a sign-in it
## started. Keep a reference to it for as long as the button is on screen; it stops
## when you let go of it.
##
## [codeblock]
## var _twitch := Tentacle.connections.create_sign_in_controller(TclStreamPlatform.Value.TWITCH)
##
## func _ready() -> void:
##     _twitch.OnStateChanged.connect(func(state: TclSignInState) -> void: $Button.text = state.label)
##     $Button.pressed.connect(_twitch.press)
## [/codeblock]

# Unreal's UTclSignInController, Unity's SignInController, and tentacle-web's
# SignInController; the TclSignInButton node runs one. Tentacle_Connections holds it
# only weakly, so the game's reference is what keeps it.

## Emitted whenever what the button should show changes, the countdown while signing in
## included.
signal OnStateChanged(state: TclSignInState)

## The platform the controller signs in to.
var platform: TclStreamPlatform.Value = TclStreamPlatform.Value.TWITCH

var _connections: Tentacle_Connections = null
var _open_browser: bool = true
var _state: TclSignInState = null
var _prompt: TclPlatformConnectionPrompt = null
var _seconds_left: float = 0.0
var _result: TclPlatformConnectionResult = null
var _started_here: bool = false


func _init(connections: Tentacle_Connections, platform_value: TclStreamPlatform.Value, open_browser: bool) -> void:
	_connections = connections
	platform = platform_value
	_open_browser = open_browser
	_state = _describe()


## What the button should show now.
func get_state() -> TclSignInState:
	return _state


## Does what the label says: sign in, cancel, or disconnect. Does nothing while the
## state cannot be pressed.
func press() -> void:
	match _state.stage:
		TclSignInStage.Value.NOT_CONNECTED, TclSignInStage.Value.NEEDS_RECONNECT:
			sign_in()
		TclSignInStage.Value.SIGNING_IN:
			cancel()
		TclSignInStage.Value.CONNECTING, TclSignInStage.Value.CONNECTED:
			disconnect_platform()


## Signs the player in, whatever the stage: for a second "Sign in again" button.
func sign_in() -> void:
	if not _connections.embedded:
		return
	_result = null
	_started_here = true
	_connections.connect_platform(platform)
	refresh()


## Abandons the sign-in in progress.
func cancel() -> void:
	if not _connections.embedded:
		return
	_connections.cancel_connect(platform)
	refresh()


## Signs the platform's account out. Named [code]disconnect_platform[/code] because
## [method Object.disconnect] is a member of every Godot object.
func disconnect_platform() -> void:
	if not _connections.embedded:
		return
	_connections.disconnect_platform(platform)
	refresh()


## Opens the sign-in page in progress again, or for the first time when the controller
## does not open it.
func open_page() -> void:
	if _prompt != null and _connections.open_url.is_valid():
		_connections.open_url.call(_prompt.url)


## Works out the state again, and emits [signal OnStateChanged] when it changed.
func refresh() -> void:
	var next := _describe()
	if next.equals(_state):
		return
	_state = next
	OnStateChanged.emit(_state)


## Moves the countdown on by [param delta] seconds; the client calls it every frame.
func advance(delta: float) -> void:
	if _prompt == null:
		return
	_seconds_left -= delta
	refresh()


## Takes a sign-in prompt from Tentacle.
func handle_prompt(prompt: TclPlatformConnectionPrompt) -> void:
	if prompt.platform != platform:
		return
	# A sign-in someone else started, the game's sign_in say, shows here too, but only
	# the controller that asked opens the page.
	_prompt = prompt
	_seconds_left = float(prompt.expires_in_seconds)
	_result = null
	if _started_here and _open_browser:
		open_page()
	refresh()


## Takes how a sign-in ended from Tentacle.
func handle_result(result: TclPlatformConnectionResult) -> void:
	if result.platform != platform:
		return
	_prompt = null
	_result = result
	_started_here = false
	refresh()


func _describe() -> TclSignInState:
	if _prompt != null and _seconds_left <= 0.0:
		# Ran out here; the core's result says so shortly.
		_prompt = null
	var note := "" if _connections.embedded else "Twitch and Kick connect through the Tentacle app"
	return TclSignInState.describe(platform, note, _connections.get_connection(platform), _prompt, _seconds_left, _result)
