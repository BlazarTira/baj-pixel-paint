class_name TclSignInStage

## Where a sign-in button's platform stands, which decides what pressing it does.

# Named after Unreal's ETclSignInStage minus its prefix; Unity's is SignInStage, its Tcl
# dropped for the namespace.

enum Value {
	## Signing in is not available here: Tentacle runs in the Tentacle app.
	UNAVAILABLE,
	## Tentacle is starting and has not said how the platform stands yet.
	WAITING,
	## No account is signed in. Pressing signs the player in.
	NOT_CONNECTED,
	## The player is signing in in their browser. Pressing cancels.
	SIGNING_IN,
	## An account is signed in and the platform is connecting. Pressing disconnects.
	CONNECTING,
	## An account is signed in and connected. Pressing disconnects.
	CONNECTED,
	## The account has to sign in again before it can connect. Pressing signs the player
	## in.
	NEEDS_RECONNECT,
}


## A human-readable name, for logs: [code]NotConnected[/code], as Unreal spells it.
static func to_text(value: Value) -> String:
	match value:
		Value.UNAVAILABLE:
			return "Unavailable"
		Value.WAITING:
			return "Waiting"
		Value.NOT_CONNECTED:
			return "NotConnected"
		Value.SIGNING_IN:
			return "SigningIn"
		Value.CONNECTING:
			return "Connecting"
		Value.CONNECTED:
			return "Connected"
		Value.NEEDS_RECONNECT:
			return "NeedsReconnect"
	return "Unknown"
