class_name Tentacle_Obs
extends RefCounted

## OBS requests, relayed through Tentacle.
##
## **Fire-and-forget**: the protocol carries no response, so there is nothing to
## await and nothing to check. The game holds no OBS credentials either - Tentacle
## already has the connection, and the game asks it to act. Where OBS is can be set
## from the game too, with [method set_connection_settings].

# Unreal's UTentacle_Obs and Unity's Tentacle_Obs.

var _session: TentacleSession = null
var _rpc: TentacleRpc = null


func _init(session: TentacleSession = null, rpc: TentacleRpc = null) -> void:
	_session = session
	_rpc = rpc


## Points this surface at a different RPC transport. The [code]Tentacle[/code] autoload
## calls this itself, rebinding the surface in place.
func bind_rpc(rpc: TentacleRpc) -> void:
	_rpc = rpc


# Unreal's SetConnectionSettings and Unity's SetConnectionSettingsAsync.
## Tells Tentacle where OBS is - the machine it runs on (empty means this one), its
## websocket port, and its websocket password (empty when it has none) - as the OBS
## fields in Tentacle's settings do, and Tentacle connects to it there.
##
## [param on_complete] is called once with a [enum TclDefinitionResult.Value]: SUCCESS,
## or FAILED when Tentacle is not running or refused the settings, such as a port
## outside 1 to 65535 (the reason is logged).
func set_connection_settings(
	host: String,
	port: int = 4455,
	password: String = "",
	on_complete: Callable = Callable(),
) -> void:
	TentacleDefinitionChange.change(
		_rpc,
		"obs.setConnectionSettings",
		{"host": host, "port": port, "password": password},
		on_complete,
	)


# Unreal's CallRequest (DisplayName "Call") and Unity's Call. Named call_request because
# Object.call is a non-virtual member of every Godot object, so a method named call would
# shadow it; the _request suffix keeps the word, the same dodge connect_session makes.
## Sends one OBS WebSocket request by name.
##
## [param request_type] is OBS's own request name, e.g.
## [code]SetCurrentProgramScene[/code]; [param request_data] is its payload.
func call_request(request_type: String, request_data: Dictionary = {}) -> void:
	if request_type.is_empty():
		TentacleLog.error("an OBS request needs a request type")
		return
	if _session == null:
		return

	var payload: Dictionary = {"requestType": request_type}
	# An absent requestData is what the app reads as "no payload"; an empty object
	# would be a payload with no fields.
	if not request_data.is_empty():
		payload["requestData"] = request_data
	_session.send("Obs_Call", payload)


## Turns one filter on a source on or off.
func set_source_filter_enabled(
	source_name: String,
	filter_name: String,
	enabled: bool,
) -> void:
	call_request(
		"SetSourceFilterEnabled",
		{"sourceName": source_name, "filterName": filter_name, "filterEnabled": enabled},
	)


## Switches OBS to a scene.
func set_current_program_scene(scene_name: String) -> void:
	call_request("SetCurrentProgramScene", {"sceneName": scene_name})
