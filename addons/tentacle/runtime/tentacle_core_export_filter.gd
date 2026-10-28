class_name TentacleCoreExportFilter
extends RefCounted

## Keeps the Tentacle core out of an export that never runs it, for [TentacleExportPlugin].
##
## Only Embedded mode runs the core, so an export whose Build Mode
## ([code]tentacle/connection/build_mode[/code]) is Paired leaves out the Tentacle
## GDExtension: its configuration file, its library, and the license files that go with
## the library. To run such an export with [code]--tentacle-mode=embedded[/code], turn on
## [code]tentacle/embedded/include_core_in_paired_builds[/code]. The editor keeps loading
## the extension either way.

# How. Godot's own GDExtension export plugin ships an extension's library when it is
# handed the extension's .gdextension file, and export plugins are handed each file in
# the order of their names, so TentacleExportPlugin is named to come before it and skips
# the file, after which no later plugin sees it. Skipping leaves the extension named in
# the editor's extension list (res://.godot/extension_list.cfg), which an export copies
# into the game filtered only by the preset's own include and exclude filters, and an
# exported game whose list names an extension it lacks logs three errors as it starts.
# So the line comes out of the list for the length of the export and goes back at its
# end. The editor reads the list only as it starts, and writes it only when the set of
# extensions it has loaded changes, so it never sees the edit; an editor killed during an
# export finds the extension again in its first scan of the project and writes the list
# anew. Checked against Godot's source from 4.4 to 4.7 and by exporting with 4.7.
#
# This is a RefCounted of its own because Godot lets only the editor instantiate an
# EditorExportPlugin, so the tests drive this instead.

## The name of the GDExtension's configuration file.
const EXTENSION_FILE: String = "tentacle_embedded.gdextension"

var _skipping: bool = false
var _list_path: String = ""
var _original: PackedByteArray = PackedByteArray()


## Whether an export ships the core: when its Build Mode, [param build_mode] (a
## [enum TclTentacleMode.Value]), is Embedded, or when [param include_in_paired_builds]
## asks for it in a Paired build too.
static func ships_core(build_mode: int, include_in_paired_builds: bool) -> bool:
	return build_mode == TclTentacleMode.Value.EMBEDDED or include_in_paired_builds


## Starts an export, as [method EditorExportPlugin._export_begin] does. Unless
## [param ships] says it carries the core, takes the extension out of the extension list
## at [param extension_list] until [method end].
func begin(ships: bool, extension_list: String) -> void:
	end()
	_skipping = not ships
	if not _skipping or not FileAccess.file_exists(extension_list):
		return

	var original := FileAccess.get_file_as_bytes(extension_list)
	var kept := PackedStringArray()
	var named := false
	for line in original.get_string_from_utf8().split("\n"):
		var entry := line.strip_edges()
		if entry.get_file() == EXTENSION_FILE:
			named = true
		elif not entry.is_empty():
			kept.append(entry)
	if not named:
		return

	var file := FileAccess.open(extension_list, FileAccess.WRITE)
	if file == null:
		push_error(
			"Tentacle: could not take the Tentacle core out of the export's extension list (%s), so the exported game reports it missing as it starts."
			% error_string(FileAccess.get_open_error())
		)
		return
	_list_path = extension_list
	_original = original
	file.store_string("".join(Array(kept).map(func(entry: String) -> String: return entry + "\n")))
	file.close()


## Whether the export leaves out the file at [param path], as
## [method EditorExportPlugin._export_file] asks: the GDExtension's configuration file,
## when the export does not ship the core.
func skips(path: String) -> bool:
	return _skipping and path.get_file() == EXTENSION_FILE


## Ends the export, as [method EditorExportPlugin._export_end] does, putting the
## extension list back as it was.
func end() -> void:
	if not _list_path.is_empty():
		var file := FileAccess.open(_list_path, FileAccess.WRITE)
		if file == null:
			push_error(
				"Tentacle: could not put back %s after the export (%s). Restart the editor to rebuild it."
				% [_list_path, error_string(FileAccess.get_open_error())]
			)
		else:
			file.store_buffer(_original)
			file.close()
	_list_path = ""
	_original = PackedByteArray()
	_skipping = false
