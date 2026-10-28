@icon("res://addons/tentacle/icons/tentacle.png")
class_name TclCustomControlComponent_Int
extends TclCustomControlComponent

## A whole-number field in Tentacle's panel.

## The streamer is typing. Fires continuously, with the value it replaced.
signal OnValueChangedFromApp(new_value: int, old_value: int)

## The streamer settled on a number. Fires once.
signal OnValueCommittedFromApp(new_value: int)

## The current value.
@export var value: int = 0:
	set(new_value):
		value = new_value
		_send_state()


## Sets the value **and** pushes it to Tentacle. Never two calls.
func set_value(new_value: int) -> void:
	value = new_value


## Whether to accept a number Tentacle sent. Override to clamp or veto.
##
## Returning false leaves **both** this node and Tentacle's copy of the control as they
## were, so the next push cannot send the number you just rejected. To clamp instead,
## call [method set_value] with the number you want and return false.
@warning_ignore("unused_parameter")
func _should_receive_value_int(new_value: int) -> bool:
	return true


func _create_control() -> TclCustomControl:
	return TclCustomControl_Int.new()


func _accepts_value_from_app(control: TclCustomControl) -> bool:
	return _should_receive_value_int((control as TclCustomControl_Int).value)


func _write_value(control: TclCustomControl) -> void:
	(control as TclCustomControl_Int).value = value


func _read_value(control: TclCustomControl, committed: bool) -> void:
	var old := value
	value = (control as TclCustomControl_Int).value
	if committed:
		OnValueCommittedFromApp.emit(value)
	else:
		OnValueChangedFromApp.emit(value, old)
