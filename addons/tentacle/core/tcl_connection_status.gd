class_name TclConnectionStatus

## Where the Tentacle session currently is.
##
## Read it from [member TentacleRuntime.connection_status], or follow it through
## [signal TentacleRuntime.OnConnectionStatusChanged]. A game that only needs to know
## whether it is connected can check for [constant Value.CONNECTED] alone.

# Named after Unreal's ETclConnectionStatus minus its prefix, as Unity's
# TclConnectionStatus is - ConnectionStatus, not ConnectionState, so a game ported
# between engines keeps its vocabulary.
#
# DISCONNECTED and CONNECTED are the two every plugin has. CONNECTING and RECONNECTING
# are a superset Unity also carries, and they are only a superset because a game that
# checks solely for CONNECTED behaves identically either way.

enum Value {
	## Not connected and not trying.
	DISCONNECTED,
	## A socket is opening, or the handshake is outstanding.
	CONNECTING,
	## The handshake completed; the session is live.
	CONNECTED,
	## Waiting out the backoff before the next attempt.
	RECONNECTING,
}


## A human-readable name, for logs and for a status readout in a scene.
static func to_text(value: Value) -> String:
	match value:
		Value.DISCONNECTED:
			return "Disconnected"
		Value.CONNECTING:
			return "Connecting"
		Value.CONNECTED:
			return "Connected"
		Value.RECONNECTING:
			return "Reconnecting"
	return "Unknown"
