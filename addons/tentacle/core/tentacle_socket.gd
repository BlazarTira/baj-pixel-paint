class_name TentacleSocket
extends RefCounted

## The transport the Tentacle connection runs over.
##
## Two implementations ship: [TentacleWebSocket], the real WebSocket the
## [code]Tentacle[/code] autoload uses, over the generated [TclSocketClient]; and
## [TentacleMemorySocket], which records what the addon sent and lets a caller inject
## inbound frames, for driving the addon from a test without Tentacle running.
##
## To write your own, extend this class, override the five transport methods and emit
## the three signals. The base methods log an error, so a missing override shows up in
## the output.

# The transport seam between the engine-neutral core and a real WebSocket. The core
# drives a TentacleSocket and never touches WebSocketPeer, which is what lets the session
# state machine be exercised with no socket, no scene, and no play mode - the thing the
# three-layer split exists for. TentacleWebSocket lives in runtime/ because WebSocketPeer
# is engine-layer; TentacleMemorySocket sits beside this file and is what the tests drive.
#
# @abstract would say "subclasses must override" in the language, but it arrived in
# Godot 4.5 and this addon's floor is 4.4, so the base's methods push an error instead.

## The socket completed its handshake and can carry frames.
signal opened()

## The socket closed, with the peer's close code and reason.
signal closed(code: int, reason: String)

## One decoded frame: its wire [param type] and its [code]data[/code] payload.
signal message(type: String, data: Dictionary)


## Starts connecting. The socket is not open until [signal opened] has fired.
func open_url(_url: String) -> Error:
	TentacleLog.error("TentacleSocket.open_url was not overridden")
	return ERR_UNCONFIGURED


## Closes the connection. Safe to call when already closed.
func close_socket() -> void:
	TentacleLog.error("TentacleSocket.close_socket was not overridden")


## Advances the transport, emitting whatever its traffic produced.
##
## Every signal fires inside this call, on the calling thread, which is what lets
## a handler touch the scene tree directly.
func poll_socket() -> void:
	pass


## True when a frame can be sent right now.
func is_socket_open() -> bool:
	return false


## Sends one envelope. Returns [constant ERR_UNAVAILABLE] when not open.
func send_envelope(_type: String, _data: Dictionary) -> Error:
	TentacleLog.error("TentacleSocket.send_envelope was not overridden")
	return ERR_UNCONFIGURED
