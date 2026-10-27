class_name TentacleRpc
extends RefCounted

## How the addon makes its HTTP calls to Tentacle.
##
## Viewer properties and the subathon counters are tRPC procedures rather than socket
## messages. The [code]Tentacle[/code] autoload supplies [TentacleHttpRpc], which sends
## them through Godot's [HTTPRequest]; extend this class to supply your own, such as a
## fake for your tests.
##
## Everything is callback-shaped rather than awaited, and the callback always fires
## exactly once, whether the call succeeded, failed, or never started.

# The seam between the engine-neutral core and Godot's HTTPRequest. The generated
# TclHttpClient is a Node, because HTTPRequest only works inside the scene tree, which
# makes it engine-layer; the core needs HTTP anyway, so it goes through this instead and
# the engine layer supplies the real implementation.
#
# Callback-shaped because a game may be mid-frame when it asks, Tentacle may be closed,
# and the answer may never come; a callback that always fires exactly once is the honest
# shape for that, and it is what Godot's own HTTPRequest offers.

## Issues one tRPC call.
##
## [param procedure] is the dot path, e.g. [code]viewerProperty.getRegistry[/code].
## [param is_query] sends GET with the input in the query string; otherwise POST.
## [param on_complete] is invoked exactly once, as
## [code](success: bool, status: int, body: String, error: String)[/code], whether
## the call succeeded, failed, or never started.
func call_procedure(
	_procedure: String,
	_is_query: bool,
	_input_json: String,
	on_complete: Callable,
) -> void:
	TentacleLog.error("TentacleRpc.call_procedure was not overridden")
	fail(on_complete, "the Tentacle RPC client is not configured")


## Takes one [code]Rpc_Response[/code] the session received. Only a transport that sends
## its calls over the session, [TentacleConnectionRpc], has any to take; this one ignores
## it.
func handle_response(_data: Dictionary) -> void:
	pass


# Shared rather than duplicated, because the one invariant every caller relies on is that
# the callback fires exactly once on every path.
## Reports a failure a call never got far enough to discover itself, calling
## [param on_complete] with [code]success[/code] false.
static func fail(on_complete: Callable, error: String) -> void:
	if on_complete.is_valid():
		on_complete.call(false, 0, "", error)
