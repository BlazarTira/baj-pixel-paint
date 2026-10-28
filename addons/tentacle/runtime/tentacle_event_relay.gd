@icon("res://addons/tentacle/icons/tentacle.png")
class_name TentacleEventRelay
extends Node

## Re-emits every signal of the [code]Tentacle[/code] autoload and its surfaces other
## than [code]twitch[/code] and [code]kick[/code], so a scene can connect them from the
## editor's Node dock.
##
## The autoload lives outside every scene, so the editor cannot show its signals while
## you edit one. Put a TentacleEventRelay in the scene, select it, and its Node dock
## lists them - [signal OnChatMessage], [signal OnDonation], [signal OnCustomEvent],
## [signal OnConnectionStatusChanged], and the rest - to connect to your own nodes like
## any other. Each one carries the same name and the same typed parameters as the signal
## it relays, so a handler written for one works for the other.
##
## Each platform's own signals have a relay of their own, [TentacleTwitchEventRelay] and
## [TentacleKickEventRelay], because Kick's [code]OnChatMessage[/code] and the autoload's
## are different signals under one name.
##
## The relay listens while it is in the tree and lets go when it leaves, so there is
## nothing to disconnect by hand. Several may coexist. Connecting in code works as well,
## though code can reach the same signals on the autoload directly:
## [code]Tentacle.OnChatMessage.connect(...)[/code].

# No Unreal counterpart - an Unreal level holds the ATentacle actor itself - so it keeps
# the Tentacle-prefixed name Unity's TentacleEventRelay component has. Unity's relays the
# cross-platform surface; this one relays every signal the autoload and its other
# surfaces declare, which test_event_relay.gd holds to exactly that set, name for name
# and type for type.
#
# One relay per surface rather than one for everything: a single node would have to
# declare the autoload's OnChatMessage and Kick's OnChatMessage as one signal, and
# suffixing one of them would push a Godot restriction into a name every engine shares.

# --- The session -------------------------------------------------------------

## The session's position changed. Relays [signal TentacleRuntime.OnConnectionStatusChanged].
signal OnConnectionStatusChanged(status: TclConnectionStatus.Value)

## A session opened and carries this id. Relays [signal TentacleRuntime.OnSessionOpened].
signal OnSessionOpened(session_id: String)

# --- Stream, across platforms ------------------------------------------------

## Every stream event. Relays [signal TentacleRuntime.OnStreamEvent].
signal OnStreamEvent(event: TclStreamEventBase, viewer: TclViewer)

## A viewer joined chat. Relays [signal TentacleRuntime.OnChatJoin].
signal OnChatJoin(viewer: TclViewer)

## A chat message that is not a command. Relays [signal TentacleRuntime.OnChatMessage].
signal OnChatMessage(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer)

## A chat command. Relays [signal TentacleRuntime.OnChatCommand].
signal OnChatCommand(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer)

## A chat message carrying emojis. Relays
## [signal TentacleRuntime.OnChatMessageWithEmojis].
signal OnChatMessageWithEmojis(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer)

## A chat message carrying emotes. Relays
## [signal TentacleRuntime.OnChatMessageWithEmotes].
signal OnChatMessageWithEmotes(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer)

## A ban. Relays [signal TentacleRuntime.OnBan].
signal OnBan(event: TclStreamEvent_Anywhere_Ban, viewer: TclViewer)

## A channel update, with no viewer. Relays [signal TentacleRuntime.OnChannelUpdate].
signal OnChannelUpdate(event: TclStreamEvent_Anywhere_ChannelUpdate)

## A donation. Relays [signal TentacleRuntime.OnDonation].
signal OnDonation(event: TclStreamEvent_Anywhere_Donation, viewer: TclViewer)

## A follow. Relays [signal TentacleRuntime.OnFollow].
signal OnFollow(event: TclStreamEvent_Anywhere_Follow, viewer: TclViewer)

## A redemption. Relays [signal TentacleRuntime.OnRedemption].
signal OnRedemption(event: TclStreamEvent_Anywhere_Redemption, viewer: TclViewer)

