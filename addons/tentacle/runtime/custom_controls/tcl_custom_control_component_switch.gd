@icon("res://addons/tentacle/icons/control.svg")
class_name TclCustomControlComponent_Switch
extends TclCustomControlComponent

## An on/off switch in Tentacle's panel.
##
## A switch has no drag to follow, so [signal OnValueChangedFromApp] and
## [signal OnValueCommittedFromApp] both fire when it is flipped. Connect whichever
## reads better; they carry the same value.

## The switch was flipped, with the value it replaced.
signal OnValueChangedFromApp(new_value: bool, old_value: bool)

## The switch was flipped.
signal OnValueCommittedFromApp(new_value: bool)

## Whether the switch is on.
@export var value: bool = false:
	set(new_value):
		value = new_value
		_send_state()


## Sets the value **and** pushes it to Tentacle. Never two calls.
func set_value(new_value: bool) -> void:
	value = new_value


## Whether to accept a flip Tentacle sent. Override to veto.
##
## Returning false leaves **both** this node and Tentacle's copy of the control as they
## were, so the next push cannot send the value you just rejected.
@warning_ignore("unused_parameter")
func _should_receive_value_bool(new_value: bool) -> bool:
	return true


func _create_control() -> TclCustomControl:
	return TclCustomControl_Switch.new()


func _accepts_value_from_app(control: TclCustomControl) -> bool:
	return _should_receive_value_bool((control as TclCustomControl_Switch).value)


func _write_value(control: TclCustomControl) -> void:
	(control as TclCustomControl_Switch).value = value


func _read_value(control: TclCustomControl, committed: bool) -> void:
	var old := value
	value = (control as TclCustomControl_Switch).value
	if committed:
		OnValueCommittedFromApp.emit(value)
	else:
		OnValueChangedFromApp.emit(value, old)
