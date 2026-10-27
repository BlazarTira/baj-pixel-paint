class_name TentacleConnectionRpc
extends TentacleRpc

## A [TentacleRpc] that carries each call over the session itself rather than over HTTP,
## which is how the [code]Tentacle[/code] autoload reaches Tentacle's core in Embedded
## mode, where there is no HTTP server.
##
## Each call goes out as an [code]Rpc_Request[/code] naming the procedure and carrying its
## input, and comes back as the [code]Rpc_Response[/code] with the same id, holding the
## status and body Tentacle's HTTP API would have answered with. Everything above the
## [TentacleRpc] is unchanged.
##
## A call made while no session is open fails at once, and a session that closes fails
## every call still waiting for its answer, so a callback always fires exactly once.

# Unreal's FTclConnectionProcedures and Unity's TentacleConnectionProcedures. The core's
# side is crates/tentacle-core/src/rpc. Callbacks fire inside the session's poll, on the
# main thread, like every other signal in the addon.

var _session: TentacleSession = null
var _pending: Dictionary[String, Callable] = {}
var _next_id: int = 0


func _init(session: TentacleSession = null) -> void:
	_session = session
	if _session != null:
		_session.status_changed.connect(_on_status_changed)


## How many calls are waiting for their answer.
func pending_count() -> int:
	return _pending.size()


func call_procedure(
	procedure: String,
	_is_query: bool,
	input_json: String,
	on_complete: Callable,
) -> void:
	if _session == null or not _session.is_connected_to_tentacle():
		fail(on_complete, "Tentacle is not connected")
		return

	# The core knows which procedures are queries, so only the name and the input go.
	_next_id += 1
	var request := TclMsg_ClientToServer_RpcRequest.new()
	request.id = "rpc-%d" % _next_id
	request.procedure = procedure
	if not input_json.is_empty():
		request.input = input_json

	_pending[request.id] = on_complete
	# The generated message writes the whole envelope; the session adds its own.
	var envelope := request.to_dictionary()
	if not _session.send(str(envelope["type"]), envelope["data"] as Dictionary):
		_pending.erase(request.id)
		fail(on_complete, "Tentacle is not connected")


## Completes the call an [code]Rpc_Response[/code] answers. One answering no call that is
## waiting is dropped.
func handle_response(data: Dictionary) -> void:
	# The generated message reads a whole envelope, of which the session hands on the data.
	var response := TclMsg_ServerToClient_RpcResponse.parse({"data": data})
	if response == null or not _pending.has(response.id):
		return
	var on_complete: Callable = _pending[response.id]
	_pending.erase(response.id)
	if not on_complete.is_valid():
		return
	# Read as the HTTP transport reads an answer, so the surfaces cannot tell them apart.
	if response.status < 200 or response.status >= 300:
		on_complete.call(false, response.status, response.body, "Tentacle answered %d" % response.status)
		return
	on_complete.call(true, response.status, response.body, "")


## Fails every call still waiting, because no answer will come for it.
func fail_all(why: String) -> void:
	var waiting := _pending.values()
	_pending.clear()
	for on_complete: Callable in waiting:
		fail(on_complete, why)


func _on_status_changed(status: TclConnectionStatus.Value) -> void:
	if status != TclConnectionStatus.Value.CONNECTED:
		fail_all("the session closed before Tentacle answered")
