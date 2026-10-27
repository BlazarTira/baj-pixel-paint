class_name TentacleChatSender
extends RefCounted

## Checks and sends the chat messages a game writes.
##
## What [method TentacleRuntime.send_chat_message], [method Tentacle_Twitch.send_chat_message],
## and [method Tentacle_Kick.post_chat_message] all send through, so a message is checked
## the same way whichever of them a game calls. A game calls those rather than this.

# One sender shared by the entry point and both platform surfaces, rather than each
# platform surface calling back into TentacleClient as Unreal's components call their
# owning actor: the client owns the surfaces, and a RefCounted surface holding its owner
# would be a reference cycle neither side ever frees.

var _session: TentacleSession = null


func _init(session: TentacleSession = null) -> void:
	_session = session


## Sends [param message] to every connected platform, or refuses it and returns false.
##
## An empty message and one over [constant TentacleClient.CHAT_MESSAGE_MAX_LENGTH] are
## refused with a log line rather than sent for the app to reject.
func send(message: String, is_bot: bool) -> bool:
	return _send(message, is_bot, "")


## Sends [param message] to every connected platform as a reply to [param viewer], or
## refuses it and returns false. Refuses a null viewer too.
func send_to_viewer(viewer: TclViewer, message: String, is_bot: bool) -> bool:
	if viewer == null or viewer.viewer_id.is_empty():
		TentacleLog.error("send_chat_message_to_viewer needs a viewer")
		return false
	return _send(message, is_bot, viewer.viewer_id)


## Sends [param message] through Twitch's own Send Chat Message, or refuses it and
## returns false. An empty [param reply_parent_message_id] leaves the reply out.
func send_twitch(message: String, reply_parent_message_id: String) -> bool:
	if not _is_sendable(message):
		return false
	if _session == null:
		return false

	var payload: Dictionary = {"message": message}
	if not reply_parent_message_id.is_empty():
		payload["replyParentMessageId"] = reply_parent_message_id
	_session.send("Twitch_SendChatMessage", payload)
	return true


## Posts [param content] through Kick's own Post Chat Message, or refuses it and returns
## false. An empty [param reply_to_message_id] leaves the reply out.
func post_kick(content: String, type: TclKickChatMessageType.Value, reply_to_message_id: String) -> bool:
	if not _is_sendable(content):
		return false
	if _session == null:
		return false

	# Kick's `type` travels as `messageType`, beside the message's own `type`.
	var payload: Dictionary = {"content": content, "messageType": TclKickChatMessageType.to_wire(type)}
	if not reply_to_message_id.is_empty():
		payload["replyToMessageId"] = reply_to_message_id
	_session.send("Kick_PostChatMessage", payload)
	return true


func _send(message: String, is_bot: bool, viewer_id: String) -> bool:
	if not _is_sendable(message):
		return false
	if _session == null:
		return false

	# Every field beyond the message is optional: no platform means every connected
	# platform, which is where the entry point always sends.
	var payload: Dictionary = {"message": message}
	if is_bot:
		payload["isBot"] = true
	if not viewer_id.is_empty():
		payload["viewerId"] = viewer_id

	_session.send("Stream_SendChatMessage", payload)
	return true


## Whether every platform accepts [param text], logging why when it does not.
func _is_sendable(text: String) -> bool:
	if text.strip_edges().is_empty():
		TentacleLog.warn("refusing to send an empty chat message")
		return false
	if text.length() > TentacleClient.CHAT_MESSAGE_MAX_LENGTH:
		TentacleLog.warn(
			"refusing to send a chat message of %d characters; the limit is %d"
			% [text.length(), TentacleClient.CHAT_MESSAGE_MAX_LENGTH]
		)
		return false
	return true
