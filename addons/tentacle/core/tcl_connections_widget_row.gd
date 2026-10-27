class_name TclConnectionsWidgetRow
extends RefCounted

## What one platform's row in a [TclConnectionsWidget] shows: its status, a line of
## detail, and the buttons, worked out from what [Tentacle_Connections] last reported.

# Unreal's FTclConnectionsWidgetRow and Unity's ConnectionsWidgetRow, with the same rules
# and the same words, so a player sees the same sign-in on every engine.

## What a row's button does when pressed.
enum Action {
	## No button.
	NONE,
	## Start signing the player in.
	CONNECT,
	## Sign the account out.
	DISCONNECT,
	## Open the sign-in page in the browser.
	OPEN_PAGE,
	## Abandon the sign-in in progress.
	CANCEL,
}

## The platform's name.
var title: String = ""
## Where the platform stands, in a few words.
var status: String = ""
## A second line: the code and time left while signing in, why the last sign-in
## failed, or that signing in again allows newer features. Empty when there is
## nothing to add.
var detail: String = ""
## What the main button does, or [constant Action.NONE] for no button.
var primary_action: Action = Action.NONE
## The main button's label.
var primary_label: String = ""
## What the second button does, or [constant Action.NONE] for none.
var secondary_action: Action = Action.NONE
## The second button's label.
var secondary_label: String = ""


## The row for [param platform], given its [param connection] (null before Tentacle has
## reported one), the sign-in [param prompt] in progress (null for none) with
## [param seconds_left] on it, the [param result] of the last sign-in (null for none),
## and whether the widget opens the sign-in page by itself.
static func describe(
	platform: TclStreamPlatform.Value,
	connection: TclPlatformConnection,
	prompt: TclPlatformConnectionPrompt,
	seconds_left: float,
	result: TclPlatformConnectionResult,
	open_browser_automatically: bool,
) -> TclConnectionsWidgetRow:
	var row := TclConnectionsWidgetRow.new()
	row.title = platform_name(platform)

	if prompt != null and seconds_left > 0.0:
		row.status = "Finish signing in in your browser"
		var left := format_time_left(seconds_left)
		if prompt.user_code != null and str(prompt.user_code) != "":
			row.detail = "Code %s · expires in %s" % [prompt.user_code, left]
		else:
			row.detail = "Expires in %s" % left
		row.primary_action = Action.OPEN_PAGE
		row.primary_label = "Open the page again" if open_browser_automatically else "Open the sign-in page"
		row.secondary_action = Action.CANCEL
		row.secondary_label = "Cancel"
		return row

	row.detail = result_detail(result)
	if connection == null:
		row.status = "Waiting for Tentacle"
		return row

	var account := connection.account
	if account != null and connection.needs_reconnect:
		row.status = "%s needs to sign in again" % account.display_name
		row.primary_action = Action.CONNECT
		row.primary_label = "Sign in again"
	elif account != null:
		if connection.status == TclPlatformConnectionStatus.Value.CONNECTED:
			row.status = "Connected as %s" % account.display_name
		else:
			row.status = "Connecting as %s..." % account.display_name
		row.primary_action = Action.DISCONNECT
		row.primary_label = "Disconnect"
		# It signed in before this version asked for more: it still works, and signing
		# in again grants the rest.
		if connection.missing_permissions:
			if row.detail == "":
				row.detail = "Sign in again to allow newer features"
			row.secondary_action = Action.CONNECT
			row.secondary_label = "Sign in again"
	else:
		row.status = "Not connected"
		row.primary_action = Action.CONNECT
		row.primary_label = "Connect"
	return row


## The platform's name as a player knows it.
static func platform_name(platform: TclStreamPlatform.Value) -> String:
	return "Kick" if platform == TclStreamPlatform.Value.KICK else "Twitch"


## [param seconds] as minutes and seconds, rounded up: [code]4:05[/code].
static func format_time_left(seconds: float) -> String:
	var whole := int(ceil(seconds))
	return "%d:%02d" % [int(whole / 60.0), whole % 60]


## Why the last sign-in did not connect, or an empty string when it did, was cancelled,
## or there was none.
static func result_detail(result: TclPlatformConnectionResult) -> String:
	if result == null:
		return ""
	match result.outcome:
		TclPlatformConnectionOutcome.Value.DENIED:
			return "Sign-in was declined"
		TclPlatformConnectionOutcome.Value.EXPIRED:
			return "Sign-in ran out of time"
		TclPlatformConnectionOutcome.Value.ERROR:
			if result.message != null and str(result.message) != "":
				return "Sign-in failed: %s" % result.message
			return "Sign-in failed"
	return ""
