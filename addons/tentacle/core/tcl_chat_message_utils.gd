class_name TclChatMessageUtils
extends RefCounted

## Counting emojis and emotes on a chat message, turning an emoji into its code points,
## naming its image file in the open emoji image sets, and reading the roles a Twitch chat
## message's badges stand for.
##
## Lookups run against the cross-platform [TclStreamEvent_Anywhere_ChatMessage], match
## on the name a message keys each emoji or emote by, and ignore case unless asked
## otherwise. A null message counts as zero.
##
## [codeblock]
## func _on_chat_message(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer) -> void:
##     var hearts := TclChatMessageUtils.get_emoji_count_containing(chat_message, "heart")
##     if hearts > 0:
##         _float_hearts(viewer, hearts)
## [/codeblock]
##
## All members are static.

# Unreal's UTclChatMessageUtils and Unity's TclChatMessageUtils, with the same semantics.
# Unity writes these as C# extension methods; GDScript has none, so they are static
# functions taking the message first, as Unreal's Blueprint library does. Godot strings
# hold whole code points, so there are no surrogate pairs to recombine.


## How many times one emoji appears, by name. Zero when the message does not carry it.
##
## The plain name ([code]thumbs_up[/code]) counts every skin tone of that emoji, and so
## does any of its aliases ([code]+1[/code]); a tone-qualified key
## ([code]thumbs_up-light[/code]) counts just that one tone.
static func get_emoji_count(
	chat_message: TclStreamEvent_Anywhere_ChatMessage,
	name: String,
	case_sensitive: bool = false,
) -> int:
	if chat_message == null:
		return 0
	# Matching the key counts one tone; matching the name or an alias covers every
	# tone of the emoji.
	var total := 0
	for key in chat_message.emojis:
		var emoji := chat_message.emojis[key]
		if emoji == null:
			continue
		if (
			_matches(key, name, case_sensitive)
			or _matches(emoji.name, name, case_sensitive)
			or _matches_any(emoji.aliases, name, case_sensitive)
		):
			total += emoji.count
	return total


## How many times one emote appears, by name. Zero when the message does not carry it.
static func get_emote_count(
	chat_message: TclStreamEvent_Anywhere_ChatMessage,
	name: String,
	case_sensitive: bool = false,
) -> int:
	if chat_message == null:
		return 0
	for key in chat_message.emotes:
		var emote := chat_message.emotes[key]
		if emote != null and _matches(key, name, case_sensitive):
			return emote.count
	return 0


## The total count of every emoji whose name contains [param substring].
static func get_emoji_count_containing(
	chat_message: TclStreamEvent_Anywhere_ChatMessage,
	substring: String,
	case_sensitive: bool = false,
) -> int:
	if chat_message == null:
		return 0
	var total := 0
	for key in chat_message.emojis:
		var emoji := chat_message.emojis[key]
		if emoji != null and _contains(key, substring, case_sensitive):
			total += emoji.count
	return total


## The total count of every emote whose name contains [param substring].
static func get_emote_count_containing(
	chat_message: TclStreamEvent_Anywhere_ChatMessage,
	substring: String,
	case_sensitive: bool = false,
) -> int:
	if chat_message == null:
		return 0
	var total := 0
	for key in chat_message.emotes:
		var emote := chat_message.emotes[key]
		if emote != null and _contains(key, substring, case_sensitive):
			total += emote.count
	return total


## True when the message carries at least one emoji.
static func has_emojis(chat_message: TclStreamEvent_Anywhere_ChatMessage) -> bool:
	return chat_message != null and not chat_message.emojis.is_empty()


## True when the message carries at least one emote.
static func has_emotes(chat_message: TclStreamEvent_Anywhere_ChatMessage) -> bool:
	return chat_message != null and not chat_message.emotes.is_empty()


