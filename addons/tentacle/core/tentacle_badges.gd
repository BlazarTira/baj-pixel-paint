class_name TentacleBadges
extends RefCounted

## The badge sets that stand for each role, and the lookups the viewer's and the Twitch
## chat message's badge helpers run over a badge list. Internal: a game reads roles
## through [TclViewer] and [TclChatMessageUtils].

# One reading of a badge list, shared by TclViewer and TclChatMessageUtils, as the Unreal
# plugin shares one between UTclViewer and UTclChatMessageUtils and Unity's TentacleBadges
# does between Viewer and ChatMessageUtils.

## Twitch's broadcaster badge set.
const TWITCH_BROADCASTER: Array[String] = ["broadcaster"]

## Twitch's moderator badge sets. A Lead Moderator wears [code]lead_moderator[/code] in
## place of [code]moderator[/code], unless they chose the plain one.
const TWITCH_MODERATOR: Array[String] = ["moderator", "lead_moderator"]

## Twitch's VIP badge set.
const TWITCH_VIP: Array[String] = ["vip"]

## Twitch's subscriber badge sets: a founder is one of the first.
const TWITCH_SUBSCRIBER: Array[String] = ["subscriber", "founder"]

## Kick's broadcaster badge type.
const KICK_BROADCASTER: Array[String] = ["broadcaster"]

## Kick's moderator badge type.
const KICK_MODERATOR: Array[String] = ["moderator"]

## Kick's VIP badge type.
const KICK_VIP: Array[String] = ["vip"]

## Kick's subscriber badge types: a founder is one of the first.
const KICK_SUBSCRIBER: Array[String] = ["subscriber", "founder"]


## A viewer profile's raw badge list as typed Twitch badges. The generated profile holds
## it untyped, since GDScript has no nullable typed array; null reads as none.
static func twitch_badges_of(raw: Variant) -> Array[TclTwitchChatBadge]:
	var out: Array[TclTwitchChatBadge] = []
	if not raw is Array:
		return out
	for item in raw:
		var badge := TclTwitchChatBadge.parse(item)
		if badge != null:
			out.append(badge)
	return out


## A viewer profile's raw badge list as typed Kick badges; null reads as none.
static func kick_badges_of(raw: Variant) -> Array[TclKickBadge]:
	var out: Array[TclKickBadge] = []
	if not raw is Array:
		return out
	for item in raw:
		var badge := TclKickBadge.parse(item)
		if badge != null:
			out.append(badge)
	return out


## Whether a Twitch badge of one of these sets is in the list.
static func any_twitch(
	badges: Array[TclTwitchChatBadge],
	set_ids: Array[String],
	case_sensitive: bool = true,
) -> bool:
	for badge in badges:
		if badge != null and _matches(badge.set_id, set_ids, case_sensitive):
			return true
	return false


## Whether a Kick badge of one of these types is in the list.
static func any_kick(
	badges: Array[TclKickBadge],
	types: Array[String],
	case_sensitive: bool = true,
) -> bool:
	for badge in badges:
		if badge != null and _matches(badge.type, types, case_sensitive):
			return true
	return false


# The core reads no clock of its own (the layering rule keeps Time out of it), so whoever
# drives it hands one in, as the session's delta is handed in; a test hands in a fixed one.

## The wall clock a timeout's end is compared with: a [Callable] that returns the time now
## in Unix seconds. Internal: [TentacleRuntime] sets it to the system clock.
static var wall_clock: Callable = Callable()


## Whether a ban that ends at [param expires_at] (an ISO time, or null for a ban that lasts
## until lifted) is still in force now. A time that does not read, or no clock to read it
## against, counts as in force, so a ban is never lifted by a typo.
static func is_running(expires_at: Variant) -> bool:
	if expires_at == null or str(expires_at).is_empty():
		return true
	var ends: Variant = unix_seconds_of(str(expires_at))
	if ends == null or not wall_clock.is_valid():
		return true
	return float(ends) > float(wall_clock.call())


## An ISO time's date and time of day ([code]2026-10-06T12:00:00[/code], the start of
## what Tentacle sends) as Unix seconds, or null when it does not read. Fractions of a
## second and the zone are left out, since Tentacle always sends UTC.
static func unix_seconds_of(text: String) -> Variant:
	if text.length() < 19 or text[4] != "-" or text[7] != "-" or text[10] != "T" \
			or text[13] != ":" or text[16] != ":":
		return null
	var parts: Array[String] = [
		text.substr(0, 4), text.substr(5, 2), text.substr(8, 2),
		text.substr(11, 2), text.substr(14, 2), text.substr(17, 2),
	]
	for part in parts:
		if not part.is_valid_int():
			return null
	var year := parts[0].to_int()
	var month := parts[1].to_int()
	var day := parts[2].to_int()
	var hour := parts[3].to_int()
	var minute := parts[4].to_int()
	var second := parts[5].to_int()
	if month < 1 or month > 12 or day < 1 or day > 31 or hour > 23 or minute > 59 or second > 60:
		return null
	return float(_days_from_civil(year, month, day)) * 86400.0 + hour * 3600.0 + minute * 60.0 + second


## Days from 1970-01-01 to a date in the proleptic Gregorian calendar (Howard Hinnant's
## days_from_civil).
static func _days_from_civil(year: int, month: int, day: int) -> int:
	var y := year - 1 if month <= 2 else year
	var era := floori(y / 400.0)
	var year_of_era := y - era * 400
	var shifted_month := month - 3 if month > 2 else month + 9
	var day_of_year := floori((153 * shifted_month + 2) / 5.0) + day - 1
	var day_of_era := year_of_era * 365 + floori(year_of_era / 4.0) - floori(year_of_era / 100.0) + day_of_year
	return era * 146097 + day_of_era - 719468


## Whether an id is one of these, under the caller's case rule.
static func _matches(id: String, wanted: Array[String], case_sensitive: bool) -> bool:
	for candidate in wanted:
		var same: bool = (id == candidate) if case_sensitive else (id.nocasecmp_to(candidate) == 0)
		if same:
			return true
	return false
