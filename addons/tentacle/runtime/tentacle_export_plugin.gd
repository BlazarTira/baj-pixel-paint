@tool
class_name TentacleExportPlugin
extends EditorExportPlugin

## Ships the Tentacle core with the exports that run it, and its license files with it.
##
## An export whose Build Mode is Paired never runs the core, so it leaves the Tentacle
## GDExtension out, unless [code]tentacle/embedded/include_core_in_paired_builds[/code]
## is on (see [TentacleCoreExportFilter]). Whenever an export carries the GDExtension,
## this puts the core's license and the notices of the third-party code compiled into it
## where the export puts the core's library: beside the executable on Windows and Linux,
## and in the app bundle's [code]Contents/Resources[/code] folder on macOS (see
## [TentacleCoreLicenseExport]).
##
## The addon's editor plugin adds it while the addon is enabled, so there is nothing to
## set up.

# Preloaded by path rather than named by class, as plugin.gd preloads this script: on a
# project's first open the editor can load the plugin before it has built the global
# class list.
const LicenseExport := preload("res://addons/tentacle/runtime/tentacle_core_license_export.gd")
const ExportFilter := preload("res://addons/tentacle/runtime/tentacle_core_export_filter.gd")
const ProjectSettingKeys := preload("res://addons/tentacle/runtime/tentacle_project_settings.gd")

# An export hands each file to its plugins in the order of their names, by code point,
# and this has to come before Godot's own "GDExtension" plugin, which ships an extension's
# library as it is handed the extension's file, so that skipping the file keeps the
# library out too.
## This plugin's name.
const NAME: String = "Embedded Tentacle"

var _filter: ExportFilter = ExportFilter.new()
var _licenses: LicenseExport = LicenseExport.new()


func _get_name() -> String:
	return NAME


func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	var ships := ExportFilter.ships_core(
		int(ProjectSettings.get_setting(ProjectSettingKeys.BUILD_MODE, 0)),
		bool(ProjectSettings.get_setting(ProjectSettingKeys.INCLUDE_CORE_IN_PAIRED_BUILDS, false)),
	)
	# The editor keeps the list in the project's data folder, whose editor/ folder this is.
	var data_folder := EditorInterface.get_editor_paths().get_project_settings_dir().get_base_dir()
	_filter.begin(ships, data_folder.path_join("extension_list.cfg"))
	_licenses.begin(features, path)


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if _filter.skips(path):
		skip()
		return
	for file in _licenses.file_exported(path):
		add_shared_object(file, PackedStringArray(), LicenseExport.MACOS_BUNDLE_FOLDER)


func _export_end() -> void:
	_licenses.end()
	_filter.end()
