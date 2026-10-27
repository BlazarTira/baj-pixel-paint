class_name TclSetPropertyResult

## The outcome of writing a viewer property.
##
## A [code]set_property_*[/code], [code]add_to_property_*[/code] or
## [code]toggle_property_bool[/code] call on [TclViewer] answers one of these in its
## outcome's [member TentaclePropertyOutcome.result]. Reads answer a
## [TclFindPropertyResult] instead.
##
## A write never creates a property: a name the streamer has not defined in Tentacle
## answers [constant Value.COLLECTION_NOT_FOUND] or [constant Value.PROPERTY_NOT_FOUND].

# Unreal's ETclSetPropertyResult and Unity's TclSetPropertyResult, member for member, and
# in the same order as TclFindPropertyResult. See tcl_find_property_result.gd for why
# there is no fourth "registry not loaded" member.

enum Value {
	## The value was written. Tentacle is told at once, and the new value reads back
	## straight away.
	SUCCESS,
	## No collection of that name exists.
	COLLECTION_NOT_FOUND,
	## The collection exists, but carries no property of that name.
	PROPERTY_NOT_FOUND,
}


## True for [constant Value.SUCCESS], so a caller can branch without naming it.
static func is_ok(value: Value) -> bool:
	return value == Value.SUCCESS


## A human-readable name, for logs.
static func to_text(value: Value) -> String:
	match value:
		Value.SUCCESS:
			return "Success"
		Value.COLLECTION_NOT_FOUND:
			return "CollectionNotFound"
		Value.PROPERTY_NOT_FOUND:
			return "PropertyNotFound"
	return "Unknown"
