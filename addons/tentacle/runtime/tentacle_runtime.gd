@icon("res://addons/tentacle/icons/tentacle.png")
class_name TentacleRuntime
extends Node

## The Tentacle session, as a Godot node. **This is the entry point.**
##
## Installed as an autoload named [code]Tentacle[/code] (the addon's
## [EditorPlugin] does that when you enable it), a game reaches everything from
## anywhere without wiring a reference through its own object graph:
##
## [codeblock]
## func _ready() -> void:
##     Tentacle.OnChatMessage.connect(_on_chat)
##     Tentacle.twitch.OnChannelCheer.connect(_on_cheer)
##     Tentacle.viewers.OnViewerAdded.connect(_on_viewer)
## [/codeblock]
##
## Stream events live in three places, and where a signal lives says which platform it
## is for. The autoload itself carries what works across platforms, in Tentacle's own
## words: [signal OnChatMessage] and [signal OnChatCommand] for chat on Twitch or Kick,
## [signal OnFollow] for a follow on either, [signal OnChatJoin], the catch-all
## [signal OnStreamEvent], and [method send_chat_message] to every connected platform.
## [member twitch] and [member kick] carry each platform's own events, one signal per
## kind named as that platform's documentation names it, and the calls that address that
## platform alone. For one event, [signal OnStreamEvent] fires first, then the event's own
## signal on its platform, then the cross-platform signal here.
##
## As an autoload it outlives every scene, so changing scenes never drops the
## connection or resets the viewer cache, and it keeps running while the game is
## paused, so a pause menu never drops it either.

# The autoload is named Tentacle after Unreal's ATentacle actor; the class keeps the
# Tentacle-prefixed name it has on Unity too, because neither is a Blueprint-visible type.
#
# Why an autoload rather than a node you place in a scene: both shapes exist in the other
# plugins - Unreal users expect a placed actor they configure in the details panel, Unity
# users expect a singleton - and Godot users reach for an autoload first for anything
# that outlives a scene, which a network session does. It also answers the two questions
# the ambient form has to: the editor plugin builds it, and Node._exit_tree tears it down.
#
# This node is deliberately thin. It owns a TentacleClient, pumps it from Node._process,
# resolves endpoints, and supplies the things the engine-neutral core cannot reach: the
# engine version, the project name, an instance id. Everything else lives in the core.
#
# The cross-platform stream members sit on the node itself, as they sit on Unreal's
# ATentacle actor, rather than on a surface of their own: the platform is chosen by where
# a member lives, never by a suffix. The signals are the client's, raised again here in
# the same dispatch, so a handler connected here hears them in the client's order.

## The longest chat message Tentacle will send.
const CHAT_MESSAGE_MAX_LENGTH: int = TentacleClient.CHAT_MESSAGE_MAX_LENGTH

## Where Tentacle keeps its data in Embedded mode when [member embedded_data_directory]
## is empty.
const DEFAULT_EMBEDDED_DATA_DIRECTORY: String = "user://Tentacle"

# The Tentacle app writes here when exporting to a Godot project (ENGINE_CONFIG_FOLDERS in
# packages/common/src/general/config-export.ts), which
# packages/app/tests/config-folders.test.ts holds this to.
## Where Tentacle reads the game's config files in Embedded mode when
## [member config_directory] is empty, and its default: the folder the Tentacle app's
## Data > Export puts them in for a Godot project.
const DEFAULT_CONFIG_DIRECTORY: String = "res://tentacle"

# What the session is handed to dial in Embedded mode, which the embedded socket ignores.
const _EMBEDDED_URL: String = "embedded:tentacle-core"

# --- Stream signals, raised from the client as they fire. ---------------------

## Every stream event, whatever its kind or platform, including kinds and platforms this
## version has no signal for yet. Fires first, before any other signal for the same
## event. Cast [param event] with [code]as[/code] to the event class you want; its class
## says which platform it came from.
signal OnStreamEvent(event: TclStreamEventBase, viewer: TclViewer)

