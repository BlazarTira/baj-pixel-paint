@icon("res://addons/tentacle/icons/control.svg")
class_name TclCustomControlComponent_Select
extends TclCustomControlComponent

## A dropdown in Tentacle's panel.
##
## [member options] is what the streamer can choose from. Change it at runtime through
## [method set_options], which pushes the new list; assigning the array in place does
## too, but mutating it with [code]append[/code] does not, because nothing observes
## that.

## The streamer picked an option, with the one it replaced.
signal OnValueChangedFromApp(new_value: String, old_value: String)

## The streamer picked an option.
signal OnValueCommittedFromApp(new_value: String)

## The currently selected option.
@export var value: String = "":
	set(new_value):
		value = new_value
		_send_state()

## What the streamer can choose from.
@export var options: Array[String] = []:
	set(new_options):
		options = new_options
		_send_state()

## Greyed-out hint shown while nothing is selected.
@export var placeholder: String = "":
	set(new_value):
		placeholder = new_value
		_send_state()


## Sets the selection **and** pushes it to Tentacle. Never two calls.
func set_value(new_value: String) -> void:
	value = new_value


## Replaces the list of options and pushes it.
func set_options(new_options: Array[String]) -> void:
	options = new_options


## Whether to accept an option Tentacle sent. Override to veto.
##
## Returning false leaves **both** this node and Tentacle's copy of the control as they
## were, so the next push cannot send the option you just rejected.
@warning_ignore("unused_parameter")
func _should_receive_value_string(new_value: String) -> bool:
	return true


func _create_control() -> TclCustomControl:
	return TclCustomControl_Select.new()


func _accepts_value_from_app(control: TclCustomControl) -> bool:
	return _should_receive_value_string((control as TclCustomControl_Select).value)


func _write_value(control: TclCustomControl) -> void:
	var select := control as TclCustomControl_Select
	select.value = value
	select.placeholder = placeholder
	# Assigned as a fresh typed array rather than by reference, so a later edit to
	# this node's array cannot change what was already sent.
	var copied: Array[String] = []
	for option in options:
		copied.append(option)
	select.options = copied


func _read_value(control: TclCustomControl, committed: bool) -> void:
	var old := value
	value = (control as TclCustomControl_Select).value
	if committed:
		OnValueCommittedFromApp.emit(value)
	else:
		OnValueChangedFromApp.emit(value, old)
