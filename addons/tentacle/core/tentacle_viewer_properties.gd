class_name Tentacle_ViewerProperties
extends RefCounted

## Per-viewer values the streamer defined: scores, levels, currencies, flags.
##
## This is the **registry** half - collections, definitions, and the plumbing that
## sends a write. The reads and writes themselves hang off [TclViewer], because
## that is how a game thinks about them: "this viewer's score", not "the property
## service's opinion about this viewer".
##
## **A name nobody has defined is an error the caller sees**, not a silent new
## property. A game that wants a property of its own creates it, with
## [method create_property_int] and the rest.
##
## **The registry self-heals.** Values travel keyed by definition id; names live
## only here. A definition the streamer creates while the game is running arrives as
## an id the addon cannot name, and without a refresh every read of that property
## would fail for the rest of the session. So an unknown id asks for one refresh,
## single-flight, and a busy stream cannot spin the backend.

# Unreal's UTentacle_ViewerProperties and Unity's Tentacle_ViewerProperties. The
# completion of an asynchronous call reaches its callback rather than a signal of its
# own, as Unity's reaches the task it returns.

## Fires once, the first time the registry loads.
signal OnInitialLoadComplete()

## Fires on every successful registry load, including the first.
signal OnCollectionsRefreshed()

## One viewer's property value changed, whether from Tentacle or a local write.
signal OnViewerPropertyUpdated(
	collection: TclViewerPropertyCollection,
	viewer: TclViewer,
	definition: TclViewerPropertyDefinition,
)

## True once the registry has loaded at least once.
var is_initial_load_complete: bool = false

## Every collection the streamer has defined.
var collections: Array[TclViewerPropertyCollection]:
	get:
		return _collections.duplicate()

## Every definition across every collection.
var definitions: Array[TclViewerPropertyDefinition]:
	get:
		return _definitions.duplicate()

var _collections: Array[TclViewerPropertyCollection] = []
var _definitions: Array[TclViewerPropertyDefinition] = []

## Definition ids seen on the wire that the registry could not name. Kept so one
## refresh is requested per id rather than one per event carrying it.
var _unknown_definition_ids: Dictionary[String, bool] = {}

## True while a refresh is outstanding, which is what makes it single-flight.
var _refreshing: bool = false

var _rpc: TentacleRpc = null

## The viewer cache, which a reset updates and a leaderboard folds its viewers into.
var _viewers: Tentacle_Viewers:
	get:
		return _viewers_ref.get_ref() as Tentacle_Viewers if _viewers_ref != null else null

# Held weakly because the cache, and every viewer in it, holds this registry: two
# RefCounted objects that hold each other are never freed, so the client's whole
# surface, its session and transport included, outlived the game that let it go.
var _viewers_ref: WeakRef = null


func _init(rpc: TentacleRpc = null) -> void:
	_rpc = rpc


## Points the registry at the RPC client. Called when the client wires itself up.
func bind_rpc(rpc: TentacleRpc) -> void:
	_rpc = rpc


## Points the registry at the viewer cache. Called when the client wires itself up.
func bind_viewers(viewers: Tentacle_Viewers) -> void:
	_viewers_ref = weakref(viewers) if viewers != null else null


# --- Lookups -----------------------------------------------------------------

## The collection with this name, or null.
##
## Case-insensitive by default, which is what a streamer typing a name into
## Tentacle expects.
func find_collection_by_name(
	collection_name: String,
	case_sensitive: bool = false,
) -> TclViewerPropertyCollection:
	for collection in _collections:
		if _names_match(collection.name, collection_name, case_sensitive):
			return collection
	return null


## The collection with this id, or null.
func find_collection_by_id(collection_id: String) -> TclViewerPropertyCollection:
	for collection in _collections:
		if collection.id == collection_id:
			return collection
	return null


## The definition with this name inside this collection, or null.
##
## Case-insensitive by default, for both names.
func find_definition_by_name(
	collection_name: String,
	property_name: String,
	case_sensitive: bool = false,
) -> TclViewerPropertyDefinition:
	var collection := find_collection_by_name(collection_name, case_sensitive)
	if collection == null:
		return null
	for definition in _definitions:
		if definition.collection_id != collection.id:
			continue
		if _names_match(definition.name, property_name, case_sensitive):
			return definition
	return null


