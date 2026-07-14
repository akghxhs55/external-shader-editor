@tool
extends RefCounted

const ActionsScript := preload("res://addons/external_shader_editor/shader_context_menu_actions.gd")

const MENU_ITEM_ID := 0x455345
const TREE_POPUP_METHOD := &"FileSystemDock::_tree_rmb_option"
const FILE_LIST_POPUP_METHOD := &"FileSystemDock::_file_list_rmb_option"

var _editor_interface: EditorInterface
var _actions: ActionsScript
var _popups: Array[PopupMenu] = []
var _about_to_show_callbacks := {}


func setup(
	editor_interface: EditorInterface,
	filesystem_dock: Node,
	actions: ActionsScript
) -> void:
	_editor_interface = editor_interface
	_actions = actions
	_find_filesystem_popups(filesystem_dock)
	if _popups.is_empty():
		push_warning(
			"External Shader Editor could not install the Godot 4.0-4.3 FileSystem context menu integration."
		)


func shutdown() -> void:
	for popup in _popups:
		if not is_instance_valid(popup):
			continue
		var callback: Callable = _about_to_show_callbacks.get(
			popup.get_instance_id(),
			Callable()
		)
		if callback.is_valid() and popup.about_to_popup.is_connected(callback):
			popup.about_to_popup.disconnect(callback)
		if popup.id_pressed.is_connected(_on_popup_id_pressed):
			popup.id_pressed.disconnect(_on_popup_id_pressed)
	_popups.clear()
	_about_to_show_callbacks.clear()
	_actions = null
	_editor_interface = null


func _find_filesystem_popups(root: Node) -> void:
	if root == null:
		return

	if root is PopupMenu and _is_filesystem_popup(root):
		var popup := root as PopupMenu
		var about_to_show := _on_popup_about_to_show.bind(popup)
		if not popup.about_to_popup.is_connected(about_to_show):
			popup.about_to_popup.connect(about_to_show)
		if not popup.id_pressed.is_connected(_on_popup_id_pressed):
			popup.id_pressed.connect(_on_popup_id_pressed)
		_popups.append(popup)
		_about_to_show_callbacks[popup.get_instance_id()] = about_to_show

	for child in root.get_children():
		_find_filesystem_popups(child)


func _is_filesystem_popup(popup: PopupMenu) -> bool:
	for connection in popup.get_signal_connection_list(&"id_pressed"):
		var callable: Callable = connection["callable"]
		if not callable.is_valid():
			continue
		var method := callable.get_method()
		if method == TREE_POPUP_METHOD or method == FILE_LIST_POPUP_METHOD:
			return true
	return false


func _on_popup_about_to_show(popup: PopupMenu) -> void:
	_remove_existing_item(popup)
	if _actions == null or _editor_interface == null:
		return

	var selected_paths := _editor_interface.get_selected_paths()
	if not _actions.has_supported_paths(selected_paths):
		return

	popup.add_separator()
	var icon := _actions.get_menu_icon()
	if icon == null:
		popup.add_item(_actions.get_menu_label(), MENU_ITEM_ID)
	else:
		popup.add_icon_item(icon, _actions.get_menu_label(), MENU_ITEM_ID)


func _on_popup_id_pressed(id: int) -> void:
	if id != MENU_ITEM_ID or _actions == null or _editor_interface == null:
		return
	_actions.open_selected(_editor_interface.get_selected_paths())


func _remove_existing_item(popup: PopupMenu) -> void:
	var item_index := popup.get_item_index(MENU_ITEM_ID)
	if item_index < 0:
		return

	popup.remove_item(item_index)
	if item_index > 0 and popup.is_item_separator(item_index - 1):
		popup.remove_item(item_index - 1)
