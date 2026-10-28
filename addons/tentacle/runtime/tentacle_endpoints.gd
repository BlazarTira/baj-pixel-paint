class_name TentacleEndpoints
extends RefCounted

## Where Tentacle is listening.
##
## Tentacle writes a [code]sidecar.json[/code] beside its database naming the ports
## its two listeners actually bound, because neither is guaranteed: a taken port
## costs the app the default address rather than its boot. The addon reads that file
## and falls back to the compiled-in defaults for whichever half it cannot resolve -
## **per field**, because the sidecar falls back independently for each.
##
## Everything here degrades. A missing file means Tentacle is not installed or has
## never run; an unreadable one means it is starting up right now and rewriting it; a
## truncated one means it was read mid-write. None of those is worth telling a game
## about - they all mean "not available yet", and the session simply retries.

# The discovery file is read the same way the Unreal and Unity plugins read it. This is
# engine-layer rather than core because it reads the filesystem and the environment.

## The port Tentacle's HTTP API uses when it is free.
const DEFAULT_HTTP_PORT: int = 47821

## The port Tentacle's engine socket uses when it is free.
const DEFAULT_ENGINE_PORT: int = 47822

## The discovery file Tentacle writes beside its database.
const DISCOVERY_FILE_NAME: String = "sidecar.json"

## Tentacle's data folder name, the same on every platform.
const DATA_FOLDER_NAME: String = "Tentacle"

## The HTTP root, e.g. [code]http://127.0.0.1:47821[/code].
var http_base_url: String = default_http_base_url()

## The engine socket URL, e.g. [code]ws://127.0.0.1:47822[/code].
var engine_socket_url: String = default_engine_socket_url()

## True when at least one endpoint came from the discovery file.
var from_discovery_file: bool = false


## The compiled-in HTTP root, used when discovery yields nothing.
static func default_http_base_url() -> String:
	return "http://127.0.0.1:%d" % DEFAULT_HTTP_PORT


## The compiled-in engine socket URL, used when discovery yields nothing.
static func default_engine_socket_url() -> String:
	return "ws://127.0.0.1:%d" % DEFAULT_ENGINE_PORT


# Tentacle ships on Windows and macOS with Linux planned, so all three are resolved here
# rather than assuming one. A missing home directory is not worth warning about.
## Tentacle's data directory for this platform: [code]%APPDATA%/Tentacle[/code] on
## Windows, [code]~/Library/Application Support/Tentacle[/code] on macOS, and
## [code]$XDG_DATA_HOME/Tentacle[/code] (or [code]~/.local/share/Tentacle[/code])
## elsewhere.
##
## Returns an empty String when the environment does not name a home directory.
static func default_data_directory() -> String:
	match OS.get_name():
		"Windows":
			var app_data := OS.get_environment("APPDATA")
			if app_data.is_empty():
				return ""
			return app_data.path_join(DATA_FOLDER_NAME)
		"macOS":
			var home := OS.get_environment("HOME")
			if home.is_empty():
				return ""
			return home.path_join("Library/Application Support").path_join(DATA_FOLDER_NAME)
		_:
			# Linux and the BSDs, following the XDG base-directory spec, which
			# ignores a relative XDG_DATA_HOME, as the app does.
			var xdg := OS.get_environment("XDG_DATA_HOME")
			if xdg.begins_with("/"):
				return xdg.path_join(DATA_FOLDER_NAME)
			var unix_home := OS.get_environment("HOME")
			if unix_home.is_empty():
				return ""
			return unix_home.path_join(".local/share").path_join(DATA_FOLDER_NAME)


## Resolves the endpoints, reading the discovery file when one is readable.
##
## [param data_directory_override] replaces the default directory; pass an empty
## String to use it.
static func resolve(data_directory_override: String = "") -> TentacleEndpoints:
	var out := TentacleEndpoints.new()

	var directory := data_directory_override.strip_edges()
	if directory.is_empty():
		directory = default_data_directory()
	if directory.is_empty():
		return out

	var path := directory.path_join(DISCOVERY_FILE_NAME)
	if not FileAccess.file_exists(path):
		return out

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		# Locked, which usually means Tentacle is rewriting it right now.
		return out
	var text := file.get_as_text()
	file.close()

	var parsed := TclJson.parse_text(text)
	if not TclJson.is_object(parsed):
		# Truncated, which means it was read mid-write.
		return out
	var json := TclJson.as_dictionary(parsed)

	# Per field, not all-or-nothing: the engine listener falls back to an
	# OS-assigned port when the default is taken, independently of the HTTP one, so
	# one resolving and the other not is normal. The file calls the HTTP port
	# "port" and the socket one "enginePort" - see packages/app/src/server/
	# sidecar-discovery.ts, which is the contract.
	var http_port := TclJson.as_int(TclJson.read_value(json, "port"))
	if http_port > 0:
		out.http_base_url = "http://127.0.0.1:%d" % http_port
		out.from_discovery_file = true

	var engine_port := TclJson.as_int(TclJson.read_value(json, "enginePort"))
	if engine_port > 0:
		out.engine_socket_url = "ws://127.0.0.1:%d" % engine_port
		out.from_discovery_file = true

	return out