## Whether a Twitch chat message wears a badge of this set, such as [code]bits[/code].
## Ignores case unless asked not to. False for a null message.
static func has_badge_twitch(
	chat_message: TclStreamEvent_Twitch_ChatMessage,
	set_id: String,
	case_sensitive: bool = false,
) -> bool:
	return chat_message != null and TentacleBadges.any_twitch(chat_message.badges, [set_id], case_sensitive)


## Whether a Twitch chat message is the broadcaster's.
static func is_broadcaster_twitch(chat_message: TclStreamEvent_Twitch_ChatMessage) -> bool:
	return chat_message != null and TentacleBadges.any_twitch(chat_message.badges, TentacleBadges.TWITCH_BROADCASTER)


## Whether a Twitch chat message is a moderator's, Lead Moderators included.
static func is_moderator_twitch(chat_message: TclStreamEvent_Twitch_ChatMessage) -> bool:
	return chat_message != null and TentacleBadges.any_twitch(chat_message.badges, TentacleBadges.TWITCH_MODERATOR)


## Whether a Twitch chat message is a VIP's.
static func is_vip_twitch(chat_message: TclStreamEvent_Twitch_ChatMessage) -> bool:
	return chat_message != null and TentacleBadges.any_twitch(chat_message.badges, TentacleBadges.TWITCH_VIP)


## Whether a Twitch chat message wears the subscriber or founder badge.
static func is_subscriber_twitch(chat_message: TclStreamEvent_Twitch_ChatMessage) -> bool:
	return chat_message != null and TentacleBadges.any_twitch(chat_message.badges, TentacleBadges.TWITCH_SUBSCRIBER)


## The Unicode code points of an emoji, formatted [code]"U+1F600"[/code]: uppercase
## hex, at least four digits, with the [code]U+[/code] prefix. Empty for an empty
## string.
##
## An emoji made of several code points - a skin tone, a flag, a family - yields every
## one of them, in order.
static func get_emoji_code_points(emoji: String) -> Array[String]:
	var out: Array[String] = []
	for index in emoji.length():
		out.append("U+%04X" % emoji.unicode_at(index))
	return out


## The Unicode code points of an emoji, formatted [code]"1f600"[/code]: lowercase hex,
## at least four digits, no prefix. Empty for an empty string. To name an emoji's image
## file, use [method get_emoji_image_file_name], which follows each image set's own
## naming rules.
static func get_emoji_hex_values(emoji: String) -> Array[String]:
	var out: Array[String] = []
	for index in emoji.length():
		out.append("%04x" % emoji.unicode_at(index))
	return out


# The same rules as tentacle-web's src/emoji.ts and the Unreal and Unity plugins, held
# together by the same table of cases in each one's tests.

## VARIATION SELECTOR-16, which asks for the colour emoji rather than the text glyph.
const _VARIATION_SELECTOR := 0xFE0F

## ZERO WIDTH JOINER, which welds several emoji into one.
const _ZERO_WIDTH_JOINER := 0x200D

## The first regional indicator letter, A, which country flags are spelled with.
const _REGIONAL_INDICATOR_A := 0x1F1E6

## The last regional indicator letter, Z.
const _REGIONAL_INDICATOR_Z := 0x1F1FF

## WAVING BLACK FLAG, the base of a subdivision flag such as England's.
const _BLACK_FLAG := 0x1F3F4

## CANCEL TAG, which ends the tag letters a subdivision flag is spelled with.
const _CANCEL_TAG := 0xE007F

## How far a tag character sits above the ASCII character it stands for.
const _TAG_OFFSET := 0xE0000

# Twemoji files one emoji against its own rule: eye in speech bubble keeps no variation
# selector even though it has a joiner. It is the only one in Emoji 18.0, checked
# against every file Twemoji v17.0.3 ships.
const _TWEMOJI_EYE_IN_SPEECH_BUBBLE: Array[int] = [0x1F441, 0xFE0F, 0x200D, 0x1F5E8, 0xFE0F]

