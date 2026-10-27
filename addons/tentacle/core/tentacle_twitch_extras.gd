class_name Tentacle_TwitchExtras
extends RefCounted

## What Tentacle adds to Twitch: things Twitch itself does not have, kept apart so that
## everything directly on [Tentacle_Twitch] is a Twitch event or call you can look up in
## Twitch's own documentation. Reached as [code]Tentacle.twitch.extras[/code].
##
## Today that is the incoming raid window. Twitch reports a raid on your channel
## ([signal TclTwitchPlatformEvents.OnChannelRaid]) but never reports it over, so
## Tentacle keeps a window open from the raid until your game closes it:
##
## [codeblock]
## func _ready() -> void:
##     Tentacle.twitch.extras.OnIncomingRaidEnded.connect(_on_raid_ended)
##
## func _on_round_over() -> void:
##     if Tentacle.twitch.extras.is_incoming_raid_ongoing:
##         Tentacle.twitch.extras.end_incoming_raid()
##
## func _on_raid_ended() -> void:
##     print("Thanks for the raid!")
## [/codeblock]

# Unreal's UTentacle_TwitchExtras, member for member. Tentacle_Twitch owns one and opens
# the window as a raid arrives, before its OnChannelRaid, as UTentacle_Twitch calls
# BeginIncomingRaid; that call is C++ only on Unreal, so it is underscored here.

## Fires when [method end_incoming_raid] closes the incoming raid window. Twitch sends no
## event when a raid is over, so your game decides when it is.
signal OnIncomingRaidEnded()

# Unreal's bIsIncomingRaidOngoing is a read-only UPROPERTY rather than a function, so this
# is a property too.
## True from a raid on your channel ([signal TclTwitchPlatformEvents.OnChannelRaid])
## until [method end_incoming_raid].
var is_incoming_raid_ongoing: bool:
	get:
		return _incoming_raid_ongoing

var _incoming_raid_ongoing: bool = false


## Closes the incoming raid window: [member is_incoming_raid_ongoing] goes false and
## [signal OnIncomingRaidEnded] fires. Twitch sends no event when a raid is over, so your
## game decides when it is.
##
## It closes and announces whether or not a raid was open, so a game can call it
## whenever its raid sequence is done.
func end_incoming_raid() -> void:
	_incoming_raid_ongoing = false
	OnIncomingRaidEnded.emit()


## Opens the incoming raid window. [Tentacle_Twitch] calls this as a raid arrives, before
## raising [signal TclTwitchPlatformEvents.OnChannelRaid], so a handler of that signal
## already sees the window open; a game has no reason to.
func _begin_incoming_raid() -> void:
	_incoming_raid_ongoing = true
