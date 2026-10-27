class_name TclViewer
extends RefCounted

## A viewer, as the game sees them.
##
## The distinction from the generated [TclViewerData] is **identity**. A payload is
## a snapshot that arrives with an event and is replaced by the next one; this is a
## stable object per viewer id that a game can hold on a spawned node for as long as
## it likes, and that keeps pointing at the freshest data. Without it, a game that
## spawns an actor per chatter gets a fresh, unrelated object on that chatter's next
## message, property writes land on an orphan, and nothing accumulates.
##
## That is also why [Tentacle_Viewers] never evicts: a game holding one of these
## would otherwise stop receiving updates with nothing to indicate why.
##
## **Property reads and writes hang off the viewer**, because that is how a game
## thinks about them - "this viewer's score", not "the property service's opinion
## about this viewer".

# Unreal's UTclViewer and Unity's TclViewer. Unity needs C# extension methods to put the
# property calls on the viewer; here the methods simply live on the class.

## The raw payload, for fields the accessors below do not cover.
var data: TclViewerData = null

## A game-owned flag marking this viewer as the host. Not wire state: nothing in
## Tentacle sets it, and nothing resets it when fresh data arrives.
var is_host: bool = false

## The viewer's Tentacle id, stable for the life of this object.
var viewer_id: String:
	get:
		return data.id if data != null else ""

## The login name: Twitch's, else Kick's, else a placeholder built from the id.
var user_name: String:
	get:
		if data == null:
			return ""
		if data.twitch != null and not data.twitch.name.is_empty():
			return data.twitch.name
		if data.kick != null and not data.kick.username.is_empty():
			return data.kick.username
		# Something readable rather than an empty label: a game putting this above
		# a spawned character should never show a blank nameplate.
		return "Viewer " + data.id

## The name to show: Twitch's display name, else the login name.
var display_name: String:
	get:
		if data != null and data.twitch != null and not data.twitch.display_name.is_empty():
			return data.twitch.display_name
		return user_name

## The chat colour as a hex string. Twitch's, then Kick's, then white.
var color_hex: String:
	get:
		if data == null:
			return DEFAULT_COLOR_HEX
		if data.twitch != null:
			var twitch_color := TclJson.as_string(data.twitch.color)
			if not twitch_color.is_empty():
				return twitch_color
		if data.kick != null:
			var kick_color := TclJson.as_string(data.kick.color)
			if not kick_color.is_empty():
				return kick_color
		return DEFAULT_COLOR_HEX

## The chat colour, ready to assign to a node.
var color: Color:
	get:
		var hex := color_hex
		# Anything the platform sends that is not a hex colour falls back to white
		# rather than to Godot's default black, which would be indistinguishable
		# from a deliberately black name.
		if not Color.html_is_valid(hex):
			return Color.WHITE
		return Color.html(hex)

## True for a simulated viewer, which has no row in Tentacle's database.
var is_mock: bool:
	get:
		return TclJson.as_bool(data.is_mock) if data != null else false

## When Tentacle first saw this viewer.
var created_at: String:
	get:
		return data.created_at if data != null else ""

## When Tentacle last updated this viewer.
var updated_at: String:
	get:
		return data.updated_at if data != null else ""

## The raw Twitch profile, or null when this viewer has none.
var twitch: TclViewerTwitch:
	get:
		return data.twitch if data != null else null

## The raw Kick profile, or null when this viewer has none.
var kick: TclViewerKick:
	get:
		return data.kick if data != null else null

## The viewer's standing in the streamer's Twitch channel, as Tentacle last learned it from
## Twitch: roles, subscription, follow, ban, and bits. Null when they have no Twitch profile,
## or the Tentacle that sent them predates it.
var standing_twitch: TclTwitchViewerStanding:
	get:
		return twitch.standing if twitch != null else null

## The badges the viewer last wore in the streamer's Twitch chat. Twitch has no way to ask
## for someone's badges, so these are only as current as their last chat message; for their
## roles, use [member is_moderator_twitch] and its siblings, which ask Twitch. Empty when
## they have none, have no Twitch profile, or have not chatted yet.
var badges_twitch: Array[TclTwitchChatBadge]:
	get:
		return TentacleBadges.twitch_badges_of(twitch.badges if twitch != null else null)

## Whether the viewer is the streamer, on Twitch.
var is_broadcaster_twitch: bool:
	get:
		var standing := standing_twitch
		if standing != null:
			return standing.is_broadcaster
		return TentacleBadges.any_twitch(badges_twitch, TentacleBadges.TWITCH_BROADCASTER)

