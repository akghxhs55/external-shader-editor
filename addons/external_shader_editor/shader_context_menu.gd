@tool
extends EditorContextMenuPlugin

const LauncherScript := preload("res://addons/external_shader_editor/external_editor_launcher.gd")

const MENU_LABEL := "Open Shader in External Editor"

var _launcher: LauncherScript


func setup(launcher: LauncherScript) -> void:
	_launcher = launcher


func _popup_menu(paths: PackedStringArray) -> void:
	if _get_supported_paths(paths).is_empty():
		return

	var icon := EditorInterface.get_editor_theme().get_icon(
		"ExternalLink",
		"EditorIcons"
	)
	
	add_context_menu_item(MENU_LABEL, _on_open_selected, icon)


func _on_open_selected(paths: Array) -> void:
	if _launcher == null:
		push_error("External Shader Editor launcher is not initialized.")
		return

	var supported_paths := _get_supported_paths(PackedStringArray(paths))
	_launcher.open_shader_files(supported_paths)


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
