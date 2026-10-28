@icon("res://addons/tentacle/icons/tentacle.png")
class_name TclCustomControlComponent_Vector4
extends TclCustomControlComponent

## A 4-component vector in Tentacle's panel.
##
## [member value] is a real [Vector4], not the numeric array the wire carries: the
## conversion happens at this boundary, so a game assigns it straight to a node's
## position or scale.

## The streamer is dragging a component. Fires continuously, with the value it
## replaced.
signal OnValueChangedFromApp(new_value: Vector4, old_value: Vector4)

## The streamer settled on a value. Fires once.
signal OnValueCommittedFromApp(new_value: Vector4)

## The current value.
@export var value: Vector4 = Vector4.ZERO:
	set(new_value):
		value = new_value
		_send_state()


## Sets the value **and** pushes it to Tentacle. Never two calls.
func set_value(new_value: Vector4) -> void:
	value = new_value


## Whether to accept a vector Tentacle sent. Override to clamp or veto.
##
## Returning false leaves **both** this node and Tentacle's copy of the control as they
## were, so the next push cannot send the vector you just rejected. To clamp instead,
## call [method set_value] with the vector you want and return false.
@warning_ignore("unused_parameter")
func _should_receive_value_vector4(new_value: Vector4) -> bool:
	return true


func _create_control() -> TclCustomControl:
	return TclCustomControl_Vector4.new()


func _accepts_value_from_app(control: TclCustomControl) -> bool:
	return _should_receive_value_vector4((control as TclCustomControl_Vector4).value)


func _write_value(control: TclCustomControl) -> void:
	(control as TclCustomControl_Vector4).value = value


func _read_value(control: TclCustomControl, committed: bool) -> void:
	var old := value
	value = (control as TclCustomControl_Vector4).value
	if committed:
		OnValueCommittedFromApp.emit(value)
	else:
		OnValueChangedFromApp.emit(value, old)
