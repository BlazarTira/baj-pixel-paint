class_name TentacleLog

## The addon's logging, in one place.
##
## Every line starts with [constant PREFIX], and there are three levels.
## [method info] is verbose-only, so a game's output is not full of session chatter.
## [method warn] is for something a developer should see but that the game survives,
## which is almost everything here: Tentacle being closed, a frame the app and the
## addon disagree about, a control value of the wrong shape. [method error] is for a
## mistake in the game's own code - registering a control with no label, say - where
## the call cannot do what was asked.
##
## Nothing here raises an engine error. A transport failure is an ordinary state
## (Tentacle is a desktop app the streamer opens and closes at will), and putting
## a developer in the debugger once a second while it is closed would be useless.
##
## All members are static; the class is never instantiated.

# The three levels match the Unity core's TentacleLog.

## The prefix every line carries, so a user can filter the addon out.
const PREFIX: String = "Tentacle: "


## Session chatter. Only reaches the output with verbose logging on.
static func info(message: String) -> void:
	print_verbose(PREFIX + message)


## Something worth seeing that the game survives.
static func warn(message: String) -> void:
	push_warning(PREFIX + message)


## A call that could not do what was asked.
static func error(message: String) -> void:
	# push_error rather than assert: this reports a mistake in the game's code
	# without halting, which matters for something that can be asked to do the
	# impossible every frame.
	push_error(PREFIX + message)
