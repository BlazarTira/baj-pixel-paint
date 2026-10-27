class_name TentacleMemorySocket
extends TentacleSocket

## An in-memory [TentacleSocket]: no peer, no port, no network.
##
## It exists so the session state machine can be driven deterministically - the
## handshake, the backoff, a drop mid-session, a reconnect - with nothing to wait
## for and nothing to tear down. A test calls [method accept] to let the attempt
## succeed, [method deliver] to push a frame inbound, and [method drop] to close
## the socket underneath the addon, then reads [member sent] to see exactly what the
## addon put on the wire.
##
## Pass one to [code]TentacleClient.new()[/code] to drive the addon from your own test
## scene without Tentacle running.

# It ships with the addon rather than living beside the tests because GDScript cannot
# subclass from outside the addon's own scripts without the class being here, and
# because driving the core without Tentacle running is genuinely useful from a game's
# own test scene.

## Every envelope the addon sent, in order, as [code]{type, data}[/code].
var sent: Array[Dictionary] = []

## The URLs [method open_url] was called with, in order.
var opened_urls: Array[String] = []

## When true, [method open_url] reports a failure instead of starting.
##
## This is how a test exercises the "Tentacle is not running" path, which is the
## common case rather than an edge: the addon must treat it as an ordinary state
## and keep retrying.
var refuse_connections: bool = false

## When true, the socket opens as soon as [method poll_socket] is next called,
## rather than waiting for [method accept]. Convenient for a test that only cares
## about what happens after the handshake.
var auto_accept: bool = false

var _open: bool = false
var _pending_open: bool = false


func open_url(url: String) -> Error:
	opened_urls.append(url)
	_open = false
	if refuse_connections:
		return ERR_CANT_CONNECT
	_pending_open = auto_accept
	return OK


# That is what the real transport does: TclSocketClient reports a close only when its
# poll finds the peer gone, never for a close it was asked to make. Emitting here would
# put the core through a path production never takes - a deliberate close re-entering
# the retry logic, and an abandoned handshake counting as two failures.
## Closes the socket from this side, **without** emitting [signal closed], as the real
## transport does.
func close_socket() -> void:
	_open = false
	_pending_open = false


func poll_socket() -> void:
	if _pending_open:
		_pending_open = false
		accept()


func is_socket_open() -> bool:
	return _open


func send_envelope(type: String, data: Dictionary) -> Error:
	if not _open:
		return ERR_UNAVAILABLE
	sent.append({"type": type, "data": data})
	return OK


## Lets the outstanding connection attempt succeed, firing [signal opened].
func accept() -> void:
	if _open:
		return
	_open = true
	opened.emit()


## Pushes one inbound frame at the addon, as if the peer had sent it.
func deliver(type: String, data: Dictionary = {}) -> void:
	message.emit(type, data)


## Closes the socket from the peer's side, firing [signal closed].
##
## Unlike [method close_socket], this is the server going away, which is what a
## reconnect test needs.
func drop(code: int = 1006, reason: String = "dropped") -> void:
	_open = false
	_pending_open = false
	closed.emit(code, reason)


## Every envelope of one type that the addon sent.
func sent_of_type(type: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in sent:
		if entry.get("type", "") == type:
			found.append(entry)
	return found


## Forgets everything recorded so far, so one test can assert in phases.
func clear_sent() -> void:
	sent.clear()
