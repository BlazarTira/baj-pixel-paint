@icon("res://addons/tentacle/icons/event.svg")
class_name TentacleTwitchEventRelay
extends TclTwitchPlatformEventRelay

## Re-emits every signal of the [code]Tentacle[/code] autoload's [code]twitch[/code]
## surface and its [code]extras[/code], so a scene can connect them from the editor's Node
## dock.
##
## Put a TentacleTwitchEventRelay in the scene, select it, and its Node dock lists every
## Twitch signal - [signal TclTwitchPlatformEventRelay.OnChannelCheer],
## [signal TclTwitchPlatformEventRelay.OnChannelChatMessage],
## [signal TclTwitchPlatformEventRelay.OnChannelRaid], [signal OnIncomingRaidEnded], and
## the rest - under the same names and with the same typed parameters as on
## [Tentacle_Twitch] and [Tentacle_TwitchExtras], so a handler written for one works for
## the other. [TentacleEventRelay] relays the autoload's own signals, the chat split and
## the catch-all among them, and [TentacleKickEventRelay] Kick's.
##
## The relay listens while it is in the tree and lets go when it leaves, so there is
## nothing to disconnect by hand. Several may coexist.

# The per-kind signals are declared by the generated base, so they stay in step with
# Tentacle_Twitch's generated base; the one signal of Tentacle_TwitchExtras is declared
# here. test_event_relay.gd holds the whole set to those two surfaces', name for name and
# type for type.

## An incoming raid was closed. Relays [signal Tentacle_TwitchExtras.OnIncomingRaidEnded].
signal OnIncomingRaidEnded()

var _forwarder: TentacleSignalForwarder = null


func _init() -> void:
	_forwarder = TentacleSignalForwarder.new(self)


func _enter_tree() -> void:
	var runtime := TentacleRuntime.instance()
	if runtime == null:
		TentacleLog.warn(
			"a Tentacle Twitch event relay is in the scene but the addon's autoload is not "
			+ "installed, so it will never fire"
		)
		return
	_forwarder.forward_every_signal_of(runtime.twitch)
	_forwarder.forward_every_signal_of(runtime.twitch.extras)


func _exit_tree() -> void:
	_forwarder.release()
