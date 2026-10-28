@icon("res://addons/tentacle/icons/tentacle.png")
class_name TclCustomEventListenerComponent
extends Node

## Listens for named custom events, authored in the scene.
##
## The counterpart of the custom-control nodes for custom events: put one in the scene,
## list the event names in the Inspector, and connect [signal OnTriggered]. No
## subscribing in code, and no unsubscribing to remember - the subscriptions live
## exactly as long as the node is in the tree.
##
## [codeblock]
## # In the Inspector: event_names = ["SpawnBoss", "HealPlayer"]
## func _on_triggered(event: TclCustomEvent, viewer: TclViewer) -> void:
##     match event.name:
##         "SpawnBoss": _spawn_boss()
##         "HealPlayer": _heal(viewer)
## [/codeblock]

# Unreal's UTclCustomEventListenerComponent and Unity's TclCustomEventListenerComponent.

## One of [member event_names] fired.
##
## [param viewer] is null for an event no viewer triggered.
signal OnTriggered(event: TclCustomEvent, viewer: TclViewer)

## The event names to listen for, as the streamer named them in Tentacle.
##
## Names are matched case-insensitively by default, which is what a streamer typing a
## name into Tentacle expects; turn on [member case_sensitive] to require an exact
## match.
@export var event_names: Array[String] = []:
	set(value):
		event_names = value
		# Re-subscribed in place, so editing the list at runtime takes effect rather
		# than needing the node removed and re-added.
		_resubscribe()

## Require each event's name to match one of [member event_names] exactly, case and all.
@export var case_sensitive: bool = false:
	set(value):
		case_sensitive = value
		_resubscribe()

## A custom events surface every listener uses instead of the [code]Tentacle[/code]
## autoload's, so a test can drive listeners without the autoload in the tree. Leave
## it null in a game.
static var surface_override: Tentacle_CustomEvents = null

var _surface: Tentacle_CustomEvents = null
var _subscribed: Array[String] = []


func _enter_tree() -> void:
	_subscribe()


func _exit_tree() -> void:
	_unsubscribe()


func _subscribe() -> void:
	_surface = surface_override
	if _surface == null:
		var runtime := TentacleRuntime.instance()
		if runtime == null:
			TentacleLog.warn(
				"a Tentacle custom-event listener is in the scene but the addon's autoload "
				+ "is not installed, so it will never fire"
			)
			return
		_surface = runtime.custom_events

	for event_name in event_names:
		if event_name.is_empty() or _already_listening_for(event_name):
			# Listed twice - or twice in two cases while case is ignored - would fire
			# OnTriggered twice for one event.
			continue
		_surface.subscribe(event_name, _on_event, case_sensitive)
		_subscribed.append(event_name)


func _unsubscribe() -> void:
	if _surface != null:
		for event_name in _subscribed:
			_surface.unsubscribe(event_name, _on_event)
	_subscribed.clear()
	_surface = null


func _resubscribe() -> void:
	if is_inside_tree():
		_unsubscribe()
		_subscribe()


func _already_listening_for(event_name: String) -> bool:
	for subscribed in _subscribed:
		if subscribed == event_name:
			return true
		if not case_sensitive and subscribed.nocasecmp_to(event_name) == 0:
			return true
	return false


func _on_event(event: TclCustomEvent, viewer: TclViewer) -> void:
	OnTriggered.emit(event, viewer)
