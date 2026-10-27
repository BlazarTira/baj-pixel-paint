class_name TentacleClient
extends RefCounted

## Everything Tentacle exposes, behind one object.
##
## Owns the session and the surfaces, and routes every message from Tentacle to the
## surface that handles it. The cross-platform stream signals, the catch-all, the chat
## split, chat joins, and chat sends are its own; each platform's own events are on
## [member twitch] and [member kick]; and [member custom_controls],
## [member custom_events], [member viewer_properties], [member viewers], [member obs],
## [member bot], [member timers], and [member subathon] carry the rest, plus connection
## state.
##
## [TentacleRuntime], the [code]Tentacle[/code] autoload, builds one of these and drives
## it every frame, and raises each of its stream signals as its own, so a game normally
## reaches all of this through the autoload rather than through this class.

# Engine-neutral throughout: hand it a TentacleSocket and a TentacleRpc and it works with
# no scene, no node, and no play mode, which is what the addon's tests do. TentacleRuntime
# in runtime/ is the thin engine shell that builds one of these and pumps it from
# Node._process.
#
# The stream members follow Unreal's ATentacle, where they sit on the actor itself: the
# platform is chosen by where a member lives, never by a suffix on its name. The entry
# point speaks Tentacle's vocabulary and each platform surface its platform's own, so the
# catch-all, the chat split, and chat joins are here alone. This class plays the actor's
# part in the dispatch - de-duplicating, resolving the viewer, raising the catch-all,
# handing the event to its platform surface, and raising the cross-platform view last -
# so the order is Unreal's HandleStreamEvent order.

# --- Every event -------------------------------------------------------------

## Every stream event, whatever its kind or platform, including kinds and platforms this
## version has no signal for yet. Fires first, before any other signal for the same
## event. Cast [param event] with [code]as[/code] to the event class you want; its class
## says which platform it came from.
signal OnStreamEvent(event: TclStreamEventBase, viewer: TclViewer)

# --- Chat --------------------------------------------------------------------

## A viewer joined chat. Only Twitch reports joins: Tentacle checks who is in the
## Twitch chat every 30 seconds, so a join arrives up to 30 seconds after it happens,
## and viewers already in chat when Tentacle connects to Twitch raise none.
signal OnChatJoin(viewer: TclViewer)

## A chat message that is **not** a command, on either platform.
signal OnChatMessage(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer)

## A chat message the app classified as a command, on either platform.
##
## A command does **not** also raise [signal OnChatMessage], so a game can listen to one
## without filtering the other back out. A message can raise neither: one that fires a
## custom event set to suppress its stream event arrives as that custom event alone, and
## no chat signal is raised for it.
signal OnChatCommand(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer)

## A chat message carrying emojis, raised **in addition to** [signal OnChatMessage] or
## [signal OnChatCommand].
signal OnChatMessageWithEmojis(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer)

## A chat message carrying emotes, raised **in addition to** [signal OnChatMessage] or
## [signal OnChatCommand].
signal OnChatMessageWithEmotes(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer)

# --- Cross-platform views ----------------------------------------------------

## A viewer was banned or timed out, on either platform.
signal OnBan(event: TclStreamEvent_Anywhere_Ban, viewer: TclViewer)

## The channel's title, category, or similar changed, on either platform.
##
## Carries **no viewer**: it describes the channel, not a person.
signal OnChannelUpdate(event: TclStreamEvent_Anywhere_ChannelUpdate)

## A donation, on either platform: a Twitch cheer, for one.
signal OnDonation(event: TclStreamEvent_Anywhere_Donation, viewer: TclViewer)

## A new follower, on either platform.
signal OnFollow(event: TclStreamEvent_Anywhere_Follow, viewer: TclViewer)

## A channel-points or reward redemption, on either platform.
signal OnRedemption(event: TclStreamEvent_Anywhere_Redemption, viewer: TclViewer)

## A new subscription, on either platform.
signal OnSubscription(event: TclStreamEvent_Anywhere_Subscription, viewer: TclViewer)

## A gifted subscription, on either platform.
signal OnSubscriptionGift(event: TclStreamEvent_Anywhere_SubscriptionGift, viewer: TclViewer)

## A renewed subscription, on either platform.
signal OnSubscriptionRenewal(event: TclStreamEvent_Anywhere_SubscriptionRenewal, viewer: TclViewer)

## The longest chat message Tentacle will send.
const CHAT_MESSAGE_MAX_LENGTH: int = 500

