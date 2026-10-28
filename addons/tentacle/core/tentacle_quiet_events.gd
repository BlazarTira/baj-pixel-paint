## Warns in the log about every signal a game listens to that the Twitch account's
## permissions keep quiet, once each until the account allows something else, as
## Twitch's connection is reported. A relay's connection counts only while the relay
## has a listener of its own.
class_name TentacleQuietEvents
extends RefCounted

# The signals already warned about while Twitch allows _allowed_key.
var _warned: Dictionary[String, bool] = {}
var _allowed_key := ""


## Warns about each signal of [param source] named in [param table] (a generated
## permissions table, such as [constant TclTwitchPlatformEvents.EVENT_PERMISSIONS]) that
## has a listener, and needs a permission [param connection]'s account has allowed none
## of. [param prefix] says where the signals are reached ([code]Tentacle.twitch.[/code]),
## and a cross-platform signal is quiet for Twitch alone, since Kick's side needs none.
func check(connection: TclPlatformConnection, source: Object, table: Dictionary, prefix: String, cross_platform: bool) -> void:
	if connection == null or connection.platform != TclStreamPlatform.Value.TWITCH:
		return
	if connection.account == null or connection.needs_reconnect or connection.permissions == null:
		return
	var allowed := PackedStringArray()
	for permission in connection.permissions.allowed:
		allowed.append(TclPlatformPermission.to_wire(permission))
	allowed.sort()
	var key := " ".join(allowed)
	if key != _allowed_key:
		_allowed_key = key
		_warned.clear()
	for signal_name: String in table:
		var needs: Dictionary = table[signal_name]
		var ids: Array = needs["permissions"]
		if ids.any(func(id: Variant) -> bool: return allowed.has(str(id))):
			continue
		if not is_listened(source, signal_name):
			continue
		var event_name := prefix + signal_name
		if _warned.has(event_name):
			continue
		_warned[event_name] = true
		TentacleLog.warn(message(event_name, cross_platform, PackedStringArray(needs["names"])))


## Whether anything listens to [param source]'s signal [param signal_name]: a connection of
## its own, or a relay's that has a listener for it ([code]relays_to_a_listener[/code]).
static func is_listened(source: Object, signal_name: String) -> bool:
	if not source.has_signal(signal_name):
		return false
	for entry: Dictionary in source.get_signal_connection_list(signal_name):
		var target: Object = (entry["callable"] as Callable).get_object()
		if target != null and target.has_method("relays_to_a_listener"):
			if target.call("relays_to_a_listener", signal_name):
				return true
			continue
		return true
	return false


## What a quiet signal is logged as, its permissions named as the Tentacle app names them.
static func message(event_name: String, cross_platform: bool, names: PackedStringArray) -> String:
	var which := "one of them" if names.size() > 1 else "it"
	return "%s won't fire%s: it needs the %s permission on Twitch, which this account hasn't allowed. Sign in to Twitch again with %s turned on." % [
		event_name,
		" for Twitch" if cross_platform else "",
		quoted_names(names),
		which,
	]


## [param names] as one phrase, each in quotes so it reads as a name within the sentence:
## "Polls" alone, "Polls" or "Clips", or "Polls", "Clips", or "Videos".
static func quoted_names(names: PackedStringArray) -> String:
	var quoted := PackedStringArray()
	for entry in names:
		quoted.append("\"%s\"" % entry)
	if quoted.size() <= 2:
		return " or ".join(quoted)
	return "%s, or %s" % [", ".join(quoted.slice(0, quoted.size() - 1)), quoted[quoted.size() - 1]]
