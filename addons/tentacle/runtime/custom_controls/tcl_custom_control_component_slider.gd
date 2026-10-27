@icon("res://addons/tentacle/icons/control.svg")
class_name TclCustomControlComponent_Slider
extends TclCustomControlComponent

## A slider in Tentacle's panel.
##
## Carries exactly the same fields as [TclCustomControlComponent_Number]; the difference is
## how the streamer drives the value, a track against a spinner field.
##
## For a slider you usually want [signal OnValueCommittedFromApp], so the game reacts
## once rather than on every pixel of the drag. Use
## [signal OnValueChangedFromApp] when you want live feedback.

## The streamer is dragging. Fires continuously, with the value it replaced.
signal OnValueChangedFromApp(new_value: float, old_value: float)

## The streamer let go. Fires once.
signal OnValueCommittedFromApp(new_value: float)

## The current value.
@export var value: float = 0.0:
	set(new_value):
		value = new_value
		_send_state()

## The value at the left end of the track.
@export var min_value: float = 0.0:
	set(new_value):
		min_value = new_value
		_send_state()

## The value at the right end of the track.
@export var max_value: float = 1.0:
	set(new_value):
		max_value = new_value
		_send_state()

## The increment the track snaps to.
@export var step: float = 0.01:
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


## Whether to accept a value Tentacle sent. Override to clamp or veto.
##
## Returning false leaves **both** this node and Tentacle's copy of the control as they
## were, so the next push cannot send the value you just rejected. To clamp instead,
## call [method set_value] with the value you want and return false.
@warning_ignore("unused_parameter")
func _should_receive_value_float(new_value: float) -> bool:
	return true


func _create_control() -> TclCustomControl:
	return TclCustomControl_Slider.new()


func _accepts_value_from_app(control: TclCustomControl) -> bool:
	return _should_receive_value_float((control as TclCustomControl_Slider).value)


func _write_value(control: TclCustomControl) -> void:
	var slider := control as TclCustomControl_Slider
	slider.value = value
	slider.min = min_value
	slider.max = max_value
	slider.step = step


func _read_value(control: TclCustomControl, committed: bool) -> void:
	var old := value
	value = (control as TclCustomControl_Slider).value
	if committed:
		OnValueCommittedFromApp.emit(value)
	else:
		OnValueChangedFromApp.emit(value, old)
