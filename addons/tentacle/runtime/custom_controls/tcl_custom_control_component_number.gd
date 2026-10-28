@icon("res://addons/tentacle/icons/tentacle.png")
class_name TclCustomControlComponent_Number
extends TclCustomControlComponent

## A number field in Tentacle's panel, with an optional range.
##
## **Number carries the same range as Slider** - [member min_value],
## [member max_value] and [member step]. The difference between the two is how the
## streamer drives the value, a spinner field against a track, not what the game can
## constrain.

# That Number carries a range is a settled decision (see .docs/PLUGIN-INTERFACE.md)
# rather than an oversight either way.

## The streamer is typing. Fires continuously, with the value it replaced.
signal OnValueChangedFromApp(new_value: float, old_value: float)

## The streamer settled on a number. Fires once.
signal OnValueCommittedFromApp(new_value: float)

## The current value.
@export var value: float = 0.0:
	set(new_value):
		value = new_value
		_send_state()

## The lowest value the streamer may set.
@export var min_value: float = 0.0:
	set(new_value):
		min_value = new_value
		_send_state()

## The highest value the streamer may set.
@export var max_value: float = 100.0:
	set(new_value):
		max_value = new_value
		_send_state()

## The increment the field steps by.
@export var step: float = 1.0:
	set(new_value):
		step = new_value
		_send_state()


## Sets the value **and** pushes it to Tentacle. Never two calls.
func set_value(new_value: float) -> void:
	value = new_value


## Sets the whole range in one push, rather than three.
func set_range(new_min: float, new_max: float, new_step: float) -> void:
	min_value = new_min
	max_value = new_max
	step = new_step


## Whether to accept a number Tentacle sent. Override to clamp or veto.
##
## Returning false leaves **both** this node and Tentacle's copy of the control as they
## were, so the next push cannot send the number you just rejected. To clamp instead,
## call [method set_value] with the number you want and return false.
@warning_ignore("unused_parameter")
func _should_receive_value_float(new_value: float) -> bool:
	return true


func _create_control() -> TclCustomControl:
	return TclCustomControl_Number.new()


func _accepts_value_from_app(control: TclCustomControl) -> bool:
	return _should_receive_value_float((control as TclCustomControl_Number).value)


func _write_value(control: TclCustomControl) -> void:
	var number := control as TclCustomControl_Number
	number.value = value
	number.min = min_value
	number.max = max_value
	number.step = step


func _read_value(control: TclCustomControl, committed: bool) -> void:
	var old := value
	value = (control as TclCustomControl_Number).value
	if committed:
		OnValueCommittedFromApp.emit(value)
	else:
		OnValueChangedFromApp.emit(value, old)
