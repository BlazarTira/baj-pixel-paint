class_name TentacleWebSocket
extends TentacleSocket

## A [TentacleSocket] over the generated [TclSocketClient], which uses Godot's
## [WebSocketPeer]. This is the transport the [code]Tentacle[/code] autoload uses.

# The engine-layer half of the transport seam: WebSocketPeer lives here so the core never
# sees it. Thin by design - it forwards three signals and five calls, and holds no state
# of its own beyond the client it owns.

var _client: TclSocketClient = TclSocketClient.new()


func _init() -> void:
	# Methods rather than lambdas: a lambda written here holds this object, and the
	# client it is connected to is this object's own, so the two held each other and
	# neither was ever freed.
	_client.socket_opened.connect(_on_socket_opened)
	_client.socket_closed.connect(_on_socket_closed)
	# One inbound signal carrying the wire type, so a message type added upstream
	# cannot arrive on a signal nothing subscribed to. The core routes on the type.
	_client.message_received.connect(_on_message_received)


func open_url(url: String) -> Error:
	return _client.connect_to_url(url)


func close_socket() -> void:
	_client.close_connection()


func poll_socket() -> void:
	_client.poll()


func is_socket_open() -> bool:
	return _client.is_open()


func send_envelope(type: String, data: Dictionary) -> Error:
	return _client.send_message(type, data)


func _on_socket_opened() -> void:
	opened.emit()


func _on_socket_closed(code: int, reason: String) -> void:
	closed.emit(code, reason)


func _on_message_received(type: String, data: Dictionary) -> void:
	message.emit(type, data)