## Twitch on its own: its events, one signal per kind, and the calls that address
## Twitch alone, each named as Twitch's own documentation names it.
var twitch: Tentacle_Twitch = null

## Kick on its own: its events, one signal per kind, and the calls that address Kick
## alone, each named as Kick's own documentation names it.
var kick: Tentacle_Kick = null

## Controls this game puts in Tentacle's custom-controls panel.
var custom_controls: Tentacle_CustomControls = null

## Named events the streamer configured.
var custom_events: Tentacle_CustomEvents = null

## Per-viewer values the streamer defined.
var viewer_properties: Tentacle_ViewerProperties = null

## Every viewer this session has been told about.
var viewers: Tentacle_Viewers = null

## OBS requests relayed through Tentacle.
var obs: Tentacle_Obs = null

## Tentacle's chat bot as the streamer configured it, with every command it answers, kept
## current.
var bot: Tentacle_Bot = null

## The timers the streamer defined, firing at the game, and their definitions, kept
## current.
var timers: Tentacle_Timers = null

## The subathon counters. [b]Internal only, and not working yet:[/b] the counters behind
## them are unfinished, so do not build on them.
var subathon: Tentacle_Subathon = null

## Signing the player in to the streaming platforms, when Tentacle runs inside the game.
var connections: Tentacle_Connections = null

## The connection state machine.
var session: TentacleSession = null

## Whether to load the viewer-property registry as each session opens.
var refresh_registry_on_connect: bool = true

## How many recent event ids to remember, so an event that arrives twice is delivered once.
var stream_deduplication_window: int = TentacleDeduplicator.DEFAULT_CAPACITY:
	set(value):
		stream_deduplication_window = maxi(value, 0)
		_dedup.capacity = stream_deduplication_window

var _dedup: TentacleDeduplicator = TentacleDeduplicator.new()
var _rpc: TentacleRpc = null
var _chat: TentacleChatSender = null


func _init(socket: TentacleSocket = null, rpc: TentacleRpc = null) -> void:
	_rpc = rpc if rpc != null else TentacleRpc.new()

	session = TentacleSession.new(socket)
	session.frame.connect(_on_frame)
	session.session_opened.connect(_on_session_opened)

	_chat = TentacleChatSender.new(session)
	viewer_properties = Tentacle_ViewerProperties.new(_rpc)
	viewers = Tentacle_Viewers.new(viewer_properties)
	viewer_properties.bind_viewers(viewers)
	twitch = Tentacle_Twitch.new(_chat, _rpc)
	kick = Tentacle_Kick.new(_chat, _rpc)
	custom_controls = Tentacle_CustomControls.new(session)
	custom_events = Tentacle_CustomEvents.new()
	obs = Tentacle_Obs.new(session, _rpc)
	bot = Tentacle_Bot.new()
	timers = Tentacle_Timers.new(_rpc)
	subathon = Tentacle_Subathon.new(_rpc)
	connections = Tentacle_Connections.new(session)


## Where the connection stands.
var connection_status: TclConnectionStatus.Value:
	get:
		return session.status if session != null else TclConnectionStatus.Value.DISCONNECTED


# One dodge, applied consistently, so a user learns a single rule rather than three;
# Unreal and Unity spell these Connect / Disconnect / IsConnected, and only the suffix is
# Godot's.
## True while a session is open.
##
## Named [code]is_session_connected[/code] rather than [code]is_connected[/code]
## because [method Object.is_connected] is a non-virtual member of every Godot
## object - the same collision that gives [method connect_session] and
## [method disconnect_session] their suffix.
var is_session_connected: bool:
	get:
		return connection_status == TclConnectionStatus.Value.CONNECTED


## The server-assigned session id, empty while not connected.
var session_id: String:
	get:
		return session.session_id if session != null else ""


## Points the client at a different RPC transport. The [code]Tentacle[/code] autoload
## calls this itself once its [TclHttpClient] node exists.
##
## Every surface is rebound **in place** rather than replaced, so signal connections a
## game already made to [member viewer_properties] and the rest keep working.
func bind_rpc(rpc: TentacleRpc) -> void:
	# None is replaced because a game subscribes as early as it can, and swapping the
	# object out from under it would drop those connections with nothing to indicate why.
	_rpc = rpc
	viewer_properties.bind_rpc(rpc)
	subathon.bind_rpc(rpc)
	timers.bind_rpc(rpc)
	obs.bind_rpc(rpc)
	twitch.bind_rpc(rpc)
	kick.bind_rpc(rpc)


