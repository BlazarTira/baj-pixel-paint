class_name TentacleSession
extends RefCounted

## The connection state machine: dial, handshake, drop, back off, dial again.
##
## **Tentacle hosts the engine listener; the addon dials in.** The game never opens a
## listening socket, so there is no firewall prompt and no leaked editor port, and
## several sessions can be live at once, such as an editor run beside an exported
## build.
##
## **"Not connected" is an ordinary state, never an error.** Tentacle is a desktop
## app the streamer opens and closes at will, so this retries forever with capped,
## jittered backoff and nothing it does can throw into a game loop.
##
## It works on a [TentacleSocket] and takes its time from [method advance], so a test
## can drive the whole lifecycle with a [TentacleMemorySocket].

# It is engine-neutral on purpose: it holds a TentacleSocket rather than a WebSocketPeer,
# takes its delta from whoever pumps it rather than reading a clock, and is handed its
# URL and identity by the engine layer. That is what lets the whole lifecycle be tested
# with TentacleMemorySocket - no scene, no play mode, no port, no sleeping. Sessions from
# different engines, a Godot game beside an Unreal one, can be live at once too.

## The session's position changed.
signal status_changed(status: TclConnectionStatus.Value)

## A session opened and carries this id. A reconnect brings a new one.
signal session_opened(new_session_id: String)

## One inbound frame that is not part of the handshake, for the client to route.
signal frame(type: String, data: Dictionary)

## The handshake frames, which sit outside the generated message surface.
const SESSION_HELLO: String = "Session_Hello"
const SESSION_WELCOME: String = "Session_Welcome"

## The reason Tentacle closes a session with when its user set a connection
## password and the game sent none, or a wrong one.
# The app's SESSION_PASSWORD_REFUSED (packages/common/src/json/engine-session-json.ts).
const PASSWORD_REFUSED_REASON: String = "connection password missing or wrong"

## How long the socket may take to open, and then to be greeted, in seconds.
##
## One budget covering both halves: either stalling means the same thing, and the
## server closes an un-greeted socket after ten seconds anyway.
var handshake_timeout: float = 10.0

## Where the session currently is.
var status: TclConnectionStatus.Value = TclConnectionStatus.Value.DISCONNECTED

## The server-assigned session id. Empty while not connected.
var session_id: String = ""

## Who this game says it is. The [code]Tentacle[/code] autoload sets it before
## connecting.
var identity: TentacleEngineIdentity = null

## Returns the engine-socket URL to dial, called fresh on **every** attempt.
##
## A Callable rather than a stored string because Tentacle may have started, or
## restarted onto a different port, since the last attempt - so the URL has to be
## re-resolved rather than remembered.
var url_provider: Callable = Callable()

## The backoff policy. The [code]Tentacle[/code] autoload carries its reconnect
## settings through to it.
var reconnect: TentacleReconnectPolicy = TentacleReconnectPolicy.new()

var _socket: TentacleSocket = null
var _want_connection: bool = false
var _failures: int = 0
# Whether the "Tentacle wants its connection password" warning has been given since
# the last session, so it is said once rather than on every retry.
var _reported_password_refused: bool = false

# A monotonic accumulator rather than a wall clock, so a system clock change cannot
# strand the retry schedule.
var _now: float = 0.0
var _retry_at: float = 0.0
var _handshake_deadline: float = 0.0


func _init(socket: TentacleSocket = null) -> void:
	set_socket(socket)


## Installs the transport. Called once by whoever builds the session.
func set_socket(socket: TentacleSocket) -> void:
	if _socket != null:
		_socket.opened.disconnect(_on_socket_opened)
		_socket.closed.disconnect(_on_socket_closed)
		_socket.message.disconnect(_on_socket_message)
	_socket = socket
	if _socket != null:
		_socket.opened.connect(_on_socket_opened)
		_socket.closed.connect(_on_socket_closed)
		_socket.message.connect(_on_socket_message)


## The transport in use.
func socket() -> TentacleSocket:
	return _socket


## True once the handshake has completed.
func is_connected_to_tentacle() -> bool:
	return status == TclConnectionStatus.Value.CONNECTED


## Starts connecting, and keeps retrying until [method disconnect_session].
##
## Idempotent: calling it while already connecting or connected changes nothing.
func connect_session() -> void:
	if _want_connection:
		return
	_want_connection = true
	_failures = 0
	_retry_at = 0.0


## Stops connecting and closes any open socket.
func disconnect_session() -> void:
	_want_connection = false
	if _socket != null:
		_socket.close_socket()
	session_id = ""
	_set_status(TclConnectionStatus.Value.DISCONNECTED)


