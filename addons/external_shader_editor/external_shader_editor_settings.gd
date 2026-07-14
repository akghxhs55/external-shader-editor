@tool
extends RefCounted

const KEY_EDITOR_PRESET := "external_shader_editor/editor_preset"
const KEY_EXEC_PATH := "external_shader_editor/exec_path"
const KEY_EXEC_FLAGS := "external_shader_editor/exec_flags"
const LEGACY_KEY_USE_EXTERNAL_EDITOR := "external_shader_editor/use_external_editor"

const GODOT_KEY_USE_EXTERNAL_EDITOR := "text_editor/external/use_external_editor"
const GODOT_KEY_EXEC_PATH := "text_editor/external/exec_path"
const GODOT_KEY_EXEC_FLAGS := "text_editor/external/exec_flags"

const PRESET_CUSTOM := 0
const PRESET_RIDER := 1
const PRESET_VS_CODE := 2

var _editor_settings: EditorSettings
var _observed_preset: int = PRESET_CUSTOM
var _applying_preset := false


func initialize(editor_settings: EditorSettings) -> void:
	_editor_settings = editor_settings
	_remove_legacy_settings()

	var godot_external_settings := _read_godot_external_editor_settings()
	var should_import_godot_settings: bool = bool(godot_external_settings["valid"])
	var default_preset := PRESET_CUSTOM if should_import_godot_settings else PRESET_VS_CODE
	var preset_defaults := get_preset_defaults(default_preset)
	var default_exec_path: String = preset_defaults["exec_path"]
	var default_exec_flags: String = preset_defaults["exec_flags"]

	if should_import_godot_settings:
		default_exec_path = godot_external_settings["exec_path"]
		default_exec_flags = godot_external_settings["exec_flags"]

	_register_setting(
		KEY_EDITOR_PRESET,
		default_preset,
		TYPE_INT,
		PROPERTY_HINT_ENUM,
		"Custom,Rider,VS Code"
	)
	_register_setting(
		KEY_EXEC_PATH,
		default_exec_path,
		TYPE_STRING,
		PROPERTY_HINT_GLOBAL_FILE
	)
	_register_setting(
		KEY_EXEC_FLAGS,
		default_exec_flags,
		TYPE_STRING,
		PROPERTY_HINT_PLACEHOLDER_TEXT,
		"Arguments with {project}, {file}, {line}, {col}, or {column}"
	)

	_observed_preset = get_editor_preset()
	if not _editor_settings.settings_changed.is_connected(_on_settings_changed):
		_editor_settings.settings_changed.connect(_on_settings_changed)


func shutdown() -> void:
	if _editor_settings != null and _editor_settings.settings_changed.is_connected(_on_settings_changed):
		_editor_settings.settings_changed.disconnect(_on_settings_changed)
	_editor_settings = null


func get_editor_preset() -> int:
	if _editor_settings == null:
		return PRESET_CUSTOM
	return int(_editor_settings.get_setting(KEY_EDITOR_PRESET))


func get_exec_path() -> String:
	if _editor_settings == null:
		return ""
	return str(_editor_settings.get_setting(KEY_EXEC_PATH))


func get_exec_flags() -> String:
	if _editor_settings == null:
		return ""
	return str(_editor_settings.get_setting(KEY_EXEC_FLAGS))


func get_preset_defaults(preset: int) -> Dictionary:
	match preset:
		PRESET_RIDER:
			var rider_path := "rider"
			if OS.get_name() == "macOS":
				rider_path = "/Applications/Rider.app"
			elif OS.get_name() == "Windows":
				rider_path = "rider64.exe"
			return {
				"exec_path": rider_path,
				"exec_flags": "{project} --line {line} {file}",
			}
		PRESET_VS_CODE:
			return {
				"exec_path": "code",
				"exec_flags": "{project} --goto {file}:{line}:{col}",
			}
		_:
			return {
				"exec_path": "",
				"exec_flags": "",
			}


func apply_preset(preset: int) -> void:
	if _editor_settings == null or preset == PRESET_CUSTOM:
		return

	var defaults := get_preset_defaults(preset)
	_applying_preset = true
	_editor_settings.set_setting(KEY_EXEC_PATH, defaults["exec_path"])
	_editor_settings.set_setting(KEY_EXEC_FLAGS, defaults["exec_flags"])
	_applying_preset = false


func _register_setting(
	key: String,
	default_value: Variant,
	type: int,
	hint: int = PROPERTY_HINT_NONE,
	hint_string: String = ""
) -> void:
	if not _editor_settings.has_setting(key):
		_editor_settings.set_setting(key, default_value)

	_editor_settings.set_initial_value(key, default_value, false)
	var property_info := {
		"name": key,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	}
	_editor_settings.add_property_info(property_info)


func _remove_legacy_settings() -> void:
	if _editor_settings.has_setting(LEGACY_KEY_USE_EXTERNAL_EDITOR):
		_editor_settings.erase(LEGACY_KEY_USE_EXTERNAL_EDITOR)


func _read_godot_external_editor_settings() -> Dictionary:
	if not _editor_settings.has_setting(GODOT_KEY_USE_EXTERNAL_EDITOR):
		return {"valid": false, "exec_path": "", "exec_flags": ""}
	if not _editor_settings.has_setting(GODOT_KEY_EXEC_PATH):
		return {"valid": false, "exec_path": "", "exec_flags": ""}

	var is_enabled := bool(_editor_settings.get_setting(GODOT_KEY_USE_EXTERNAL_EDITOR))
	var exec_path := str(_editor_settings.get_setting(GODOT_KEY_EXEC_PATH)).strip_edges()
	var exec_flags := "{file}"
	if _editor_settings.has_setting(GODOT_KEY_EXEC_FLAGS):
		exec_flags = str(_editor_settings.get_setting(GODOT_KEY_EXEC_FLAGS))
		if exec_flags.strip_edges().is_empty():
			exec_flags = "{file}"

	return {
		"valid": is_enabled and not exec_path.is_empty(),
		"exec_path": exec_path,
		"exec_flags": exec_flags,
	}


func _on_settings_changed() -> void:
	if _applying_preset or _editor_settings == null:
		return

	var current_preset := get_editor_preset()
	if current_preset == _observed_preset:
		return

	_observed_preset = current_preset
	apply_preset(current_preset)
