extends SceneTree

const TokenizerScript := preload("res://addons/external_shader_editor/command_line_tokenizer.gd")
const LauncherScript := preload("res://addons/external_shader_editor/external_editor_launcher.gd")
const ContextMenuActionsScript := preload("res://addons/external_shader_editor/shader_context_menu_actions.gd")
const PluginScript := preload("res://addons/external_shader_editor/external_shader_editor_plugin.gd")
const InterceptorScript := preload("res://addons/external_shader_editor/editor_open_interceptor.gd")

var _failure_count := 0


func _init() -> void:
	_test_tokenizer()
	_test_argument_building()
	_test_macos_bundle_arguments()
	_test_command_path_resolution()
	_test_shader_error_meta_parsing()
	_test_callable_method_inspection()
	_test_context_menu_labels()

	if _failure_count == 0:
		print("External Shader Editor tests passed.")
		quit(0)
	else:
		push_error("External Shader Editor tests failed: %d" % _failure_count)
		quit(1)


func _test_tokenizer() -> void:
	var tokenizer := TokenizerScript.new()

	_assert_tokens(
		tokenizer,
		"{project} --line {line} {file}",
		PackedStringArray(["{project}", "--line", "{line}", "{file}"])
	)
	_assert_tokens(
		tokenizer,
		"\"{project}\" --line {line} \"{file}\"",
		PackedStringArray(["{project}", "--line", "{line}", "{file}"])
	)
	_assert_tokens(
		tokenizer,
		"\"{project path}\" \"--flag=value with spaces\"",
		PackedStringArray(["{project path}", "--flag=value with spaces"])
	)
	_assert_tokens(
		tokenizer,
		"\"\" \"{file}\"",
		PackedStringArray(["", "{file}"])
	)
	_assert_tokens(
		tokenizer,
		'"hello \\"shader\\""',
		PackedStringArray(['hello "shader"'])
	)

	var invalid_tokens: PackedStringArray = tokenizer.tokenize_exec_flags('"unterminated')
	_assert_equal(invalid_tokens.size(), 0, "unterminated quote returns no arguments")
	_assert_true(not tokenizer.get_last_error().is_empty(), "unterminated quote reports an error")


func _test_argument_building() -> void:
	var launcher := LauncherScript.new()
	var context := {
		"project": "/tmp/Shader Project",
		"file": "/tmp/Shader Project/test shader.gdshader",
		"line": 1,
		"col": 1,
		"column": 1,
	}
	var result: Dictionary = launcher.build_arguments(
		"\"{project}\" --goto \"{file}:{line}:{column}\"",
		context
	)
	_assert_true(bool(result["ok"]), "argument builder succeeds")
	_assert_equal(
		result["arguments"],
		PackedStringArray([
			"/tmp/Shader Project",
			"--goto",
			"/tmp/Shader Project/test shader.gdshader:1:1",
		]),
		"quoted placeholders remain single arguments"
	)


func _test_macos_bundle_arguments() -> void:
	var launcher := LauncherScript.new()
	var editor_arguments := PackedStringArray([
		"/tmp/Shader Project",
		"--line",
		"1",
		"/tmp/Shader Project/test shader.gdshader",
	])
	var launch_arguments: PackedStringArray = launcher.build_macos_bundle_launch_arguments(
		"/Applications/Example Editor.app",
		editor_arguments
	)
	_assert_equal(
		launch_arguments,
		PackedStringArray([
			"-n",
			"-a",
			"/Applications/Example Editor.app",
			"--args",
			"/tmp/Shader Project",
			"--line",
			"1",
			"/tmp/Shader Project/test shader.gdshader",
		]),
		"macOS bundle launcher preserves all configured Exec Flags arguments"
	)


func _test_command_path_resolution() -> void:
	var launcher := LauncherScript.new()
	var godot_executable := OS.get_executable_path()
	var executable_directory := godot_executable.get_base_dir()
	var executable_name := godot_executable.get_file()

	_assert_equal(
		launcher.resolve_command_path(executable_name, executable_directory),
		godot_executable.simplify_path(),
		"command resolver finds an executable on PATH"
	)
	_assert_equal(
		launcher.resolve_command_path(
			"definitely-missing-external-shader-editor-command",
			executable_directory
		),
		"",
		"command resolver rejects a missing command"
	)


func _test_shader_error_meta_parsing() -> void:
	var interceptor := InterceptorScript.new()
	var location: Dictionary = interceptor.parse_shader_error_meta(
		"res://shaders/example.gdshader:27"
	)
	_assert_true(bool(location["valid"]), "shader error metadata is recognized")
	_assert_equal(location["path"], "res://shaders/example.gdshader", "shader error path")
	_assert_equal(location["line"], 27, "shader error line")

	location = interceptor.parse_shader_error_meta("res://shaders/shared.gdshaderinc:0")
	_assert_true(bool(location["valid"]), "shader include error metadata is recognized")
	_assert_equal(location["line"], 1, "shader error line is clamped to one")

	location = interceptor.parse_shader_error_meta("res://scripts/player.gd:10")
	_assert_true(not bool(location["valid"]), "non-shader error metadata is ignored")


func _test_callable_method_inspection() -> void:
	var interceptor := InterceptorScript.new()
	var method_callable := Callable(interceptor, &"parse_shader_error_meta")
	var custom_callable := func() -> void: pass

	_assert_true(
		interceptor._can_inspect_callable_method(method_callable),
		"standard method callables can be inspected"
	)
	_assert_true(custom_callable.is_custom(), "lambda is represented by a custom callable")
	_assert_true(
		interceptor._can_inspect_callable_method(custom_callable),
		"inspectable custom callables remain eligible for editor hooks"
	)


func _test_context_menu_labels() -> void:
	_assert_equal(
		ContextMenuActionsScript.get_menu_label_for_default(true),
		"Open Shader in Godot Editor",
		"external default exposes the Godot editor context action"
	)
	_assert_equal(
		ContextMenuActionsScript.get_menu_label_for_default(false),
		"Open Shader in External Editor",
		"Godot default exposes the external editor context action"
	)


func _assert_tokens(tokenizer: RefCounted, template: String, expected: PackedStringArray) -> void:
	var actual: PackedStringArray = tokenizer.tokenize_exec_flags(template)
	_assert_true(tokenizer.get_last_error().is_empty(), "tokenizer accepts: %s" % template)
	_assert_equal(actual, expected, "tokenizer output for: %s" % template)


func _assert_true(value: bool, label: String) -> void:
	if not value:
		_failure_count += 1
		push_error("Assertion failed: %s" % label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failure_count += 1
		push_error("Assertion failed: %s. Expected %s, got %s" % [label, expected, actual])
