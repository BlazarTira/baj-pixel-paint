class_name TclConfigFiles
extends RefCounted
## Reads the config files an embedded game ships from a folder.

# Unity's TentacleConfigFiles and Unreal's FTclConfigFiles read the same way: every .json
# file in one folder, in name order, so the files the Tentacle app exports are picked up
# with no list to keep. In runtime/ rather than core/ because it reads files.


## The text of every [code].json[/code] file in [param directory] (a [code]res://[/code],
## [code]user://[/code], or absolute path), in name order. Empty when the folder is not
## there, which is a game that ships no config. Read through DirAccess and FileAccess,
## which find files inside an exported game's pack as well as in the project folder. A
## file that cannot be read is reported and skipped.
static func read(directory: String) -> PackedStringArray:
	var texts := PackedStringArray()
	if directory.is_empty() or not DirAccess.dir_exists_absolute(directory):
		return texts
	var names := Array(DirAccess.get_files_at(directory)).filter(
		func(file_name: String) -> bool: return file_name.get_extension().to_lower() == "json"
	)
	names.sort()
	for file_name: String in names:
		var path := directory.path_join(file_name)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			TentacleLog.warn(
				"could not read the config file %s (%s); starting without it"
				% [path, error_string(FileAccess.get_open_error())]
			)
			continue
		texts.append(file.get_as_text())
	return texts
