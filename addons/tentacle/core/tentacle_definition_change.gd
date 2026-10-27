class_name TentacleDefinitionChange
extends RefCounted

## Makes one change to the streamer's definitions and reports what it came to.

# Shared by every surface a game changes the streamer's definitions from, as Unity's
# TentacleClient.ChangeDefinitionAsync and tentacle-web's changeDefinition are.


## Calls one mutation that changes the streamer's definitions, and calls
## [param on_complete] once with a [enum TclDefinitionResult.Value]: NOT_FOUND when
## Tentacle has nothing by the name or id it named, NAME_TAKEN when another already has
## the name it asked for, and FAILED for anything else - Tentacle not running, or the
## change refused - with the reason logged.
static func change(rpc: TentacleRpc, procedure: String, input: Dictionary, on_complete: Callable) -> void:
	if rpc == null:
		TentacleLog.warn("%s failed: there is no connection to Tentacle" % procedure)
		finish(on_complete, TclDefinitionResult.Value.FAILED)
		return
	rpc.call_procedure(
		procedure,
		false,
		TclJson.to_text(input),
		func(success: bool, status: int, _body: String, error: String) -> void:
			if success:
				finish(on_complete, TclDefinitionResult.Value.SUCCESS)
			elif status == 404:
				finish(on_complete, TclDefinitionResult.Value.NOT_FOUND)
			elif status == 409:
				finish(on_complete, TclDefinitionResult.Value.NAME_TAKEN)
			else:
				TentacleLog.warn("%s failed (%d): %s" % [procedure, status, error])
				finish(on_complete, TclDefinitionResult.Value.FAILED)
	)


## Calls [param on_complete] with [param result], when there is one to call.
static func finish(on_complete: Callable, result: TclDefinitionResult.Value) -> void:
	if on_complete.is_valid():
		on_complete.call(result)