# The folder each set's PNG images are in, pinned to a release so the address cannot move
# under a game. Noto's are Google's own Noto CDN, by emoji version, where flags are drawn
# as emoji at every size; the others are the set's GitHub release on jsDelivr.
# tentacle-web's tests/emoji-urls.test.ts requests real images from each, at every size,
# and fails when these differ from its own.
const _NOTO_FOLDER := "https://fonts.gstatic.com/s/e/notoemoji/18.0/"
const _TWEMOJI_FOLDER := "https://cdn.jsdelivr.net/gh/jdecked/twemoji@v17.0.3/assets/"
const _OPEN_MOJI_FOLDER := "https://cdn.jsdelivr.net/gh/hfg-gmuend/openmoji@17.0.0/color/"

# The sizes, in pixels, each set ships its PNG images in, smallest first.
const _NOTO_SIZES: Array[int] = [32, 72, 128, 512]
const _TWEMOJI_SIZES: Array[int] = [72]
const _OPEN_MOJI_SIZES: Array[int] = [72, 618]


## The file name of an emoji's PNG image in a copy of one of the open emoji image sets
## you ship or host yourself: [code]emoji_u2764.png[/code] in Noto's own download,
## [code]2764.png[/code] in Twemoji and OpenMoji.
##
## Each set names its files its own way, down to how it treats the invisible variation
## selector, so the name comes from here rather than from the code points joined
## together. Noto's download names flags by region code ([code]US.png[/code],
## [code]GB-ENG.png[/code]) and keeps them in a folder of their own. To load an image
## straight from the set, use [method get_emoji_image_url]. Empty for a null emoji, or one
## with no code points.
static func get_emoji_image_file_name(emoji: TclChatMessageEmoji, image_set: TclEmojiImageSet.Value) -> String:
	if emoji == null:
		return ""
	var values := _parse_code_points(emoji.code_points)
	if values.is_empty():
		return ""

	match image_set:
		TclEmojiImageSet.Value.NOTO:
			return _noto_file_name(values)
		TclEmojiImageSet.Value.TWEMOJI:
			return _twemoji_file_name(values)
		TclEmojiImageSet.Value.OPEN_MOJI:
			return _open_moji_file_name(values)
	return ""


## The address of an emoji's PNG image in one of the open emoji image sets.
##
## [param size] asks for an image at least that many pixels across: the address is for
## the smallest size the set ships that is as big, or its largest when none is. Noto
## ships 32, 72, 128, and 512 pixels, Twemoji 72, and OpenMoji 72 and 618.
##
## Noto's images come from Google's own Noto CDN, the rest from the set's release on
## jsDelivr. Each address names a release of the set, so it does not move. A set may not
## have drawn the newest emoji yet, so treat an image that fails to download as normal.
## Empty for a null emoji, or one with no code points.
static func get_emoji_image_url(
	emoji: TclChatMessageEmoji, image_set: TclEmojiImageSet.Value, size: int = 512
) -> String:
	if emoji == null:
		return ""
	var values := _parse_code_points(emoji.code_points)
	if values.is_empty():
		return ""

	match image_set:
		TclEmojiImageSet.Value.NOTO:
			return "%s%s/%d.png" % [_NOTO_FOLDER, _noto_sequence_name(values), _image_size_for(_NOTO_SIZES, size)]
		TclEmojiImageSet.Value.TWEMOJI:
			var pixels := _image_size_for(_TWEMOJI_SIZES, size)
			return "%s%dx%d/%s" % [_TWEMOJI_FOLDER, pixels, pixels, _twemoji_file_name(values)]
		TclEmojiImageSet.Value.OPEN_MOJI:
			var pixels := _image_size_for(_OPEN_MOJI_SIZES, size)
			return "%s%dx%d/%s" % [_OPEN_MOJI_FOLDER, pixels, pixels, _open_moji_file_name(values)]
	return ""


## The smallest of a set's sizes that is at least [param size] pixels, or its largest when
## none is.
static func _image_size_for(sizes: Array[int], size: int) -> int:
	for available in sizes:
		if available >= size:
			return available
	return sizes[-1]


