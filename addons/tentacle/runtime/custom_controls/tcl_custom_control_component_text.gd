@icon("res://addons/tentacle/icons/control.svg")
class_name TclCustomControlComponent_Text
extends TclCustomControlComponent

## A text field in Tentacle's panel.

## The streamer is typing. Fires continuously, with the text it replaced.
signal OnValueChangedFromApp(new_value: String, old_value: String)

## The streamer finished typing. Fires once.
signal OnValueCommittedFromApp(new_value: String)

## The current text.
@export var value: String = "":
	set(new_value):
		value = new_value
		_send_state()

## Greyed-out hint shown while the field is empty.
@export var placeholder: String = "":
	set(new_value):
		placeholder = new_value
		_send_state()


## Sets the text **and** pushes it to Tentacle. Never two calls.
func set_value(new_value: String) -> void:
	value = new_value


## Whether to accept text Tentacle sent. Override to clamp or veto.
##
## Returning false leaves **both** this node and Tentacle's copy of the control as they
## were, so the next push cannot send the text you just rejected. To trim or shorten it
## instead, call [method set_value] with the text you want and return false.
@warning_ignore("unused_parameter")
func _should_receive_value_string(new_value: String) -> bool:
	return true


func _create_control() -> TclCustomControl:
	return TclCustomControl_Text.new()


func _accepts_value_from_app(control: TclCustomControl) -> bool:
	return _should_receive_value_string((control as TclCustomControl_Text).value)


func _write_value(control: TclCustomControl) -> void:
	var text := control as TclCustomControl_Text
	text.value = value
	text.placeholder = placeholder


func _read_value(control: TclCustomControl, committed: bool) -> void:
	var old := value
	value = (control as TclCustomControl_Text).value
	if committed:
		OnValueCommittedFromApp.emit(value)
	else:
		OnValueChangedFromApp.emit(value, old)
