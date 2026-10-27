class_name Tentacle_Timers
extends RefCounted

## The timers the streamer defined in Tentacle, firing at the game.
##
## A timer fires on a schedule the streamer sets in Tentacle - a fixed interval or a
## random one from a range, repeating or once, only while the stream is live if they
## like, and only after enough chat - so the game reacts to one **name** and keeps no
## clock of its own. The streamer starts, pauses, and resets timers in Tentacle, and
## the game can too, and define its own: see [method create_timer].
##
## **Not de-duplicated**: every fire is a fire.
##
## [member definitions] holds every timer with whether it is counting down, kept current
## as the streamer changes them.

# Unreal's UTentacle_Timers and Unity's Tentacle_Timers. Names match ignoring case by
# default, as every other name lookup in the plugins does, with case_sensitive to opt in.
# The changes (create_timer and the rest) take their callback before the case rule, as
# every asynchronous call in the addon puts its callback after what it acts on.

## Every timer fire, whatever the timer's name.
signal OnTimerFired(event: TclTimerEvent)

## Fires whenever the timer definitions change, including when the first ones arrive.
## [member definitions] already holds the new ones when it fires. Definitions Tentacle
## sends again unchanged, as it does every time the session opens, do not fire it.
signal OnDefinitionsChanged()

## Every timer the streamer defined, ordered by name, with whether it is counting down.
var definitions: Array[TclTimerDefinition]:
	get:
		return _definitions.duplicate()

## Whether Tentacle has sent the definitions yet. Until it has, [member definitions] is
## empty.
var are_definitions_loaded: bool:
	get:
		return _are_definitions_loaded

## Every subscription, in the order it was made, which is the order handlers run in.
var _subscriptions: Array[_Subscription] = []

var _definitions: Array[TclTimerDefinition] = []
var _are_definitions_loaded: bool = false

## The last definitions as received, so ones sent again unchanged fire nothing.
var _definitions_key: String = ""

var _rpc: TentacleRpc = null


func _init(rpc: TentacleRpc = null) -> void:
	_rpc = rpc


## Points this surface at a different RPC transport. The [code]Tentacle[/code] autoload
## calls this itself, rebinding the surface in place.
func bind_rpc(rpc: TentacleRpc) -> void:
	_rpc = rpc


## Creates a timer, stopped until [method start_timer] starts it.
##
## Configuring a timer in Tentacle and shipping its export is the easier way to give a
## game the timers it needs; this is for timers the game decides on as it runs.
## [param on_complete] is called once with a [enum TclDefinitionResult.Value]: SUCCESS,
## NAME_TAKEN when another timer has the name, or FAILED (the reason is logged).
func create_timer(settings: TclTimerSettings, on_complete: Callable = Callable()) -> void:
	var input := settings.to_input()
	input["name"] = settings.name
	TentacleDefinitionChange.change(_rpc, "timers.create", input, on_complete)


