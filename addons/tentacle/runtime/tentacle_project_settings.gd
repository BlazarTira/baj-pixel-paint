@tool
class_name TentacleProjectSettings
extends RefCounted

## The Tentacle autoload's settings, kept in Project Settings.
##
## Enabling the addon adds them under [b]Project > Project Settings > General >
## Tentacle[/b], and the [code]Tentacle[/code] autoload reads them when it is ready,
## before it first connects. Each setting is named after the [TentacleRuntime] property
## it sets and starts at that property's default, apart from the ones an export reads
## (see [method export_definitions]).
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

## In Embedded mode, your own Kick app's client ID, set with
## [constant KICK_SIGN_IN_SERVER_URL]. Empty uses Tentacle's.
const KICK_CLIENT_ID: String = "tentacle/embedded/kick_client_id"

## In Embedded mode, the address of the Kick sign-in server holding your Kick app's client
## secret. Empty uses Tentacle's.
const KICK_SIGN_IN_SERVER_URL: String = "tentacle/embedded/kick_sign_in_server_url"

## In Embedded mode, the folder the game's config files are read from.
const CONFIG_DIRECTORY: String = "tentacle/embedded/config_directory"

## Whether an export whose Build Mode is Paired still carries Tentacle's core, so it can
## be run with [code]--tentacle-mode=embedded[/code]. Off, such an export leaves the core
## out (see [TentacleExportPlugin]).
const INCLUDE_CORE_IN_PAIRED_BUILDS: String = "tentacle/embedded/include_core_in_paired_builds"

## In Embedded mode, ask only for the permissions in the four lists below.
const CUSTOM_PERMISSIONS: String = "tentacle/embedded/custom_permissions"

## What every Twitch sign-in asks for besides chat, with custom permissions on.
const TWITCH_REQUIRED_PERMISSIONS: String = "tentacle/embedded/twitch_required_permissions"

## What a Twitch sign-in may also ask for, with custom permissions on.
const TWITCH_OPTIONAL_PERMISSIONS: String = "tentacle/embedded/twitch_optional_permissions"

## What every Kick sign-in asks for besides chat, with custom permissions on.
const KICK_REQUIRED_PERMISSIONS: String = "tentacle/embedded/kick_required_permissions"

## What a Kick sign-in may also ask for, with custom permissions on.
const KICK_OPTIONAL_PERMISSIONS: String = "tentacle/embedded/kick_optional_permissions"

# Loaded by path rather than named, for the same reason the runtime is typed as Node below.
const _PERMISSION_SCRIPT: String = "res://addons/tentacle/generated/tcl_platform_permission.gd"

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
		Setting.make(EDITOR_MODE, "editor_mode", TYPE_INT, 0, PROPERTY_HINT_ENUM, "Paired,Embedded"),
		Setting.make(BUILD_MODE, "build_mode", TYPE_INT, 0, PROPERTY_HINT_ENUM, "Paired,Embedded"),
		Setting.make(
			EMBEDDED_DATA_DIRECTORY, "embedded_data_directory", TYPE_STRING, "",
			PROPERTY_HINT_GLOBAL_DIR,
		),
		Setting.make(TWITCH_CLIENT_ID, "twitch_client_id", TYPE_STRING, ""),
		Setting.make(KICK_CLIENT_ID, "kick_client_id", TYPE_STRING, ""),
		Setting.make(KICK_SIGN_IN_SERVER_URL, "kick_sign_in_server_url", TYPE_STRING, ""),
		Setting.make(
			CONFIG_DIRECTORY, "config_directory", TYPE_STRING, "res://tentacle",
			PROPERTY_HINT_DIR,
		),
		Setting.make(CUSTOM_PERMISSIONS, "custom_permissions", TYPE_BOOL, false),
		_permissions(TWITCH_REQUIRED_PERMISSIONS, "twitch_required_permissions"),
		_permissions(TWITCH_OPTIONAL_PERMISSIONS, "twitch_optional_permissions"),
		_permissions(KICK_REQUIRED_PERMISSIONS, "kick_required_permissions"),
		_permissions(KICK_OPTIONAL_PERMISSIONS, "kick_optional_permissions"),
	]


## The settings an export reads rather than the runtime, so they set no runtime property.
static func export_definitions() -> Array[Setting]:
	return [
		Setting.make(INCLUDE_CORE_IN_PAIRED_BUILDS, "", TYPE_BOOL, false),
	]


## A list of permissions, shown in the editor as a list of the permissions' names.
static func _permissions(setting_name: String, setting_property: String) -> Setting:
	var permission_script: GDScript = load(_PERMISSION_SCRIPT)
	var names: PackedStringArray = []
	# The enum's members in order, which is their values' order.
	for member: String in permission_script.get_script_constant_map()["Value"].keys():
		names.append(member.capitalize())
	return Setting.make(
		setting_name, setting_property, TYPE_ARRAY, [],
		PROPERTY_HINT_TYPE_STRING, "%d/%d:%s" % [TYPE_INT, PROPERTY_HINT_ENUM, ",".join(names)],
	)


## Adds every setting to Project Settings, with its default and editor hint, keeping any
## value already set. The addon's editor plugin calls this whenever the addon loads.
static func register() -> void:
	for setting in definitions() + export_definitions():
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
		var value: Variant = ProjectSettings.get_setting(setting.name, setting.default)
		if setting.type == TYPE_ARRAY:
			# Project Settings keep an untyped array, which a typed one is filled from.
			var typed: Array = runtime.get(setting.property)
			typed.assign(value)
		else:
			runtime.set(setting.property, value)


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
