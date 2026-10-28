class_name TentacleEmbeddedOptions
extends RefCounted

## How the Tentacle core running inside the game is configured, in Embedded mode.
##
## The [code]Tentacle[/code] autoload builds these from its settings
## ([member TentacleRuntime.embedded_data_directory] and the rest) when it first
## connects. The core reads them once, when it starts.

# Unreal's FTclEmbeddedOptions and Unity's TentacleEmbeddedOptions. Engine-neutral: the
# runtime reads the config files and resolves the folder, and hands this the results.

## The folder the core keeps its database and the player's accounts in, as an absolute
## path. Empty keeps nothing between runs.
var data_directory: String = ""

## A Twitch app's client ID to sign in with instead of Tentacle's own. Empty uses
## Tentacle's.
var twitch_client_id: String = ""

## A Kick app's client ID to sign in with instead of Tentacle's own. It needs
## [member kick_sign_in_server_url] too. Empty uses Tentacle's.
var kick_client_id: String = ""

## The address of the Kick sign-in server holding [member kick_client_id]'s client
## secret, which finishes and renews Kick sign-ins. Empty uses Tentacle's.
var kick_sign_in_server_url: String = ""

## The text of each config file the game ships, as the Tentacle app exports them,
## applied when the core starts.
var config_files: PackedStringArray = PackedStringArray()

## Whether the four permission lists below decide what a sign-in may ask for. Off, a
## sign-in may ask for everything Tentacle can use, with the player choosing what to turn
## off.
var custom_permissions: bool = false

## What every Twitch sign-in asks for besides chat, which is always asked for, when
## [member custom_permissions] is on.
var twitch_required_permissions: Array[TclPlatformPermission.Value] = []

## What a Twitch sign-in may also ask for, unless the player turns it off, when
## [member custom_permissions] is on.
var twitch_optional_permissions: Array[TclPlatformPermission.Value] = []

## What every Kick sign-in asks for besides chat, which is always asked for, when
## [member custom_permissions] is on.
var kick_required_permissions: Array[TclPlatformPermission.Value] = []

## What a Kick sign-in may also ask for, unless the player turns it off, when
## [member custom_permissions] is on.
var kick_optional_permissions: Array[TclPlatformPermission.Value] = []


## These options as the core's configuration: a JSON object, leaving out what is empty.
func to_config_json() -> String:
	var config: Dictionary = {}
	if not data_directory.is_empty():
		config["dataDirectory"] = data_directory
	if not twitch_client_id.is_empty():
		config["twitchClientId"] = twitch_client_id
	if not kick_client_id.is_empty():
		config["kickClientId"] = kick_client_id
	if not kick_sign_in_server_url.is_empty():
		config["kickSignInServerUrl"] = kick_sign_in_server_url
	# Always present, so the shape the core reads never depends on the project.
	config["configFiles"] = Array(config_files)
	if custom_permissions:
		config["permissions"] = {
			"twitch": {"required": _ids(twitch_required_permissions), "optional": _ids(twitch_optional_permissions)},
			"kick": {"required": _ids(kick_required_permissions), "optional": _ids(kick_optional_permissions)},
		}
	return JSON.stringify(config)


## [param permissions] as their ids.
static func _ids(permissions: Array[TclPlatformPermission.Value]) -> Array[String]:
	var ids: Array[String] = []
	for permission in permissions:
		ids.append(TclPlatformPermission.to_wire(permission))
	return ids
