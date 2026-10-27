class_name TentacleDeduplicator
extends RefCounted

## Remembers recent event ids so an event that arrives twice is delivered once.
##
## Tentacle sends stream events live and re-sends none after a reconnect, so this is
## a safeguard: a handler that spawns an actor or credits a viewer must not run twice
## for one event, however it came to arrive twice. The window is bounded because a
## long stream would otherwise accumulate ids for the life of the process.
##
## Stream events are de-duplicated; **custom events deliberately are not**, because
## a custom event is a command to act and the streamer firing the same one twice
## means twice.

## The default window, in event ids.
const DEFAULT_CAPACITY: int = 100

## How many ids to remember. Zero means no de-duplication at all.
var capacity: int = DEFAULT_CAPACITY:
	set(value):
		capacity = maxi(value, 0)
		if capacity == 0:
			# Turning it off mid-run must also release what it already holds.
			_order.clear()
			_seen.clear()
			return
		_evict()

var _order: Array[String] = []
var _seen: Dictionary[String, bool] = {}


## Records an id, reporting false when it has been seen before.
##
## An empty id is always delivered: there is nothing to key on, so it cannot be
## de-duplicated, and dropping it would lose a real event.
func remember(event_id: String) -> bool:
	if capacity == 0:
		# Gating only the eviction on this - which an earlier version did - left
		# both containers growing by one entry per event for the life of the
		# process, which is exactly the flood a window exists to bound.
		return true
	if event_id.is_empty():
		return true
	if _seen.has(event_id):
		return false

	_seen[event_id] = true
	_order.append(event_id)
	_evict()
	return true


## True when an id is currently remembered, without recording it.
func has_seen(event_id: String) -> bool:
	return _seen.has(event_id)


## How many ids are currently remembered.
func size() -> int:
	return _order.size()


## Forgets everything, e.g. on a deliberate disconnect.
func clear() -> void:
	_order.clear()
	_seen.clear()


func _evict() -> void:
	while _order.size() > capacity:
		_seen.erase(_order[0])
		_order.remove_at(0)
