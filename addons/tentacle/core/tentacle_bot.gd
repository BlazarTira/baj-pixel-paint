class_name Tentacle_Bot
extends RefCounted

## Tentacle's chat bot, as the streamer configured it: whether it is on, and every
## command it answers, kept current.
##
## Tentacle sends the whole command list as the session opens, and again whenever the
## streamer creates, changes, or removes a command or switches the bot on or off, so what
## this holds is never more than a moment old. That is what a game needs to talk about
## the commands in chat - listing the ones a viewer can use, say - without keeping a copy
## of the streamer's settings.
##
## The list stays as it was while the session is closed, and is replaced by the one
## Tentacle sends when it opens again.

# Unreal's UTentacle_Bot and Unity's Tentacle_Bot, member for member: bIsEnabled and
# bAreCommandsLoaded are is_enabled and are_commands_loaded here.

## Fires whenever the command list changes, including when the first list arrives.
## [member commands] and the rest already hold the new list when it fires. A list
## Tentacle sends again unchanged, as it does every time the session opens, does not
## fire it.
signal OnCommandsChanged()

## Every command and phrase the streamer configured, enabled or not, ordered by name,
## with who may use it, where, how often, what it replies and what it does.
var commands: Array[TclBotCommand]:
	get:
		return _commands.duplicate()

## Whether the bot answers in chat at all. When false, no command answers. False until
## a list arrives.
var is_enabled: bool:
	get:
		return _is_enabled

## What a chat message starts with to be read as a command, such as [code]![/code].
## Empty until a list arrives.
var command_prefix: String:
	get:
		return _command_prefix

## The bot-wide cooldown that spaces out every command, in seconds.
var global_cooldown_seconds: int:
	get:
		return _global_cooldown_seconds

## Whether Tentacle has sent a command list yet. Until it has, [member commands] is
## empty.
var are_commands_loaded: bool:
	get:
		return _are_commands_loaded

var _commands: Array[TclBotCommand] = []
var _is_enabled: bool = false
var _command_prefix: String = ""
var _global_cooldown_seconds: int = 0
var _are_commands_loaded: bool = false

## The last command list as received, so a list sent again unchanged fires nothing.
var _commands_key: String = ""


## The command or phrase with this name, without the command prefix, or null.
##
## Case-insensitive by default, as every name lookup is; pass [param case_sensitive] to
## require an exact match.
func find_command_by_name(command_name: String, case_sensitive: bool = false) -> TclBotCommand:
	if command_name.is_empty():
		return null
	for command in _commands:
		if case_sensitive and command.name == command_name:
			return command
		if not case_sensitive and command.name.nocasecmp_to(command_name) == 0:
			return command
	return null


## Takes the command list a [code]Bot_Commands[/code] message carries.
func handle_commands(data: Dictionary) -> void:
	# Tentacle sends the current list every time a session opens, so a list identical
	# to the one held is not a change.
	var key := TclJson.to_text(data)
	if _are_commands_loaded and key == _commands_key:
		return

	var received := TclBotCommands.parse(data)
	if received == null:
		return

	_commands.clear()
	for command in received.commands:
		if command != null:
			_commands.append(command)
	_is_enabled = received.bot_enabled
	_command_prefix = received.command_prefix
	_global_cooldown_seconds = received.global_cooldown_seconds
	_are_commands_loaded = true
	_commands_key = key

	OnCommandsChanged.emit()
