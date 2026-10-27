class_name TentacleControlValues

## Reads and writes a custom control's value, whatever its type.
##
## A value of the wrong shape is **refused rather than coerced**, with a warning in the
## log, so Tentacle and your game disagreeing about a control's type shows up there
## instead of reading as zero.
##
## All members are static.

# Much smaller than Unity's equivalent, because the generated types here carry a
# to_dictionary and so serialise themselves - the wire half needs no hand-written writer
# at all, which is what that file mostly is. What is left is folding an inbound value onto
# the typed control, which the generator cannot do: which field a value belongs in depends
# on which variant the control is.

# Read off the generated to_dictionary rather than from a parallel table, so it cannot
# disagree with what is actually sent.
## The wire type discriminator for a control, or "" when it is not a known variant.
static func type_of(control: TclCustomControl) -> String:
	if control == null:
		return ""
	return TclJson.as_string(control.to_dictionary().get("type", ""))


## A control's current value, in the engine's own types, or null for a Button.
static func read_value(control: TclCustomControl) -> Variant:
	if control is TclCustomControl_Color:
		return (control as TclCustomControl_Color).value
	if control is TclCustomControl_Int:
		return (control as TclCustomControl_Int).value
	if control is TclCustomControl_Slider:
		return (control as TclCustomControl_Slider).value
	if control is TclCustomControl_Number:
		return (control as TclCustomControl_Number).value
	if control is TclCustomControl_Select:
		return (control as TclCustomControl_Select).value
	if control is TclCustomControl_Switch:
		return (control as TclCustomControl_Switch).value
	if control is TclCustomControl_Text:
		return (control as TclCustomControl_Text).value
	if control is TclCustomControl_Vector2:
		return (control as TclCustomControl_Vector2).value
	if control is TclCustomControl_Vector3:
		return (control as TclCustomControl_Vector3).value
	if control is TclCustomControl_Vector4:
		return (control as TclCustomControl_Vector4).value
	# A Button carries no value; its events are click and mouse only.
	return null


## Writes an inbound value onto the control it belongs to.
##
## Reports whether anything was applied, so a caller can tell a refused value from
## an accepted one.
static func apply_value(control: TclCustomControl, value: Variant) -> bool:
	if control == null or value == null:
		return false

	# Colour arrives as the hex string the wire carries; the node layer converts it
	# to a Color, which is where the engine's own type belongs.
	if control is TclCustomControl_Color:
		if not value is String:
			return _refuse(control, value, "a string")
		(control as TclCustomControl_Color).value = value
		return true

	if control is TclCustomControl_Int:
		if not _is_number(value):
			return _refuse(control, value, "a number")
		(control as TclCustomControl_Int).value = TclJson.as_int(value)
		return true

	# Slider is checked before Number precisely because the two are otherwise
	# alike: both carry a value and the same min/max/step range.
	if control is TclCustomControl_Slider:
		if not _is_number(value):
			return _refuse(control, value, "a number")
		(control as TclCustomControl_Slider).value = TclJson.as_float(value)
		return true

	if control is TclCustomControl_Number:
		if not _is_number(value):
			return _refuse(control, value, "a number")
		(control as TclCustomControl_Number).value = TclJson.as_float(value)
		return true

	if control is TclCustomControl_Select:
		if not value is String:
			return _refuse(control, value, "a string")
		(control as TclCustomControl_Select).value = value
		return true

	if control is TclCustomControl_Switch:
		if not value is bool:
			return _refuse(control, value, "a boolean")
		(control as TclCustomControl_Switch).value = value
		return true

	if control is TclCustomControl_Text:
		if not value is String:
			return _refuse(control, value, "a string")
		(control as TclCustomControl_Text).value = value
		return true

	if control is TclCustomControl_Vector2:
		var two := _components(value, 2)
		if two.is_empty():
			return _refuse(control, value, "2 numbers")
		(control as TclCustomControl_Vector2).value = Vector2(two[0], two[1])
		return true

	if control is TclCustomControl_Vector3:
		var three := _components(value, 3)
		if three.is_empty():
			return _refuse(control, value, "3 numbers")
		(control as TclCustomControl_Vector3).value = Vector3(three[0], three[1], three[2])
		return true

	if control is TclCustomControl_Vector4:
		var four := _components(value, 4)
		if four.is_empty():
			return _refuse(control, value, "4 numbers")
		(control as TclCustomControl_Vector4).value = Vector4(four[0], four[1], four[2], four[3])
		return true

	return false


## True for a JSON number, which may arrive as either an int or a float.
static func _is_number(value: Variant) -> bool:
	return value is int or value is float


## A fixed-length numeric array, or an empty array when the value is not one.
static func _components(value: Variant, needed: int) -> PackedFloat64Array:
	if not value is Array:
		return PackedFloat64Array()
	var items: Array = value
	if items.size() < needed:
		return PackedFloat64Array()
	var out := PackedFloat64Array()
	for index in needed:
		if not _is_number(items[index]):
			return PackedFloat64Array()
		out.append(TclJson.as_float(items[index]))
	return out


## Logs a refused value and reports failure, so callers stay one-liners.
static func _refuse(control: TclCustomControl, value: Variant, expected: String) -> bool:
	TentacleLog.warn(
		'ignoring a value for control "%s"; expected %s but got %s'
		% [control.id, expected, type_string(typeof(value))]
	)
	return false
