class_name Tentacle_Subathon
extends RefCounted

## The subathon counters Tentacle keeps: subscriptions, gifted subscriptions, and
## donations, each with its goal. Reached as [code]Tentacle.subathon[/code].
##
## [b]Internal only, and not working yet:[/b] the subathon counters behind these fetches
## are unfinished, so do not build on them.
##
## Each fetch is asynchronous: call it with a callback, and the callback runs once, with
## the counter's stats, or with null when the fetch failed.

# A surface of its own on the entry point, because a subathon is Tentacle's feature
# rather than Twitch's, so its fetches carry no Twitch in their name or their place.
# Unreal's deprecated Stream component carries these as FetchTwitchSubathon*, and its
# Twitch component has none. The counters are unfinished, so every doc comment says so
# and the user docs page for them is unlisted.

var _rpc: TentacleRpc = null


func _init(rpc: TentacleRpc = null) -> void:
	_rpc = rpc


## Points this surface at a different RPC transport. The [code]Tentacle[/code] autoload
## calls this itself, rebinding the surface in place.
func bind_rpc(rpc: TentacleRpc) -> void:
	# Exists so the engine layer can supply a real HTTP client once its node is in the
	# tree without replacing this object, which a game may already hold.
	_rpc = rpc


## Fetches the subscription counter. [b]Internal only, and not working yet:[/b] the
## subathon counters behind it are unfinished, so do not build on it.
##
## [param on_complete] is called once with a [TclSubathonStats_Subscriptions], or with
## null when the fetch failed, so a caller always hears back.
func fetch_subscriptions(on_complete: Callable) -> void:
	_fetch("subathonStats.subs", TclSubathonStats_Subscriptions.parse, on_complete)


## Fetches the gifted-subscription counter. [b]Internal only, and not working yet:[/b]
## the subathon counters behind it are unfinished, so do not build on it.
##
## [param on_complete] is called once with a [TclSubathonStats_GiftedSubscriptions], or
## with null when the fetch failed.
func fetch_gifted_subscriptions(on_complete: Callable) -> void:
	_fetch("subathonStats.giftedSubs", TclSubathonStats_GiftedSubscriptions.parse, on_complete)


## Fetches the donation counter, in dollars. [b]Internal only, and not working yet:[/b]
## the subathon counters behind it are unfinished, so do not build on it.
##
## [param on_complete] is called once with a [TclSubathonStats_Donations], or with null
## when the fetch failed.
func fetch_donations(on_complete: Callable) -> void:
	_fetch("subathonStats.donations", TclSubathonStats_Donations.parse, on_complete)


# Unreal's subathon completion delegates carry the three numbers; Unity's fetches return
# the generated stats type, and so does this, so the unlocks and top viewers the server
# sends reach a game too.
## Runs one subathon query, parsing the tRPC result with [param parse] - one of the
## generated [code]TclSubathonStats_*[/code] parsers - and handing [param on_complete]
## what it made, or null when the fetch failed.
func _fetch(procedure: String, parse: Callable, on_complete: Callable) -> void:
	if not on_complete.is_valid():
		return
	if _rpc == null:
		on_complete.call(null)
		return
	_rpc.call_procedure(
		procedure,
		true,
		"",
		func(success: bool, _status: int, body: String, error: String) -> void:
			if not success:
				TentacleLog.info("could not fetch %s: %s" % [procedure, error])
				on_complete.call(null)
				return
			var parsed := TclJson.parse_text(body)
			if not TclJson.is_object(parsed):
				on_complete.call(null)
				return
			# tRPC wraps a query result as {result: {data: ...}}.
			var data: Variant = TclJson.read_value(
				TclJson.read_object(TclJson.as_dictionary(parsed), "result"), "data"
			)
			on_complete.call(parse.call(data))
	)
