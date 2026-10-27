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

## The text of each config file the game ships, as the Tentacle app exports them,
## applied when the core starts.
var config_files: PackedStringArray = PackedStringArray()


## These options as the core's configuration: a JSON object, leaving out what is empty.
func to_config_json() -> String:
	var config: Dictionary = {}
	if not data_directory.is_empty():
		config["dataDirectory"] = data_directory
	if not twitch_client_id.is_empty():
		config["twitchClientId"] = twitch_client_id
	# Always present, so the shape the core reads never depends on the project.
	config["configFiles"] = Array(config_files)
	return JSON.stringify(config)
