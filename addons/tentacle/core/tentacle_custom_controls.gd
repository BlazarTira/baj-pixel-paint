class_name Tentacle_CustomControls
extends RefCounted

## The controls this game puts in Tentacle's custom-controls panel.
##
## The registry is the authority whether or not a session is open: a control
## registered while Tentacle is closed is sent as soon as one opens, and the whole
## registry is **replayed on every new session**, because Tentacle drops a session's
## controls the moment its socket closes.
##
## **Ids are generated here, never supplied by the caller**, so nothing has to keep
## them unique.
##
## [member custom_controls] is in **registration order**, which is what breaks a tie
## between two controls sharing a sort index.
##
## Most games author controls as scene nodes instead - the
## [TclCustomControlComponent] subclasses - which register themselves here.

# Unreal's UTentacle_CustomControls and Unity's Tentacle_CustomControls. A user keeping
# ids unique across a scene is exactly the bookkeeping the scene-authored nodes exist to
# remove, and a duplicate would make one control unreachable.

## A control event arrived for one of this game's controls.
##
## Raised in addition to the handle's own typed signals, for a game that would
## rather branch in one place.
signal OnControlEvent(handle: TentacleControlHandle, event: TclCustomControlEvent)

var _by_id: Dictionary[String, TentacleControlHandle] = {}

# Registration order, which a Dictionary's key order happens to match but does not
# promise. Kept explicitly so the ordering is a fact rather than an implementation
# detail - the interface guide lists "ordering claimed but not kept" as a trap already
# hit once.
var _order: Array[TentacleControlHandle] = []

var _session: TentacleSession = null


func _init(session: TentacleSession = null) -> void:
	_session = session


## Every control currently registered, in registration order.
var custom_controls: Array[TentacleControlHandle]:
	get:
		return _order.duplicate()


## The handle for a control id, or null.
func find_custom_control_by_id(control_id: String) -> TentacleControlHandle:
	return _by_id.get(control_id, null)


## Registers a control and returns its handle, or null when it cannot be sent.
##
## The control's [code]id[/code] is **overwritten** with a generated one: whatever
## the caller set is discarded, so nothing has to keep ids unique.
func register_custom_control(control: TclCustomControl) -> TentacleControlHandle:
	if control == null:
		TentacleLog.error("cannot register a null custom control")
		return null

	if TentacleControlValues.type_of(control) == "":
		# Refusing here rather than at send time keeps the registry free of
		# controls that could never be discriminated by the app, which would simply
		# never appear in its panel.
		TentacleLog.error(
			"cannot register a control that is not one of the TclCustomControl_* variants"
		)
		return null

	control.id = _generate_id()

	var handle := TentacleControlHandle.new(self, control)
	_by_id[control.id] = handle
	_order.append(handle)
	_send("CustomControls_RegisterControl", control)
	return handle


## Removes a control by id. False when nothing was registered under it.
func unregister_custom_control(control_id: String) -> bool:
	var handle := find_custom_control_by_id(control_id)
	if handle == null:
		return false
	unregister_handle(handle)
	return true


## Removes a control. Safe to call for an already-removed handle.
func unregister_handle(handle: TentacleControlHandle) -> void:
	if handle == null or not handle.is_registered:
		return
	handle.is_registered = false
	_by_id.erase(handle.id)
	_order.erase(handle)
	_send("CustomControls_UnregisterControl", handle.control)


## Sends a control's current state. Ignored for an unregistered handle.
func push_state(handle: TentacleControlHandle) -> void:
	if handle == null or not handle.is_registered:
		return
	_send("CustomControls_ControlState", handle.control)


## Re-sends every registered control, in registration order.
##
## Called as each session opens, and again when Tentacle asks for the registry,
## which it does once right after it welcomes a session.
func replay() -> void:
	for handle in _order:
		_send("CustomControls_RegisterControl", handle.control)


## Forgets every control without telling Tentacle, for a deliberate shutdown.
func clear() -> void:
	for handle in _order:
		handle.is_registered = false
	_by_id.clear()
	_order.clear()


## Routes one inbound control event to its handle.
func handle_control_event(payload: Dictionary) -> void:
	var event := TclCustomControlEvent.parse(TclJson.read_object(payload, "event"))
	if event == null:
		return

	var handle := find_custom_control_by_id(event.control_id)
	if handle == null:
		# A control this session no longer owns. Ordinary after an unregister that
		# raced an event already in flight.
		TentacleLog.info('no registered control for event "%s"' % event.control_id)
		return

	handle.deliver(event)
	OnControlEvent.emit(handle, event)


## A fresh control id.
##
## A per-registry random prefix plus a counter. Uniqueness only has to hold within
## a session - the app scopes controls to the session that registered them - but the
## prefix means two processes running the same project still never collide, which
## matters because an editor run and an exported build can both be connected.
func _generate_id() -> String:
	_next_id += 1
	return "gd-%x-%d" % [_id_prefix, _next_id]

# Drawn once per registry. randi() is a global function, so this stays inside the core's
# layering rule - no Engine, no OS, no Time.
var _id_prefix: int = randi()
var _next_id: int = 0


func _send(type: String, control: TclCustomControl) -> void:
	if _session == null or control == null:
		return
	_session.send(type, {"control": control.to_dictionary()})
