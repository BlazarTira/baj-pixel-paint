class_name Tentacle_CustomEvents
extends RefCounted

## Named events the streamer configured in Tentacle.
##
## The game reacts to a **name** and never encodes the trigger rules: what makes a
## custom event fire - a cheer over some amount, a chat command, a redemption - is
## the streamer's to change without touching the game.
##
## **Deliberately not de-duplicated**, unlike stream events. A custom event is a
## command to act, and the streamer firing the same one twice means twice.
##
## [member definitions] holds every custom event the streamer configured, each with the
## chat commands that fire it, kept current as the streamer creates, changes, and removes
## them.

# Unreal's UTentacle_CustomEvents and Unity's Tentacle_CustomEvents. Names match ignoring
# case by default, as Unreal's shipped listener component and every viewer-property name
# do, with case_sensitive to opt in.

## Every custom event, with the viewer who triggered it when there was one.
signal OnCustomEvent(event: TclCustomEvent, viewer: TclViewer)

## Fires whenever the custom event definitions change, including when the first ones
## arrive. [member definitions] already holds the new ones when it fires. Definitions
## Tentacle sends again unchanged, as it does every time the session opens, do not fire
## it.
signal OnDefinitionsChanged()

## Every custom event the streamer configured, enabled or not, ordered by name.
## [code]chat_commands[/code] on each lists the chat commands that fire it, without the
## command prefix: the commands a trigger requires exactly.
var definitions: Array[TclCustomEventDefinition]:
	get:
		return _definitions.duplicate()

## Whether Tentacle has sent the definitions yet. Until it has, [member definitions] is
## empty.
var are_definitions_loaded: bool:
	get:
		return _are_definitions_loaded

## Every subscription, in the order it was made, which is the order handlers run in.
var _subscriptions: Array[_Subscription] = []

var _definitions: Array[TclCustomEventDefinition] = []
var _are_definitions_loaded: bool = false

## The last definitions as received, so ones sent again unchanged fire nothing.
var _definitions_key: String = ""


## Calls [param handler] for every custom event with this name.
##
## Names are matched case-insensitively by default, which is what a streamer typing a
## name into Tentacle expects; pass [param case_sensitive] to require an exact match.
## The handler is called as [code](event: TclCustomEvent, viewer: TclViewer)[/code];
## the viewer is null for an event no viewer triggered.
##
## Subscribing the same handler to the same name again subscribes it once, taking the
## newer [param case_sensitive].
func subscribe(event_name: String, handler: Callable, case_sensitive: bool = false) -> void:
	if event_name.is_empty() or not handler.is_valid():
		TentacleLog.error("a custom-event subscription needs a name and a valid handler")
		return
	for existing in _subscriptions:
		if existing.event_name == event_name and existing.handler == handler:
			existing.case_sensitive = case_sensitive
			return
	var subscription := _Subscription.new()
	subscription.event_name = event_name
	subscription.handler = handler
	subscription.case_sensitive = case_sensitive
	_subscriptions.append(subscription)


## Stops calling [param handler] for this name.
##
## The name is compared the way the subscription compares it: a case-insensitive
## subscription is ended by its name in any case, a case-sensitive one only by its
## exact name.
func unsubscribe(event_name: String, handler: Callable) -> void:
	for subscription in _subscriptions.duplicate():
		if subscription.handler == handler and subscription.matches(event_name):
			_subscriptions.erase(subscription)


## Every name currently subscribed to, as it was subscribed.
func subscribed_names() -> Array[String]:
	var out: Array[String] = []
	for subscription in _subscriptions:
		if not out.has(subscription.event_name):
			out.append(subscription.event_name)
	return out


## Drops every subscription.
func clear() -> void:
	_subscriptions.clear()


## The definition with this name, or null.
##
## Case-insensitive by default, the same rule [method subscribe] uses; pass
## [param case_sensitive] to require an exact match. When two definitions share a name,
## the first in [member definitions] is the one found.
func find_definition_by_name(event_name: String, case_sensitive: bool = false) -> TclCustomEventDefinition:
	if event_name.is_empty():
		return null
	for definition in _definitions:
		if case_sensitive and definition.name == event_name:
			return definition
		if not case_sensitive and definition.name.nocasecmp_to(event_name) == 0:
			return definition
	return null


## Takes the definitions a [code]CustomEvents_Definitions[/code] message carries.
func handle_definitions(data: Dictionary) -> void:
	# Tentacle sends the current definitions every time a session opens, so ones
	# identical to those held are not a change.
	var key := TclJson.to_text(data)
	if _are_definitions_loaded and key == _definitions_key:
		return

	_definitions.clear()
	for item in TclJson.read_array(data, "definitions"):
		var definition := TclCustomEventDefinition.parse(item)
		if definition != null:
			_definitions.append(definition)
	_are_definitions_loaded = true
	_definitions_key = key

	OnDefinitionsChanged.emit()


## Routes one inbound custom event.
func handle_event(payload: Dictionary, viewer: TclViewer) -> void:
	var custom_event := TclCustomEvent.parse(payload)
	if custom_event == null:
		# A malformed frame is dropped here rather than handed on, so a game's
		# handler never has to null-check what the signal promises is an event.
		return

	OnCustomEvent.emit(custom_event, viewer)

	# Iterated over a copy: a handler is allowed to unsubscribe itself, which would
	# otherwise mutate the array mid-loop.
	for subscription in _subscriptions.duplicate():
		if not subscription.matches(custom_event.name):
			continue
		if not subscription.handler.is_valid():
			continue
		# One throwing subscriber must not stop the others, and must not stop the
		# pump that delivered this.
		subscription.handler.call(custom_event, viewer)


## One handler listening for one name.
class _Subscription:
	var event_name: String = ""
	var handler: Callable = Callable()
	var case_sensitive: bool = false

	## True when an event called [param name] is one this subscription listens for.
	func matches(name: String) -> bool:
		if case_sensitive:
			return name == event_name
		return name.nocasecmp_to(event_name) == 0
