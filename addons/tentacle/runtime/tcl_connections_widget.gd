@icon("res://addons/tentacle/icons/tentacle.png")
class_name TclConnectionsWidget
extends VBoxContainer

## A ready-made sign-in screen for Embedded mode: one row per platform, with its status
## and a button to connect, disconnect, or sign in again.
##
## Put one in a menu scene and the player can connect their Twitch or Kick channel with
## no code of yours. While signing in, it opens the sign-in page in the player's browser,
## shows Twitch's code and how long it has left, and offers to open the page again or
## cancel; afterwards it says why a sign-in that did not connect failed. In Paired mode it
## shows one line saying the Tentacle app connects the platforms instead.
##
## It takes the look of the project's [Theme] like any other control. For a sign-in
## screen of your own, use [TclSignInButton] nodes, or [method Tentacle_Connections.sign_in].

# Unreal's UTclConnectionsWidget and Unity's ConnectionsWidget. Godot alone has no font
# size or colour settings here, because a Theme already styles every control. Not @tool,
# like the scene's other Tentacle nodes, so an open scene registers nothing.

## The platforms to offer, in the order they are listed.
@export var platforms: Array[TclStreamPlatform.Value] = [
	TclStreamPlatform.Value.TWITCH,
	TclStreamPlatform.Value.KICK,
]

## Open the sign-in page in the player's browser as soon as signing in needs them. Off,
## the row offers a button for it instead.
@export var open_browser_automatically: bool = true

## A connections surface every widget uses instead of the [code]Tentacle[/code]
## autoload's, as if Tentacle were embedded, so a test can drive widgets without the
## autoload. Leave it null in a game.
static var surface_override: Tentacle_Connections = null

## How a row opens a page; a test swaps in a recorder so no browser opens.
var _open_url: Callable = func(url: String) -> void: OS.shell_open(url)


## One platform's row and what it last heard.
class _Row:
	extends RefCounted

	var platform: TclStreamPlatform.Value
	var status: Label
	var detail: Label
	var primary: Button
	var secondary: Button
	var primary_action: TclConnectionsWidgetRow.Action = TclConnectionsWidgetRow.Action.NONE
	var secondary_action: TclConnectionsWidgetRow.Action = TclConnectionsWidgetRow.Action.NONE
	var prompt: TclPlatformConnectionPrompt = null
	var prompt_deadline_msec: int = 0
	var result: TclPlatformConnectionResult = null


var _surface: Tentacle_Connections = null
var _rows: Array[_Row] = []
var _note: Label = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_surface = surface_override
	if _surface == null:
		var runtime := TentacleRuntime.instance()
		if runtime == null or not runtime.is_embedded:
			_note = Label.new()
			_note.text = "Twitch and Kick connect through the Tentacle app"
			add_child(_note)
			set_process(false)
			return
		_surface = runtime.connections

	_surface.OnConnectionChanged.connect(_on_connection_changed)
	_surface.OnConnectPrompt.connect(_on_connect_prompt)
	_surface.OnConnectResult.connect(_on_connect_result)
	for platform in platforms:
		_rows.append(_build_row(platform))
	for row in _rows:
		_refresh(row)


func _exit_tree() -> void:
	if _surface == null:
		return
	if _surface.OnConnectionChanged.is_connected(_on_connection_changed):
		_surface.OnConnectionChanged.disconnect(_on_connection_changed)
	if _surface.OnConnectPrompt.is_connected(_on_connect_prompt):
		_surface.OnConnectPrompt.disconnect(_on_connect_prompt)
	if _surface.OnConnectResult.is_connected(_on_connect_result):
		_surface.OnConnectResult.disconnect(_on_connect_result)


func _process(_delta: float) -> void:
	# The countdown, while a row is signing in.
	for row in _rows:
		if row.prompt != null:
			_refresh(row)


func _build_row(platform: TclStreamPlatform.Value) -> _Row:
	var row := _Row.new()
	row.platform = platform

	var line := HBoxContainer.new()
	var title := Label.new()
	title.text = TclConnectionsWidgetRow.platform_name(platform)
	title.custom_minimum_size.x = 72.0
	line.add_child(title)

	# Wrapped, so a long status takes another line rather than pushing the buttons out
	# of a narrow menu.
	row.status = Label.new()
	row.status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(row.status)

	row.primary = Button.new()
	row.primary.pressed.connect(_on_pressed.bind(row, true))
	line.add_child(row.primary)

	row.secondary = Button.new()
	row.secondary.pressed.connect(_on_pressed.bind(row, false))
	line.add_child(row.secondary)
	add_child(line)

	row.detail = Label.new()
	row.detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.detail.modulate = Color(1.0, 1.0, 1.0, 0.7)
	add_child(row.detail)
	return row


func _refresh(row: _Row) -> void:
	var seconds_left := 0.0
	if row.prompt != null:
		seconds_left = (row.prompt_deadline_msec - Time.get_ticks_msec()) / 1000.0
		if seconds_left <= 0.0:
			# Ran out here; the core's result says so shortly.
			row.prompt = null
	var described := TclConnectionsWidgetRow.describe(
		row.platform,
		_surface.get_connection(row.platform),
		row.prompt,
		seconds_left,
		row.result,
		open_browser_automatically,
	)
	row.status.text = described.status
	row.detail.text = described.detail
	row.detail.visible = described.detail != ""
	row.primary_action = described.primary_action
	row.primary.text = described.primary_label
	row.primary.visible = described.primary_action != TclConnectionsWidgetRow.Action.NONE
	row.secondary_action = described.secondary_action
	row.secondary.text = described.secondary_label
	row.secondary.visible = described.secondary_action != TclConnectionsWidgetRow.Action.NONE


func _row_for(platform: TclStreamPlatform.Value) -> _Row:
	for row in _rows:
		if row.platform == platform:
			return row
	return null


func _on_pressed(row: _Row, primary: bool) -> void:
	match row.primary_action if primary else row.secondary_action:
		TclConnectionsWidgetRow.Action.CONNECT:
			row.result = null
			_surface.connect_platform(row.platform)
		TclConnectionsWidgetRow.Action.DISCONNECT:
			_surface.disconnect_platform(row.platform)
		TclConnectionsWidgetRow.Action.OPEN_PAGE:
			if row.prompt != null:
				_open_url.call(row.prompt.url)
		TclConnectionsWidgetRow.Action.CANCEL:
			_surface.cancel_connect(row.platform)
	_refresh(row)


func _on_connection_changed(connection: TclPlatformConnection) -> void:
	var row := _row_for(connection.platform)
	if row != null:
		_refresh(row)


func _on_connect_prompt(prompt: TclPlatformConnectionPrompt) -> void:
	var row := _row_for(prompt.platform)
	if row == null:
		return
	row.prompt = prompt
	row.prompt_deadline_msec = Time.get_ticks_msec() + prompt.expires_in_seconds * 1000
	row.result = null
	if open_browser_automatically:
		_open_url.call(prompt.url)
	_refresh(row)


func _on_connect_result(result: TclPlatformConnectionResult) -> void:
	var row := _row_for(result.platform)
	if row == null:
		return
	row.prompt = null
	row.result = result
	_refresh(row)
