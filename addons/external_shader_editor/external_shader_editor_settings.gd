@tool
extends RefCounted

const KEY_DEFAULT_EDITOR := "external_shader_editor/default_editor"
const KEY_EDITOR_PRESET := "external_shader_editor/editor_preset"
const KEY_EXEC_PATH := "external_shader_editor/exec_path"
const KEY_EXEC_FLAGS := "external_shader_editor/exec_flags"

const GODOT_KEY_USE_EXTERNAL_EDITOR := "text_editor/external/use_external_editor"
const GODOT_KEY_EXEC_PATH := "text_editor/external/exec_path"
const GODOT_KEY_EXEC_FLAGS := "text_editor/external/exec_flags"

const PRESET_CUSTOM := 0
const PRESET_RIDER := 1
const PRESET_VS_CODE := 2

const DEFAULT_EDITOR_EXTERNAL := 0
const DEFAULT_EDITOR_GODOT := 1

var _editor_settings: EditorSettings
var _observed_preset: int = PRESET_CUSTOM
var _applying_preset := false


func initialize(editor_settings: EditorSettings) -> void:
	_editor_settings = editor_settings

	var godot_external_settings := _read_godot_external_editor_settings()
	var fallback_defaults := get_preset_defaults(PRESET_VS_CODE)
	var initial_settings := get_initial_settings(
		bool(godot_external_settings["enabled"]),
		str(godot_external_settings["exec_path"]),
		str(godot_external_settings["exec_flags"]),
		str(fallback_defaults["exec_path"]),
		str(fallback_defaults["exec_flags"])
	)

	_register_setting(
		KEY_DEFAULT_EDITOR,
		initial_settings["default_editor"],
		TYPE_INT,
		PROPERTY_HINT_ENUM,
		"External Editor,Godot Editor"
	)
	_register_setting(
		KEY_EDITOR_PRESET,
		initial_settings["editor_preset"],
		TYPE_INT,
		PROPERTY_HINT_ENUM,
		"Custom,Rider,VS Code"
	)
	_register_setting(
		KEY_EXEC_PATH,
		initial_settings["exec_path"],
		TYPE_STRING,
		PROPERTY_HINT_GLOBAL_FILE
	)
	_register_setting(
		KEY_EXEC_FLAGS,
		initial_settings["exec_flags"],
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


func is_external_editor_default() -> bool:
	if _editor_settings == null:
		return true
	return int(_editor_settings.get_setting(KEY_DEFAULT_EDITOR)) == DEFAULT_EDITOR_EXTERNAL


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


static func get_initial_settings(
	use_external_editor: bool,
	godot_exec_path: String,
	godot_exec_flags: String,
	fallback_exec_path: String,
	fallback_exec_flags: String
) -> Dictionary:
	if use_external_editor:
		return {
			"default_editor": DEFAULT_EDITOR_EXTERNAL,
			"editor_preset": PRESET_CUSTOM,
			"exec_path": godot_exec_path,
			"exec_flags": godot_exec_flags,
		}

	return {
		"default_editor": DEFAULT_EDITOR_GODOT,
		"editor_preset": PRESET_VS_CODE,
		"exec_path": fallback_exec_path,
		"exec_flags": fallback_exec_flags,
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


func _read_godot_external_editor_settings() -> Dictionary:
	if not _editor_settings.has_setting(GODOT_KEY_USE_EXTERNAL_EDITOR):
		return {"enabled": false, "exec_path": "", "exec_flags": ""}

	var is_enabled := bool(_editor_settings.get_setting(GODOT_KEY_USE_EXTERNAL_EDITOR))
	var exec_path := ""
	if _editor_settings.has_setting(GODOT_KEY_EXEC_PATH):
		exec_path = str(_editor_settings.get_setting(GODOT_KEY_EXEC_PATH))
	var exec_flags := "{file}"
	if _editor_settings.has_setting(GODOT_KEY_EXEC_FLAGS):
		exec_flags = str(_editor_settings.get_setting(GODOT_KEY_EXEC_FLAGS))

	return {
		"enabled": is_enabled,
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
