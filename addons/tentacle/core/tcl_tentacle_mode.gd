class_name TclTentacleMode

## Where the game finds Tentacle.
##
## Set it with the [code]tentacle/connection/editor_mode[/code] and
## [code]tentacle/connection/build_mode[/code] Project Settings, or
## [member TentacleRuntime.editor_mode] and [member TentacleRuntime.build_mode] before
## the autoload is ready.

# Named after Unreal's ETclTentacleMode minus its prefix; Unity's is TentacleMode, its
# Tcl dropped for the namespace.

enum Value {
	## Paired with the Tentacle app running on the same machine, which holds the accounts
	## and everything configured in it.
	PAIRED = 0,
	## Run Tentacle inside the game itself, with no app needed: the game signs the player
	## in to the streaming platforms (see [Tentacle_Connections]) and receives their
	## events directly. Needs the Tentacle GDExtension in
	## [code]res://addons/tentacle_embedded/[/code].
	EMBEDDED = 1,
	## @deprecated: Use [constant PAIRED].
	APP = 0,
}

const _ARGUMENT: String = "tentacle-mode="


## A human-readable name, for logs.
static func to_text(value: Value) -> String:
	match value:
		Value.PAIRED:
			return "Paired"
		Value.EMBEDDED:
			return "Embedded"
	return "Unknown"


## Whether Tentacle runs inside the game: [param editor_mode] when the game runs from the
## editor, [param build_mode] once exported. A [code]--tentacle-mode=paired[/code] or
## [code]--tentacle-mode=embedded[/code] argument in [param arguments] (one dash or two)
## wins over both, so an exported game can be tested against the app; any other value is
## ignored with a warning.
static func resolves_to_embedded(
	editor_mode: Value, build_mode: Value, in_editor: bool, arguments: PackedStringArray
) -> bool:
	# Unreal's TclTentacleMode::ResolvesToEmbedded and Unity's TentacleModeResolver. The
	# runtime passes the engine's own facts in, which keeps this file free of OS.
	for argument in arguments:
		var bare := argument.trim_prefix("-").trim_prefix("-")
		if not bare.begins_with(_ARGUMENT):
			continue
		var value := bare.substr(_ARGUMENT.length()).to_lower()
		# "app" is what Paired mode was called before 1.2.0-alpha.3.
		if value == "paired" or value == "app":
			return false
		if value == "embedded":
			return true
		TentacleLog.warn("ignoring %s; it takes paired or embedded" % argument)
		break
	return (editor_mode if in_editor else build_mode) == Value.EMBEDDED
