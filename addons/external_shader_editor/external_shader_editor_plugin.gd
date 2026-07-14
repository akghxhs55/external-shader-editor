@tool
extends EditorPlugin

const SettingsScript := preload("res://addons/external_shader_editor/external_shader_editor_settings.gd")
const LauncherScript := preload("res://addons/external_shader_editor/external_editor_launcher.gd")
const ContextMenuActionsScript := preload("res://addons/external_shader_editor/shader_context_menu_actions.gd")
const LegacyContextMenuScript := preload("res://addons/external_shader_editor/legacy_shader_context_menu.gd")
const ModernContextMenuFactoryScript := preload("res://addons/external_shader_editor/shader_context_menu.gd")
const InterceptorScript := preload("res://addons/external_shader_editor/editor_open_interceptor.gd")

const CONTEXT_SLOT_FILESYSTEM := 1

var _editor_interface: EditorInterface
var _settings: SettingsScript
var _launcher: LauncherScript
var _context_menu_actions: ContextMenuActionsScript
var _context_menu: RefCounted
var _uses_modern_context_menu := false
var _interceptor: InterceptorScript


func _enter_tree() -> void:
	_editor_interface = get_editor_interface()

	_settings = SettingsScript.new()
	_settings.initialize(_editor_interface.get_editor_settings())

	_launcher = LauncherScript.new()
	_launcher.setup(_settings, _editor_interface)

	_context_menu_actions = ContextMenuActionsScript.new()
	_context_menu_actions.setup(_editor_interface, _launcher, _settings)
	_install_context_menu()

	_interceptor = InterceptorScript.new()
	call_deferred(&"_install_editor_integrations")


func _install_editor_integrations() -> void:
	if _interceptor != null and _launcher != null:
		_interceptor.setup(_launcher, _settings, _editor_interface)


func _install_context_menu() -> void:
	_uses_modern_context_menu = (
		ClassDB.class_exists(&"EditorContextMenuPlugin")
		and has_method(&"add_context_menu_plugin")
	)
	if _uses_modern_context_menu:
		_context_menu = ModernContextMenuFactoryScript.create(_context_menu_actions)
		if _context_menu == null:
			return
		call(&"add_context_menu_plugin", CONTEXT_SLOT_FILESYSTEM, _context_menu)
		return

	_context_menu = LegacyContextMenuScript.new()
	_context_menu.setup(
		_editor_interface,
		_editor_interface.get_file_system_dock(),
		_context_menu_actions
	)


func _exit_tree() -> void:
	if _interceptor != null:
		_interceptor.shutdown()
		_interceptor = null

	if _context_menu != null and _uses_modern_context_menu:
		call(&"remove_context_menu_plugin", _context_menu)
	elif _context_menu != null:
		_context_menu.shutdown()
	if _context_menu != null:
		_context_menu = null
	_context_menu_actions = null
	_uses_modern_context_menu = false

	_launcher = null
	if _settings != null:
		_settings.shutdown()
		_settings = null
	_editor_interface = null