## Whether the viewer moderates the streamer's Twitch channel, Lead Moderators included.
## Tentacle asks Twitch rather than waiting for them to chat. The broadcaster is not a
## moderator; ask [member is_broadcaster_twitch] as well.
var is_moderator_twitch: bool:
	get:
		var standing := standing_twitch
		if standing != null:
			return standing.is_moderator
		return TentacleBadges.any_twitch(badges_twitch, TentacleBadges.TWITCH_MODERATOR)

## Whether the viewer is a VIP in the streamer's Twitch channel. Tentacle asks Twitch rather
## than waiting for them to chat.
var is_vip_twitch: bool:
	get:
		var standing := standing_twitch
		if standing != null:
			return standing.is_vip
		return TentacleBadges.any_twitch(badges_twitch, TentacleBadges.TWITCH_VIP)

## Whether the viewer subscribes to the streamer on Twitch. Tentacle asks Twitch rather than
## waiting for them to chat.
var is_subscriber_twitch: bool:
	get:
		var standing := standing_twitch
		if standing != null:
			return standing.is_subscriber
		return TentacleBadges.any_twitch(badges_twitch, TentacleBadges.TWITCH_SUBSCRIBER)

## Whether the viewer follows the streamer on Twitch, as of Tentacle's last check with
## Twitch. Twitch says nothing when someone unfollows, so an unfollow shows once Tentacle
## next looks the viewer up, within a day.
var is_follower_twitch: bool:
	get:
		var standing := standing_twitch
		return standing != null and standing.is_follower

## Whether the viewer is banned from the streamer's Twitch chat, or in a timeout that has
## not run out yet.
var is_banned_twitch: bool:
	get:
		var standing := standing_twitch
		if standing == null or standing.ban == null:
			return false
		return TentacleBadges.is_running(standing.ban.expires_at)

## The badges the viewer last wore in the streamer's Kick chat, as of their last chat
## message. Empty when they have none, have no Kick profile, or have not chatted yet.
var badges_kick: Array[TclKickBadge]:
	get:
		return TentacleBadges.kick_badges_of(kick.badges if kick != null else null)

## Whether the viewer wears Kick's broadcaster badge.
var is_broadcaster_kick: bool:
	get:
		return TentacleBadges.any_kick(badges_kick, TentacleBadges.KICK_BROADCASTER)

## Whether the viewer moderates the streamer's Kick chat. The broadcaster is not a
## moderator; ask [member is_broadcaster_kick] as well.
var is_moderator_kick: bool:
	get:
		return TentacleBadges.any_kick(badges_kick, TentacleBadges.KICK_MODERATOR)

## Whether the viewer is a VIP in the streamer's Kick chat.
var is_vip_kick: bool:
	get:
		return TentacleBadges.any_kick(badges_kick, TentacleBadges.KICK_VIP)

## Whether the viewer wears Kick's subscriber or founder badge.
var is_subscriber_kick: bool:
	get:
		return TentacleBadges.any_kick(badges_kick, TentacleBadges.KICK_SUBSCRIBER)

## Whether the viewer is the broadcaster on any platform.
var is_broadcaster: bool:
	get:
		return is_broadcaster_twitch or is_broadcaster_kick

## Whether the viewer moderates the streamer's chat on any platform. The broadcaster is
## not a moderator; ask [member is_broadcaster] as well.
var is_moderator: bool:
	get:
		return is_moderator_twitch or is_moderator_kick

## Whether the viewer is a VIP on any platform.
var is_vip: bool:
	get:
		return is_vip_twitch or is_vip_kick

## Whether the viewer subscribes to the streamer on any platform.
var is_subscriber: bool:
	get:
		return is_subscriber_twitch or is_subscriber_kick

## The colour used when neither platform supplied one.
const DEFAULT_COLOR_HEX: String = "#FFFFFF"

## The registry that resolves a property name to its ids. Injected by the cache.
var _properties: Tentacle_ViewerProperties:
	get:
		return _properties_ref.get_ref() as Tentacle_ViewerProperties if _properties_ref != null else null

# Held weakly: the client holds the registry, and a viewer that held it too would
# close a cycle with anything holding the viewer that the registry reaches - such as a
# game's handler on OnViewerPropertyUpdated that captures the viewer - and keep the
# whole client alive after shutdown. A viewer kept past its client resolves nothing.
var _properties_ref: WeakRef = null

## Entries keyed "collectionId/definitionId".
var _entries: Dictionary[String, TentacleViewerPropertyEntry] = {}


