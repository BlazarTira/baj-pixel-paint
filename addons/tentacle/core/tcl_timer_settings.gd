class_name TclTimerSettings
extends RefCounted

## How a timer runs, for [method Tentacle_Timers.create_timer] and
## [method Tentacle_Timers.update_timer]. Every setting is sent, so one you leave alone
## takes its default.

# The Unreal plugin's FTclTimerSettings, field for field, with the same defaults, so
# the same settings make the same timer in every engine.

## The timer's name, unique among the timers. On an update, empty keeps the timer's own
## name.
var name: String = ""

## Whether it starts its countdown again after it fires, rather than stopping.
var repeating: bool = true

## Whether it counts down only while the stream is live on a connected platform.
var only_while_live: bool = true

## The shortest countdown, in seconds, from 1 to 86400. Each countdown's length is drawn
## from the range; equal ends make it fixed.
var interval_min_seconds: int = 600

## The longest countdown, in seconds, from 1 to 86400.
var interval_max_seconds: int = 600

## How many viewer chat messages must come between two fires, up to 1000.
var min_chat_messages: int = 0


## Every setting as a create or an update sends it, the name only when it is not empty.
func to_input() -> Dictionary:
	var input := {
		"repeating": repeating,
		"onlyWhileLive": only_while_live,
		"intervalMinSeconds": interval_min_seconds,
		"intervalMaxSeconds": interval_max_seconds,
		"minChatMessages": min_chat_messages,
	}
	if not name.is_empty():
		input["name"] = name
	return input
