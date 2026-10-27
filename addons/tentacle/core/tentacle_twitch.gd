class_name Tentacle_Twitch
extends TclTwitchPlatformEvents

## Twitch on its own: every Twitch event, one signal per kind, and the calls that address
## Twitch alone, each named as Twitch's own documentation names it (EventSub's Channel
## Cheer is [code]OnChannelCheer[/code] here). Reached as [code]Tentacle.twitch[/code].
##
## Every Twitch event kind has a **signal of its own**, handing its handler that kind's
## own type, so there is nothing to cast:
##
## [codeblock]
## Tentacle.twitch.OnChannelCheer.connect(_on_cheer)
##
## func _on_cheer(event: TclStreamEvent_Twitch_Cheer, viewer: TclViewer) -> void:
##     print("%s cheered %d bits" % [viewer.display_name, event.bits])
## [/codeblock]
##
## Those per-kind signals ([signal TclTwitchPlatformEvents.OnChannelCheer],
## [signal TclTwitchPlatformEvents.OnChannelRaid], and the rest) are declared on the
## generated base, [TclTwitchPlatformEvents]. A Twitch chat message is one of them,
## [signal TclTwitchPlatformEvents.OnChannelChatMessage], raised for every message,
## commands included.
##
## The [code]Tentacle[/code] autoload itself carries the cross-platform side, in
## Tentacle's own words: [signal TentacleRuntime.OnFollow] for a follow on any platform,
## the chat split into [signal TentacleRuntime.OnChatMessage] and
## [signal TentacleRuntime.OnChatCommand], [signal TentacleRuntime.OnChatJoin], the
## catch-all [signal TentacleRuntime.OnStreamEvent], and
## [method TentacleRuntime.send_chat_message] to every connected platform. Listen here for
## what only Twitch has, or to react to Twitch alone. For one Twitch event, the autoload's
## [signal TentacleRuntime.OnStreamEvent] fires first, then the event's own signal here,
## then the event's cross-platform signal on the autoload.
##
## What Tentacle adds to Twitch, such as the incoming raid window, is on [member extras].

# Unreal's UTentacle_Twitch: the signal names, their payload types, where a viewer is
# passed, and the firing order are Unreal's, delegate for delegate. The per-kind signals
# live on a generated base because a generator test holds them to Unreal's
# Tentacle_Twitch.h, and every signal this surface has is one of them.
#
# TentacleClient drives the dispatch: it de-duplicates, resolves the viewer, raises its
# own OnStreamEvent, hands the event here, and raises the cross-platform signal after
# this returns. Unreal's component broadcasts the actor's view itself; here the client
# does, so this surface holds no reference back to the client that owns it.

## What Tentacle adds to Twitch: things Twitch itself does not have, such as the incoming
## raid window.
var extras: Tentacle_TwitchExtras:
	get:
		return _extras

var _extras: Tentacle_TwitchExtras = Tentacle_TwitchExtras.new()
var _chat: TentacleChatSender = null
var _rpc: TentacleRpc = null


func _init(chat: TentacleChatSender = null, rpc: TentacleRpc = null) -> void:
	_chat = chat
	_rpc = rpc


## Points this surface's Twitch API requests at a different RPC transport. The
## [code]Tentacle[/code] autoload calls this itself, rebinding the surface in place.
func bind_rpc(rpc: TentacleRpc) -> void:
	_rpc = rpc


# The generated base's requests (TclTwitchApiRequests) travel as the app's twitch.*
# procedures, over HTTP or, embedded, over the session.
func _send_platform_request(procedure: String, is_query: bool, input_json: String, on_complete: Callable) -> void:
	if _rpc == null:
		TentacleRpc.fail(on_complete, "the Tentacle RPC client is not configured")
		return
	_rpc.call_procedure(procedure, is_query, input_json, on_complete)


# --- Sending -----------------------------------------------------------------

## Sends a message in the broadcaster's Twitch chat, from the broadcaster: Twitch's Send
## Chat Message. To send on every connected platform at once, use
## [method TentacleRuntime.send_chat_message] instead.
##
## [param reply_parent_message_id] is the id of the chat message this one replies to (a
## Twitch chat message's [code]message_id[/code]); leave it empty for none. During a shared
## chat session the message reaches every channel in the session.
##
## Fire-and-forget: a message Twitch drops shows in Tentacle's log rather than here.
## Checked the same way as [method TentacleRuntime.send_chat_message]: an empty message
## and one over [constant TentacleClient.CHAT_MESSAGE_MAX_LENGTH] are refused with a log
## line rather than sent for the app to reject. Returns false when the message was
## refused.
func send_chat_message(message: String, reply_parent_message_id: String = "") -> bool:
	if _chat == null:
		return false
	return _chat.send_twitch(message, reply_parent_message_id)


# --- Inbound routing -----------------------------------------------------------

## Raises the event's own signal on this surface. [TentacleClient] calls this once per
## Twitch event, after de-duplication, after resolving the viewer, and after its own
## [signal TentacleClient.OnStreamEvent]; a game has no reason to.
func handle_event(stream_event: TclStreamEvent_Twitch_Base, viewer: TclViewer) -> void:
	if stream_event == null:
		return
	# Opened before the raid's own signal fires, as Unreal's UTentacle_Twitch calls
	# BeginIncomingRaid, so a handler of OnChannelRaid already sees the window open.
	if stream_event is TclStreamEvent_Twitch_Raid:
		_extras._begin_incoming_raid()
	if not _emit_platform_event(stream_event, viewer):
		# A kind this version predates, which Unreal logs at the same point.
		TentacleLog.info(
			'no Twitch signal of its own for the stream event kind "%s"; only the catch-all carried it'
			% TclJson.as_string(TclJson.read_value(stream_event._retained_payload, "$type"))
		)
