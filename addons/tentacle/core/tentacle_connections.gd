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


## Signs the player in to [param platform] in one call, as the connections widget's
## button does: Tentacle connects it, the sign-in page opens in the player's browser
## unless [param open_browser] is false, and the call returns how it ended, so await it.
## [param on_prompt] is called with the [TclPlatformConnectionPrompt] as the page opens,
## with the code to show for Twitch. Signing in to the same platform again ends this call
## as cancelled. With the Tentacle app, which has its own sign-in, it returns at once as
## an error.
func sign_in(platform: TclStreamPlatform.Value, open_browser: bool = true, on_prompt: Callable = Callable()) -> TclPlatformConnectionResult:
	if not embedded:
		return _ended_as(platform, TclPlatformConnectionOutcome.Value.ERROR, "Twitch and Kick connect through the Tentacle app")
	var replaced: _SignIn = _sign_ins.get(platform, null)
	var pending := _SignIn.new()
	pending.open_browser = open_browser
	pending.on_prompt = on_prompt
	_sign_ins[platform] = pending
	if replaced != null:
		replaced.ended.emit(_ended_as(platform, TclPlatformConnectionOutcome.Value.CANCELLED, null))
	connect_platform(platform)
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
## Named [code]connect_platform[/code] rather than [code]connect[/code] because
## [method Object.connect] is a member of every Godot object, as
## [method disconnect_platform] is for the same reason.
func connect_platform(platform: TclStreamPlatform.Value) -> void:
	_send("Connections_Connect", platform)


## Abandons the connection attempt in progress on [param platform].
func cancel_connect(platform: TclStreamPlatform.Value) -> void:
	_send("Connections_CancelConnect", platform)


## Disconnects [param platform], signing its account out and forgetting it.
func disconnect_platform(platform: TclStreamPlatform.Value) -> void:
	_send("Connections_Disconnect", platform)


## Takes one [code]Connections_Status[/code] payload.
func handle_status(data: Dictionary) -> void:
	var connection := TclPlatformConnection.parse(data)
	if connection == null:
		return
	_connections[connection.platform] = connection
	for controller in _live_sign_in_controllers():
		controller.refresh()
	OnConnectionChanged.emit(connection)


## Takes one [code]Connections_Prompt[/code] payload.
func handle_prompt(data: Dictionary) -> void:
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


func _send(type: String, platform: TclStreamPlatform.Value) -> void:
	if _session == null:
		return
	# Dropped while no session is open, like every other message: there is nothing to
	# sign in to until there is.
	_session.send(type, {"platform": TclStreamPlatform.to_wire(platform)})
