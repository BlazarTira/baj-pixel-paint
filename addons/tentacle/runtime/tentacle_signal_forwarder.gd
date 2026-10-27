class_name TentacleSignalForwarder
extends RefCounted

## Re-emits the signals other objects declare as the same-named signals of one target.
##
## What [TentacleEventRelay], [TentacleTwitchEventRelay], and [TentacleKickEventRelay] are
## built on, and how the [code]Tentacle[/code] autoload raises its client's stream signals
## as its own. A game has no reason to use it directly.

# Signals are read off each source's script rather than listed by hand, so whatever a
# surface declares is forwarded; the relays' tests hold each relay's own declarations to
# exactly that set.

## Each connection made: [source object, signal name, forwarding callable].
var _connections: Array[Array] = []

var _target: Object = null


func _init(target: Object = null) -> void:
	_target = target


## Connects every signal [param source]'s script declares, inherited ones included, to
## the target's signal of the same name.
##
## A signal the target does not declare is left alone, and so is a name already
## forwarded from an earlier source: a name two sources share is forwarded from the first
## that declares it, so one signal on the target never stands for two different things.
func forward_every_signal_of(source: Object) -> void:
	if source == null or _target == null:
		return
	for entry in (source.get_script() as Script).get_script_signal_list():
		var signal_name := StringName(entry.get("name", ""))
		if not _target.has_signal(signal_name) or _forwards(signal_name):
			continue
		var forward := _forwarder((entry.get("args", []) as Array).size(), signal_name)
		source.connect(signal_name, forward)
		_connections.append([source, signal_name, forward])


## Disconnects everything [method forward_every_signal_of] connected.
func release() -> void:
	for connection in _connections:
		# A source can be gone already - a scene tearing down frees in its own order - and
		# a freed object has nothing left to disconnect.
		if not is_instance_valid(connection[0]):
			continue
		var source: Object = connection[0]
		if source.is_connected(connection[1], connection[2]):
			source.disconnect(connection[1], connection[2])
	_connections.clear()


## Whether a signal called [param signal_name] is already forwarded.
func _forwards(signal_name: StringName) -> bool:
	for connection in _connections:
		if connection[1] == signal_name:
			return true
	return false


## A callable that re-emits [param signal_name] on the target with [param arity]
## arguments.
##
## [method Callable.bind] appends its arguments after the ones the signal passes, so the
## name arrives last.
func _forwarder(arity: int, signal_name: StringName) -> Callable:
	match arity:
		0:
			return _forward_0.bind(signal_name)
		1:
			return _forward_1.bind(signal_name)
		2:
			return _forward_2.bind(signal_name)
	return _forward_3.bind(signal_name)


func _forward_0(signal_name: StringName) -> void:
	_target.emit_signal(signal_name)


func _forward_1(first: Variant, signal_name: StringName) -> void:
	_target.emit_signal(signal_name, first)


func _forward_2(first: Variant, second: Variant, signal_name: StringName) -> void:
	_target.emit_signal(signal_name, first, second)


func _forward_3(first: Variant, second: Variant, third: Variant, signal_name: StringName) -> void:
	_target.emit_signal(signal_name, first, second, third)
