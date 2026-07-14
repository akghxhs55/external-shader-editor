@tool
extends RefCounted

const MODERN_CONTEXT_MENU_SOURCE := """
@tool
extends EditorContextMenuPlugin

var _actions: RefCounted


func setup(actions: RefCounted) -> void:
	_actions = actions


func _popup_menu(paths: PackedStringArray) -> void:
	if _actions == null or not _actions.has_supported_paths(paths):
		return

	add_context_menu_item(
		_actions.get_menu_label(),
		_actions.open_selected,
		_actions.get_menu_icon()
	)
"""


static func create(actions: RefCounted) -> RefCounted:
	var script := GDScript.new()
	script.source_code = MODERN_CONTEXT_MENU_SOURCE
	var error := script.reload()
	if error != OK:
		push_error("Could not create the External Shader Editor context menu plugin.")
		return null

	var context_menu: RefCounted = script.new()
	context_menu.setup(actions)
	return context_menu