## A viewer joined chat. Only Twitch reports joins: Tentacle checks who is in the
## Twitch chat every 30 seconds, so a join arrives up to 30 seconds after it happens,
## and viewers already in chat when Tentacle connects to Twitch raise none.
## Permission required on Twitch: "Who's in chat"
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

## A viewer was banned or timed out, on either platform.
## Permission required on Twitch: "Bans and timeouts"
signal OnBan(event: TclStreamEvent_Anywhere_Ban, viewer: TclViewer)

## The channel's title, category, or similar changed, on either platform.
##
## Carries **no viewer**: it describes the channel, not a person.
signal OnChannelUpdate(event: TclStreamEvent_Anywhere_ChannelUpdate)

## A donation, on either platform: a Twitch cheer, for one.
## Permission required on Twitch: "Bits"
signal OnDonation(event: TclStreamEvent_Anywhere_Donation, viewer: TclViewer)

## A new follower, on either platform.
## Permission required on Twitch: "Follows"
signal OnFollow(event: TclStreamEvent_Anywhere_Follow, viewer: TclViewer)

## A channel-points or reward redemption, on either platform.
## Permissions required on Twitch: "Channel Points redemptions" or "Channel Points rewards"
signal OnRedemption(event: TclStreamEvent_Anywhere_Redemption, viewer: TclViewer)

## A new subscription, on either platform.
## Permission required on Twitch: "Subscriptions"
signal OnSubscription(event: TclStreamEvent_Anywhere_Subscription, viewer: TclViewer)

## A gifted subscription, on either platform.
## Permission required on Twitch: "Subscriptions"
signal OnSubscriptionGift(event: TclStreamEvent_Anywhere_SubscriptionGift, viewer: TclViewer)

## A renewed subscription, on either platform.
## Permission required on Twitch: "Subscriptions"
signal OnSubscriptionRenewal(event: TclStreamEvent_Anywhere_SubscriptionRenewal, viewer: TclViewer)

# The surfaces, plus connection state, are reached through these.

## Twitch on its own: its events, one signal per kind, and the calls that address
## Twitch alone, each named as Twitch's own documentation names it. What Tentacle adds
## to Twitch is on its [member Tentacle_Twitch.extras].
var twitch: Tentacle_Twitch:
	get:
		return _client.twitch

## Kick on its own: its events, one signal per kind, and the calls that address Kick
## alone, each named as Kick's own documentation names it.
var kick: Tentacle_Kick:
	get:
		return _client.kick

## Controls this game puts in Tentacle's custom-controls panel.
var custom_controls: Tentacle_CustomControls:
	get:
		return _client.custom_controls

## Named events the streamer configured.
var custom_events: Tentacle_CustomEvents:
	get:
		return _client.custom_events

## Per-viewer values the streamer defined.
var viewer_properties: Tentacle_ViewerProperties:
	get:
		return _client.viewer_properties

## Every viewer this session has been told about.
var viewers: Tentacle_Viewers:
	get:
		return _client.viewers

## OBS requests relayed through Tentacle.
var obs: Tentacle_Obs:
	get:
		return _client.obs

## Tentacle's chat bot as the streamer configured it, with every command it answers, kept
## current.
var bot: Tentacle_Bot:
	get:
		return _client.bot

## The timers the streamer defined, firing at the game, and their definitions, kept
## current.
var timers: Tentacle_Timers:
	get:
		return _client.timers

## The subathon counters. [b]Internal only, and not working yet:[/b] the counters behind
## them are unfinished, so do not build on them.
var subathon: Tentacle_Subathon:
	get:
		return _client.subathon

## Signing the player in to the streaming platforms, in Embedded mode.
var connections: Tentacle_Connections:
	get:
		return _client.connections

## Where the connection stands.
var connection_status: TclConnectionStatus.Value:
	get:
		return _client.connection_status

## True while a session is open. See [method connect_session] for the naming.
var is_session_connected: bool:
	get:
		return _client.is_session_connected

## True when Tentacle runs inside the game rather than in the Tentacle app:
## [member editor_mode] when run from the editor, [member build_mode] once exported, or a
## [code]--tentacle-mode[/code] argument on the command line. Signing in from the game
## only applies when this is true. Settled as the node becomes ready.
var is_embedded: bool:
	get:
		return _embedded