## Starts connecting, and keeps retrying until [method disconnect_session].
func connect_session() -> void:
	session.connect_session()


## Closes the session and stops retrying.
func disconnect_session() -> void:
	session.disconnect_session()
	_dedup.clear()


## Drives everything forward by [param delta] seconds.
func advance(delta: float) -> void:
	session.advance(delta)
	connections.advance(delta)


# --- Sending -----------------------------------------------------------------

## Sends a chat message to every connected platform. [param is_bot] sends it as
## Tentacle's bot where the platform has one.
##
## Checked here rather than left for the app to reject: an empty message and one over
## [constant CHAT_MESSAGE_MAX_LENGTH] are refused with a log line. Returns false when the
## message was refused. [method Tentacle_Twitch.send_chat_message] and
## [method Tentacle_Kick.post_chat_message] send on one platform alone, with that
## platform's own options.
func send_chat_message(message: String, is_bot: bool = false) -> bool:
	return _chat.send(message, is_bot)


## Sends a chat message to every connected platform as a reply to one viewer.
##
## The **only** public way to address a viewer: [method send_chat_message] deliberately
## takes no viewer id, so there is one path rather than two and the checks cannot be
## bypassed.
func send_chat_message_to_viewer(viewer: TclViewer, message: String, is_bot: bool = false) -> bool:
	return _chat.send_to_viewer(viewer, message, is_bot)


# --- Inbound routing ---------------------------------------------------------

## Routes one [code]Stream_Event[/code] payload, as the session does when one arrives:
## de-duplicated by the event's id first, then the viewer merged into the cache, then
## every signal for it, on this client and on its platform surface, in order.
func handle_stream_event(data: Dictionary) -> void:
	var stream_event := TclStreamEventBase.parse(TclJson.read_object(data, "event"))
	if stream_event == null:
		return

	# A duplicate never reaches a handler, on any surface. De-duplicated **before**
	# merging the viewer: a duplicate can carry a stale viewer snapshot that must not
	# overwrite fresher cache state.
	if not _dedup.remember(stream_event.id):
		return

	var viewer := viewers.upsert_viewer(TclJson.read_value(data, "viewer"))
	OnStreamEvent.emit(stream_event, viewer)

	if stream_event is TclStreamEvent_Twitch_Base:
		twitch.handle_event(stream_event as TclStreamEvent_Twitch_Base, viewer)
	elif stream_event is TclStreamEvent_Kick_Base:
		kick.handle_event(stream_event as TclStreamEvent_Kick_Base, viewer)
	else:
		# A platform this version predates: the catch-all above is all it has.
		return

	# The cross-platform view fires last, after the platform surface's own signal. For a
	# chat message that is the split, which is this entry point's alone: the platform's
	# own chat signal has already carried the message whole.
	var view := _anywhere_view(stream_event)
	if view is TclStreamEvent_Anywhere_ChatMessage:
		_emit_chat(view as TclStreamEvent_Anywhere_ChatMessage, viewer)
	else:
		_emit_anywhere(view, viewer)


## Routes one [code]Stream_ChatJoin[/code] payload, as the session does when one
## arrives: the viewer merged into the cache, then [signal OnChatJoin].
func handle_chat_join(data: Dictionary) -> void:
	var viewer := viewers.upsert_viewer(TclJson.read_value(data, "viewer"))
	if viewer == null:
		return
	# A join is Tentacle's own event rather than a platform's, so it fires here alone, as
	# Unreal's HandleChatJoin does; the viewer's profiles say which chat they joined.
	OnChatJoin.emit(viewer)


func _on_session_opened(_new_session_id: String) -> void:
	# Tentacle drops a session's controls the moment its socket closes, so every new
	# session starts by replaying the whole registry.
	custom_controls.replay()
	if refresh_registry_on_connect:
		viewer_properties.refresh_registry()


