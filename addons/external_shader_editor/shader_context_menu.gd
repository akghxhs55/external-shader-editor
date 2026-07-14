@tool
extends EditorContextMenuPlugin

const LauncherScript := preload("res://addons/external_shader_editor/external_editor_launcher.gd")
const SettingsScript := preload("res://addons/external_shader_editor/external_shader_editor_settings.gd")

const MENU_LABEL_EXTERNAL := "Open Shader in External Editor"
const MENU_LABEL_GODOT := "Open Shader in Godot Editor"

var _launcher: LauncherScript
var _settings: SettingsScript


func setup(launcher: LauncherScript, settings: SettingsScript) -> void:
	_launcher = launcher
	_settings = settings


func _popup_menu(paths: PackedStringArray) -> void:
	if _get_supported_paths(paths).is_empty():
		return

	var use_external_editor := _settings == null or _settings.is_external_editor_default()
	var icon_name := "Shader" if use_external_editor else "ExternalLink"
	var icon := EditorInterface.get_editor_theme().get_icon(
		icon_name,
		"EditorIcons"
	)

	add_context_menu_item(get_menu_label(use_external_editor), _on_open_selected, icon)


func _on_open_selected(paths: Array) -> void:
	var supported_paths := _get_supported_paths(PackedStringArray(paths))
	if _settings == null or _settings.is_external_editor_default():
		_open_in_godot_editor(supported_paths)
	elif _launcher == null:
		push_error("External Shader Editor launcher is not initialized.")
	else:
		_launcher.open_shader_files(supported_paths)


static func get_menu_label(use_external_editor: bool) -> String:
	return MENU_LABEL_GODOT if use_external_editor else MENU_LABEL_EXTERNAL


func _open_in_godot_editor(paths: Array[String]) -> void:
	for path in paths:
		var resource := ResourceLoader.load(path)
		if resource == null:
			push_error("Could not load shader resource in Godot editor: %s" % path)
			continue
		EditorInterface.edit_resource(resource)


func _get_supported_paths(paths: PackedStringArray) -> Array[String]:
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
