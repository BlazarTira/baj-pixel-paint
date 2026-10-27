class_name TentacleViewerPropertyEntry
extends RefCounted

## One viewer property's current value, as the addon holds it.
##
## Values travel keyed by **definition id**, not by name: names live only in the
## registry. That is why an entry carries ids and why resolving a name is the
## registry's job rather than this object's.

## The collection this value belongs to.
var collection_id: String = ""

## The definition this value belongs to.
var definition_id: String = ""

## The value itself. [Variant] because a definition's type is a runtime fact - the
## same entry shape carries a float, an int, a bool, or a String.
var value: Variant = null

## True when this is the definition's default rather than a value set for this
## viewer.
var is_default: bool = false

## True when the game wrote this value and Tentacle has not echoed it back yet.
##
## This is what makes an optimistic write survive a server snapshot that predates
## it. The flag is cleared when Tentacle confirms the value **and also when the
## write turns out to have failed** - without the second half, a failed write would
## make the game read its own value for the rest of the session while Tentacle held
## a different one.
var locally_modified: bool = false