## The server-assigned session id. Empty while not connected.
var session_id: String:
	get:
		return _client.session_id

## This process's Tentacle instance id.
##
## Deliberately not [code]instance_id[/code]: that is [Object]'s own, and shadowing
## it breaks things in ways whose errors name neither.
var tentacle_instance_id: String:
	get:
		return _instance_id

## The whole client, for anything these shortcuts do not cover.
var client: TentacleClient:
	get:
		return _client

## The tRPC client, for procedures the surfaces do not wrap.
var http_client: TclHttpClient:
	get:
		return _http

## The endpoints currently in use, or null before the first attempt. Always null in
## Embedded mode, which has none.
var endpoints: TentacleEndpoints:
	get:
		return _endpoints

# --- Configuration ------------------------------------------------------------
#
# The autoload takes these from Project Settings (TentacleProjectSettings) as it becomes
# ready; a runtime a scene instances takes them from its own Inspector. Either way, a
# value assigned before the node is ready wins, which is how code configures it early -
# and how the test runner holds the host project's autoload offline.

## Connect as soon as the node is ready. The autoload reads this from the
## [code]tentacle/connection/auto_connect[/code] Project Setting.
@export var auto_connect: bool = true:
	set(value):
		auto_connect = value
		_assigned[&"auto_connect"] = true

## The name shown beside the session in Tentacle. Empty means the project name. The
## autoload reads this from the [code]tentacle/connection/session_label[/code] Project
## Setting.
@export var session_label: String = "":
	set(value):
		session_label = value
		_assigned[&"session_label"] = true

## Where to look for Tentacle's discovery file. Leave empty unless you are running
## an isolated Tentacle instance.
@export_dir var data_directory_override: String = "":
	set(value):
		data_directory_override = value
		_assigned[&"data_directory_override"] = true

## Tentacle's connection password, for a Tentacle whose user set one under Settings >
## System > Connection Password. Empty, the default, sends none, which is all Tentacle
## asks for until a password is set. A change is sent with the next request and the
## next connection attempt, so a game for other people can set it from its own settings
## screen. Not used in Embedded mode. The autoload reads this from the
## [code]tentacle/connection/connection_password[/code] Project Setting.
@export_custom(PROPERTY_HINT_PASSWORD, "") var connection_password: String = "":
	set(value):
		connection_password = value
		_assigned[&"connection_password"] = true
		_apply_connection_password()

# The Inspector lists the modes by hand so it leaves out APP, PAIRED's old name.
## Where Tentacle runs when the game runs from the editor: Paired, with the Tentacle app on
## this machine, or Embedded, Tentacle's core running inside the game (which needs the Tentacle
## GDExtension). A [code]--tentacle-mode=paired[/code] or [code]--tentacle-mode=embedded[/code]
## argument on the command line wins over it. Read once, as the node becomes ready. The
## autoload reads this from the [code]tentacle/connection/editor_mode[/code] Project
## Setting.
@export_custom(PROPERTY_HINT_ENUM, "Paired:0,Embedded:1") var editor_mode: TclTentacleMode.Value = TclTentacleMode.Value.PAIRED:
	set(value):
		editor_mode = value
		_assigned[&"editor_mode"] = true

## Where Tentacle runs in an exported game: Paired, with the Tentacle app on the player's
## machine, or Embedded,
## Tentacle's core running inside the game, so players need no app. A
## [code]--tentacle-mode=paired[/code] or [code]--tentacle-mode=embedded[/code] argument on
## the command line wins over it. Read once, as the node becomes ready. The autoload
## reads this from the [code]tentacle/connection/build_mode[/code] Project Setting.
@export_custom(PROPERTY_HINT_ENUM, "Paired:0,Embedded:1") var build_mode: TclTentacleMode.Value = TclTentacleMode.Value.PAIRED:
	set(value):
		build_mode = value
		_assigned[&"build_mode"] = true

