@icon("res://addons/tentacle/icons/control.svg")
class_name TclCustomControlComponent_Vector2
extends TclCustomControlComponent

## A 2-component vector in Tentacle's panel.
##
## [member value] is a real [Vector2], not the numeric array the wire carries: the
## conversion happens at this boundary, so a game assigns it straight to a node's
## position or scale.

## The streamer is dragging a component. Fires continuously, with the value it
## replaced.
signal OnValueChangedFromApp(new_value: Vector2, old_value: Vector2)

## The streamer settled on a value. Fires once.
signal OnValueCommittedFromApp(new_value: Vector2)

## The current value.
@export var value: Vector2 = Vector2.ZERO:
	set(new_value):
		value = new_value
		_send_state()


## Sets the value **and** pushes it to Tentacle. Never two calls.
func set_value(new_value: Vector2) -> void:
	value = new_value


## Whether to accept a vector Tentacle sent. Override to clamp or veto.
##
## Returning false leaves **both** this node and Tentacle's copy of the control as they
## were, so the next push cannot send the vector you just rejected. To clamp instead,
## call [method set_value] with the vector you want and return false.
@warning_ignore("unused_parameter")
func _should_receive_value_vector2(new_value: Vector2) -> bool:
	return true


func _create_control() -> TclCustomControl:
	return TclCustomControl_Vector2.new()


func _accepts_value_from_app(control: TclCustomControl) -> bool:
	return _should_receive_value_vector2((control as TclCustomControl_Vector2).value)


func _write_value(control: TclCustomControl) -> void:
	(control as TclCustomControl_Vector2).value = value


func _read_value(control: TclCustomControl, committed: bool) -> void:
	var old := value
	value = (control as TclCustomControl_Vector2).value
	if committed:
		OnValueCommittedFromApp.emit(value)
	else:
		OnValueChangedFromApp.emit(value, old)