## The definition with this id, or null. Used when folding wire values in.
func find_definition_by_id(definition_id: String) -> TclViewerPropertyDefinition:
	for definition in _definitions:
		if definition.id == definition_id:
			return definition
	return null


# --- Registry loading --------------------------------------------------------

## Fetches the registry.
##
## [param on_complete] is optional and called with a single bool. Concurrent calls
## collapse: while one fetch is outstanding, another returns immediately rather than
## issuing a second request.
func refresh_registry(on_complete: Callable = Callable()) -> void:
	if _rpc == null:
		if on_complete.is_valid():
			on_complete.call(false)
		return
	if _refreshing:
		if on_complete.is_valid():
			on_complete.call(false)
		return

	_refreshing = true
	_rpc.call_procedure(
		"viewerProperty.getRegistry",
		true,
		"",
		func(success: bool, _status: int, body: String, error: String) -> void:
			_refreshing = false
			if not success:
				# Not an error a game can act on: the registry is retried on the
				# next connect and on demand.
				TentacleLog.info("could not load the viewer-property registry: " + error)
				if on_complete.is_valid():
					on_complete.call(false)
				return
			var applied := _apply_registry_body(body)
			if on_complete.is_valid():
				on_complete.call(applied)
	)


## Records a definition id the registry cannot name, and asks for one refresh.
func note_unknown_definition(definition_id: String) -> void:
	if definition_id.is_empty() or _unknown_definition_ids.has(definition_id):
		return
	_unknown_definition_ids[definition_id] = true
	TentacleLog.info(
		'refreshing the viewer-property registry for unknown definition "%s"' % definition_id
	)
	refresh_registry()


# "The registry has not loaded" is deliberately not an outcome (see the maintainer note in
# tcl_find_property_result.gd), but asking for the load is free.
## Logs a name that could not be resolved, and asks for a refresh once.
##
## The counterpart of [method note_unknown_definition] for the other direction: the
## game naming something the registry has not heard of. The read still answers
## [constant TclFindPropertyResult.Value.COLLECTION_NOT_FOUND].
func report_unresolved(collection_name: String, property_name: String) -> void:
	TentacleLog.info(
		'no viewer-property collection named "%s" (looking for "%s")'
		% [collection_name, property_name]
	)
	if not is_initial_load_complete:
		refresh_registry()


# --- Writes ------------------------------------------------------------------

## Sends one optimistic write to Tentacle.
##
## Called by [TclViewer] after it has already applied the value locally. A
## failed write releases the entry's hold, so the game stops reading its own value
## while Tentacle holds a different one.
func send_value(viewer: TclViewer, entry: TentacleViewerPropertyEntry) -> void:
	if _rpc == null or viewer == null or entry == null:
		return

	# The procedure takes a batch - an array of writes - and refuses a bare object, so
	# even one write travels as a one-element array. The definition id alone identifies
	# the property; the collection is implied by it.
	var input := TclJson.to_text([{
		"viewerId": viewer.viewer_id,
		"definitionId": entry.definition_id,
		"value": entry.value,
	}])
	_rpc.call_procedure(
		"viewerProperty.setForViewer",
		false,
		input,
		func(success: bool, _status: int, _body: String, error: String) -> void:
			if success:
				return
			TentacleLog.warn("a viewer-property write failed: " + error)
			# Releasing the hold is the half that is easy to forget: without it the
			# game would read its own rejected value for the rest of the session.
			var current := viewer.find_entry(entry.collection_id, entry.definition_id)
			if current != null:
				current.locally_modified = false
	)


