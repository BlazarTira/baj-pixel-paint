@tool
class_name TentacleProjectSettings
extends RefCounted

## The Tentacle autoload's settings, kept in Project Settings.
##
## Enabling the addon adds them under [b]Project > Project Settings > General >
## Tentacle[/b], and the [code]Tentacle[/code] autoload reads them when it is ready,
## before it first connects. Each setting is named after the [TentacleRuntime] property
## it sets and starts at that property's default.
##
## A value a script assigns to the autoload before it is ready wins over the setting,
## and a [TentacleRuntime] a scene instances itself ignores these and keeps what its own
## Inspector says.
##
## All members are static.

# Project Settings rather than the autoload's @exports because an autoload installed from
# a script has no scene: the Inspector shows its exported fields but has nowhere to save
# them, so a value set there was gone on the next run. Engine layer, since the core may
# not reach ProjectSettings. @tool because the editor plugin calls register() in the
# editor.

## Connect as soon as the game starts.
const AUTO_CONNECT: String = "tentacle/connection/auto_connect"

## The name shown beside the session in Tentacle. Empty means the project name.
const SESSION_LABEL: String = "tentacle/connection/session_label"

## Where to look for Tentacle's discovery file, for an isolated Tentacle instance.
const DATA_DIRECTORY_OVERRIDE: String = "tentacle/connection/data_directory_override"

## Tentacle's connection password, for a Tentacle whose user set one. Empty sends none.
const CONNECTION_PASSWORD: String = "tentacle/connection/connection_password"

## Seconds before the first retry.
const RECONNECT_INITIAL_DELAY: String = "tentacle/connection/reconnect_initial_delay"

## The ceiling retries back off to, in seconds.
const RECONNECT_MAX_DELAY: String = "tentacle/connection/reconnect_max_delay"

## Where Tentacle runs when the game runs from the editor: the app on this machine, or
## Tentacle's core inside the game.
const EDITOR_MODE: String = "tentacle/connection/editor_mode"

## Where Tentacle runs in an exported game: the app on the player's machine, or
## Tentacle's core inside the game, so players need no app.
const BUILD_MODE: String = "tentacle/connection/build_mode"

## In Embedded mode, the folder Tentacle keeps its data in. Empty means
## [code]user://Tentacle[/code].
const EMBEDDED_DATA_DIRECTORY: String = "tentacle/embedded/embedded_data_directory"

## In Embedded mode, your own Twitch app's client ID. Empty uses Tentacle's.
const TWITCH_CLIENT_ID: String = "tentacle/embedded/twitch_client_id"

## In Embedded mode, the folder the game's config files are read from.
const CONFIG_DIRECTORY: String = "tentacle/embedded/config_directory"

## How many recent event ids are remembered, so an event that arrives twice is delivered once.
const STREAM_DEDUPLICATION_WINDOW: String = "tentacle/stream/stream_deduplication_window"

## Load the viewer-property registry as each session opens.
const REFRESH_REGISTRY_ON_CONNECT: String = "tentacle/viewer_properties/refresh_registry_on_connect"


