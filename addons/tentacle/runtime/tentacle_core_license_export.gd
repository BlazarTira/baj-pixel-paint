class_name TentacleCoreLicenseExport
extends RefCounted

## Works out where an export puts the Tentacle core's license files, for
## [TentacleExportPlugin].
##
## The Tentacle GDExtension, which Embedded mode runs on, keeps two text files beside its
## [code].gdextension[/code] file: [code]TENTACLE-CORE-LICENSE.md[/code], the core's own
## license, and [code]THIRD-PARTY-NOTICES.txt[/code], the notices of the third-party code
## compiled into it. Both have to go with every copy of the core's library, the one inside
## a shipped game included, and an export leaves text files out. So whenever an export
## carries the GDExtension, both go beside its library: beside the executable on Windows
## and Linux, in a folder or in a [code].zip[/code], and in the app bundle's
## [code]Contents/Resources[/code] folder on macOS.

# The library itself is shipped by Godot's own GDExtension export plugin, as a shared
# object beside the executable. The license files are not shared objects there: on
# Windows, Godot code-signs every shared object file it copies when the preset signs the
# export, and signtool fails on a text file, failing the export. So on Windows and Linux
# they are written once the export has written its files. When that is depends on the
# version: in Godot 4.4 the hooks end as the export's executable is written, into a
# temporary folder for a .zip export, so the files are copied beside it; in 4.7 they end
# once the .zip itself is written, so the files are added to the archive. On macOS they are
# shared objects with a target, which Godot copies relative to the bundle root and signs
# only when they are code.
#
# This is a RefCounted of its own because Godot lets only the editor instantiate an
# EditorExportPlugin, so the tests drive this instead.

## The name of the GDExtension's configuration file, which an export carrying the core
## includes.
const EXTENSION_FILE: String = "tentacle_embedded.gdextension"

## The license files the GDExtension keeps beside its configuration file.
const LICENSE_FILES: PackedStringArray = ["TENTACLE-CORE-LICENSE.md", "THIRD-PARTY-NOTICES.txt"]

## Where in a macOS app bundle the license files go.
const MACOS_BUNDLE_FOLDER: String = "Contents/Resources"

var _export_path: String = ""
var _features: PackedStringArray = PackedStringArray()
var _extension_file: String = ""


## Starts an export with [param features] to [param path], as
## [method EditorExportPlugin._export_begin] does.
func begin(features: PackedStringArray, path: String) -> void:
	_export_path = path
	_features = features
	_extension_file = ""


## Notes a file the export includes, as [method EditorExportPlugin._export_file] does,
## and returns the license files to add to a macOS bundle under [constant
## MACOS_BUNDLE_FOLDER] when it is the GDExtension's configuration file.
func file_exported(path: String) -> PackedStringArray:
	if path.get_file() != EXTENSION_FILE:
		return PackedStringArray()
	_extension_file = path
	if _features.has("macos"):
		return license_files(path.get_base_dir())
	return PackedStringArray()


## Ends the export, as [method EditorExportPlugin._export_end] does: puts the license
## files beside each copy of the core's library a Windows or Linux export wrote, in a
## folder or in a [code].zip[/code], and returns where it put them.
func end() -> PackedStringArray:
	var written := PackedStringArray()
	if _extension_file != "" and not _features.has("macos"):
		var libraries := library_file_names(_extension_file)
		var folder := _extension_file.get_base_dir()
		match _export_path.get_extension().to_lower():
			"pck":
				pass
			"zip":
				written = add_license_files_to_archive(folder, _export_path, libraries)
			_:
				for library in libraries:
					if FileAccess.file_exists(_export_path.get_base_dir().path_join(library)):
						written = copy_license_files(folder, _export_path.get_base_dir())
						break
	_extension_file = ""
	return written


## The file names of the libraries the GDExtension configuration file at
## [param extension_file] lists, one per platform.
static func library_file_names(extension_file: String) -> PackedStringArray:
	var names := PackedStringArray()
	var config := ConfigFile.new()
	if config.load(extension_file) != OK or not config.has_section("libraries"):
		return names
	for key in config.get_section_keys("libraries"):
		var library := str(config.get_value("libraries", key)).get_file()
		if library != "" and not names.has(library):
			names.append(library)
	return names


## The license files in [param folder], the GDExtension's folder, warning about each one
## that is missing.
static func license_files(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file_name in LICENSE_FILES:
		var file := folder.path_join(file_name)
		if FileAccess.file_exists(file):
			found.append(file)
		else:
			push_warning(
				"Tentacle: %s is missing from %s, so the export carries Tentacle's core without it. Reinstall the Tentacle addon."
				% [file_name, folder]
			)
	return found


## Copies the license files in [param folder] into [param target], and returns the files
## it wrote.
static func copy_license_files(folder: String, target: String) -> PackedStringArray:
	var written := PackedStringArray()
	for file in license_files(folder):
		var destination := target.path_join(file.get_file())
		var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(file), ProjectSettings.globalize_path(destination))
		if error == OK:
			written.append(destination)
		else:
			push_error("Tentacle: could not copy %s into the export (%s)." % [file, error_string(error)])
	return written


## Adds the license files in [param folder] to the [code].zip[/code] at [param archive],
## beside each of the [param libraries] it holds, and returns the entries it added. An
## archive of the project's files alone holds no library and is left as it is.
static func add_license_files_to_archive(folder: String, archive: String, libraries: PackedStringArray) -> PackedStringArray:
	var reader := ZIPReader.new()
	if reader.open(archive) != OK:
		return PackedStringArray()
	var entries := reader.get_files()
	reader.close()

	var wanted := PackedStringArray()
	for entry in entries:
		if not libraries.has(entry.get_file()):
			continue
		for file_name in LICENSE_FILES:
			var target := file_name if entry.get_base_dir() == "" else entry.get_base_dir().path_join(file_name)
			if not entries.has(target) and not wanted.has(target):
				wanted.append(target)
	if wanted.is_empty():
		return PackedStringArray()

	var sources: Dictionary[String, String] = {}
	for file in license_files(folder):
		sources[file.get_file()] = file
	var packer := ZIPPacker.new()
	var error := packer.open(archive, ZIPPacker.APPEND_ADDINZIP)
	if error != OK:
		push_error("Tentacle: could not add the core's license files to %s (%s)." % [archive, error_string(error)])
		return PackedStringArray()
	var added := PackedStringArray()
	for target in wanted:
		if not sources.has(target.get_file()):
			continue
		packer.start_file(target)
		packer.write_file(FileAccess.get_file_as_bytes(sources[target.get_file()]))
		packer.close_file()
		added.append(target)
	packer.close()
	return added