# The Unity and Unreal plugins reset their cached viewers the same way: only once
# Tentacle confirms.
## Resets every value in a collection to its definition's default, for every viewer.
##
## [param on_complete] is optional and called with a single bool. The cached viewers
## are reset **only once Tentacle confirms**, raising [signal OnViewerPropertyUpdated]
## for each value that changed: a local reset on a failed request would show every
## viewer at a default the app never applied.
func reset_collection_values(collection_name: String, on_complete: Callable = Callable()) -> void:
	var collection := find_collection_by_name(collection_name)
	if collection == null:
		TentacleLog.warn('cannot reset unknown collection "%s"' % collection_name)
		if on_complete.is_valid():
			on_complete.call(false)
		return
	_mutate(
		"viewerProperty.resetCollectionValues",
		TclJson.to_text({"collectionId": collection.id}),
		func(success: bool) -> void:
			if success:
				for definition in _definitions.duplicate():
					if definition.collection_id == collection.id:
						_reset_locally(collection, definition)
			if on_complete.is_valid():
				on_complete.call(success)
	)


## Resets one property's values, across every viewer, to its default.
##
## Confirmed the same way as [method reset_collection_values].
func reset_property_values(
	collection_name: String,
	property_name: String,
	on_complete: Callable = Callable(),
) -> void:
	var definition := find_definition_by_name(collection_name, property_name)
	if definition == null:
		TentacleLog.warn('cannot reset unknown property "%s"' % property_name)
		if on_complete.is_valid():
			on_complete.call(false)
		return
	_mutate(
		"viewerProperty.resetPropertyValues",
		TclJson.to_text({"definitionId": definition.id}),
		func(success: bool) -> void:
			if success:
				_reset_locally(find_collection_by_id(definition.collection_id), definition)
			if on_complete.is_valid():
				on_complete.call(success)
	)


# --- Changing the definitions --------------------------------------------------

# Unreal's CreateCollection, RenameCollection, DeleteCollection, CreateProperty_<Type>,
# SetPropertyDefault_<Type>, RenameProperty, and DeleteProperty, and Unity's *Async
# counterparts. Each names what it acts on through the registry, under the usual case
# rule, and sends Tentacle its id; each reloads the registry after a change is made, so
# the name it introduced resolves by the time on_complete is called.

## Creates a collection.
##
## Configuring viewer properties in Tentacle and shipping its export is the easier way to
## give a game the properties it needs; this is for ones the game decides on as it runs.
## [param on_complete] is called once with a [enum TclDefinitionResult.Value]: SUCCESS,
## NAME_TAKEN when another collection has the name, or FAILED (the reason is logged).
## After a change is made the registry is reloaded first, and so for every change below.
func create_collection(collection_name: String, on_complete: Callable = Callable()) -> void:
	_change("viewerProperty.createCollection", {"name": collection_name}, on_complete)


