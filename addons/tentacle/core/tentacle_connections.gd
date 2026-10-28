class_name Tentacle_Connections
extends RefCounted

## Connecting the streaming platforms from the game, which signs the player in, and each
## platform's connection as Tentacle reports it.
##
## This is for Tentacle running inside the game ([constant TclTentacleMode.Value.EMBEDDED]),
## where the game signs the player in itself. The Tentacle app has its own sign-in, so
## with the app none of these calls are answered.
##
## [method sign_in] does all of signing in at once:
##
## [codeblock]
## func _on_sign_in_pressed() -> void:
##     var result := await Tentacle.connections.sign_in(TclStreamPlatform.Value.TWITCH)
## [/codeblock]
##
## For a sign-in button, the [TclSignInButton] node is one, styled by your Theme, and
## [method create_sign_in_controller] is the logic of one for a button of your own.
##
## For finer control, [method connect_platform] starts it: [signal OnConnectPrompt] says
## what to show (open the page in a browser with [method OS.shell_open], and show the
## code in case the page asks for it), and [signal OnConnectResult] how it ended. The
## account stays signed in across runs until [method disconnect_platform]. Those calls
## are fire-and-forget; their outcome arrives as a signal.
##
## [method has_permission] says whether the account lets Tentacle do something, and
## [signal OnPermissionNeeded] fires when Tentacle refused a request because it doesn't.

# Unreal's UTentacle_Connections and Unity's Tentacle_Connections. Object owns connect()
# and disconnect(), so those two are spelled connect_platform() and disconnect_platform(),
# the same dodge the session's connect_session() makes; everything else keeps Unreal's
# name.

## A platform's connection changed, and once for each platform as a session opens.
## [method get_connection] already returns the new connection when it fires.
signal OnConnectionChanged(connection: TclPlatformConnection)

## Connecting needs the player: open [member TclPlatformConnectionPrompt.url] in a
## browser, and show [member TclPlatformConnectionPrompt.user_code] (when there is one)
## in case the page asks for it.
signal OnConnectPrompt(prompt: TclPlatformConnectionPrompt)

## Connecting ended: connected, denied, expired, cancelled, or failed.
signal OnConnectResult(result: TclPlatformConnectionResult)

## Tentacle refused a request, or a chat message, because the account has not allowed a
## permission it needs. Offer the player to sign in again with one of
## [member TclPlatformPermissionNeeded.permissions] turned on. Each one is also logged as
## an error.
signal OnPermissionNeeded(permission_needed: TclPlatformPermissionNeeded)

## Whether Tentacle runs inside the game, where the game signs the player in. The
## runtime sets it; with the Tentacle app, [method sign_in] fails at once.
var embedded: bool = false

## Opens a sign-in page in the player's browser, taking its URL. The runtime sets it to
## [method OS.shell_open]; empty opens nothing.
var open_url: Callable = Callable()

var _session: TentacleSession = null

## Each platform's last reported connection, by [enum TclStreamPlatform.Value].
var _connections: Dictionary[int, TclPlatformConnection] = {}

# Each platform's sign_in in progress, by TclStreamPlatform.Value. Tentacle drops an
# attempt a new connect replaces without reporting it, so a new sign_in ends the one it
# replaces itself, or that call would never return. An entry lives only until its sign-in
# ends, which is what lets the suspended call go.
var _sign_ins: Dictionary[int, _SignIn] = {}

# Every sign-in controller made here, held weakly: the game's reference is what keeps
# one, so letting go of it is enough to stop it. Each hears every message before the
# signals do, and the client's advance moves their countdowns.
var _sign_in_controllers: Array[WeakRef] = []

# The platforms a message was ignored for, so each is logged once.
var _unknown_platforms: Dictionary[String, bool] = {}


## One sign_in waiting on how it ends.
class _SignIn:
	extends RefCounted

	## Emitted once, with how signing in ended.
	signal ended(result: TclPlatformConnectionResult)

	var open_browser: bool = true
	var on_prompt: Callable = Callable()


func _init(session: TentacleSession = null) -> void:
	_session = session


## A platform's connection as Tentacle last reported it, or null before it has reported
## one.
func get_connection(platform: TclStreamPlatform.Value) -> TclPlatformConnection:
	return _connections.get(platform, null)


