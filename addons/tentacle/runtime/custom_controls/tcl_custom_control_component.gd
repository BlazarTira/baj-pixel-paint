@icon("res://addons/tentacle/icons/control.svg")
class_name TclCustomControlComponent
extends Node

## Base for the scene-authored custom controls. Add one of its subclasses, not this.
##
## **This is the primary way to author a custom control.** Drop a
## [TclCustomControlComponent_Slider] on a node, set its label in the Inspector, and it
## appears in Tentacle's panel while the scene is running - no ids to keep unique, no
## registration to remember, no teardown to write. The code-only registry
## ([member TentacleRuntime.custom_controls]) stays available and this sits **on top
## of** it rather than beside it.
##
## Registration is scoped to the node's lifetime: it registers when the node enters
## the tree and unregisters when it leaves. The script is not [code]@tool[/code], so
## merely having a scene open in the editor never registers anything with Tentacle.
##
## To clamp or veto a value the streamer sends, override the typed hook on the
## component you use: [code]_should_receive_value_float[/code] on a Number or Slider,
## [code]_should_receive_value_color[/code] on a Color, and so on. Each is handed the
## value already in the engine's own type.
##
## [codeblock]
## extends TclCustomControlComponent_Slider
##
## func _should_receive_value_float(new_value: float) -> bool:
##     return new_value <= 0.8  # refuse anything above 0.8
## [/codeblock]

# Unreal's UTclCustomControlComponent and Unity's TclCustomControlComponent; the signals
# are Unreal's delegate names and the typed hooks its ShouldReceiveValue_<Type> natives.
# Unreal also keeps a raw ShouldReceiveValue(FString) that runs first; Unity and Godot
# have only the typed ones. Not @tool deliberately: registering from an open scene is a
# trap the Unity plugin had to work around explicitly.

## Fires once the control has registered and its id exists.
signal OnInitialize()

## A button was clicked. Only Button-style controls raise this.
signal OnClick()

## A button was pressed down.
signal OnMouseDown()

## A button was released.
signal OnMouseUp()

## The label shown in Tentacle's panel.
@export var label: String = "":
	set(value):
		label = value
		_send_state()

## Where this control sits in Tentacle's ordering.
##
## Controls sharing a sort index fall back to registration order.
@export var sort_index: int = 0:
	set(value):
		sort_index = value
		_send_state()

## A registry every control node uses instead of the [code]Tentacle[/code] autoload's,
## so a test can drive registration without the autoload in the tree. Leave it null in
## a game.
static var registry_override: Tentacle_CustomControls = null

## The control's generated id. Empty until it registers.
var control_id: String = ""

## The group this control was filed under, resolved from the nearest ancestor
## [TclCustomControlGroupComponent]. Empty when there is none.
var group: String = ""

## The registered control, or null before registration.
var handle: TentacleControlHandle = null

## True while Tentacle knows about this control.
var is_registered: bool:
	get:
		return handle != null and handle.is_registered

## The kind of control this is in Tentacle's panel: "Slider", "Color", "Button" and
## so on.
var control_type: String:
	get:
		return TentacleControlValues.type_of(_create_control())

var _registry: Tentacle_CustomControls = null


func _enter_tree() -> void:
	_register()


func _exit_tree() -> void:
	_unregister()


## Sets the label shown in Tentacle's panel and pushes it. The same as assigning
## [member label].
func set_label(new_label: String) -> void:
	label = new_label


## Sets where this control sits in Tentacle's ordering and pushes it. The same as
## assigning [member sort_index].
func set_sort_index(new_sort_index: int) -> void:
	sort_index = new_sort_index


## Files the control under a group name.
##
## Normally resolved from the enclosing [TclCustomControlGroupComponent] rather than
## called directly.
func set_group(new_group: String) -> void:
	group = new_group
	_send_state()


# --- For subclasses ----------------------------------------------------------

## Asks this component's typed veto whether to take the value Tentacle just wrote onto
## [param _control]. Each typed component converts the value and calls its own
## [code]_should_receive_value_<type>[/code]; a Button has no value to veto.
func _accepts_value_from_app(_control: TclCustomControl) -> bool:
	return true