## Points this viewer at the registry it resolves names through.
func bind_registry(properties: Tentacle_ViewerProperties) -> void:
	_properties_ref = weakref(properties) if properties != null else null


## Whether the viewer last wore a Twitch badge of this set, such as [code]bits[/code] or
## [code]hype-train[/code]. Ignores case unless asked not to.
func has_badge_twitch(set_id: String, case_sensitive: bool = false) -> bool:
	return TentacleBadges.any_twitch(badges_twitch, [set_id], case_sensitive)


## Whether the viewer last wore a Kick badge of this type, such as [code]og[/code] or
## [code]sub_gifter[/code]. Ignores case unless asked not to.
func has_badge_kick(type: String, case_sensitive: bool = false) -> bool:
	return TentacleBadges.any_kick(badges_kick, [type], case_sensitive)


## Replaces the payload backing this viewer, folding in its property values.
##
## A value the game wrote and Tentacle has not confirmed is kept: the snapshot may
## predate the write, and letting it win would revert the game's own change.
func apply_data(new_data: TclViewerData) -> void:
	if new_data == null:
		return
	data = new_data

	for collection_id in new_data.properties:
		var by_definition := TclJson.as_dictionary(new_data.properties[collection_id])
		for definition_id in by_definition:
			var incoming := TclViewerPropertyValue.parse(by_definition[definition_id])
			if incoming == null:
				continue
			_apply_incoming(str(collection_id), str(definition_id), incoming)


## Every property value this viewer currently carries.
func properties() -> Array[TentacleViewerPropertyEntry]:
	var out: Array[TentacleViewerPropertyEntry] = []
	for key in _entries:
		out.append(_entries[key])
	return out


## The entry for a collection and definition id, or null.
func find_entry(collection_id: String, definition_id: String) -> TentacleViewerPropertyEntry:
	return _entries.get(_key(collection_id, definition_id), null)


## Puts one value back to its definition's default, after Tentacle confirmed a reset.
##
## Returns whether this viewer held a value for it to reset. A local hold is dropped
## too: the reset is the server's word, and it is newer than any unconfirmed write.
func reset_to_default(collection_id: String, definition_id: String, default_value: Variant) -> bool:
	var entry: TentacleViewerPropertyEntry = _entries.get(_key(collection_id, definition_id), null)
	if entry == null:
		return false
	entry.value = default_value
	entry.is_default = true
	entry.locally_modified = false
	return true


# ============================================================================
# Typed reads
# ============================================================================

## This viewer's value for a float property, by collection and property **name**.
##
## The outcome's [member TentaclePropertyOutcome.result] is a
## [enum TclFindPropertyResult.Value]. Names are matched case-insensitively by default,
## which is what a streamer typing a name into Tentacle expects; pass
## [param case_sensitive] to require an exact match.
func get_property_float(
	collection_name: String,
	property_name: String,
	case_sensitive: bool = false,
) -> TentaclePropertyFloat:
	var out := TentaclePropertyFloat.new()
	var found := _read(collection_name, property_name, case_sensitive)
	out.result = found.result
	if out.is_ok():
		out.value = TclJson.as_float(found.value)
	return out


## This viewer's value for an int property. See [method get_property_float].
func get_property_int(
	collection_name: String,
	property_name: String,
	case_sensitive: bool = false,
) -> TentaclePropertyInt:
	var out := TentaclePropertyInt.new()
	var found := _read(collection_name, property_name, case_sensitive)
	out.result = found.result
	if out.is_ok():
		out.value = TclJson.as_int(found.value)
	return out


## This viewer's value for a bool property. See [method get_property_float].
func get_property_bool(
	collection_name: String,
	property_name: String,
	case_sensitive: bool = false,
) -> TentaclePropertyBool:
	var out := TentaclePropertyBool.new()
	var found := _read(collection_name, property_name, case_sensitive)
	out.result = found.result
	if out.is_ok():
		out.value = TclJson.as_bool(found.value)
	return out


## This viewer's value for a String property. See [method get_property_float].
func get_property_string(
	collection_name: String,
	property_name: String,
	case_sensitive: bool = false,
) -> TentaclePropertyString:
	var out := TentaclePropertyString.new()
	var found := _read(collection_name, property_name, case_sensitive)
	out.result = found.result
	if out.is_ok():
		out.value = TclJson.as_string(found.value)
	return out