## Reads hex code points into their values. Empty when there are none, or one is not
## written in hex.
static func _parse_code_points(code_points: Array[String]) -> Array[int]:
	var values: Array[int] = []
	for code_point in code_points:
		if code_point.is_empty() or code_point.length() > 6 or not code_point.is_valid_hex_number(false):
			return [] as Array[int]
		values.append(code_point.hex_to_int())
	return values


## The two letters a country flag spells ([code]"US"[/code]), or empty when the emoji is
## not one.
static func _country_flag_letters(values: Array[int]) -> String:
	if values.size() != 2:
		return ""
	var letters := ""
	for value in values:
		if value < _REGIONAL_INDICATOR_A or value > _REGIONAL_INDICATOR_Z:
			return ""
		letters += String.chr("A".unicode_at(0) + value - _REGIONAL_INDICATOR_A)
	return letters


## The region and subdivision a subdivision flag spells ([code]"GB-ENG"[/code]), or empty
## when the emoji is not one.
static func _subdivision_flag_code(values: Array[int]) -> String:
	if values.size() < 3 or values[0] != _BLACK_FLAG or values[-1] != _CANCEL_TAG:
		return ""
	var letters := ""
	for index in range(1, values.size() - 1):
		letters += String.chr(values[index] - _TAG_OFFSET)
	letters = letters.to_upper()
	return "%s-%s" % [letters.left(2), letters.substr(2)]


## How Noto names an emoji: its code points in lowercase, joined with underscores, with
## every variation selector dropped ([code]2764_200d_1f525[/code]).
static func _noto_sequence_name(values: Array[int]) -> String:
	var parts := PackedStringArray()
	for value in values:
		if value != _VARIATION_SELECTOR:
			parts.append("%04x" % value)
	return "_".join(parts)


## The name of a file in Noto's own download: [code]emoji_u[/code] and the emoji's Noto
## name. Flags are the exception: the download keeps them apart, named by region code.
static func _noto_file_name(values: Array[int]) -> String:
	var flag := _country_flag_letters(values)
	if flag.is_empty():
		flag = _subdivision_flag_code(values)
	if not flag.is_empty():
		return flag + ".png"
	return "emoji_u" + _noto_sequence_name(values) + ".png"


## Twemoji's name: the code points in lowercase without leading zeros, joined with
## hyphens, with the variation selector dropped unless the emoji has a joiner.
static func _twemoji_file_name(values: Array[int]) -> String:
	var keep_selector := values.has(_ZERO_WIDTH_JOINER) and values != _TWEMOJI_EYE_IN_SPEECH_BUBBLE
	var parts := PackedStringArray()
	for value in values:
		if keep_selector or value != _VARIATION_SELECTOR:
			parts.append("%x" % value)
	return "-".join(parts) + ".png"


## OpenMoji's name: the code points in uppercase, joined with hyphens, with the
## variation selector dropped only from an emoji that is one character and the selector.
static func _open_moji_file_name(values: Array[int]) -> String:
	var kept := 1 if values.size() == 2 and values[1] == _VARIATION_SELECTOR else values.size()
	var parts := PackedStringArray()
	for index in kept:
		parts.append("%04X" % values[index])
	return "-".join(parts) + ".png"


## Compares two names under the caller's case rule.
static func _matches(key: String, name: String, case_sensitive: bool) -> bool:
	if case_sensitive:
		return key == name
	return key.nocasecmp_to(name) == 0


## Whether any of an emoji's other names matches.
static func _matches_any(names: Array[String], name: String, case_sensitive: bool) -> bool:
	for candidate in names:
		if _matches(candidate, name, case_sensitive):
			return true
	return false


## Substring test under the caller's case rule.
static func _contains(key: String, substring: String, case_sensitive: bool) -> bool:
	if case_sensitive:
		return key.contains(substring)
	return key.containsn(substring)
