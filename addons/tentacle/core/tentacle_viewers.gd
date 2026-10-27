class_name Tentacle_Viewers
extends RefCounted

## Every viewer this session has been told about, keyed by viewer id.
##
## The point is **stable identity**: the same id always yields the same
## [TclViewer] instance, so a game can hold one on a spawned node and keep
## seeing fresh data through it.
##
## **Deliberately unbounded.** An eviction policy would break the guarantee the
## cache exists for - a game holding an evicted viewer would silently stop
## receiving updates - so removal and clearing are public instead, for a game that
## runs long enough to want to prune.

# Unreal's UTentacle_Viewers component and Unity's Tentacle_Viewers, member for member.
# Unreal also keeps the same calls on its ATentacle actor, forwarding here.

## Fires once the first time a viewer is seen, never on a refresh.
signal OnViewerAdded(viewer: TclViewer)

## How many distinct viewers have been seen this session.
var viewer_count: int:
	get:
		return _by_id.size()

## Every viewer, in the order they were first seen.
var all_viewers: Array[TclViewer]:
	get:
		var out: Array[TclViewer] = []
		for key in _by_id:
			out.append(_by_id[key])
		return out

var _by_id: Dictionary[String, TclViewer] = {}
var _properties: Tentacle_ViewerProperties = null


func _init(properties: Tentacle_ViewerProperties = null) -> void:
	_properties = properties


## The cached viewer with this id, or null when none has been seen.
func find_viewer_by_id(viewer_id: String) -> TclViewer:
	return _by_id.get(viewer_id, null)


## Folds a payload into the cache and returns the stable viewer object.
##
## Returns null for a payload with no id, which is the one case that cannot be
## cached: without an id there is nothing to be stable about.
func upsert_viewer(payload: Variant) -> TclViewer:
	if payload == null:
		# No viewer on the frame at all, which is ordinary for a custom event or a
		# channel update. Parsing it would warn about a malformed payload on every
		# such frame.
		return null

	var parsed := TclViewerData.parse(payload)
	if parsed == null or parsed.id.is_empty():
		return null

	var existing: TclViewer = _by_id.get(parsed.id, null)
	if existing != null:
		existing.apply_data(parsed)
		return existing

	var viewer := TclViewer.new()
	viewer.bind_registry(_properties)
	viewer.apply_data(parsed)
	_by_id[parsed.id] = viewer
	OnViewerAdded.emit(viewer)
	return viewer


## Drops one viewer. False when nothing was cached under that id.
func destroy_viewer(viewer_id: String) -> bool:
	return _by_id.erase(viewer_id)


## Drops every viewer.
func destroy_all_viewers() -> void:
	_by_id.clear()


## Points the cache, and every viewer already in it, at the property registry.
##
## Called once when the client wires itself together. Existing viewers are rebound
## too, so a cache built before the registry existed still resolves names.
func bind_registry(properties: Tentacle_ViewerProperties) -> void:
	_properties = properties
	for key in _by_id:
		_by_id[key].bind_registry(properties)