## Builds the wire control this node stands for, with its own defaults.
##
## The base fills in the id, label, ordering, and group afterwards.
func _create_control() -> TclCustomControl:
	TentacleLog.error("%s did not override _create_control" % get_script().resource_path)
	return null


## Copies this node's value onto the wire control.
func _write_value(_control: TclCustomControl) -> void:
	pass


## Copies the wire control's value onto this node and raises the typed signal.
func _read_value(_control: TclCustomControl, _committed: bool) -> void:
	pass


## True while a value from Tentacle is being written onto this node.
##
## Godot property setters run on **every** assignment, including the one inside
## [method _read_value], so without this a value arriving from the app would be
## pushed straight back as if the game had set it - a loop, and one that would fight
## the streamer mid-drag.
var _applying_from_app: bool = false


## Pushes this node's label, ordering, group, and value to Tentacle.
##
## Every typed [code]set_value[/code] ends here.
func _send_state() -> void:
	if handle == null or not handle.is_registered:
		return
	if _applying_from_app:
		return
	handle.control.label = label
	handle.control.sort_index = sort_index
	handle.control.group = null if group.is_empty() else group
	_write_value(handle.control)
	handle.push_state()


# --- Internals ---------------------------------------------------------------

func _register() -> void:
	if handle != null:
		# Registering twice must register once.
		return

	# Qualified rather than bare, so it unambiguously names the one storage the
	# subclasses share rather than relying on how an inherited static resolves.
	_registry = TclCustomControlComponent.registry_override
	if _registry == null:
		var runtime := TentacleRuntime.instance()
		if runtime == null:
			TentacleLog.warn(
				"a Tentacle custom control is in the scene but the addon's autoload is not "
				+ "installed, so it will not appear in Tentacle"
			)
			return
		_registry = runtime.custom_controls

	group = _resolve_group()

	var control := _create_control()
	if control == null:
		return
	control.label = label
	control.sort_index = sort_index
	# An absent group means "ungrouped"; an empty string would be a group whose name
	# is blank.
	control.group = null if group.is_empty() else group
	_write_value(control)

	handle = _registry.register_custom_control(control)
	if handle == null:
		# register_custom_control() already said why. Carrying on with a null handle
		# would turn every later call into a null dereference.
		_registry = null
		return

	control_id = handle.id
	handle.OnClick.connect(_on_click)
	handle.OnMouseDown.connect(_on_mouse_down)
	handle.OnMouseUp.connect(_on_mouse_up)
	handle.OnValueChangedFromApp.connect(_on_value_changed_from_app)
	handle.OnValueCommittedFromApp.connect(_on_value_committed_from_app)

	OnInitialize.emit()


func _unregister() -> void:
	if handle != null:
		handle.OnClick.disconnect(_on_click)
		handle.OnMouseDown.disconnect(_on_mouse_down)
		handle.OnMouseUp.disconnect(_on_mouse_up)
		handle.OnValueChangedFromApp.disconnect(_on_value_changed_from_app)
		handle.OnValueCommittedFromApp.disconnect(_on_value_committed_from_app)
		handle.unregister()

	handle = null
	_registry = null
	control_id = ""


## The group name from the nearest group above this node, or empty.
func _resolve_group() -> String:
	var parent := get_parent()
	while parent != null:
		if parent is TclCustomControlGroupComponent:
			return (parent as TclCustomControlGroupComponent).group_name
		parent = parent.get_parent()
	return ""


func _on_click() -> void:
	OnClick.emit()


func _on_mouse_down() -> void:
	OnMouseDown.emit()


func _on_mouse_up() -> void:
	OnMouseUp.emit()


func _on_value_changed_from_app(value: Variant) -> void:
	_apply_from_app(value, false)


func _on_value_committed_from_app(value: Variant) -> void:
	_apply_from_app(value, true)


## Folds one value from Tentacle onto this node, or refuses it.
##
## A refusal puts the old value back on the wire control, so this node and Tentacle's
## copy agree: the handle writes the value onto the control **before** raising, so
## without that the next state push would send the value just rejected.
func _apply_from_app(_value: Variant, committed: bool) -> void:
	if handle == null:
		return

	if not _accepts_value_from_app(handle.control):
		_write_value(handle.control)
		return

	_applying_from_app = true
	_read_value(handle.control, committed)
	_applying_from_app = false
