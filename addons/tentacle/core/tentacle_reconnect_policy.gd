class_name TentacleReconnectPolicy
extends RefCounted

## How long to wait before the next connection attempt.
##
## Capped exponential backoff with additive jitter: [method delay_for] takes a failure
## count and a jitter fraction and returns a delay. The session passes
## [method @GlobalScope.randf] as the jitter; pass 0.0 for an exact number.
## [member TentacleRuntime.reconnect_initial_delay] and
## [member TentacleRuntime.reconnect_max_delay] set [member initial_delay] and
## [member max_delay].

# Deliberately a separate object with no clock of its own, which makes every case - the
# first retry, the ceiling, the jitter bounds - testable without waiting for anything.
# The jitter is supplied by the caller rather than drawn here for the same reason.

## The shortest delay the policy will honour, in seconds.
##
## A floor rather than a preference: the backoff multiplies, so a zero initial
## delay stays zero forever, never reaches the ceiling, and retries every frame
## for as long as Tentacle is closed. Four attempts a second is already far more
## than a loopback socket needs.
const MIN_DELAY_SECONDS: float = 0.25

## How much of the delay jitter may add. It never subtracts, so a fleet of clients
## spreads out rather than some of them retrying sooner than the policy intends.
const JITTER_FRACTION: float = 0.25

## The multiplier applied per consecutive failure.
const BACKOFF_MULTIPLIER: float = 2.0

## The delay before the first retry.
var initial_delay: float = 1.0:
	set(value):
		initial_delay = maxf(value, MIN_DELAY_SECONDS)
		# The ceiling must stay at or above the floor, or the backoff has no room
		# to grow and every attempt fires at the minimum.
		max_delay = maxf(max_delay, initial_delay)

## The ceiling the delay backs off to.
var max_delay: float = 30.0:
	set(value):
		max_delay = maxf(value, maxf(initial_delay, MIN_DELAY_SECONDS))


## The delay after [param failures] consecutive failures.
##
## [param jitter] is a 0..1 fraction, normally [method @GlobalScope.randf]; pass
## 0.0 for a deterministic result.
func delay_for(failures: int, jitter: float = 0.0) -> float:
	var delay := initial_delay
	# Loops rather than using pow(), and breaks at the ceiling: the failure count
	# grows without bound while Tentacle is closed, and multiplying to infinity
	# first would lose the cap to a float overflow.
	for _i in range(1, maxi(failures, 1)):
		delay *= BACKOFF_MULTIPLIER
		if delay >= max_delay:
			delay = max_delay
			break
	delay = minf(delay, max_delay)
	return delay + delay * JITTER_FRACTION * clampf(jitter, 0.0, 1.0)
