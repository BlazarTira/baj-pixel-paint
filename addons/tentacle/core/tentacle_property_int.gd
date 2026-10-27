class_name TentaclePropertyInt
extends TentaclePropertyOutcome

## A viewer-property read or write whose value is an int.
##
## [member value] is only meaningful when [method TentaclePropertyOutcome.is_ok]
## is true; on either failure it holds the type's zero value, so a caller that
## forgets to check reads something harmless rather than dereferencing a null.

## The property's value.
var value: int = 0