## Whether the account signed in to [param platform] lets Tentacle do what
## [param permission] covers, as Tentacle last reported. False with no account.
func has_permission(platform: TclStreamPlatform.Value, permission: TclPlatformPermission.Value) -> bool:
	var connection := get_connection(platform)
	return connection != null and connection.permissions != null and connection.permissions.allowed.has(permission)


## Signs the player in to [param platform] in one call, as the connections widget's
## button does: Tentacle connects it, the sign-in page opens in the player's browser
## unless [param open_browser] is false, and the call returns how it ended, so await it.
## [param on_prompt] is called with the [TclPlatformConnectionPrompt] as the page opens,
## with the code to show for Twitch. Signing in to the same platform again ends this call
## as cancelled. With the Tentacle app, which has its own sign-in, it returns at once as
## an error. [param permissions] is what to ask for besides what the game requires, as
## [method connect_platform] takes it.
func sign_in(
	platform: TclStreamPlatform.Value,
	open_browser: bool = true,
	on_prompt: Callable = Callable(),
	permissions: Array[TclPlatformPermission.Value] = [],
) -> TclPlatformConnectionResult:
	if not embedded:
		return _ended_as(platform, TclPlatformConnectionOutcome.Value.ERROR, "Twitch and Kick connect through the Tentacle app")
	var replaced: _SignIn = _sign_ins.get(platform, null)
	var pending := _SignIn.new()
	pending.open_browser = open_browser
	pending.on_prompt = on_prompt
	_sign_ins[platform] = pending
	if replaced != null:
		replaced.ended.emit(_ended_as(platform, TclPlatformConnectionOutcome.Value.CANCELLED, null))
	connect_platform(platform, permissions)
	var result: TclPlatformConnectionResult = await pending.ended
	return result


## A sign-in controller for [param platform]: the logic of a sign-in button with no look
## of its own, for a button of your own design. It opens the sign-in page in the
## player's browser unless [param open_browser] is false. Keep a reference to it while
## the button is on screen. [TclSignInButton] makes one for you.
func create_sign_in_controller(platform: TclStreamPlatform.Value, open_browser: bool = true) -> TclSignInController:
	var controller := TclSignInController.new(self, platform, open_browser)
	_sign_in_controllers.append(weakref(controller))
	return controller


## Moves every sign-in controller's countdown on by [param delta] seconds; the client
## calls it every frame.
func advance(delta: float) -> void:
	for controller in _live_sign_in_controllers():
		controller.advance(delta)


## Starts connecting [param platform], which signs the player in, replacing any attempt
## already in progress. [signal OnConnectPrompt] follows with what to show them.
##
## [param permissions] is what to ask for besides what the game requires, such as the
## features the player turned on in the game's own settings. Empty asks for everything
## the player has not turned off; to ask for only what the game requires, name
## [constant TclPlatformPermission.Value.CHAT].
##
## Named [code]connect_platform[/code] rather than [code]connect[/code] because
## [method Object.connect] is a member of every Godot object, as
## [method disconnect_platform] is for the same reason.
func connect_platform(platform: TclStreamPlatform.Value, permissions: Array[TclPlatformPermission.Value] = []) -> void:
	_send("Connections_Connect", platform, permissions)


## Turns [param permissions] off for the account signed in to [param platform] without
## signing in again, such as ones the player said no to after an update of the game asked
## for more. The next sign-in leaves them out.
func decline_permissions(platform: TclStreamPlatform.Value, permissions: Array[TclPlatformPermission.Value]) -> void:
	if permissions.is_empty():
		return
	_send("Connections_DeclinePermissions", platform, permissions)


## Abandons the connection attempt in progress on [param platform].
func cancel_connect(platform: TclStreamPlatform.Value) -> void:
	_send("Connections_CancelConnect", platform)


## Disconnects [param platform], signing its account out and forgetting it.
func disconnect_platform(platform: TclStreamPlatform.Value) -> void:
	_send("Connections_Disconnect", platform)


## Takes one [code]Connections_Status[/code] payload.
func handle_status(data: Dictionary) -> TclPlatformConnection:
	if not _for_known_platform(data):
		return null
	var connection := TclPlatformConnection.parse(data)
	if connection == null:
		return null
	_connections[connection.platform] = connection
	for controller in _live_sign_in_controllers():
		controller.refresh()
	OnConnectionChanged.emit(connection)
	return connection


