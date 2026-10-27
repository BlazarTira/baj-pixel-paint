@icon("res://addons/tentacle/icons/control.svg")
class_name TclCustomControlComponent_Button
extends TclCustomControlComponent

## A button in Tentacle's panel. Carries no value.
##
## Connect [signal TclCustomControlComponent.OnClick], or
## [signal TclCustomControlComponent.OnMouseDown] and
## [signal TclCustomControlComponent.OnMouseUp] when you want the press and release
## separately - holding a button down to charge something, say.


func _create_control() -> TclCustomControl:
	return TclCustomControl_Button.new()
