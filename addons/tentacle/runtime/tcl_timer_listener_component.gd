@icon("res://addons/tentacle/icons/tentacle.png")
class_name TclTimerListenerComponent
extends Node

## Listens for the timers the streamer defined in Tentacle, authored in the scene.
##
## Put one in the scene, list the timer names in the Inspector, and connect
## [signal OnFired]. No subscribing in code, and no unsubscribing to remember - the
## subscriptions live exactly as long as the node is in the tree.
##
## [codeblock]
## # In the Inspector: timer_names = ["Boss", "Loot Drop"]
## func _on_fired(event: TclTimerEvent) -> void:
##     match event.name:
##         "Boss": _spawn_boss()
##         "Loot Drop": _drop_loot()
## [/codeblock]

# Unreal's UTclTimerListenerComponent and Unity's TimerListenerComponent.

## One of [member timer_names] fired.
signal OnFired(event: TclTimerEvent)

## The timer names to listen for, as the streamer named them in Tentacle.
##
## Names are matched case-insensitively by default; turn on [member case_sensitive] to
## require an exact match.
@export var timer_names: Array[String] = []:
	set(value):
		timer_names = value
		# Re-subscribed in place, so editing the list at runtime takes effect rather than
		# needing the node removed and re-added.
		_resubscribe()

## Require each timer's name to match one of [member timer_names] exactly, case and all.
@export var case_sensitive: bool = false:
	set(value):
		case_sensitive = value
		_resubscribe()

## A timers surface every listener uses instead of the [code]Tentacle[/code] autoload's,
## so a test can drive listeners without the autoload in the tree. Leave it null in a
## game.
static var surface_override: Tentacle_Timers = null

var _surface: Tentacle_Timers = null
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
				"a Tentacle timer listener is in the scene but the addon's autoload "
				+ "is not installed, so it will never fire"
			)
			return
		_surface = runtime.timers

	for timer_name in timer_names:
		if timer_name.is_empty() or _already_listening_for(timer_name):
			# Listed twice - or twice in two cases while case is ignored - would fire
			# OnFired twice for one fire.
			continue
		_surface.subscribe(timer_name, _on_fired, case_sensitive)
		_subscribed.append(timer_name)


func _unsubscribe() -> void:
	if _surface != null:
		for timer_name in _subscribed:
			_surface.unsubscribe(timer_name, _on_fired)
	_subscribed.clear()
	_surface = null


func _resubscribe() -> void:
	if is_inside_tree():
		_unsubscribe()
		_subscribe()


func _already_listening_for(timer_name: String) -> bool:
	for subscribed in _subscribed:
		if subscribed == timer_name:
			return true
		if not case_sensitive and subscribed.nocasecmp_to(timer_name) == 0:
			return true
	return false


func _on_fired(event: TclTimerEvent) -> void:
	OnFired.emit(event)