## Renames a collection. [param on_complete] is called once with SUCCESS, NOT_FOUND,
## NAME_TAKEN when another collection has the new name, or FAILED.
func rename_collection(
	collection_name: String,
	new_name: String,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	var collection := _resolve_collection(collection_name, case_sensitive, on_complete)
	if collection != null:
		_change("viewerProperty.renameCollection", {"collectionId": collection.id, "name": new_name}, on_complete)


## Deletes a collection, its properties, and every viewer's values for them.
## [param on_complete] is called once with SUCCESS, NOT_FOUND, or FAILED.
func delete_collection(
	collection_name: String,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	var collection := _resolve_collection(collection_name, case_sensitive, on_complete)
	if collection != null:
		_change("viewerProperty.deleteCollection", {"collectionId": collection.id}, on_complete)


## Creates a whole-number property in a collection, which every viewer has at
## [param default_value] until a value of their own is written. [param on_complete] is
## called once with SUCCESS, NOT_FOUND when there is no such collection, NAME_TAKEN when
## the collection already has a property by that name, or FAILED.
func create_property_int(
	collection_name: String,
	property_name: String,
	default_value: int,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	_create_property(collection_name, property_name, "int", default_value, on_complete, case_sensitive)


## Creates a floating-point property in a collection; see [method create_property_int].
func create_property_float(
	collection_name: String,
	property_name: String,
	default_value: float,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	_create_property(collection_name, property_name, "float", default_value, on_complete, case_sensitive)


## Creates a boolean property in a collection; see [method create_property_int].
func create_property_bool(
	collection_name: String,
	property_name: String,
	default_value: bool,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	_create_property(collection_name, property_name, "bool", default_value, on_complete, case_sensitive)


## Creates a string property in a collection; see [method create_property_int].
func create_property_string(
	collection_name: String,
	property_name: String,
	default_value: String,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	_create_property(collection_name, property_name, "string", default_value, on_complete, case_sensitive)


## Changes a whole-number property's default, which every viewer without a value of their
## own then has. [param on_complete] is called once with SUCCESS, NOT_FOUND, or FAILED,
## including when the property is not a whole-number one (the log says which type it is).
func set_property_default_int(
	collection_name: String,
	property_name: String,
	default_value: int,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	_set_property_default(collection_name, property_name, TclViewerPropertyType.Value.INT, default_value, on_complete, case_sensitive)


## Changes a floating-point property's default; see [method set_property_default_int].
func set_property_default_float(
	collection_name: String,
	property_name: String,
	default_value: float,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	_set_property_default(collection_name, property_name, TclViewerPropertyType.Value.FLOAT, default_value, on_complete, case_sensitive)


## Changes a boolean property's default; see [method set_property_default_int].
func set_property_default_bool(
	collection_name: String,
	property_name: String,
	default_value: bool,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	_set_property_default(collection_name, property_name, TclViewerPropertyType.Value.BOOL, default_value, on_complete, case_sensitive)


## Changes a string property's default; see [method set_property_default_int].
func set_property_default_string(
	collection_name: String,
	property_name: String,
	default_value: String,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	_set_property_default(collection_name, property_name, TclViewerPropertyType.Value.STRING, default_value, on_complete, case_sensitive)


## Renames a property, keeping every viewer's value for it. [param on_complete] is called
## once with SUCCESS, NOT_FOUND, NAME_TAKEN when the collection has another property by
## the new name, or FAILED.
func rename_property(
	collection_name: String,
	property_name: String,
	new_name: String,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	var definition := _resolve_property(collection_name, property_name, case_sensitive, on_complete)
	if definition != null:
		_change("viewerProperty.renameDefinition", {"definitionId": definition.id, "name": new_name}, on_complete)


## Deletes a property and every viewer's value for it. [param on_complete] is called once
## with SUCCESS, NOT_FOUND, or FAILED.
func delete_property(
	collection_name: String,
	property_name: String,
	on_complete: Callable = Callable(),
	case_sensitive: bool = false,
) -> void:
	var definition := _resolve_property(collection_name, property_name, case_sensitive, on_complete)
	if definition != null:
		_change("viewerProperty.deleteDefinition", {"definitionId": definition.id}, on_complete)


# Unreal's FetchViewersByDefinition(CollectionName, PropertyName, PropertyType,
# OrderDirection, Take), in that order, and Unity's FetchViewersByDefinitionAsync; the
# callback comes last, where every other asynchronous call here takes it. Unreal only
# echoes PropertyType back through its completion delegate. A callback made per call
# needs no echo, so here it checks the caller's expectation instead.
## Fetches the viewers ranked by one property, for a leaderboard.
##
## [param property_type] is the type you expect the property to hold; a property the
## streamer defined as another type is still ranked, with a warning in the log.
## [param on_complete] receives an [Array] of [TclViewer]: the cached instances, in the
## server's order, so a leaderboard entry is the same object a game already holds for
## that viewer and its values are folded in. A property the streamer has not defined,
## or a failed fetch, hands back an empty array rather than nothing - a leaderboard
## that cannot be fetched shows nobody. By default it fetches the ten highest values.
##
## [codeblock]
## Tentacle.viewer_properties.fetch_viewers_by_definition(
##     "Stats", "Score", TclViewerPropertyType.Value.INT,
##     TclOrderDirection.Value.DESC, 10, _show_leaderboard)
## [/codeblock]
func fetch_viewers_by_definition(
	collection_name: String,
	property_name: String,
	property_type: TclViewerPropertyType.Value,
	order_direction: TclOrderDirection.Value = TclOrderDirection.Value.DESC,
	take: int = 10,
	on_complete: Callable = Callable(),
) -> void:
	var definition := find_definition_by_name(collection_name, property_name)
	if definition == null or _rpc == null:
		if definition == null:
			TentacleLog.warn(
				'no viewer property "%s" in collection "%s"' % [property_name, collection_name]
			)
		if on_complete.is_valid():
			on_complete.call([] as Array[TclViewer])
		return
	if definition.type != property_type:
		TentacleLog.warn(
			'viewer property "%s" holds %s values, not %s; ranking it anyway'
			% [
				property_name,
				TclViewerPropertyType.to_wire(definition.type),
				TclViewerPropertyType.to_wire(property_type),
			]
		)

	var input := TclJson.to_text({
		"definitionId": definition.id,
		"orderDirection": TclOrderDirection.to_wire(order_direction),
		"take": take,
	})
	_rpc.call_procedure(
		"viewerProperty.getViewersByDefinition",
		true,
		input,
		func(success: bool, _status: int, body: String, error: String) -> void:
			var out: Array[TclViewer] = []
			if not success:
				TentacleLog.info("could not fetch viewers by definition: " + error)
				if on_complete.is_valid():
					on_complete.call(out)
				return
			var parsed := TclJson.parse_text(body)
			if TclJson.is_object(parsed):
				var data := TclJson.read_object(
					TclJson.read_object(TclJson.as_dictionary(parsed), "result"), "data"
				)
				for item in TclJson.read_array(data, "viewers"):
					var viewers := _viewers
					var viewer: TclViewer = viewers.upsert_viewer(item) if viewers != null else null
					if viewer != null:
						out.append(viewer)
			if on_complete.is_valid():
				on_complete.call(out)
	)


# --- Internals ---------------------------------------------------------------

## Raises [signal OnViewerPropertyUpdated] for one entry, resolving its ids to objects.
func notify_value_changed(
	viewer: TclViewer,
	entry: TentacleViewerPropertyEntry,
) -> void:
	if viewer == null or entry == null:
		return
	var definition := find_definition_by_id(entry.definition_id)
	if definition == null:
		# An id the registry cannot name yet. Ask for a refresh and stay quiet:
		# raising with a null definition would make every handler null-check.
		note_unknown_definition(entry.definition_id)
		return
	OnViewerPropertyUpdated.emit(find_collection_by_id(entry.collection_id), viewer, definition)


## Replaces the registry from a tRPC response body.
func _apply_registry_body(body: String) -> bool:
	var parsed := TclJson.parse_text(body)
	if not TclJson.is_object(parsed):
		return false
	var data := TclJson.read_object(
		TclJson.read_object(TclJson.as_dictionary(parsed), "result"), "data"
	)
	var registry := TclViewerPropertyRegistry.parse(data)
	if registry == null:
		return false

	_collections.clear()
	for collection in registry.collections:
		_collections.append(collection)
	_definitions.clear()
	for definition in registry.definitions:
		_definitions.append(definition)

	# Anything previously unnameable may be nameable now, so the set is cleared
	# rather than kept: holding stale ids would suppress a later, legitimate refresh.
	_unknown_definition_ids.clear()

	var was_first := not is_initial_load_complete
	is_initial_load_complete = true
	OnCollectionsRefreshed.emit()
	if was_first:
		OnInitialLoadComplete.emit()
	return true


## Puts one definition back to its default on every cached viewer that holds a value
## for it, raising [signal OnViewerPropertyUpdated] for each.
func _reset_locally(
	collection: TclViewerPropertyCollection,
	definition: TclViewerPropertyDefinition,
) -> void:
	var viewers := _viewers
	if viewers == null or collection == null or definition == null:
		return
	for viewer in viewers.all_viewers:
		if viewer.reset_to_default(collection.id, definition.id, definition.value):
			OnViewerPropertyUpdated.emit(collection, viewer, definition)


func _mutate(procedure: String, input: String, on_complete: Callable) -> void:
	if _rpc == null:
		if on_complete.is_valid():
			on_complete.call(false)
		return
	_rpc.call_procedure(
		procedure,
		false,
		input,
		func(success: bool, _status: int, _body: String, error: String) -> void:
			if not success:
				TentacleLog.warn("%s failed: %s" % [procedure, error])
			if on_complete.is_valid():
				on_complete.call(success)
	)


## Creates a property of one type in a collection named through the registry.
func _create_property(
	collection_name: String,
	property_name: String,
	type: String,
	default_value: Variant,
	on_complete: Callable,
	case_sensitive: bool,
) -> void:
	var collection := _resolve_collection(collection_name, case_sensitive, on_complete)
	if collection == null:
		return
	_change(
		"viewerProperty.createDefinition",
		{"collectionId": collection.id, "name": property_name, "type": type, "defaultValue": default_value},
		on_complete,
	)


## Changes a property's default, after checking it is of the type the caller wrote it as:
## Tentacle would store a value of another type as given.
func _set_property_default(
	collection_name: String,
	property_name: String,
	type: TclViewerPropertyType.Value,
	default_value: Variant,
	on_complete: Callable,
	case_sensitive: bool,
) -> void:
	var definition := _resolve_property(collection_name, property_name, case_sensitive, on_complete)
	if definition == null:
		return
	if definition.type != type:
		TentacleLog.warn(
			'viewer property "%s/%s" is of type %s, so its default cannot be set as %s; nothing changed'
			% [collection_name, property_name, TclViewerPropertyType.to_wire(definition.type), TclViewerPropertyType.to_wire(type)]
		)
		TentacleDefinitionChange.finish(on_complete, TclDefinitionResult.Value.FAILED)
		return
	_change("viewerProperty.updateDefinition", {"definitionId": definition.id, "defaultValue": default_value}, on_complete)


## The collection with this name, or null after calling [param on_complete] with why:
## NOT_FOUND when there is no such collection, FAILED when the registry has not loaded,
## which says nothing about the name (a load is requested, as a read would).
func _resolve_collection(collection_name: String, case_sensitive: bool, on_complete: Callable) -> TclViewerPropertyCollection:
	if not is_initial_load_complete:
		TentacleLog.warn(
			'the viewer-property registry has not loaded yet, so the collection "%s" cannot be found; a load has been requested'
			% collection_name
		)
		refresh_registry()
		TentacleDefinitionChange.finish(on_complete, TclDefinitionResult.Value.FAILED)
		return null
	var collection := find_collection_by_name(collection_name, case_sensitive)
	if collection == null:
		TentacleDefinitionChange.finish(on_complete, TclDefinitionResult.Value.NOT_FOUND)
	return collection


## The property with this name in this collection, or null after calling
## [param on_complete] with why, as for a collection.
func _resolve_property(
	collection_name: String,
	property_name: String,
	case_sensitive: bool,
	on_complete: Callable,
) -> TclViewerPropertyDefinition:
	var collection := _resolve_collection(collection_name, case_sensitive, on_complete)
	if collection == null:
		return null
	for definition in _definitions:
		if definition.collection_id == collection.id and _names_match(definition.name, property_name, case_sensitive):
			return definition
	TentacleDefinitionChange.finish(on_complete, TclDefinitionResult.Value.NOT_FOUND)
	return null


## Makes one change, and reloads the registry once it is made before reporting it. A
## reload that fails keeps the registry the game had and is logged; the change was still
## made, so it still reports SUCCESS.
func _change(procedure: String, input: Dictionary, on_complete: Callable) -> void:
	TentacleDefinitionChange.change(
		_rpc,
		procedure,
		input,
		func(result: TclDefinitionResult.Value) -> void:
			if result != TclDefinitionResult.Value.SUCCESS:
				TentacleDefinitionChange.finish(on_complete, result)
				return
			refresh_registry(func(_loaded: bool) -> void:
				TentacleDefinitionChange.finish(on_complete, result)
			)
	)


static func _names_match(left: String, right: String, case_sensitive: bool) -> bool:
	if case_sensitive:
		return left == right
	return left.nocasecmp_to(right) == 0
