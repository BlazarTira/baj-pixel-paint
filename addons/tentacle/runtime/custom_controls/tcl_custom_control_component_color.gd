@icon("res://addons/tentacle/icons/tentacle.png")
class_name TclCustomControlComponent_Color
extends TclCustomControlComponent

## A colour picker in Tentacle's panel.
##
## [member value] is a real [Color], not the hex string the wire carries: the
## conversion happens at this boundary, so a game assigns it straight to a node. That
## is the rule for every value type - the engine's own [Color], [Vector3] and so on,
## never the wire's encoding.

## The streamer is dragging in the picker. Fires continuously, with the value it
## replaced.
signal OnValueChangedFromApp(new_value: Color, old_value: Color)

## The streamer settled on a colour. Fires once.
signal OnValueCommittedFromApp(new_value: Color)

## The current colour.
@export var value: Color = Color.WHITE:
	set(new_value):
		value = new_value
		_send_state()


## Sets the colour **and** pushes it to Tentacle. Never two calls.
func set_value(new_value: Color) -> void:
	value = new_value


## Whether to accept a colour Tentacle sent. Override to clamp or veto.
##
## Returning false leaves **both** this node and Tentacle's copy of the control as they
## were, so the next push cannot send the colour you just rejected. To clamp instead,
## call [method set_value] with the colour you want and return false.
@warning_ignore("unused_parameter")
func _should_receive_value_color(new_value: Color) -> bool:
	return true


func _create_control() -> TclCustomControl:
	return TclCustomControl_Color.new()


func _accepts_value_from_app(control: TclCustomControl) -> bool:
	var hex := (control as TclCustomControl_Color).value
	# A colour the engine cannot read is refused like a vetoed one, so the wire copy is
	# put back rather than left holding something this node never showed.
	if not Color.html_is_valid(hex):
		return false
	return _should_receive_value_color(Color.html(hex))


func _write_value(control: TclCustomControl) -> void:
	# Tentacle's colour format is "#RRGGBB"; Godot's to_html() adds alpha unless told
	# not to, and the app does not read it.
	(control as TclCustomControl_Color).value = "#" + value.to_html(false)


func _read_value(control: TclCustomControl, committed: bool) -> void:
	var hex := (control as TclCustomControl_Color).value
	if not Color.html_is_valid(hex):
		return
	var old := value
	# The setter runs, but the base has set _applying_from_app, so this does not push
	# the value straight back to Tentacle as if the game had set it.
	value = Color.html(hex)
	if committed:
		OnValueCommittedFromApp.emit(value)
	else:
		OnValueChangedFromApp.emit(value, old)
