class_name TentacleHttpRpc
extends TentacleRpc

## A [TentacleRpc] over the generated [TclHttpClient], which is what the
## [code]Tentacle[/code] autoload uses.
##
## [TclHttpClient] is a [Node], because [HTTPRequest] only works inside the scene tree,
## so it has to be in the tree for calls to go out; the autoload adds it as a child.

# The engine-layer half of the tRPC seam: TclHttpClient being a Node is exactly why the
# core cannot hold one, so this owns it and the runtime parents it.

var _client: TclHttpClient = null


func _init(client: TclHttpClient = null) -> void:
	_client = client


## Points the client at Tentacle's HTTP root. Called on every connection attempt,
## because Tentacle may have restarted onto a different port.
func set_base_url(base_url: String) -> void:
	if _client != null:
		_client.base_url = base_url


func call_procedure(
	procedure: String,
	is_query: bool,
	input_json: String,
	on_complete: Callable,
) -> void:
	if _client == null:
		fail(on_complete, "the Tentacle HTTP client is not available")
		return
	_client.call_procedure(procedure, is_query, input_json, on_complete)