## Every setting, with its type, default, and editor hint.
static func definitions() -> Array[Setting]:
	# The defaults match TentacleRuntime's exported defaults; test_project_settings.gd
	# holds the two together.
	return [
		Setting.make(AUTO_CONNECT, "auto_connect", TYPE_BOOL, true),
		Setting.make(SESSION_LABEL, "session_label", TYPE_STRING, ""),
		Setting.make(
			DATA_DIRECTORY_OVERRIDE, "data_directory_override", TYPE_STRING, "",
			PROPERTY_HINT_GLOBAL_DIR,
		),
		Setting.make(
			CONNECTION_PASSWORD, "connection_password", TYPE_STRING, "", PROPERTY_HINT_PASSWORD,
		),
		Setting.make(
			RECONNECT_INITIAL_DELAY, "reconnect_initial_delay", TYPE_FLOAT, 1.0,
			PROPERTY_HINT_RANGE, "0.25,60,0.05,or_greater,suffix:s",
		),
		Setting.make(
			RECONNECT_MAX_DELAY, "reconnect_max_delay", TYPE_FLOAT, 30.0,
			PROPERTY_HINT_RANGE, "0.25,300,0.05,or_greater,suffix:s",
		),
		Setting.make(
			STREAM_DEDUPLICATION_WINDOW, "stream_deduplication_window", TYPE_INT, 100,
			PROPERTY_HINT_RANGE, "0,10000,1,or_greater",
		),
		Setting.make(REFRESH_REGISTRY_ON_CONNECT, "refresh_registry_on_connect", TYPE_BOOL, true),
		# The modes' hint lists TclTentacleMode.Value's members in order.
		Setting.make(EDITOR_MODE, "editor_mode", TYPE_INT, 0, PROPERTY_HINT_ENUM, "App,Embedded"),
		Setting.make(BUILD_MODE, "build_mode", TYPE_INT, 0, PROPERTY_HINT_ENUM, "App,Embedded"),
		Setting.make(
			EMBEDDED_DATA_DIRECTORY, "embedded_data_directory", TYPE_STRING, "",
			PROPERTY_HINT_GLOBAL_DIR,
		),
		Setting.make(TWITCH_CLIENT_ID, "twitch_client_id", TYPE_STRING, ""),
		Setting.make(
			CONFIG_DIRECTORY, "config_directory", TYPE_STRING, "res://tentacle",
			PROPERTY_HINT_DIR,
		),
	]


## Adds every setting to Project Settings, with its default and editor hint, keeping any
## value already set. The addon's editor plugin calls this whenever the addon loads.
static func register() -> void:
	for setting in definitions():
		if not ProjectSettings.has_setting(setting.name):
			ProjectSettings.set_setting(setting.name, setting.default)
		# The initial value is what Project Settings reverts to and what it leaves out of
		# project.godot, so a setting at its default costs the project nothing.
		ProjectSettings.set_initial_value(setting.name, setting.default)
		ProjectSettings.add_property_info({
			"name": setting.name,
			"type": setting.type,
			"hint": setting.hint,
			"hint_string": setting.hint_string,
		})
		ProjectSettings.set_as_basic(setting.name, true)


# The runtime is typed as the Node it is rather than as TentacleRuntime: the editor plugin
# preloads this script, possibly before the global class list exists, so it names no
# other addon class.
## Copies every setting onto [param runtime], a [TentacleRuntime], skipping the
## properties named in [param keep], which hold values assigned before it was ready.
static func apply_to(runtime: Node, keep: Dictionary[StringName, bool]) -> void:
	for setting in definitions():
		if keep.has(StringName(setting.property)):
			continue
		# Read with the default, because an exported game carries only the settings that
		# differ from it.
		runtime.set(setting.property, ProjectSettings.get_setting(setting.name, setting.default))


## One setting: where it lives in Project Settings, the runtime property it sets, and how
## the editor shows it.
class Setting:
	## The Project Settings path, e.g. [code]tentacle/connection/auto_connect[/code].
	var name: String = ""
	## The [TentacleRuntime] property it sets.
	var property: String = ""
	## Its [enum Variant.Type].
	var type: int = TYPE_NIL
	## Its default, the runtime's own.
	var default: Variant = null
	## Its editor hint, a [enum PropertyHint].
	var hint: int = PROPERTY_HINT_NONE
	## Its editor hint string.
	var hint_string: String = ""

	## A setting with every field filled in.
	static func make(
		setting_name: String,
		setting_property: String,
		setting_type: int,
		setting_default: Variant,
		setting_hint: int = PROPERTY_HINT_NONE,
		setting_hint_string: String = "",
	) -> Setting:
		var out := Setting.new()
		out.name = setting_name
		out.property = setting_property
		out.type = setting_type
		out.default = setting_default
		out.hint = setting_hint
		out.hint_string = setting_hint_string
		return out