# Routing on the wire type in one place, rather than subscribing to a signal per message
# type, is what keeps a message type added upstream from arriving somewhere nothing is
# listening: anything unrecognised reaches the log below.
## Routes one inbound frame onto the surface that owns it.
func _on_frame(type: String, data: Dictionary) -> void:
	match type:
		"Stream_Event":
			handle_stream_event(data)
		"Stream_ChatJoin":
			handle_chat_join(data)
		"CustomEvents_Event":
			custom_events.handle_event(data, viewers.upsert_viewer(TclJson.read_value(data, "viewer")))
		"CustomEvents_Definitions":
			custom_events.handle_definitions(data)
		"Bot_Commands":
			bot.handle_commands(data)
		"Timers_Fired":
			timers.handle_fired(data)
		"Timers_Definitions":
			timers.handle_definitions(data)
		"CustomControls_ControlEvent":
			custom_controls.handle_control_event(data)
		"CustomControls_Initialize":
			# Tentacle asking for the registry, which it does once right after
			# welcoming a session.
			custom_controls.replay()
		"ViewerAction_Action":
			# Deliberately unhandled. Viewer actions are still an experimental app
			# feature, so no Tentacle plugin surfaces them: the generated types exist
			# because they follow the app's type surface, and that is all.
			pass
		"Connections_Status":
			# Sent only by a Tentacle that runs inside the game; the app never does.
			connections.handle_status(data)
		"Connections_Prompt":
			connections.handle_prompt(data)
		"Connections_Result":
			connections.handle_result(data)
		"Rpc_Response":
			# An answer to a call made over the session, in Embedded mode.
			_rpc.handle_response(data)
		_:
			# Forward-compatible by design: a newer Tentacle may send a type this
			# version has never heard of, and that must not cost the session.
			TentacleLog.info('ignoring message type "%s"; this version does not handle it' % type)


## The event's cross-platform view, or null when its kind has none.
##
## The view is reachable from the concrete event rather than from the base, and each
## call rebuilds it from the retained payload, so it is asked for once per event.
static func _anywhere_view(stream_event: TclStreamEventBase) -> TclStreamEventAnywhereBase:
	if not stream_event.has_method("get_anywhere_event"):
		return null
	var view: Variant = stream_event.call("get_anywhere_event")
	return view as TclStreamEventAnywhereBase if view is TclStreamEventAnywhereBase else null


## Raises whichever cross-platform signal [param view] belongs to, if any.
##
## Asks each view type in turn instead of inspecting a discriminant string. An event with
## no cross-platform view has a null [param view] and raises nothing here.
func _emit_anywhere(view: TclStreamEventAnywhereBase, viewer: TclViewer) -> void:
	if view == null:
		return

	if view is TclStreamEvent_Anywhere_Ban:
		OnBan.emit(view as TclStreamEvent_Anywhere_Ban, viewer)
		return
	if view is TclStreamEvent_Anywhere_ChannelUpdate:
		# No viewer: a channel update describes the channel, not a person.
		OnChannelUpdate.emit(view as TclStreamEvent_Anywhere_ChannelUpdate)
		return
	if view is TclStreamEvent_Anywhere_Donation:
		OnDonation.emit(view as TclStreamEvent_Anywhere_Donation, viewer)
		return
	if view is TclStreamEvent_Anywhere_Follow:
		OnFollow.emit(view as TclStreamEvent_Anywhere_Follow, viewer)
		return
	if view is TclStreamEvent_Anywhere_Redemption:
		OnRedemption.emit(view as TclStreamEvent_Anywhere_Redemption, viewer)
		return
	# Gift and renewal are checked before the plain subscription: both extend it on
	# some platforms, so the general test would swallow the specific ones.
	if view is TclStreamEvent_Anywhere_SubscriptionGift:
		OnSubscriptionGift.emit(view as TclStreamEvent_Anywhere_SubscriptionGift, viewer)
		return
	if view is TclStreamEvent_Anywhere_SubscriptionRenewal:
		OnSubscriptionRenewal.emit(view as TclStreamEvent_Anywhere_SubscriptionRenewal, viewer)
		return
	if view is TclStreamEvent_Anywhere_Subscription:
		OnSubscription.emit(view as TclStreamEvent_Anywhere_Subscription, viewer)


## Raises the command/message split, plus the emoji and emote signals alongside, as
## Unreal's ATentacle::DispatchChatMessage does.
func _emit_chat(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer) -> void:
	if TclJson.as_string(chat_message.command).is_empty():
		OnChatMessage.emit(chat_message, viewer)
	else:
		OnChatCommand.emit(chat_message, viewer)

	# Raised in addition to whichever of the two fired above, never instead of it.
	if not chat_message.emojis.is_empty():
		OnChatMessageWithEmojis.emit(chat_message, viewer)
	if not chat_message.emotes.is_empty():
		OnChatMessageWithEmotes.emit(chat_message, viewer)
