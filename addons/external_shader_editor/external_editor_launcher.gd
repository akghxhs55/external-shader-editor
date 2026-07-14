@tool
extends RefCounted

const CommandLineTokenizerScript := preload("res://addons/external_shader_editor/command_line_tokenizer.gd")
const SettingsScript := preload("res://addons/external_shader_editor/external_shader_editor_settings.gd")
const MACOS_OPEN_EXECUTABLE := "/usr/bin/open"

var _settings: SettingsScript
var _editor_interface: EditorInterface
var _tokenizer := CommandLineTokenizerScript.new()


func setup(settings: SettingsScript, editor_interface: EditorInterface = null) -> void:
	_settings = settings
	_editor_interface = editor_interface


func open_shader_files(resource_paths: Array[String]) -> void:
	if _settings == null:
		_report_error("External Shader Editor is not initialized.")
		return
	if resource_paths.is_empty():
		_report_error("No supported shader file was selected.")
		return

	for resource_path in resource_paths:
		open_shader_file(resource_path)


func open_shader_file(resource_path: String, line: int = 1, column: int = 1) -> bool:
	if _settings == null:
		_report_error("External Shader Editor is not initialized.")
		return false
	if not _is_supported_shader_path(resource_path):
		_report_error("Unsupported shader file: %s" % resource_path)
		return false

	var absolute_file_path := ProjectSettings.globalize_path(resource_path).simplify_path()
	if not FileAccess.file_exists(absolute_file_path):
		_report_error("Shader file does not exist: %s" % absolute_file_path)
		return false

	var executable := _settings.get_exec_path().strip_edges()
	if executable.is_empty():
		_report_error("External Shader Editor Exec Path is empty.")
		return false
	if not _validate_executable(executable):
		return false

	var project_path := ProjectSettings.globalize_path("res://").simplify_path()
	var context := {
		"project": project_path,
		"file": absolute_file_path,
		"line": maxi(line, 1),
		"col": maxi(column, 1),
		"column": maxi(column, 1),
	}
	var build_result := build_arguments(_settings.get_exec_flags(), context)
	if not bool(build_result["ok"]):
		_report_error(str(build_result["error"]))
		return false

	var arguments: PackedStringArray = build_result["arguments"]
	var process_id := _launch_process(executable, arguments)
	if process_id == -1:
		_report_error(
			"Failed to start external shader editor '%s'. Check Exec Path and Exec Flags." % executable
		)
		return false

	return true


func build_arguments(template: String, context: Dictionary) -> Dictionary:
	var arguments: PackedStringArray = _tokenizer.build_arguments(template, context)
	var tokenizer_error: String = _tokenizer.get_last_error()
	if not tokenizer_error.is_empty():
		return {
			"ok": false,
			"arguments": PackedStringArray(),
			"error": tokenizer_error,
		}

	return {
		"ok": true,
		"arguments": arguments,
		"error": "",
	}


func _launch_process(executable: String, arguments: PackedStringArray) -> int:
	if OS.get_name() == "macOS" and executable.to_lower().ends_with(".app"):
		return _launch_macos_application_bundle(executable, arguments)
	return OS.create_process(executable, arguments)


func _launch_macos_application_bundle(bundle_path: String, arguments: PackedStringArray) -> int:
	# Use macOS `open` for application bundles so configured arguments are passed to
	# the bundle's executable. `-n` creates a launch request even when the application
	# is already running; the application decides whether to keep the new instance or
	# forward the request to an existing one.
	return OS.create_process(
		MACOS_OPEN_EXECUTABLE,
		build_macos_bundle_launch_arguments(bundle_path, arguments)
	)


func build_macos_bundle_launch_arguments(
	bundle_path: String,
	arguments: PackedStringArray
) -> PackedStringArray:
	var launch_arguments := PackedStringArray(["-n", "-a", bundle_path, "--args"])
	launch_arguments.append_array(arguments)
	return launch_arguments


func resolve_command_path(command: String, search_path: String) -> String:
	if command.is_empty() or search_path.is_empty():
		return ""

	var path_separator := ";" if OS.get_name() == "Windows" else ":"
	var candidates := PackedStringArray([command])
	if OS.get_name() == "Windows" and command.get_extension().is_empty():
		var path_extensions := OS.get_environment("PATHEXT")
		if path_extensions.is_empty():
			path_extensions = ".COM;.EXE;.BAT;.CMD"
		for extension in path_extensions.split(";", false):
			candidates.append(command + extension.strip_edges())

	for directory in search_path.split(path_separator, false):
		var normalized_directory := directory.strip_edges().trim_prefix('"').trim_suffix('"')
		if normalized_directory.is_empty():
			continue
		for candidate in candidates:
			var candidate_path := normalized_directory.path_join(candidate).simplify_path()
			if FileAccess.file_exists(candidate_path):
				return candidate_path

	return ""


func _validate_executable(executable: String) -> bool:
	if not executable.is_absolute_path():
		if executable.contains("/") or executable.contains("\\"):
			if FileAccess.file_exists(executable):
				return true
			_report_error("External editor executable does not exist: %s" % executable)
			return false

		if resolve_command_path(executable, OS.get_environment("PATH")).is_empty():
			_report_error("External editor command was not found on PATH: %s" % executable)
			return false
		return true

	if OS.get_name() == "macOS" and executable.to_lower().ends_with(".app"):
		if not DirAccess.dir_exists_absolute(executable):
			_report_error("macOS application bundle does not exist: %s" % executable)
			return false
		return true

	if not FileAccess.file_exists(executable):
		_report_error("External editor executable does not exist: %s" % executable)
		return false
	return true


func _is_supported_shader_path(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return extension == "gdshader" or extension == "gdshaderinc"


func _report_error(message: String) -> void:
	push_error(message)
	if (
		Engine.is_editor_hint()
		and _editor_interface != null
		and _editor_interface.has_method(&"get_editor_toaster")
	):
		var toaster: Object = _editor_interface.call(&"get_editor_toaster")
		if toaster != null:
			toaster.call(&"push_toast", message, 2)