## The declared type of a named property, without reading a value.
##
## Returns [constant TclViewerPropertyType.Value.STRING] when the property cannot
## be resolved; check [member TentaclePropertyOutcome.result] on a read if the
## difference matters.
func get_property_type(
	collection_name: String,
	property_name: String,
	case_sensitive: bool = false,
) -> TclViewerPropertyType.Value:
	if _properties == null:
		return TclViewerPropertyType.Value.STRING
	var definition := _properties.find_definition_by_name(collection_name, property_name, case_sensitive)
	if definition == null:
		return TclViewerPropertyType.Value.STRING
	return definition.type


# ============================================================================
# Typed writes
# ============================================================================

## Sets a float property for this viewer.
##
## The outcome's [member TentaclePropertyOutcome.result] is a
## [enum TclSetPropertyResult.Value]. Optimistic: the local value changes at once so
## the next read sees it, and the entry is flagged so a server snapshot taken before
## the write cannot revert it.
func set_property_float(
	collection_name: String,
	property_name: String,
	value: float,
	case_sensitive: bool = false,
) -> TentaclePropertyFloat:
	var out := TentaclePropertyFloat.new()
	out.is_write = true
	out.result = _write(collection_name, property_name, value, case_sensitive)
	if out.is_ok():
		out.value = value
	return out


## Sets an int property for this viewer. See [method set_property_float].
func set_property_int(
	collection_name: String,
	property_name: String,
	value: int,
	case_sensitive: bool = false,
) -> TentaclePropertyInt:
	var out := TentaclePropertyInt.new()
	out.is_write = true
	out.result = _write(collection_name, property_name, value, case_sensitive)
	if out.is_ok():
		out.value = value
	return out


## Sets a bool property for this viewer. See [method set_property_float].
func set_property_bool(
	collection_name: String,
	property_name: String,
	value: bool,
	case_sensitive: bool = false,
) -> TentaclePropertyBool:
	var out := TentaclePropertyBool.new()
	out.is_write = true
	out.result = _write(collection_name, property_name, value, case_sensitive)
	if out.is_ok():
		out.value = value
	return out


## Sets a String property for this viewer. See [method set_property_float].
func set_property_string(
	collection_name: String,
	property_name: String,
	value: String,
	case_sensitive: bool = false,
) -> TentaclePropertyString:
	var out := TentaclePropertyString.new()
	out.is_write = true
	out.result = _write(collection_name, property_name, value, case_sensitive)
	if out.is_ok():
		out.value = value
	return out


## Adds to a float property, reading the current value first.
##
## A write: the outcome's [member TentaclePropertyOutcome.result] is a
## [enum TclSetPropertyResult.Value], and [member TentaclePropertyFloat.value] holds
## the value written.
func add_to_property_float(
	collection_name: String,
	property_name: String,
	delta: float,
	case_sensitive: bool = false,
) -> TentaclePropertyFloat:
	var current := get_property_float(collection_name, property_name, case_sensitive)
	if not current.is_ok():
		var missed := TentaclePropertyFloat.new()
		_answer_miss(missed, current)
		return missed
	return set_property_float(
		collection_name, property_name, current.value + delta, case_sensitive
	)


## Adds to an int property, reading the current value first. See
## [method add_to_property_float].
func add_to_property_int(
	collection_name: String,
	property_name: String,
	delta: int,
	case_sensitive: bool = false,
) -> TentaclePropertyInt:
	var current := get_property_int(collection_name, property_name, case_sensitive)
	if not current.is_ok():
		var missed := TentaclePropertyInt.new()
		_answer_miss(missed, current)
		return missed
	return set_property_int(collection_name, property_name, current.value + delta, case_sensitive)


## Inverts a bool property. A write, like [method add_to_property_float].
func toggle_property_bool(
	collection_name: String,
	property_name: String,
	case_sensitive: bool = false,
) -> TentaclePropertyBool:
	var current := get_property_bool(collection_name, property_name, case_sensitive)
	if not current.is_ok():
		var missed := TentaclePropertyBool.new()
		_answer_miss(missed, current)
		return missed
	return set_property_bool(collection_name, property_name, not current.value, case_sensitive)


# ============================================================================
# Internals
# ============================================================================

