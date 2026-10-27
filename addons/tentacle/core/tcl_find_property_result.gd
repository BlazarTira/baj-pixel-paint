class_name TclFindPropertyResult

## The outcome of reading a viewer property.
##
## A [code]get_property_*[/code] call on [TclViewer] answers one of these in its
## outcome's [member TentaclePropertyOutcome.result]. Writes answer a
## [TclSetPropertyResult] instead.
##
## There are exactly three. A read made before the viewer-property definitions have
## loaded answers [constant Value.COLLECTION_NOT_FOUND]: the definitions are fetched on
## connect, retried on failure, and fetched again on demand, so waiting resolves it. With
## verbose logging on, the addon logs what it could not resolve.

# Unreal's ETclFindPropertyResult and Unity's TclFindPropertyResult, member for member,
# and in the same order as TclSetPropertyResult, so the one outcome class can carry
# either and is_ok() reads the same way for both.
#
# Exactly three members, and a fourth was deliberately rejected. "The registry has not
# loaded" was briefly a fourth member on the Unreal and Unity plugins and was removed
# from both: the state resolves itself, so a game has nothing to do about it that waiting
# would not also do, and a fourth outcome puts a branch in every graph for a case that
# goes away.
#
# The general rule that settled it: an error a game can act on gets an outcome; an error
# only a developer can act on gets a log line. A registry that has not loaded logs what
# could not resolve, asks for the load, and answers COLLECTION_NOT_FOUND.

enum Value {
	## The property was found.
	FOUND,
	## No collection of that name exists.
	COLLECTION_NOT_FOUND,
	## The collection exists, but carries no property of that name.
	PROPERTY_NOT_FOUND,
}


## True for [constant Value.FOUND], so a caller can branch without naming it.
static func is_ok(value: Value) -> bool:
	return value == Value.FOUND


## A human-readable name, for logs.
static func to_text(value: Value) -> String:
	match value:
		Value.FOUND:
			return "Found"
		Value.COLLECTION_NOT_FOUND:
			return "CollectionNotFound"
		Value.PROPERTY_NOT_FOUND:
			return "PropertyNotFound"
	return "Unknown"