## Drives the session forward by [param delta] seconds.
##
## Everything happens inside this call, on the calling thread: the socket is polled,
## inbound frames are routed, and the retry schedule advances. That is what lets a
## handler touch the scene tree directly.
func advance(delta: float) -> void:
	_now += delta

	if _socket != null:
		_socket.poll_socket()

	if not _want_connection:
		return
	if status == TclConnectionStatus.Value.CONNECTED:
		return

	if status == TclConnectionStatus.Value.CONNECTING:
		if _now >= _handshake_deadline:
			TentacleLog.info("the session handshake timed out; retrying")
			_schedule_retry()
		return

	if _now < _retry_at:
		return

	_begin_attempt()


## Sends one envelope, if a session is open. Returns false when it was dropped.
##
## Dropping while disconnected is ordinary rather than an error: the custom-control
## registry is replayed on the next session, and anything else was transient.
func send(type: String, data: Dictionary) -> bool:
	if _socket == null or not is_connected_to_tentacle():
		return false
	return _socket.send_envelope(type, data) == OK


# --- Internals ---------------------------------------------------------------

func _set_status(next: TclConnectionStatus.Value) -> void:
	if status == next:
		return
	status = next
	status_changed.emit(status)


func _begin_attempt() -> void:
	if _socket == null or not url_provider.is_valid():
		_schedule_retry()
		return

	var url := str(url_provider.call())
	if url.is_empty():
		# No endpoint to dial yet, which means Tentacle has never run on this
		# machine. Ordinary; try again later.
		_schedule_retry()
		return

	if _socket.open_url(url) != OK:
		# Tentacle not running is the common case here, and not worth telling the
		# game about.
		_schedule_retry()
		return

	_handshake_deadline = _now + handshake_timeout * 2.0
	_set_status(TclConnectionStatus.Value.CONNECTING)


func _schedule_retry() -> void:
	if _socket != null:
		_socket.close_socket()
	session_id = ""

	if not _want_connection:
		_set_status(TclConnectionStatus.Value.DISCONNECTED)
		return

	_failures += 1
	_retry_at = _now + reconnect.delay_for(_failures, randf())
	_set_status(TclConnectionStatus.Value.RECONNECTING)


func _on_socket_opened() -> void:
	_send_hello()
	_handshake_deadline = _now + handshake_timeout


func _on_socket_closed(code: int, reason: String) -> void:
	if reason == PASSWORD_REFUSED_REASON:
		# The user's to fix, on one side or the other, so it is said once, plainly,
		# and the session keeps trying: clearing or matching the password in Tentacle
		# lets the next attempt in.
		if not _reported_password_refused:
			_reported_password_refused = true
			var sent := identity != null and not identity.password.is_empty()
			TentacleLog.warn(
				(
					"Tentacle has a connection password set, and %s. Set the Tentacle "
					+ "autoload's connection_password, or Project Settings > Tentacle > "
					+ "Connection > Connection Password, to the one under Settings > System > "
					+ "Connection Password in Tentacle. Retrying in the background."
				)
				% ("the one this game sent is wrong" if sent else "this game sent none")
			)
	elif not reason.is_empty():
		TentacleLog.info("the engine socket closed (%d): %s" % [code, reason])
	_schedule_retry()


func _send_hello() -> void:
	if _socket == null:
		return
	var hello := identity.to_hello() if identity != null else {}
	# Sent directly rather than through send(): the session is not CONNECTED yet,
	# and the hello is what makes it so.
	_socket.send_envelope(SESSION_HELLO, hello)


func _on_socket_message(type: String, data: Dictionary) -> void:
	if type == SESSION_WELCOME:
		_handle_welcome(data)
		return

	if not is_connected_to_tentacle():
		# A frame before the welcome. Nothing is surfaced before the handshake
		# completes, so a game cannot see an event from a session it has no id for.
		TentacleLog.info('ignoring "%s" received before the session welcome' % type)
		return

	frame.emit(type, data)


func _handle_welcome(data: Dictionary) -> void:
	var new_id := TclJson.as_string(TclJson.read_value(data, "sessionId"))
	if new_id.is_empty():
		# A welcome with no session id is a failed handshake, not a live session;
		# keeping the socket would leave it half-open until the server reaped it.
		TentacleLog.warn("the session handshake returned no session id")
		_schedule_retry()
		return

	session_id = new_id
	_failures = 0
	_reported_password_refused = false
	_set_status(TclConnectionStatus.Value.CONNECTED)
	session_opened.emit(session_id)