## In Embedded mode, the folder Tentacle keeps its database and the player's accounts
## in. Empty means [code]user://Tentacle[/code]. The autoload reads this from the
## [code]tentacle/embedded/embedded_data_directory[/code] Project Setting.
@export_global_dir var embedded_data_directory: String = "":
	set(value):
		embedded_data_directory = value
		_assigned[&"embedded_data_directory"] = true

## In Embedded mode, the client ID of your own Twitch app to sign players in with, so its
## name is the one on Twitch's consent page. Empty uses Tentacle's. The autoload reads
## this from the [code]tentacle/embedded/twitch_client_id[/code] Project Setting.
@export var twitch_client_id: String = "":
	set(value):
		twitch_client_id = value
		_assigned[&"twitch_client_id"] = true

## In Embedded mode, the client ID of your own Kick app to sign players in with, so its
## name is the one on Kick's consent page. Kick finishes a sign-in only with the app's
## client secret, so set [member kick_sign_in_server_url] too: one without the other
## refuses Kick sign-ins. Empty uses Tentacle's. The autoload reads this from the
## [code]tentacle/embedded/kick_client_id[/code] Project Setting.
@export var kick_client_id: String = "":
	set(value):
		kick_client_id = value
		_assigned[&"kick_client_id"] = true

## In Embedded mode, the address of your Kick sign-in server, which holds your Kick app's
## client secret and finishes and renews sign-ins with it. Empty uses Tentacle's. The
## autoload reads this from the [code]tentacle/embedded/kick_sign_in_server_url[/code]
## Project Setting.
@export var kick_sign_in_server_url: String = "":
	set(value):
		kick_sign_in_server_url = value
		_assigned[&"kick_sign_in_server_url"] = true

## In Embedded mode, the folder the game's config files are read from: the timers, custom
## events, viewer properties, and bot commands the Tentacle app's Data > Export writes
## there. Every [code].json[/code] file in it is applied each time Tentacle starts: what the
## files name is brought in line with them, what they stop naming is removed (a viewer
## property is kept, with its values), and what the game creates itself is never touched.
## An export packs the folder like the rest of the project. The autoload reads this from the
## [code]tentacle/embedded/config_directory[/code] Project Setting.
@export_dir var config_directory: String = DEFAULT_CONFIG_DIRECTORY:
	set(value):
		config_directory = value
		_assigned[&"config_directory"] = true

## In Embedded mode, ask Twitch and Kick only for the permissions in the four lists below,
## rather than for everything Tentacle can use, with the player choosing what to turn
## off. Chat is always asked for. The autoload reads this from the
## [code]tentacle/embedded/custom_permissions[/code] Project Setting.
@export var custom_permissions: bool = false:
	set(value):
		custom_permissions = value
		_assigned[&"custom_permissions"] = true

## What every Twitch sign-in asks for besides chat, when [member custom_permissions] is
## on. The autoload reads this from the
## [code]tentacle/embedded/twitch_required_permissions[/code] Project Setting.
@export var twitch_required_permissions: Array[TclPlatformPermission.Value] = []:
	set(value):
		twitch_required_permissions = value
		_assigned[&"twitch_required_permissions"] = true

## What a Twitch sign-in may also ask for, unless the player turns it off, when
## [member custom_permissions] is on. The autoload reads this from the
## [code]tentacle/embedded/twitch_optional_permissions[/code] Project Setting.
@export var twitch_optional_permissions: Array[TclPlatformPermission.Value] = []:
	set(value):
		twitch_optional_permissions = value
		_assigned[&"twitch_optional_permissions"] = true

## What every Kick sign-in asks for besides chat, when [member custom_permissions] is on.
## The autoload reads this from the [code]tentacle/embedded/kick_required_permissions[/code]
## Project Setting.
@export var kick_required_permissions: Array[TclPlatformPermission.Value] = []:
	set(value):
		kick_required_permissions = value
		_assigned[&"kick_required_permissions"] = true

## What a Kick sign-in may also ask for, unless the player turns it off, when
## [member custom_permissions] is on. The autoload reads this from the
## [code]tentacle/embedded/kick_optional_permissions[/code] Project Setting.
@export var kick_optional_permissions: Array[TclPlatformPermission.Value] = []:
	set(value):
		kick_optional_permissions = value
		_assigned[&"kick_optional_permissions"] = true

