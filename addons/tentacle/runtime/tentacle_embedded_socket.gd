class_name TentacleEmbeddedSocket
extends TentacleSocket

## A [TentacleSocket] over a connection to the Tentacle core running inside the game (see
## [TentacleEmbeddedCore]). This is the transport the [code]Tentacle[/code] autoload uses
## in Embedded mode.
##
## It carries the same frames the WebSocket to the app does, so the session above it
## shakes hands, reconnects, and routes exactly as it does over the WebSocket. Frames are
## polled from the core in [method poll_socket], so every signal still fires on the main
## thread.

# Unreal's FTclEmbeddedEngineSocket and Unity's TentacleEmbeddedTransport. Unity reads on
# a thread of its own; this polls from the autoload's _process instead, as the WebSocket
# does, which is what keeps every signal on the main thread.

## The most frames one poll hands on, so a burst cannot stall a frame.
const MAX_FRAMES_PER_POLL: int = 512

## How the core starts, when this socket's connection is the one that starts it.
var options: TentacleEmbeddedOptions = TentacleEmbeddedOptions.new()

## Opens a connection for [param options], or returns null, when a test supplies one;
## otherwise [method TentacleEmbeddedCore.open_connection] does.
var _open_connection: Callable = Callable()

## The open TentacleNativeConnection, reached only through call() because the class
## exists only when the GDExtension is installed.
var _connection: Object = null
var _open: bool = false
var _opening: bool = false


func _init(embedded_options: TentacleEmbeddedOptions = null, open_connection: Callable = Callable()) -> void:
	if embedded_options != null:
		options = embedded_options
	_open_connection = open_connection


func open_url(_url: String) -> Error:
	close_socket()
	var connection: Object = (
		_open_connection.call(options) if _open_connection.is_valid()
		else TentacleEmbeddedCore.open_connection(options)
	)
	if connection == null:
		return ERR_CANT_CONNECT
	_connection = connection
	# Reported on the next poll, as a WebSocket's open is, after the session has
	# recorded that it is connecting.
	_opening = true
	return OK


# The core is not told why: closing a connection ends its session, which is all a close
# means to it.
## Closes the connection from this side, **without** emitting [signal closed], as the
## WebSocket transport does.
func close_socket() -> void:
	if _connection != null:
		_connection.call("close")
	_connection = null
	_open = false
	_opening = false


func poll_socket() -> void:
	if _connection == null:
		return

	if _opening:
		_opening = false
		_open = true
		opened.emit()

	var connection := _connection
	var frames: PackedStringArray = connection.call("poll", MAX_FRAMES_PER_POLL)
	for frame in frames:
		_dispatch(frame)
		# A handler may have closed the session, which ends this connection.
		if _connection != connection:
			return

	if bool(connection.call("is_closed")):
		var reason := str(connection.call("close_reason"))
		_connection = null
		_open = false
		closed.emit(1000, reason)


func is_socket_open() -> bool:
	return _open


func send_envelope(type: String, data: Dictionary) -> Error:
	if not _open or _connection == null:
		return ERR_UNAVAILABLE
	var envelope: Dictionary = {"type": type}
	# Left out when empty, as the WebSocket transport leaves it out.
	if not data.is_empty():
		envelope["data"] = data
	if not bool(_connection.call("send", JSON.stringify(envelope))):
		return ERR_UNAVAILABLE
	return OK


## Routes one frame onto [signal message], as the WebSocket transport decodes one.
func _dispatch(text: String) -> void:
	var envelope: Variant = TclJson.parse_text(text)
	if not TclJson.is_object(envelope):
		TentacleLog.warn("ignoring a frame from the embedded core that is not a JSON object")
		return
	var object := TclJson.as_dictionary(envelope)
	var type := TclJson.as_string(TclJson.read_value(object, "type"))
	if type.is_empty():
		TentacleLog.warn("ignoring a frame from the embedded core with no type")
		return
	message.emit(type, TclJson.read_object(object, "data"))
