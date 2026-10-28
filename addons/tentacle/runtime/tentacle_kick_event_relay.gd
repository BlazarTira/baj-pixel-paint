@icon("res://addons/tentacle/icons/tentacle.png")
class_name TentacleKickEventRelay
extends TclKickPlatformEventRelay

## Re-emits every signal of the [code]Tentacle[/code] autoload's [code]kick[/code]
## surface, so a scene can connect them from the editor's Node dock.
##
## Put a TentacleKickEventRelay in the scene, select it, and its Node dock lists every
## Kick signal - [signal TclKickPlatformEventRelay.OnChannelFollow],
## [signal TclKickPlatformEventRelay.OnChatMessage], and the rest - under the same names
## and with the same typed parameters as on [Tentacle_Kick], so a handler written for one
## works for the other. [TentacleEventRelay] relays the autoload's own signals, the chat
## split and the catch-all among them, and [TentacleTwitchEventRelay] Twitch's.
##
## The relay listens while it is in the tree and lets go when it leaves, so there is
## nothing to disconnect by hand. Several may coexist.

# Every signal is declared by the generated base, so the set stays in step with
# Tentacle_Kick's generated base; test_event_relay.gd holds it to Tentacle_Kick's, name
# for name and type for type.

var _forwarder: TentacleSignalForwarder = null


func _init() -> void:
	_forwarder = TentacleSignalForwarder.new(self)


func _enter_tree() -> void:
	var runtime := TentacleRuntime.instance()
	if runtime == null:
		TentacleLog.warn(
			"a Tentacle Kick event relay is in the scene but the addon's autoload is not "
			+ "installed, so it will never fire"
		)
		return
	_forwarder.forward_every_signal_of(runtime.kick)


func _exit_tree() -> void:
	_forwarder.release()