## Seconds before the first retry.
@export_range(0.25, 60.0, 0.05, "or_greater", "suffix:s") var reconnect_initial_delay: float = 1.0:
	set(value):
		reconnect_initial_delay = value
		_assigned[&"reconnect_initial_delay"] = true
		_client.session.reconnect.initial_delay = value

## The ceiling retries back off to, in seconds.
@export_range(0.25, 300.0, 0.05, "or_greater", "suffix:s") var reconnect_max_delay: float = 30.0:
	set(value):
		reconnect_max_delay = value
		_assigned[&"reconnect_max_delay"] = true
		_client.session.reconnect.max_delay = value

## How many recent event ids are remembered, so an event that arrives twice is
## delivered once. Zero disables de-duplication.
@export_range(0, 10000, 1, "or_greater") var stream_deduplication_window: int = 100:
	set(value):
		stream_deduplication_window = value
		_assigned[&"stream_deduplication_window"] = true
		_client.stream_deduplication_window = value

## Load the viewer-property registry as each session opens.
@export var refresh_registry_on_connect: bool = true:
	set(value):
		refresh_registry_on_connect = value
		_assigned[&"refresh_registry_on_connect"] = true
		_client.refresh_registry_on_connect = value

## The settings assigned before this node was ready, which Project Settings leave alone.
var _assigned: Dictionary[StringName, bool] = {}

# --- Signals, re-emitted from the core so a scene can wire them directly. ----

## The session's position changed.
signal OnConnectionStatusChanged(status: TclConnectionStatus.Value)

## A session opened and carries this id. A reconnect brings a new one.
signal OnSessionOpened(session_id: String)

## The running instance, for code that cannot reach the autoload by name.
##
## The autoload is called [code]Tentacle[/code] by default, but a user may rename it,
## so the scene-authored control and listener nodes find the session through this
## rather than through a hardcoded [code]/root/Tentacle[/code] path.
static var _singleton: TentacleRuntime = null

## The runtime this one displaced as [member _singleton], handed back when this one
## leaves - so removing a second runtime does not strand the scene nodes while the
## first is still installed.
var _displaced: TentacleRuntime = null

var _client: TentacleClient = null
## Raises the client's stream signals as this node's own.
var _client_signals: TentacleSignalForwarder = null
## Warns about this node's cross-platform signals the Twitch account keeps quiet.
var _quiet_events: TentacleQuietEvents = TentacleQuietEvents.new()
var _http: TclHttpClient = null
## The procedures' transport: over HTTP to the app, or over the session in Embedded mode.
var _rpc: TentacleRpc = null
var _endpoints: TentacleEndpoints = null
var _instance_id: String = ""
## Where the modes put Tentacle, settled in [method _ready].
var _embedded: bool = false


## The running Tentacle runtime, or null when the addon's autoload is not installed.
static func instance() -> TentacleRuntime:
	return _singleton


func _enter_tree() -> void:
	# Last one in wins, which matters only if a project installs two - in which case
	# the second is a mistake worth saying so about.
	if _singleton != null and _singleton != self:
		TentacleLog.warn(
			"a second TentacleRuntime entered the tree; the scene-authored nodes will "
			+ "use the most recent one"
		)
		_displaced = _singleton
	_singleton = self


func _init() -> void:
	# Built in _init rather than _ready so a game may configure the client, or
	# subscribe to a surface, before the node enters the tree.
	_instance_id = _build_instance_id()
	# The core has no clock of its own; a viewer's timeout is read against this one.
	TentacleBadges.wall_clock = Time.get_unix_time_from_system
	_client = TentacleClient.new(TentacleWebSocket.new())
	_client_signals = TentacleSignalForwarder.new(self)
	_client_signals.forward_every_signal_of(_client)
	_client.session.status_changed.connect(
		func(status: TclConnectionStatus.Value) -> void:
			OnConnectionStatusChanged.emit(status)
	)
	_client.session.session_opened.connect(
		func(new_id: String) -> void: OnSessionOpened.emit(new_id)
	)
	_client.session.url_provider = _resolve_engine_url
	_client.connections.OnConnectionChanged.connect(_warn_about_quiet_events)