## Folds one incoming value onto an entry, respecting an unconfirmed local write.
func _apply_incoming(
	collection_id: String,
	definition_id: String,
	incoming: TclViewerPropertyValue,
) -> void:
	var key := _key(collection_id, definition_id)
	var existing: TentacleViewerPropertyEntry = _entries.get(key, null)

	if existing != null and existing.locally_modified:
		# Tentacle echoing our own value back is the confirmation we were waiting
		# for; anything else is a snapshot that predates the write and must not
		# revert it.
		if _values_equal(existing.value, incoming.value):
			existing.locally_modified = false
			existing.is_default = incoming.is_default
		return

	var entry := existing
	if entry == null:
		entry = TentacleViewerPropertyEntry.new()
		entry.collection_id = collection_id
		entry.definition_id = definition_id
		_entries[key] = entry
	entry.value = incoming.value
	entry.is_default = incoming.is_default
	entry.locally_modified = false

	if _properties != null:
		_properties.notify_value_changed(self, entry)


## Writes a value locally and asks the registry to send it.
func _write(
	collection_name: String,
	property_name: String,
	value: Variant,
	case_sensitive: bool,
) -> TclSetPropertyResult.Value:
	if _properties == null:
		TentacleLog.warn("a viewer property write needs a connected Tentacle session")
		return TclSetPropertyResult.Value.COLLECTION_NOT_FOUND

	var collection := _properties.find_collection_by_name(collection_name, case_sensitive)
	if collection == null:
		_properties.report_unresolved(collection_name, property_name)
		return TclSetPropertyResult.Value.COLLECTION_NOT_FOUND

	var definition := _properties.find_definition_by_name(collection_name, property_name, case_sensitive)
	if definition == null:
		return TclSetPropertyResult.Value.PROPERTY_NOT_FOUND

	var key := _key(collection.id, definition.id)
	var entry: TentacleViewerPropertyEntry = _entries.get(key, null)
	if entry == null:
		entry = TentacleViewerPropertyEntry.new()
		entry.collection_id = collection.id
		entry.definition_id = definition.id
		_entries[key] = entry
	entry.value = value
	entry.is_default = false
	entry.locally_modified = true

	_properties.send_value(self, entry)
	_properties.notify_value_changed(self, entry)
	return TclSetPropertyResult.Value.SUCCESS


## Makes [param missed] the write outcome for a read-modify-write whose read, [param read],
## found nothing to modify: the same miss, answered as a write.
static func _answer_miss(missed: TentaclePropertyOutcome, read: TentaclePropertyOutcome) -> void:
	missed.is_write = true
	match read.result:
		TclFindPropertyResult.Value.PROPERTY_NOT_FOUND:
			missed.result = TclSetPropertyResult.Value.PROPERTY_NOT_FOUND
		_:
			missed.result = TclSetPropertyResult.Value.COLLECTION_NOT_FOUND


# An inner class rather than a second TentacleViewerPropertyEntry with a flag bolted on:
# the typed readers need exactly these two things, and entries are stored state rather
# than return values.
## What one resolution attempt produced: an outcome and, when it succeeded, a value.
class _Read:
	var result: TclFindPropertyResult.Value = TclFindPropertyResult.Value.FOUND
	var value: Variant = null

	static func miss(failed: TclFindPropertyResult.Value) -> _Read:
		var out := _Read.new()
		out.result = failed
		return out

	static func hit(found: Variant) -> _Read:
		var out := _Read.new()
		out.value = found
		return out


## Resolves a name pair to a value, reporting which half was missing.
func _read(collection_name: String, property_name: String, case_sensitive: bool) -> _Read:
	if _properties == null:
		# No session yet. Nothing a game can do about it that waiting would not
		# also do, which is exactly why "registry not loaded" is not an outcome.
		return _Read.miss(TclFindPropertyResult.Value.COLLECTION_NOT_FOUND)

	var collection := _properties.find_collection_by_name(collection_name, case_sensitive)
	if collection == null:
		_properties.report_unresolved(collection_name, property_name)
		return _Read.miss(TclFindPropertyResult.Value.COLLECTION_NOT_FOUND)

	var definition := _properties.find_definition_by_name(collection_name, property_name, case_sensitive)
	if definition == null:
		return _Read.miss(TclFindPropertyResult.Value.PROPERTY_NOT_FOUND)

	var entry := find_entry(collection.id, definition.id)
	if entry == null:
		# The definition exists, so the property does; this viewer simply has no
		# value for it yet, which means the definition's default.
		return _Read.hit(definition.value)

	return _Read.hit(entry.value)


static func _key(collection_id: String, definition_id: String) -> String:
	return collection_id + "/" + definition_id


## True when two property values are the same, for confirming a local write.
static func _values_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		# JSON carries one number type, so an int written and a float echoed back
		# are the same value arriving differently typed.
		if left is float or left is int:
			if right is float or right is int:
				return is_equal_approx(float(left), float(right))
		return false
	return left == right
