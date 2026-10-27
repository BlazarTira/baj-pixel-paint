class_name TentacleControlHandle
extends RefCounted

## One registered custom control, as code holds it.
##
## [method Tentacle_CustomControls.register_custom_control] returns one. The
## scene-authored control nodes (the [TclCustomControlComponent] subclasses) sit on top
## of this rather than beside it: each node owns a handle and forwards its signals.

# No Unreal counterpart - Unreal's components hold their control directly - so the class
# keeps its name; its signals carry the component's names, so code-only use reads the
# same as a component. The scene-authored nodes live in runtime/custom_controls/.

## A button was clicked.
signal OnClick()

## A button was pressed down.
signal OnMouseDown()

## A button was released.
signal OnMouseUp()

## The streamer is dragging or typing. Fires continuously, with the value as Tentacle
## sent it.
signal OnValueChangedFromApp(value: Variant)

## The streamer settled on a value. Fires once, with the value as Tentacle sent it.
signal OnValueCommittedFromApp(value: Variant)

## The control this handle stands for. Its fields are the wire state.
var control: TclCustomControl = null

## False once the control has been unregistered.
var is_registered: bool = false

## The control's generated id.
var id: String:
	get:
		return control.id if control != null else ""

var _owner: Tentacle_CustomControls:
	get:
		return _owner_ref.get_ref() as Tentacle_CustomControls if _owner_ref != null else null

# Held weakly because the surface holds every handle it made: two RefCounted objects
# that hold each other are never freed, and the surface holds the session, so a game's
# registered controls kept the session, its socket, and the transport alive for good.
var _owner_ref: WeakRef = null


func _init(owner: Tentacle_CustomControls = null, for_control: TclCustomControl = null) -> void:
	_owner_ref = weakref(owner) if owner != null else null
	control = for_control
	is_registered = owner != null and for_control != null


## Sends the control's current state to Tentacle.
##
## Call after changing a field on [member control] from code. The scene nodes do
## this for you whenever their value, label, ordering, or group changes.
func push_state() -> void:
	var owner := _owner
	if owner != null:
		owner.push_state(self)


## Removes the control from Tentacle. Safe to call more than once.
func unregister() -> void:
	var owner := _owner
	if owner != null:
		owner.unregister_handle(self)


## Applies an inbound control event and raises the matching signal.
##
## The value is written onto [member control] **before** the signal is raised, so a
## handler reading [member control] sees the new value. A node that vetoes the value
## has to put the old one back, which is what its refusal path does.
func deliver(event: TclCustomControlEvent) -> void:
	if event == null:
		return

	if event is TclCustomControlEvent_ValueChange:
		var change := event as TclCustomControlEvent_ValueChange
		TentacleControlValues.apply_value(control, change.value)
		OnValueChangedFromApp.emit(change.value)
		return

	if event is TclCustomControlEvent_ValueCommit:
		var commit := event as TclCustomControlEvent_ValueCommit
		TentacleControlValues.apply_value(control, commit.value)
		OnValueCommittedFromApp.emit(commit.value)
		return

	if event is TclCustomControlEvent_Click:
		OnClick.emit()
		return
	if event is TclCustomControlEvent_MouseDown:
		OnMouseDown.emit()
		return
	if event is TclCustomControlEvent_MouseUp:
		OnMouseUp.emit()
		return

	# A control event kind this addon version predates. The app is
	# forward-compatible by design, so this is a notice, not a failure.
	TentacleLog.warn('ignoring an unrecognised control event for "%s"' % id)