func _ready() -> void:
	# The editor loads the addon's scripts too, and an editor-side session would
	# show in Tentacle's Engines list as a phantom game nobody started.
	if Engine.is_editor_hint():
		set_process(false)
		return

	# Before the identity is built and before auto-connect is read, so both see them.
	if _is_project_autoload():
		TentacleProjectSettings.apply_to(self, _assigned)

	_embedded = TclTentacleMode.resolves_to_embedded(
		editor_mode, build_mode, OS.has_feature("editor"), OS.get_cmdline_args() + OS.get_cmdline_user_args()
	)
	_client.connections.embedded = _embedded
	_client.connections.open_url = OS.shell_open
	_http = TclHttpClient.new()
	add_child(_http)
	if _embedded:
		# The core runs in this process and has no HTTP server: the session goes to it,
		# and every procedure travels over the session, the http_client's included.
		_client.session.set_socket(TentacleEmbeddedSocket.new(_build_embedded_options()))
		var over_session := TentacleConnectionRpc.new(_client.session)
		_http.procedure_transport = over_session.call_procedure
		_rpc = over_session
	else:
		_rpc = TentacleHttpRpc.new(_http)
	_client.bind_rpc(_rpc)

	_client.session.identity = _build_identity()
	_apply_connection_password()

	# A polled network client has to keep running while the game is paused. As an
	# autoload this node's parent is the root, where an inherited process mode
	# resolves to PAUSABLE - so any ordinary pause menu would stop _process, which
	# stops polling, which stops answering the server's pings. Tentacle pings every
	# 15s and reaps at 45s, so pausing that long would drop the session, lose every
	# event that arrived meanwhile, and come back with a different session id.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

	if auto_connect:
		connect_session()


func _process(delta: float) -> void:
	_client.advance(delta)


func _exit_tree() -> void:
	# The OS socket and its buffers outlive this node unless it is closed here.
	_client.disconnect_session()
	if _singleton == self:
		var fallback := _displaced
		_singleton = fallback if is_instance_valid(fallback) and fallback.is_inside_tree() else null
	_displaced = null


# The Unreal and Unity plugins call these Connect / Disconnect / IsConnected; the words
# survive, only the suffix is Godot's.
## Starts connecting, and keeps retrying until [method disconnect_session].
##
## Named [code]connect_session[/code] rather than [code]connect[/code] because
## [method Object.connect] is a non-virtual member of every Godot object - the same
## reason [method disconnect_session] and [member is_session_connected] are spelled
## as they are.
func connect_session() -> void:
	_client.connect_session()


## Closes the session and stops retrying.
func disconnect_session() -> void:
	_client.disconnect_session()


## Sends a chat message to every connected platform. [param is_bot] sends it as
## Tentacle's bot where the platform has one.
##
## Checked here rather than left for the app to reject: an empty message and one over
## [constant CHAT_MESSAGE_MAX_LENGTH] are refused with a log line. Returns false when the
## message was refused. Not being connected is not a refusal: the message is accepted and
## goes nowhere. [method Tentacle_Twitch.send_chat_message] and
## [method Tentacle_Kick.post_chat_message] send on one platform alone, with that
## platform's own options.
func send_chat_message(message: String, is_bot: bool = false) -> bool:
	return _client.send_chat_message(message, is_bot)


## Sends a chat message to every connected platform as a reply to one viewer.
##
## The **only** way to address a viewer: [method send_chat_message] deliberately takes no
## viewer id, so there is one path rather than two and the checks cannot be bypassed.
func send_chat_message_to_viewer(viewer: TclViewer, message: String, is_bot: bool = false) -> bool:
	return _client.send_chat_message_to_viewer(viewer, message, is_bot)


# --- Internals ---------------------------------------------------------------

