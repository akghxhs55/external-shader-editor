@tool
extends RefCounted

const LauncherScript := preload("res://addons/external_shader_editor/external_editor_launcher.gd")
const SettingsScript := preload("res://addons/external_shader_editor/external_shader_editor_settings.gd")

const FILESYSTEM_TREE_METHOD := &"FileSystemDock::_tree_activate_file"
const FILESYSTEM_LIST_METHOD := &"FileSystemDock::_file_list_activate_file"
const OUTPUT_META_METHOD := &"EditorLog::_meta_clicked"
const CSHARP_DELEGATE_CALLABLE := "Delegate::Invoke"

var _launcher: LauncherScript
var _settings: SettingsScript
var _hooks: Array[Dictionary] = []


func setup(launcher: LauncherScript, settings: SettingsScript) -> void:
	if not _hooks.is_empty():
		return
	_launcher = launcher
	_settings = settings
	_install_hooks()
	_report_missing_hooks()


func shutdown() -> void:
	for hook in _hooks:
		var emitter: Object = hook["emitter"]
		if not is_instance_valid(emitter):
			continue

		var signal_name: StringName = hook["signal"]
		var replacement: Callable = hook["replacement"]
		var original: Callable = hook["original"]
		if emitter.is_connected(signal_name, replacement):
			emitter.disconnect(signal_name, replacement)
		if original.is_valid() and not emitter.is_connected(signal_name, original):
			emitter.connect(signal_name, original, int(hook["flags"]))

	_hooks.clear()
	_launcher = null
	_settings = null


func parse_shader_error_meta(meta: String) -> Dictionary:
	if not meta.contains(":"):
		return {"valid": false, "path": "", "line": 1, "column": 1}

	var parts := meta.rsplit(":", true, 1)
	if parts.size() != 2 or not parts[1].is_valid_int():
		return {"valid": false, "path": "", "line": 1, "column": 1}

	var path := parts[0]
	if not _is_supported_shader_path(path):
		return {"valid": false, "path": "", "line": 1, "column": 1}

	return {
		"valid": true,
		"path": path,
		"line": maxi(parts[1].to_int(), 1),
		"column": 1,
	}


func _install_hooks() -> void:
	var filesystem_dock := EditorInterface.get_file_system_dock()
	_hook_descendant_connections(
		filesystem_dock,
		{
			FILESYSTEM_TREE_METHOD: _on_filesystem_tree_item_activated,
			FILESYSTEM_LIST_METHOD: _on_filesystem_list_item_activated,
		}
	)

	var editor_root := EditorInterface.get_base_control()
	_hook_descendant_connections(editor_root, {OUTPUT_META_METHOD: _on_output_meta_clicked})


func _hook_descendant_connections(
	root: Node,
	replacements: Dictionary
) -> void:
	if root == null:
		return

	for signal_info in root.get_signal_list():
		var signal_name: StringName = signal_info["name"]
		for connection in root.get_signal_connection_list(signal_name):
			var original: Callable = connection["callable"]
			if not _can_inspect_callable_method(original):
				continue

			var original_method := original.get_method()
			if not replacements.has(original_method):
				continue
			if original_method == OUTPUT_META_METHOD:
				var target := original.get_object()
				if target == null or target.get_class() != &"EditorLog":
					continue
			var replacement: Callable = replacements[original_method]

			root.disconnect(signal_name, original)
			root.connect(signal_name, replacement, int(connection["flags"]))
			_hooks.append({
				"emitter": root,
				"signal": signal_name,
				"original": original,
				"replacement": replacement,
				"flags": int(connection["flags"]),
			})

	for child in root.get_children():
		_hook_descendant_connections(child, replacements)


func _can_inspect_callable_method(callable: Callable) -> bool:
	return callable.is_valid() and str(callable) != CSHARP_DELEGATE_CALLABLE


func _report_missing_hooks() -> void:
	var hooked_methods := {}
	for hook in _hooks:
		var original: Callable = hook["original"]
		hooked_methods[original.get_method()] = true

	var required_methods := [
		FILESYSTEM_TREE_METHOD,
		FILESYSTEM_LIST_METHOD,
		OUTPUT_META_METHOD,
	]
	for method in required_methods:
		if not hooked_methods.has(method):
			push_warning(
				"External Shader Editor could not install the Godot 4.6 integration hook for %s."
				% method
			)


func _on_filesystem_tree_item_activated() -> void:
	var hook := _find_hook_for_replacement(_on_filesystem_tree_item_activated)
	if not hook.is_empty():
		var tree := hook["emitter"] as Tree
		var selected_item := tree.get_selected() if tree != null else null
		var path := str(selected_item.get_metadata(0)) if selected_item != null else ""
		if _should_open_in_external_editor(path):
			if _launcher.open_shader_file(path):
				return

	_call_original(hook, [])


func _on_filesystem_list_item_activated(index: int) -> void:
	var hook := _find_hook_for_replacement(_on_filesystem_list_item_activated)
	if not hook.is_empty():
		var file_list := hook["emitter"] as ItemList
		var path := ""
		if file_list != null and index >= 0 and index < file_list.item_count:
			path = str(file_list.get_item_metadata(index))
		if _should_open_in_external_editor(path):
			if _launcher.open_shader_file(path):
				return

	_call_original(hook, [index])


func _on_output_meta_clicked(meta: Variant) -> void:
	var hook := _find_hook_for_replacement(_on_output_meta_clicked)
	var location := parse_shader_error_meta(str(meta))
	if bool(location["valid"]) and _should_open_in_external_editor(str(location["path"])):
		if _launcher.open_shader_file(
			str(location["path"]),
			int(location["line"]),
			int(location["column"])
		):
			return

	_call_original(hook, [meta])


func _find_hook_for_replacement(replacement: Callable) -> Dictionary:
	for hook in _hooks:
		if hook["replacement"] == replacement:
			return hook
	return {}


func _call_original(hook: Dictionary, arguments: Array) -> void:
	if hook.is_empty():
		return
	var original: Callable = hook["original"]
	if original.is_valid():
		original.callv(arguments)


func _is_supported_shader_path(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return extension == "gdshader" or extension == "gdshaderinc"


func _should_open_in_external_editor(path: String) -> bool:
	return (
		_launcher != null
		and _settings != null
		and _settings.is_external_editor_default()
		and _is_supported_shader_path(path)
	)
