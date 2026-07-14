@tool
extends RefCounted

const LauncherScript := preload("res://addons/external_shader_editor/external_editor_launcher.gd")
const SettingsScript := preload("res://addons/external_shader_editor/external_shader_editor_settings.gd")

const MENU_LABEL_EXTERNAL := "Open Shader in External Editor"
const MENU_LABEL_GODOT := "Open Shader in Godot Editor"

var _editor_interface: EditorInterface
var _launcher: LauncherScript
var _settings: SettingsScript


func setup(
	editor_interface: EditorInterface,
	launcher: LauncherScript,
	settings: SettingsScript
) -> void:
	_editor_interface = editor_interface
	_launcher = launcher
	_settings = settings


func has_supported_paths(paths: PackedStringArray) -> bool:
	return not get_supported_paths(paths).is_empty()


func get_menu_label() -> String:
	return get_menu_label_for_default(_settings == null or _settings.is_external_editor_default())


func get_menu_icon() -> Texture2D:
	if _editor_interface == null:
		return null

	var base_control := _editor_interface.get_base_control()
	if base_control == null:
		return null

	var use_external_editor := _settings == null or _settings.is_external_editor_default()
	var icon_name := "Shader" if use_external_editor else "ExternalLink"
	return base_control.get_theme_icon(icon_name, "EditorIcons")


func open_selected(paths: Array) -> void:
	var supported_paths := get_supported_paths(PackedStringArray(paths))
	if _settings == null or _settings.is_external_editor_default():
		_open_in_godot_editor(supported_paths)
	elif _launcher == null:
		push_error("External Shader Editor launcher is not initialized.")
	else:
		_launcher.open_shader_files(supported_paths)


static func get_menu_label_for_default(use_external_editor: bool) -> String:
	return MENU_LABEL_GODOT if use_external_editor else MENU_LABEL_EXTERNAL


func get_supported_paths(paths: PackedStringArray) -> Array[String]:
	var supported_paths: Array[String] = []
	for path in paths:
		var extension := path.get_extension().to_lower()
		var is_supported_extension := extension == "gdshader" or extension == "gdshaderinc"
		var is_directory := path.ends_with("/") or DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(path)
		)
		if is_supported_extension and not is_directory:
			supported_paths.append(path)
	return supported_paths


func _open_in_godot_editor(paths: Array[String]) -> void:
	if _editor_interface == null:
		push_error("Godot editor interface is not initialized.")
		return

	for path in paths:
		var resource := ResourceLoader.load(path)
		if resource == null:
			push_error("Could not load shader resource in Godot editor: %s" % path)
			continue
		_editor_interface.edit_resource(resource)
