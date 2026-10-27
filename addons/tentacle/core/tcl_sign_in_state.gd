class_name TclSignInState
extends RefCounted

## What a sign-in button shows for one platform: what its label says, a status line and
## a detail line to show beside it, and whether it can be pressed.

# Unreal's FTclSignInState and Unity's SignInState, with the same rules, and the
# Connections widget's words (TclConnectionsWidgetRow) for the status and detail, so a
# player reads the same sign-in on every engine.

## The platform this is about.
var platform: TclStreamPlatform.Value = TclStreamPlatform.Value.TWITCH
## Where the platform stands, which decides what pressing does.
var stage: TclSignInStage.Value = TclSignInStage.Value.WAITING
## What the button says: Connect, Cancel, Disconnect, or Sign in again.
var label: String = "Connect"
## The platform's name: Twitch or Kick.
var title: String = ""
## Where the platform stands, in a few words, such as "Connected as Streamer".
var status: String = ""
## A second line, or empty: Twitch's code and the time left while signing in, why the
## last sign-in failed, or that signing in again allows newer features.
var detail: String = ""
## While signing in to Twitch, the code to show the player in case the page asks for it.
## Empty otherwise.
var user_code: String = ""
## While signing in, the sign-in page. Empty otherwise.
var url: String = ""
## The signed-in account's display name, or empty when none is signed in.
var account_name: String = ""
## Whether pressing the button does anything: false while
## [constant TclSignInStage.Value.UNAVAILABLE] or [constant TclSignInStage.Value.WAITING].
var can_press: bool = false
## True when the account signed in before an update asked the platform for more access:
## it keeps working, and signing in again turns on what needs it.
var missing_permissions: bool = false


## The state for [param platform_value], given why signing in is unavailable here
## ([param unavailable_note], empty when it is available), its [param connection] (null
## before Tentacle has reported one), the sign-in [param prompt] in progress (null for
## none) with [param seconds_left] on it, and the [param result] of the last sign-in
## (null for none).
static func describe(
	platform_value: TclStreamPlatform.Value,
	unavailable_note: String,
	connection: TclPlatformConnection,
	prompt: TclPlatformConnectionPrompt,
	seconds_left: float,
	result: TclPlatformConnectionResult,
) -> TclSignInState:
	var state := TclSignInState.new()
	state.platform = platform_value
	state.title = TclConnectionsWidgetRow.platform_name(platform_value)

	if unavailable_note != "":
		state.stage = TclSignInStage.Value.UNAVAILABLE
		state.status = unavailable_note
		return state

	# The widget's words for where the platform stands; a button has one action per stage
	# where a row has two buttons.
	var row := TclConnectionsWidgetRow.describe(platform_value, connection, prompt, seconds_left, result, true)
	state.status = row.status
	state.detail = row.detail

	if prompt != null and seconds_left > 0.0:
		state.stage = TclSignInStage.Value.SIGNING_IN
		state.label = "Cancel"
		state.user_code = str(prompt.user_code) if prompt.user_code != null else ""
		state.url = prompt.url
		state.can_press = true
		return state

	if connection == null:
		state.stage = TclSignInStage.Value.WAITING
		return state

	state.can_press = true
	var account := connection.account
	if account != null:
		state.account_name = account.display_name

	if account != null and connection.needs_reconnect:
		state.stage = TclSignInStage.Value.NEEDS_RECONNECT
		state.label = "Sign in again"
	elif account != null:
		if connection.status == TclPlatformConnectionStatus.Value.CONNECTED:
			state.stage = TclSignInStage.Value.CONNECTED
		else:
			state.stage = TclSignInStage.Value.CONNECTING
		state.label = "Disconnect"
		state.missing_permissions = connection.missing_permissions
	else:
		state.stage = TclSignInStage.Value.NOT_CONNECTED
	return state


## Whether [param other] shows exactly the same.
func equals(other: TclSignInState) -> bool:
	return (
		other != null
		and platform == other.platform
		and stage == other.stage
		and label == other.label
		and title == other.title
		and status == other.status
		and detail == other.detail
		and user_code == other.user_code
		and url == other.url
		and account_name == other.account_name
		and can_press == other.can_press
		and missing_permissions == other.missing_permissions
	)
