@tool
extends EditorPlugin

const SettingsScript := preload("res://addons/external_shader_editor/external_shader_editor_settings.gd")
const LauncherScript := preload("res://addons/external_shader_editor/external_editor_launcher.gd")
const ContextMenuScript := preload("res://addons/external_shader_editor/shader_context_menu.gd")
const InterceptorScript := preload("res://addons/external_shader_editor/editor_open_interceptor.gd")

var _settings: SettingsScript
var _launcher: LauncherScript
var _context_menu: ContextMenuScript
var _interceptor: InterceptorScript


func _enter_tree() -> void:
	_settings = SettingsScript.new()
	_settings.initialize(EditorInterface.get_editor_settings())

	_launcher = LauncherScript.new()
	_launcher.setup(_settings)

	_context_menu = ContextMenuScript.new()
	_context_menu.setup(_launcher, _settings)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _context_menu)

	_interceptor = InterceptorScript.new()
	call_deferred(&"_install_editor_integrations")


func _install_editor_integrations() -> void:
	if _interceptor != null and _launcher != null:
		_interceptor.setup(_launcher, _settings)


func _exit_tree() -> void:
	if _interceptor != null:
		_interceptor.shutdown()
		_interceptor = null

	if _context_menu != null:
		remove_context_menu_plugin(_context_menu)
		_context_menu = null

	_launcher = null
	if _settings != null:
		_settings.shutdown()
		_settings = null
