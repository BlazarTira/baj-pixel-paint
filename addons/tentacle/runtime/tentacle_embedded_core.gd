class_name TentacleEmbeddedCore
extends RefCounted

## The Tentacle core running inside the game, in Embedded mode: one per process, shared
## by every connection to it.
##
## The core comes with the Tentacle GDExtension, installed in
## [code]res://addons/tentacle_embedded/[/code] beside this addon. The first embedded
## connection starts it with that connection's [TentacleEmbeddedOptions], and it stops
## when the game ends. Without the GDExtension, Embedded mode says so in the output and
## keeps retrying, and App mode is unaffected.
##
## All members are static.

# Unreal's FTclEmbeddedCore and Unity's TentacleEmbeddedCore. The GDExtension's classes
# are reached through ClassDB alone, never named, so this script and everything that uses
# it still parse in a project without the library (crates/tentacle-godot registers them).
#
# Godot runs a game from the editor in a process of its own, so stopping the core with
# the process (the extension stops it as it unloads) is the whole lifetime; Unity has to
# stop it on play-mode exit and Unreal at the end of play-in-editor, because their
# editors run the game in the editor's own process.

## The GDExtension class that starts and stops the core.
const NATIVE_CORE_CLASS: StringName = &"TentacleNativeCore"

static var _native: Object = null

## The last problem reported, so a connection that keeps retrying says each one once.
static var _reported: String = ""

## Whether a connection asking for other settings than the running core's has been
## warned about.
static var _warned_about_options: bool = false


## Whether the Tentacle GDExtension is installed, so Embedded mode can run.
static func is_available() -> bool:
	return ClassDB.class_exists(NATIVE_CORE_CLASS)


## Whether the core is running.
static func is_running() -> bool:
	var native := _native_core()
	return native != null and bool(native.call("is_running"))


## The core's version, or empty without the GDExtension.
static func version() -> String:
	var native := _native_core()
	return str(native.call("version")) if native != null else ""


## Opens a connection to the core, starting it with [param options] when it is not
## running yet. Returns the connection, or null when the core is not available or could
## not start, which is reported in the output once.
static func open_connection(options: TentacleEmbeddedOptions) -> Object:
	var native := _native_core()
	if native == null:
		_report(
			"Embedded mode needs the Tentacle GDExtension in res://addons/tentacle_embedded/, "
			+ "which this project does not have"
		)
		return null

	var config := options.to_config_json()
	if not bool(native.call("is_running")):
		var problem := str(native.call("start", config))
		if not problem.is_empty():
			_report("the embedded Tentacle core could not start: %s" % problem)
			return null
		_warned_about_options = false
		var where := options.data_directory if not options.data_directory.is_empty() else "memory"
		TentacleLog.info("started the embedded Tentacle core %s (data in %s)" % [version(), where])
	elif str(native.call("running_config")) != config and not _warned_about_options:
		_warned_about_options = true
		TentacleLog.warn(
			"the embedded Tentacle core is already running with other settings, and keeps "
			+ "them until the game ends"
		)

	var connection: Object = native.call("open_connection")
	if connection != null:
		_reported = ""
	return connection


## Stops the core, closing every connection to it. The next embedded connection starts
## it again. A game does not need to call this: the core stops when the game ends.
static func shutdown() -> void:
	var native := _native_core()
	if native != null:
		native.call("stop")


static func _native_core() -> Object:
	if _native == null and is_available():
		_native = ClassDB.instantiate(NATIVE_CORE_CLASS)
	return _native


static func _report(problem: String) -> void:
	if problem == _reported:
		return
	_reported = problem
	TentacleLog.warn("%s. Retrying in the background" % problem)