## Changes how a timer runs.
##
## Every setting is sent, so start from the timer's definition to change only one; an
## empty [member TclTimerSettings.name] keeps its name. A new interval starts its
## countdown over. [param on_complete] is called once with SUCCESS, NOT_FOUND,
## NAME_TAKEN when renaming it to a name another timer has, or FAILED.
func update_timer(
	timer_name: String,
	settings: TclTimerSettings,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	var id := _resolve(timer_name, case_sensitive, on_complete)
	if id.is_empty():
		return
	var input := settings.to_input()
	input["id"] = id
	TentacleDefinitionChange.change(_rpc, "timers.update", input, on_complete)


## Deletes a timer. [param on_complete] is called once with SUCCESS, NOT_FOUND, or
## FAILED.
func delete_timer(timer_name: String, on_complete: Callable = Callable(), case_sensitive: bool = false) -> void:
	_drive("timers.delete", timer_name, on_complete, case_sensitive)


## Starts a timer: resumes a paused countdown, or begins a fresh one. A running timer is
## left as it is. [param on_complete] is called once with SUCCESS, NOT_FOUND, or FAILED.
func start_timer(timer_name: String, on_complete: Callable = Callable(), case_sensitive: bool = false) -> void:
	_drive("timers.start", timer_name, on_complete, case_sensitive)


## Pauses a running timer, keeping what its countdown has left. [param on_complete] is
## called once with SUCCESS, NOT_FOUND, or FAILED.
func pause_timer(timer_name: String, on_complete: Callable = Callable(), case_sensitive: bool = false) -> void:
	_drive("timers.pause", timer_name, on_complete, case_sensitive)


## Starts a timer's countdown over, leaving it running or paused as it was.
## [param on_complete] is called once with SUCCESS, NOT_FOUND, or FAILED.
func reset_timer(timer_name: String, on_complete: Callable = Callable(), case_sensitive: bool = false) -> void:
	_drive("timers.reset", timer_name, on_complete, case_sensitive)


## Fires a timer now, as its countdown ending would, whatever its chat minimum:
## [signal OnTimerFired] fires for it everywhere. A repeating timer then starts its
## countdown over; one that does not stops. [param on_complete] is called once with
## SUCCESS, NOT_FOUND, or FAILED.
func fire_timer(timer_name: String, on_complete: Callable = Callable(), case_sensitive: bool = false) -> void:
	_drive("timers.fire", timer_name, on_complete, case_sensitive)


## Calls [param handler] every time the timer with this name fires.
##
## Names are matched case-insensitively by default; pass [param case_sensitive] to
## require an exact match. The handler is called as [code](event: TclTimerEvent)[/code].
##
## Subscribing the same handler to the same name again subscribes it once, taking the
## newer [param case_sensitive].
func subscribe(timer_name: String, handler: Callable, case_sensitive: bool = false) -> void:
	if timer_name.is_empty() or not handler.is_valid():
		TentacleLog.error("a timer subscription needs a name and a valid handler")
		return
	for existing in _subscriptions:
		if existing.timer_name == timer_name and existing.handler == handler:
			existing.case_sensitive = case_sensitive
			return
	var subscription := _Subscription.new()
	subscription.timer_name = timer_name
	subscription.handler = handler
	subscription.case_sensitive = case_sensitive
	_subscriptions.append(subscription)


## Stops calling [param handler] for this name.
##
## The name is compared the way the subscription compares it: a case-insensitive
## subscription is ended by its name in any case, a case-sensitive one only by its
## exact name.
func unsubscribe(timer_name: String, handler: Callable) -> void:
	for subscription in _subscriptions.duplicate():
		if subscription.handler == handler and subscription.matches(timer_name):
			_subscriptions.erase(subscription)


## Drops every subscription.
func clear() -> void:
	_subscriptions.clear()


## The timer with this name, or null.
##
## Case-insensitive by default, the same rule [method subscribe] uses; pass
## [param case_sensitive] to require an exact match.
func find_definition_by_name(timer_name: String, case_sensitive: bool = false) -> TclTimerDefinition:
	if timer_name.is_empty():
		return null
	for definition in _definitions:
		if case_sensitive and definition.name == timer_name:
			return definition
		if not case_sensitive and definition.name.nocasecmp_to(timer_name) == 0:
			return definition
	return null


## Takes the definitions a [code]Timers_Definitions[/code] message carries.
func handle_definitions(data: Dictionary) -> void:
	# Tentacle sends the current definitions every time a session opens, so ones
	# identical to those held are not a change.
	var key := TclJson.to_text(data)
	if _are_definitions_loaded and key == _definitions_key:
		return

	_definitions.clear()
	for item in TclJson.read_array(data, "definitions"):
		var definition := TclTimerDefinition.parse(item)
		if definition != null:
			_definitions.append(definition)
	_are_definitions_loaded = true
	_definitions_key = key

	OnDefinitionsChanged.emit()


## Routes one inbound timer fire.
func handle_fired(payload: Dictionary) -> void:
	var fired := TclTimerEvent.parse(payload)
	if fired == null:
		# A malformed frame is dropped here rather than handed on, so a game's handler
		# never has to null-check what the signal promises is a fire.
		return

	OnTimerFired.emit(fired)

	# Iterated over a copy: a handler is allowed to unsubscribe itself, which would
	# otherwise mutate the array mid-loop.
	for subscription in _subscriptions.duplicate():
		if not subscription.matches(fired.name):
			continue
		if not subscription.handler.is_valid():
			continue
		subscription.handler.call(fired)


## The id of the timer with this name, or empty after calling [param on_complete] with
## why: NOT_FOUND when there is no such timer, FAILED when the timers have not arrived
## from Tentacle, which says nothing about the name.
func _resolve(timer_name: String, case_sensitive: bool, on_complete: Callable) -> String:
	if not _are_definitions_loaded:
		TentacleLog.warn("the timers have not arrived from Tentacle yet, so '%s' cannot be found; is it connected?" % timer_name)
		TentacleDefinitionChange.finish(on_complete, TclDefinitionResult.Value.FAILED)
		return ""
	var definition := find_definition_by_name(timer_name, case_sensitive)
	if definition == null:
		TentacleDefinitionChange.finish(on_complete, TclDefinitionResult.Value.NOT_FOUND)
		return ""
	return definition.id


## Calls a procedure that acts on one timer, named by its id.
func _drive(procedure: String, timer_name: String, on_complete: Callable, case_sensitive: bool) -> void:
	var id := _resolve(timer_name, case_sensitive, on_complete)
	if not id.is_empty():
		TentacleDefinitionChange.change(_rpc, procedure, {"id": id}, on_complete)


## One handler listening for one timer.
class _Subscription:
	var timer_name: String = ""
	var handler: Callable = Callable()
	var case_sensitive: bool = false

	## True when a timer called [param name] is one this subscription listens for.
	func matches(name: String) -> bool:
		if case_sensitive:
			return name == timer_name
		return name.nocasecmp_to(timer_name) == 0