## Takes one [code]Connections_Prompt[/code] payload.
func handle_prompt(data: Dictionary) -> void:
	if not _for_known_platform(data):
		return
	var prompt := TclPlatformConnectionPrompt.parse(data)
	if prompt == null:
		return
	var pending: _SignIn = _sign_ins.get(prompt.platform, null)
	if pending != null:
		if pending.open_browser and open_url.is_valid():
			open_url.call(prompt.url)
		if pending.on_prompt.is_valid():
			pending.on_prompt.call(prompt)
	for controller in _live_sign_in_controllers():
		controller.handle_prompt(prompt)
	OnConnectPrompt.emit(prompt)


## Takes one [code]Connections_Result[/code] payload.
func handle_result(data: Dictionary) -> void:
	if not _for_known_platform(data):
		return
	var result := TclPlatformConnectionResult.parse(data)
	if result == null:
		return
	var pending: _SignIn = _sign_ins.get(result.platform, null)
	if pending != null:
		_sign_ins.erase(result.platform)
		pending.ended.emit(result)
	for controller in _live_sign_in_controllers():
		controller.handle_result(result)
	OnConnectResult.emit(result)


## Takes one [code]Connections_PermissionNeeded[/code] payload.
func handle_permission_needed(data: Dictionary) -> void:
	if not _for_known_platform(data):
		return
	var needed := TclPlatformPermissionNeeded.parse(data)
	if needed == null:
		return
	# An error rather than a warning: what the game asked for did not happen, and the
	# player has to do something about it.
	TentacleLog.error(permission_needed_message(needed))
	OnPermissionNeeded.emit(needed)


## What a refused request is logged as: what needed which permissions, by the names the
## Tentacle app shows, and what to do about it.
static func permission_needed_message(needed: TclPlatformPermissionNeeded) -> String:
	# Tentacle's core and the other plugins word it the same way.
	var names := PackedStringArray(needed.permission_names)
	var platform := "Kick" if needed.platform == TclStreamPlatform.Value.KICK else "Twitch"
	if names.is_empty():
		return "%s needs a %s permission this account hasn't allowed." % [needed.request, platform]
	var which := "one of them" if names.size() > 1 else "it"
	return "%s needs the %s permission on %s, which this account hasn't allowed. Sign in to %s again with %s turned on." % [
		needed.request,
		TentacleQuietEvents.quoted_names(names),
		platform,
		platform,
		which,
	]


## Whether [param data] is about a platform this version knows. A newer Tentacle reports
## platforms this version predates, and reading one as the enum's first member would
## file its connection, sign-in, or refusal under Twitch, so it is ignored instead, and
## logged once per platform.
func _for_known_platform(data: Dictionary) -> bool:
	var platform := TclJson.as_string(TclJson.read_value(data, "platform"))
	if TclStreamPlatform.is_known(platform):
		return true
	if not _unknown_platforms.has(platform):
		_unknown_platforms[platform] = true
		TentacleLog.warn('ignoring "%s", a platform this version of the plugin doesn\'t know.' % platform)
	return false


## A result for [param platform] that this side decided, as Tentacle would report one.
func _ended_as(platform: TclStreamPlatform.Value, outcome: TclPlatformConnectionOutcome.Value, message: Variant) -> TclPlatformConnectionResult:
	var result := TclPlatformConnectionResult.new()
	result.platform = platform
	result.outcome = outcome
	result.message = message
	return result


## The sign-in controllers the game still holds, forgetting the ones it let go of.
func _live_sign_in_controllers() -> Array[TclSignInController]:
	var live: Array[TclSignInController] = []
	var kept: Array[WeakRef] = []
	for held in _sign_in_controllers:
		var controller: TclSignInController = held.get_ref()
		if controller != null:
			live.append(controller)
			kept.append(held)
	_sign_in_controllers = kept
	return live


func _send(type: String, platform: TclStreamPlatform.Value, permissions: Array[TclPlatformPermission.Value] = []) -> void:
	if _session == null:
		return
	# Dropped while no session is open, like every other message: there is nothing to
	# sign in to until there is.
	var data := {"platform": TclStreamPlatform.to_wire(platform)}
	if not permissions.is_empty():
		var ids: Array[String] = []
		for permission in permissions:
			ids.append(TclPlatformPermission.to_wire(permission))
		data["permissions"] = ids
	_session.send(type, data)