## Re-resolves the engine socket URL, called fresh on every attempt.
##
## Warns in the log about each cross-platform signal a game listens to here that
## [param connection]'s Twitch account keeps quiet.
func _warn_about_quiet_events(connection: TclPlatformConnection) -> void:
	_quiet_events.check(connection, self, TclTwitchPlatformEvents.CROSS_PLATFORM_EVENT_PERMISSIONS, "Tentacle.", true)


## Tentacle may have started, or restarted onto a different port, since the last
## one, so the endpoints are read again rather than remembered. The HTTP base URL is
## updated at the same time for the same reason.
func _resolve_engine_url() -> String:
	if _embedded:
		# Never dialled: the embedded socket connects to the core in this process. Not
		# empty, because an empty URL means there is nothing to connect to yet.
		return _EMBEDDED_URL
	_endpoints = TentacleEndpoints.resolve(data_directory_override)
	if _rpc is TentacleHttpRpc:
		(_rpc as TentacleHttpRpc).set_base_url(_endpoints.http_base_url)
	return _endpoints.engine_socket_url


## Hands [member connection_password] to the session's hello and the HTTP client, once
## they exist.
func _apply_connection_password() -> void:
	if _client != null and _client.session.identity != null:
		_client.session.identity.password = connection_password
	if _http != null:
		_http.connection_password = connection_password


## The core's settings, from this node's: the data folder (made if missing), the Twitch
## and Kick apps, and the text of each config file in the config folder.
func _build_embedded_options() -> TentacleEmbeddedOptions:
	var options := TentacleEmbeddedOptions.new()
	var folder := embedded_data_directory.strip_edges()
	if folder.is_empty():
		folder = DEFAULT_EMBEDDED_DATA_DIRECTORY
	options.data_directory = ProjectSettings.globalize_path(folder)
	var made := DirAccess.make_dir_recursive_absolute(options.data_directory)
	if made != OK:
		TentacleLog.warn(
			"could not create the embedded data folder %s (%s); Tentacle will keep nothing "
			% [options.data_directory, error_string(made)]
			+ "between runs"
		)
		options.data_directory = ""
	options.twitch_client_id = twitch_client_id.strip_edges()
	options.kick_client_id = kick_client_id.strip_edges()
	options.kick_sign_in_server_url = kick_sign_in_server_url.strip_edges()
	var configs := config_directory.strip_edges()
	options.config_files = TclConfigFiles.read(DEFAULT_CONFIG_DIRECTORY if configs.is_empty() else configs)
	options.custom_permissions = custom_permissions
	options.twitch_required_permissions = twitch_required_permissions
	options.twitch_optional_permissions = twitch_optional_permissions
	options.kick_required_permissions = kick_required_permissions
	options.kick_optional_permissions = kick_optional_permissions
	return options


## Builds the handshake identity from what only the engine can tell: its version, the
## project's name, and whether this is an editor run.
func _build_identity() -> TentacleEngineIdentity:
	var identity := TentacleEngineIdentity.new()
	identity.engine = "godot"
	identity.engine_version = str(Engine.get_version_info().get("string", ""))
	identity.plugin_version = TentacleVersion.PLUGIN
	identity.instance_id = _instance_id

	var label := session_label.strip_edges()
	if label.is_empty():
		label = str(ProjectSettings.get_setting("application/config/name", ""))
		# An editor marker, so a game run from the editor is distinguishable from an
		# exported build in Tentacle's Engines list. Matches what the other plugins
		# append.
		if OS.has_feature("editor"):
			label += " (editor)"
	identity.label = label
	return identity


## An id unique to this process.
##
## Must differ between two processes running the same project: custom controls are
## scoped to the session that registered them, so without a distinct id Tentacle
## cannot tell an editor run's controls from an exported build's.
func _build_instance_id() -> String:
	return "%x-%x" % [Time.get_ticks_usec(), randi()]


## True when this node is installed as one of the project's autoloads - a direct child
## of the root under a name Project Settings lists as one - which is the one runtime that
## reads its settings from Project Settings.
func _is_project_autoload() -> bool:
	if not is_inside_tree() or get_parent() != get_tree().root:
		return false
	return ProjectSettings.has_setting("autoload/" + String(name))
