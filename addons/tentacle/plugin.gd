@tool
extends EditorPlugin

## Installs and removes the Tentacle autoload, and registers its Project Settings.
##
## Enabling the addon under Project > Project Settings > Plugins adds a node named
## [code]Tentacle[/code] to the project's autoloads, and disabling it removes it. The
## autoload's settings - Auto Connect, Session Label and the rest - appear under
## [b]Project > Project Settings > General > Tentacle[/b] (see
## [TentacleProjectSettings]).
##
## The autoload is the one node the addon installs. Everything else is reached through
## it, and the scene-authored nodes find it through
## [method TentacleRuntime.instance] rather than by path, so renaming the autoload does
## not break them.

# This is what makes setup "enable the addon" rather than a documented ritual: the
# GDExtension version of this addon needed the user to create a scene, add a node to it,
# save it, and register it as an autoload by hand - four steps where three of them could
# go wrong silently.
#
# The settings are registered on every load rather than once, because Project Settings
# keeps only a setting's value: its default and its editor hint have to be declared again
# each session. They are left in place when the addon is disabled, so a user who turns it
# back on keeps what they chose; a setting still at its default is not saved to
# project.godot at all.

## The autoload's name, and therefore what a game types: `Tentacle.OnChatMessage`,
## `Tentacle.twitch`, and so on.
const AUTOLOAD_NAME: String = "Tentacle"

const RUNTIME_SCRIPT: String = "res://addons/tentacle/runtime/tentacle_runtime.gd"

# Preloaded by path rather than named by class, like the runtime above: on a project's
# first open the editor can load this plugin before it has built the global class list,
# and a class name would not resolve yet.
const PROJECT_SETTINGS: GDScript = preload("res://addons/tentacle/runtime/tentacle_project_settings.gd")


func _enter_tree() -> void:
	PROJECT_SETTINGS.register()
	# add_autoload_singleton takes a script path directly, so no wrapper scene is
	# needed - the script's class is instantiated as the autoload's root node.
	add_autoload_singleton(AUTOLOAD_NAME, RUNTIME_SCRIPT)


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _get_plugin_name() -> String:
	return "Tentacle"
