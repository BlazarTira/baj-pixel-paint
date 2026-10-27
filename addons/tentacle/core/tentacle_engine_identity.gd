class_name TentacleEngineIdentity
extends RefCounted

## Who this game says it is, in the session handshake.
##
## [TentacleRuntime] builds it from the engine's version, the project's name and
## whether this process is an editor run. To change the name shown in Tentacle, set
## [member TentacleRuntime.session_label].

# Built by the engine layer, because every field but the plugin version comes from
# somewhere the core may not reach. The core only clamps and sends it.
#
# The counterpart of Unreal's FTclEngineIdentity and Unity's TentacleEngineIdentity.

## The longest value the server accepts for any handshake field.
const FIELD_MAX_LENGTH: int = 128

## Which engine this is. Always "godot" here.
var engine: String = "godot"

## The engine's version, e.g. "4.4.1.stable".
var engine_version: String = ""

## The addon's version, held in lockstep with the Tentacle app's.
var plugin_version: String = ""

## Distinguishes two processes running the same project.
##
## **Must differ between them.** Custom controls are scoped to the session that
## registered them, and without a distinct instance id Tentacle cannot tell an
## editor run's controls from an exported build's.
var instance_id: String = ""

## The name shown beside the session in Tentacle's Engines list.
var label: String = ""

## Tentacle's connection password, for a Tentacle whose user set one under
## Settings > System > Connection Password. Empty sends none, which is all Tentacle
## asks for until a password is set.
var password: String = ""


## The handshake payload, with every field but the password trimmed and clamped.
##
## The server rejects an over-long field outright, and it would do so on every
## reconnect, so clamping here turns a permanently failing handshake into a slightly
## shortened label. The password goes out exactly as entered, and only when set.
func to_hello() -> Dictionary:
	var hello := {
		"engine": _clamp(engine),
		"engineVersion": _clamp(engine_version),
		"pluginVersion": _clamp(plugin_version),
		"instanceId": _clamp(instance_id),
		"label": _clamp(label),
	}
	if not password.is_empty():
		hello["password"] = password
	return hello


static func _clamp(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed.length() <= FIELD_MAX_LENGTH:
		return trimmed
	return trimmed.substr(0, FIELD_MAX_LENGTH)