## A new subscription. Relays [signal TentacleRuntime.OnSubscription].
signal OnSubscription(event: TclStreamEvent_Anywhere_Subscription, viewer: TclViewer)

## A gifted subscription. Relays [signal TentacleRuntime.OnSubscriptionGift].
signal OnSubscriptionGift(event: TclStreamEvent_Anywhere_SubscriptionGift, viewer: TclViewer)

## A renewed subscription. Relays [signal TentacleRuntime.OnSubscriptionRenewal].
signal OnSubscriptionRenewal(event: TclStreamEvent_Anywhere_SubscriptionRenewal, viewer: TclViewer)

# --- Viewers -----------------------------------------------------------------

## A viewer was seen for the first time. Relays [signal Tentacle_Viewers.OnViewerAdded].
signal OnViewerAdded(viewer: TclViewer)

# --- Custom events and controls ----------------------------------------------

## A custom event. Relays [signal Tentacle_CustomEvents.OnCustomEvent].
signal OnCustomEvent(event: TclCustomEvent, viewer: TclViewer)

## The custom event definitions changed. Relays
## [signal Tentacle_CustomEvents.OnDefinitionsChanged].
signal OnDefinitionsChanged()

## An event for one of the game's custom controls. Relays
## [signal Tentacle_CustomControls.OnControlEvent].
signal OnControlEvent(handle: TentacleControlHandle, event: TclCustomControlEvent)

# --- Viewer properties -------------------------------------------------------

## The viewer-property registry loaded for the first time. Relays
## [signal Tentacle_ViewerProperties.OnInitialLoadComplete].
signal OnInitialLoadComplete()

## The viewer-property registry loaded. Relays
## [signal Tentacle_ViewerProperties.OnCollectionsRefreshed].
signal OnCollectionsRefreshed()

## A viewer's property value changed. Relays
## [signal Tentacle_ViewerProperties.OnViewerPropertyUpdated].
signal OnViewerPropertyUpdated(
	collection: TclViewerPropertyCollection,
	viewer: TclViewer,
	definition: TclViewerPropertyDefinition,
)

# --- Bot ---------------------------------------------------------------------

## The bot's command list changed. Relays [signal Tentacle_Bot.OnCommandsChanged].
signal OnCommandsChanged()

# --- Timers ------------------------------------------------------------------

# Tentacle_Timers.OnDefinitionsChanged shares its name with the custom events' signal,
# which is the one relayed under that name; a game follows the timer definitions from
# code.
## A timer fired. Relays [signal Tentacle_Timers.OnTimerFired].
signal OnTimerFired(event: TclTimerEvent)

# --- Connections -------------------------------------------------------------

## A platform's connection changed, in Embedded mode. Relays
## [signal Tentacle_Connections.OnConnectionChanged].
signal OnConnectionChanged(connection: TclPlatformConnection)

## Connecting needs the player, in Embedded mode. Relays
## [signal Tentacle_Connections.OnConnectPrompt].
signal OnConnectPrompt(prompt: TclPlatformConnectionPrompt)

## Connecting ended, in Embedded mode. Relays [signal Tentacle_Connections.OnConnectResult].
signal OnConnectResult(result: TclPlatformConnectionResult)

## Tentacle refused a request because the account has not allowed a permission it needs.
## Relays [signal Tentacle_Connections.OnPermissionNeeded].
signal OnPermissionNeeded(permission_needed: TclPlatformPermissionNeeded)

var _forwarder: TentacleSignalForwarder = null


func _init() -> void:
	_forwarder = TentacleSignalForwarder.new(self)


func _enter_tree() -> void:
	var runtime := TentacleRuntime.instance()
	if runtime == null:
		TentacleLog.warn(
			"a Tentacle event relay is in the scene but the addon's autoload is not "
			+ "installed, so it will never fire"
		)
		return
	for source: Object in [
		runtime,
		runtime.viewers,
		runtime.custom_events,
		runtime.custom_controls,
		runtime.viewer_properties,
		runtime.bot,
		runtime.timers,
		runtime.connections,
	]:
		_forwarder.forward_every_signal_of(source)


func _exit_tree() -> void:
	_forwarder.release()
