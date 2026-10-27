@icon("res://addons/tentacle/icons/control.svg")
class_name TclSignInButton
extends Button

## A button that signs the player in to one platform, with no look of its own: the
## project's [Theme] styles it like any other [Button], so it fits your menus.
##
## Pressing it does what its state says: Connect signs the player in and opens the
## sign-in page, Cancel abandons a sign-in in progress, and Disconnect signs the account
## out. It shows the label as its text, unless [member set_label] is off, and is
## disabled while it cannot be pressed. [signal OnSignInStateChanged] hands you the whole
## state, the status line and Twitch's code included, to show wherever you like.
##
## Only Tentacle embedded in the game signs players in; with the Tentacle app the button
## stays disabled. For a button of your own, use
## [method Tentacle_Connections.create_sign_in_controller] instead.

# Unreal's UTclSignInButton and Unity's SignInButton component. A Button rather than a
# container, so a Theme type variation styles it and it drops into any layout. Not
# @tool, like the scene's other Tentacle nodes, so an open scene signs nothing in.

## Emitted once as the button becomes ready, and whenever what it shows changes, the
## countdown while signing in included.
signal OnSignInStateChanged(state: TclSignInState)

## The platform the button signs in to. Read when the button becomes ready.
@export var platform: TclStreamPlatform.Value = TclStreamPlatform.Value.TWITCH

## Open the sign-in page in the player's browser when signing in needs it. Off, open the
## state's [member TclSignInState.url] yourself.
@export var open_browser: bool = true

## Keep the button's text reading the label: Connect, Cancel, Disconnect, or Sign in
## again. Off, the text is yours.
@export var set_label: bool = true

## Disable the button while it cannot be pressed: with the Tentacle app, and while
## Tentacle starts.
@export var disable_when_unavailable: bool = true

## A connections surface every button uses instead of the [code]Tentacle[/code]
## autoload's, so a test can drive buttons without the autoload. Leave it null in a game.
static var surface_override: Tentacle_Connections = null

var _controller: TclSignInController = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var surface := surface_override
	if surface == null:
		var runtime := TentacleRuntime.instance()
		if runtime == null:
			disabled = disable_when_unavailable
			return
		surface = runtime.connections
	_controller = surface.create_sign_in_controller(platform, open_browser)
	_controller.OnStateChanged.connect(_show)
	pressed.connect(_controller.press)
	_show(_controller.get_state())


## What the button shows now, or null before it is ready.
func get_sign_in_state() -> TclSignInState:
	return _controller.get_state() if _controller != null else null


## The controller behind the button, for its [method TclSignInController.sign_in],
## [method TclSignInController.cancel], [method TclSignInController.disconnect_platform],
## and [method TclSignInController.open_page]; null before it is ready.
func get_sign_in_controller() -> TclSignInController:
	return _controller


func _show(state: TclSignInState) -> void:
	if set_label:
		text = state.label
	if disable_when_unavailable:
		disabled = not state.can_press
	OnSignInStateChanged.emit(state)
