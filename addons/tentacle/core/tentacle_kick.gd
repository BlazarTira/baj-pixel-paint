class_name Tentacle_Kick
extends TclKickPlatformEvents

## Kick on its own: every Kick event, one signal per kind, and the calls that address
## Kick alone, each named as Kick's own documentation names it (the Channel Follow webhook
## is [code]OnChannelFollow[/code] here). Reached as [code]Tentacle.kick[/code].
##
## Every Kick event kind has a **signal of its own**, handing its handler that kind's own
## type, so there is nothing to cast:
##
## [codeblock]
## Tentacle.kick.OnChannelFollow.connect(_on_followed)
##
## func _on_followed(event: TclStreamEvent_Kick_ChannelFollowed, viewer: TclViewer) -> void:
##     print("%s followed" % viewer.display_name)
## [/codeblock]
##
## Those per-kind signals ([signal TclKickPlatformEvents.OnChannelFollow] and the rest)
## are declared on the generated base, [TclKickPlatformEvents]. A Kick chat message is one
## of them, [signal TclKickPlatformEvents.OnChatMessage], raised for every message,
## commands included.
##
## The [code]Tentacle[/code] autoload itself carries the cross-platform side, in
## Tentacle's own words: [signal TentacleRuntime.OnFollow] for a follow on any platform,
## the chat split into [signal TentacleRuntime.OnChatMessage] and
## [signal TentacleRuntime.OnChatCommand], [signal TentacleRuntime.OnChatJoin], the
## catch-all [signal TentacleRuntime.OnStreamEvent], and
## [method TentacleRuntime.send_chat_message] to every connected platform. Listen here for
## what only Kick has, or to react to Kick alone. For one Kick event, the autoload's
## [signal TentacleRuntime.OnStreamEvent] fires first, then the event's own signal here,
## then the event's cross-platform signal on the autoload.

# Unreal's UTentacle_Kick, delegate for delegate, as Tentacle_Twitch is Unreal's
# UTentacle_Twitch; see there for why TentacleClient rather than this surface raises the
# cross-platform signal. Kick's chat message shares its name with the autoload's
# OnChatMessage because both are named by their own vocabulary, which is why the relays
# are split per surface.

var _chat: TentacleChatSender = null
var _rpc: TentacleRpc = null


func _init(chat: TentacleChatSender = null, rpc: TentacleRpc = null) -> void:
	_chat = chat
	_rpc = rpc


## Points this surface's Kick API requests at a different RPC transport. The
## [code]Tentacle[/code] autoload calls this itself, rebinding the surface in place.
func bind_rpc(rpc: TentacleRpc) -> void:
	_rpc = rpc


# The generated base's requests (TclKickApiRequests) travel as the app's kick.*
# procedures, over HTTP or, embedded, over the session.
func _send_platform_request(procedure: String, is_query: bool, input_json: String, on_complete: Callable) -> void:
	if _rpc == null:
		TentacleRpc.fail(on_complete, "the Tentacle RPC client is not configured")
		return
	_rpc.call_procedure(procedure, is_query, input_json, on_complete)


# --- Sending -----------------------------------------------------------------

## Posts a message in the broadcaster's Kick chat: Kick's Post Chat Message. To send on
## every connected platform at once, use [method TentacleRuntime.send_chat_message]
## instead.
##
## [param type] posts as the broadcaster ([code]USER[/code]) or as the channel's bot
## ([code]BOT[/code]). [param reply_to_message_id] is the id of the chat message this one
## replies to (a Kick chat message's [code]message_id[/code]); leave it empty for none.
##
## Fire-and-forget: a message Kick refuses shows in Tentacle's log rather than here.
## Checked the same way as [method TentacleRuntime.send_chat_message]: empty content and
## content over [constant TentacleClient.CHAT_MESSAGE_MAX_LENGTH] are refused with a log
## line rather than posted for the app to reject. Returns false when the content was
## refused.
func post_chat_message(
	content: String,
	type: TclKickChatMessageType.Value = TclKickChatMessageType.Value.USER,
	reply_to_message_id: String = ""
) -> bool:
	if _chat == null:
		return false
	return _chat.post_kick(content, type, reply_to_message_id)


# --- Inbound routing -----------------------------------------------------------

## Raises the event's own signal on this surface. [TentacleClient] calls this once per
## Kick event, after de-duplication, after resolving the viewer, and after its own
## [signal TentacleClient.OnStreamEvent]; a game has no reason to.
func handle_event(stream_event: TclStreamEvent_Kick_Base, viewer: TclViewer) -> void:
	if stream_event == null:
		return
	if not _emit_platform_event(stream_event, viewer):
		# A kind this version predates, which Unreal logs at the same point.
		TentacleLog.info(
			'no Kick signal of its own for the stream event kind "%s"; only the catch-all carried it'
			% TclJson.as_string(TclJson.read_value(stream_event._retained_payload, "$type"))
		)
