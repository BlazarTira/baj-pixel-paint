class_name TentaclePropertyOutcome
extends RefCounted

## The result of one viewer-property read or write, without its value.
##
## The typed subclasses, [TentaclePropertyFloat], [TentaclePropertyInt],
## [TentaclePropertyBool] and [TentaclePropertyString], carry a [code]value[/code] of
## the type you asked for. Check [method is_ok], then read it:
##
## [codeblock]
## var score := viewer.get_property_float("Stats", "Score")
## if score.is_ok():
##     label.text = str(score.value)  # a real float
## [/codeblock]
##
## A read ([code]get_property_*[/code]) answers a [enum TclFindPropertyResult.Value]
## in [member result]; a write ([code]set_property_*[/code],
## [code]add_to_property_*[/code], [code]toggle_property_bool[/code]) answers a
## [enum TclSetPropertyResult.Value]:
##
## [codeblock]
## var written := viewer.set_property_int("Stats", "Level", 3)
## if written.result == TclSetPropertyResult.Value.PROPERTY_NOT_FOUND:
##     push_warning("Define a Level property in Tentacle first")
## [/codeblock]

# Unreal and Unity return the outcome and hand the value back through an out-parameter.
# GDScript has no out-parameters, so the typed subclasses carry a real typed value
# instead - which is better than the alternatives: a Variant return would cost the caller
# the type it already asked for by name, and a Dictionary would cost it autocomplete as
# well.
#
# result is an int rather than either enum because one class carries both: GDScript
# refuses to assign one enum type to a variable of another, and the two enums keep the
# same member order (FOUND / SUCCESS first) precisely so the int reads the same way
# whichever one produced it.

## Which of the three outcomes this was: a [enum TclFindPropertyResult.Value] for a
## read, a [enum TclSetPropertyResult.Value] for a write. Compare it with either enum's
## members.
var result: int = TclFindPropertyResult.Value.FOUND

## True when this outcome answers a write, so [member result] is a
## [enum TclSetPropertyResult.Value] rather than a [enum TclFindPropertyResult.Value].
var is_write: bool = false


## True when the read found the property ([constant TclFindPropertyResult.Value.FOUND]),
## or the write succeeded ([constant TclSetPropertyResult.Value.SUCCESS]).
func is_ok() -> bool:
	if is_write:
		return result == TclSetPropertyResult.Value.SUCCESS
	return result == TclFindPropertyResult.Value.FOUND


## The outcome's name, for logs: "Found" or "Success", "CollectionNotFound" or
## "PropertyNotFound".
func to_text() -> String:
	if is_write:
		return TclSetPropertyResult.to_text(result as TclSetPropertyResult.Value)
	return TclFindPropertyResult.to_text(result as TclFindPropertyResult.Value)
