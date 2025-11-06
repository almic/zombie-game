@tool
extends HSplitContainer


const THEME = preload("uid://d0tmanljmd1ao")
const CREATE = preload("uid://cd6347u3w4lsf")

const EDITOR_MIND = preload("uid://dfu7q11sy44hk")
const EDITOR_VISION = preload("uid://dh5k5n1pp0xmg")
const EDITOR_HEARING = preload("uid://b7bxudl0ogo2i")

const LIST_ITEM = &'bhvr_editor_list_item'


enum Menu {
    CLOSE = 1,
}

class ResourceItem:
    var resource: Resource
    var editor: BehaviorResourceEditor

    ## Child items, this list is just meant to keep a reference. Should not be
    ## used to access the child items.
    var children: Array[ResourceItem]

    func _init(resource: Resource, editor: BehaviorResourceEditor = null):
        self.resource = resource
        self.editor = editor
        children = []


## Emitted when traveling to behavior menu
signal goto_menu()


var current_item: ResourceItem
var popup_menu: PopupMenu

var all_items: Array[ResourceItem]
var opened: Array[ResourceItem]

# Copied from engine source
var grab_focus_block: bool = false

# Used to ensure only 1 list save check each call
var _run_check_list: bool = false


func _ready() -> void:
    %LineEditFilter.right_icon = get_theme_icon(&'Search', &'EditorIcons')
    %LineEditFilter.text_changed.connect(on_filter_text_changed)

    %ItemList.item_selected.connect(on_item_selected)
    %ItemList.item_clicked.connect(on_item_clicked, CONNECT_DEFERRED)
    %ItemList.set_drag_forwarding(on_drag_start, on_drag_can_drop, on_drag_end)

    %ButtonCollapseList.icon = get_theme_icon(&'Back', &'EditorIcons')
    %ButtonCollapseList.pressed.connect(on_collapse_list)

    %ButtonRename.pressed.connect(on_rename_resource)
    %ResourceNameEdit.text_submitted.connect(on_rename_resource_submitted)

    %ButtonSave.pressed.connect(save_resource)

    %ButtonNew.pressed.connect(create_resource)

    %ButtonMenu.pressed.connect(goto_menu.emit)


func edit(res: Resource) -> void:
    var item: ResourceItem = get_or_add_item(res)

    if item == null:
        return

    open_item(item)

func select_item(item: ResourceItem) -> void:
    if item == current_item:
        return

    if current_item:
        current_item.editor.visible = false

    current_item = item

    if not current_item:
        %NoItem.visible = true
        %ResourceNameEdit.release_focus()
        %ResourceNameEdit.editable = false
        %ResourceNameEdit.visible = false
        %ButtonRename.visible = false
        %ButtonSave.visible = false
        return

    %NoItem.visible = false

    %ButtonRename.visible = true
    %ButtonRename.text = "Rename"

    %ButtonSave.visible = true

    %ResourceNameEdit.visible = true
    %ResourceNameEdit.editable = false
    %ResourceNameEdit.text = current_item.resource.resource_name

    # Ensure the editor is on the main window
    if current_item.editor.get_parent():
        current_item.editor.reparent(%Editors, false)
    else:
        %Editors.add_child(current_item.editor)
    current_item.editor.visible = true

    if current_item.resource is BehaviorMindSettings:
        var resource: BehaviorMindSettings = current_item.resource as BehaviorMindSettings
        var vision := get_or_add_item(resource.sense_vision)
        var hearing := get_or_add_item(resource.sense_hearing)
        current_item.editor.accept_editors(vision.editor, hearing.editor)

    if not grab_focus_block:
        current_item.editor.grab_focus()

    # Select from list (if not selected)
    var selected: PackedInt32Array = %ItemList.get_selected_items()
    if not selected.is_empty() and current_item == %ItemList.get_item_metadata(selected[0]):
        return

    var idx: int = get_item_index(current_item)
    if idx != -1:
        %ItemList.select(idx)
        return

    # Temporarily add to the list, put at the top
    idx = add_to_item_list(item)
    move_item(idx, 0)
    %ItemList.select(0)


## Ensures a resource is in the "all items" list. This does not open or select
## the item. This is mainly responsible for instancing a ResourceItem
func get_or_add_item(resource: Resource) -> ResourceItem:
    for item in all_items:
        if item.resource == resource:
            return item

    var editor: BehaviorResourceEditor
    var children: Array[ResourceItem]
    if resource is BehaviorMindSettings:
        editor = EDITOR_MIND.instantiate()
        var vision := get_or_add_item(resource.sense_vision)
        var hearing := get_or_add_item(resource.sense_hearing)
        children = [vision, hearing]
    elif resource is BehaviorSenseVisionSettings:
        editor = EDITOR_VISION.instantiate()
    elif resource is BehaviorSenseHearingSettings:
        editor = EDITOR_HEARING.instantiate()
    # TODO: add other editor types
    # elif res is ... :
    else:
        push_error('Unknown resource type "%s"!' % (resource.get_script() as Script).get_global_name())
        return null

    editor.focus_mode = Control.FOCUS_ALL
    editor.visible = false
    editor.set_resource(resource)

    var item: ResourceItem = ResourceItem.new(resource, editor)
    item.children.append_array(children)
    all_items.append(item)

    return item

func get_item_index(item: ResourceItem) -> int:
    for i in range(%ItemList.item_count):
        if item == %ItemList.get_item_metadata(i):
            return i
    return -1

func on_collapse_list() -> void:
    if not %ResourceList.visible:
        %ResourceList.visible = true
        %ButtonCollapseList.icon = get_theme_icon("Back", "EditorIcons")
        dragger_visibility = SplitContainer.DRAGGER_VISIBLE
        return

    %ResourceList.visible = false
    %ButtonCollapseList.icon = get_theme_icon("Forward", "EditorIcons")
    dragger_visibility = SplitContainer.DRAGGER_HIDDEN_COLLAPSED

func on_drag_start(at: Vector2) -> Variant:
    if not %ItemList.is_anything_selected():
        return null

    var idx: int = %ItemList.get_selected_items()[0]
    var item: ResourceItem = %ItemList.get_item_metadata(idx)

    var preview: PanelContainer = PanelContainer.new()
    preview.theme = THEME
    preview.theme_type_variation = 'DragPreview'
    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override('margin_right', 4)
    margin.add_theme_constant_override('margin_left', 4)
    var label: Label = Label.new()
    label.text = item.resource.resource_path.get_file()
    margin.add_child(label)
    preview.add_child(margin)
    %ItemList.set_drag_preview(preview)

    return {
        type = LIST_ITEM,
        idx = idx,
    }

func on_drag_can_drop(at: Vector2, data: Variant) -> bool:
    var d: Dictionary = data as Dictionary
    if d.get('type') == LIST_ITEM:
        if typeof(d.get('idx')) == TYPE_INT:
            return true
    # From the file system
    elif str(d.get('type')) == 'files':
        # Accept if any file matches our types
        for file in d.get('files'):
            if file.is_empty() or not FileAccess.file_exists(file):
                continue
            if ResourceLoader.exists(file, 'Resource'):
                return true
    return false

func on_drag_end(at: Vector2, data: Variant) -> void:
    if not on_drag_can_drop(at, data):
        return

    var d: Dictionary = data as Dictionary

    var new_idx: int = 0
    if at == Vector2.INF:
        if %ItemList.is_anything_selected():
            new_idx = %ItemList.get_selected_items()[0]
    else:
        new_idx = %ItemList.get_item_at_position(at)

    if d.get('type') == LIST_ITEM:
        var from_idx: int = (data as Dictionary).get('idx')
        move_item(from_idx, new_idx)
        return

    if str(d.get('type')) == 'files':
        if %ItemList.item_count > 0:
            new_idx = opened.find(%ItemList.get_item_metadata(new_idx))
            if new_idx == -1:
                push_error('Unable to find original item index when dropping files!')
                new_idx = 0

        # Load many files
        var last_item: ResourceItem = null
        for file in d.get('files'):
            if file.is_empty() or not FileAccess.file_exists(file):
                continue
            if not ResourceLoader.exists(file, 'Resource'):
                continue

            var res: Resource = ResourceLoader.load(file)
            if not res:
                push_error('Failed to load resource "%s" from file drop!' % file)
                continue

            var bvhr_res: BehaviorExtendedResource = res as BehaviorExtendedResource
            if not bvhr_res:
                toast('Resource at "%s" is not a recognized Behavior resource type.' % file, EditorToaster.SEVERITY_WARNING)
                continue

            var item := get_or_add_item(bvhr_res)
            open_item(item, false)
            last_item = item

            var idx: int = get_item_index(item)
            if idx != -1:
                # Already in our list
                continue

            # Add to list in place
            idx = add_to_item_list(item)
            move_item(idx, new_idx)
            new_idx += 1

        if last_item:
            select_item(last_item)

        return

func on_filter_text_changed(filter: String) -> void:
    update_list()

func on_item_clicked(idx: int, at_pos: Vector2, mouse_button: int) -> void:
    if mouse_button == MouseButton.MOUSE_BUTTON_LEFT:
        select_item(%ItemList.get_item_metadata(idx))
        return
    elif mouse_button == MouseButton.MOUSE_BUTTON_RIGHT:
        show_popup_menu(idx)
        return

func on_item_selected(idx: int) -> void:
    grab_focus_block = !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) # Quote: "amazing hack, simply amazing"
    select_item(%ItemList.get_item_metadata(idx))
    grab_focus_block = false

func on_popup_id_pressed(id: int, item_idx: int) -> void:
    if item_idx < 0 or item_idx >= %ItemList.item_count:
        return

    var item: ResourceItem = %ItemList.get_item_metadata(item_idx)
    if id == Menu.CLOSE:
        # TODO: check if not saved and ask to save
        close_item(item)
        return

func on_rename_resource() -> void:
    if not current_item:
        toast('No resource opened!', EditorToaster.SEVERITY_WARNING)
        return

    if not %ResourceNameEdit.editable:
        %ResourceNameEdit.text = current_item.resource.resource_name
        %ResourceNameEdit.editable = true
        %ResourceNameEdit.edit()
        %ResourceNameEdit.caret_column = %ResourceNameEdit.text.length()
        %ButtonRename.text = "Confirm"
        return

    on_rename_resource_submitted(%ResourceNameEdit.text)

func on_rename_resource_submitted(new_name: String) -> void:
    if not current_item:
        toast('No resource opened!', EditorToaster.SEVERITY_WARNING)

    var old_name: String = current_item.resource.resource_name
    current_item.resource.resource_name = new_name

    var err: Error = ResourceSaver.save(current_item.resource)
    if err:
        push_error('Error renaming resource from "' + old_name + '" to "' + new_name + '": ' + str(err))
        current_item.resource.resource_name = old_name
        return

    %ResourceNameEdit.editable = false
    %ResourceNameEdit.text = current_item.resource.resource_name
    %ButtonRename.text = "Rename"

func add_to_item_list(item: ResourceItem) -> int:
    var idx: int = %ItemList.add_item(item.resource.resource_path.get_file())
    %ItemList.set_item_icon(idx, get_theme_icon("Warning", "EditorIcons"))
    %ItemList.set_item_icon_modulate(idx, Color(0, 0, 0, 0))
    %ItemList.set_item_metadata(idx, item)
    return idx

func create_resource() -> void:
    var popup: AcceptDialog = AcceptDialog.new()
    popup.title = 'Create New Resource'
    popup.get_label().visible = false
    popup.get_ok_button().visible = false
    popup.theme = theme

    var create: Control = CREATE.instantiate()
    create.new_resource.connect(
        func(res: Resource):
            edit(res)
            popup.queue_free()
    )
    create.canceled.connect(
        func():
            popup.queue_free()
    )

    popup.add_child(create)

    EditorInterface.popup_dialog_centered(popup)

func move_item(from: int, to: int) -> void:
    if from == to:
        return

    # If fewer than two items, ignore
    if %ItemList.item_count < 2:
        return

    var item_from: ResourceItem = %ItemList.get_item_metadata(from)
    var item_to: ResourceItem = %ItemList.get_item_metadata(to)

    if not item_from or not item_to:
        return

    var item_from_idx: int = opened.find(item_from)
    var item_to_idx: int = opened.find(item_to)

    if item_from_idx == -1 or item_to_idx == -1:
        return

    opened.remove_at(item_from_idx)
    opened.insert(item_to_idx, item_from)

    %ItemList.move_item(from, to)

## Ensures an item is in the "opened" list, allowing it to appear in the main
## item list. It will also be selected for editing, but this can be disabled by
## passing 'false' as the second parameter.
func open_item(item: ResourceItem, select: bool = true) -> void:
    if not opened.has(item):
        opened.append(item)
        item.editor.changed.connect(check_saved)
        item.editor.saved.connect(check_saved)

    if select:
        select_item(item)

## Remove an item from the "opened" list, preventing it from showing up in the
## main item list. It will also open the next available item for editing, but
## this can be disabled by passing 'false' as the second parameter.
func close_item(item: ResourceItem, select_next: bool = true) -> void:
    opened.erase(item)

    if item.editor.changed.is_connected(check_saved):
        item.editor.changed.disconnect(check_saved)
    if item.editor.saved.is_connected(check_saved):
        item.editor.saved.disconnect(check_saved)

    var idx: int = get_item_index(item)
    if idx != -1:
        %ItemList.remove_item(idx)

    var selected: bool = false
    if select_next:
        var items: PackedInt32Array = %ItemList.get_selected_items()
        if items.size() > 0:
            var next: int = clampi(items[0] - 1, 0, %ItemList.item_count - 1)
            select_item(%ItemList.get_item_metadata(next))
            selected = true

    if not selected:
        select_item(null)

    update_all_items.call_deferred()

func save_resource() -> void:
    # Check if CTRL+S is pressed, then save the current scene as well
    if Input.is_key_pressed(KEY_S) and Input.is_key_pressed(KEY_CTRL):
        EditorInterface.save_scene()

    if not current_item:
        toast('No opened behavior resource to save.')

    var err: Error = ResourceSaver.save(current_item.resource)
    if err == OK:
        current_item.editor.on_save()
        var res_name: String = current_item.resource.resource_name
        if res_name.is_empty():
            res_name = current_item.resource.resource_path
        toast('Saved resource "%s"!' % res_name)
    else:
        var msg: String = 'Failed to save resource "%s"! Error: %d' % [current_item.resource.resource_path, err]
        toast(msg, EditorToaster.SEVERITY_ERROR)
        push_error(msg)

func show_popup_menu(idx: int) -> void:
    if not popup_menu:
        popup_menu = PopupMenu.new()
        add_child(popup_menu)

    var sh: Shortcut
    var ev: InputEventKey
    popup_menu.clear()

    sh = Shortcut.new()
    ev = InputEventKey.new()
    ev.keycode = KEY_W
    ev.ctrl_pressed = true
    sh.events.append(ev)
    popup_menu.add_item("Close", Menu.CLOSE)
    popup_menu.set_item_shortcut(-1, sh)

    popup_menu.position = get_screen_position() + get_local_mouse_position()
    popup_menu.reset_size()
    for connection in popup_menu.id_pressed.get_connections():
        popup_menu.id_pressed.disconnect(connection.callable)
    popup_menu.id_pressed.connect(on_popup_id_pressed.bind(idx), CONNECT_ONE_SHOT)
    popup_menu.popup()

func update_all_items() -> void:
    var first: bool = true
    var removed: bool = false
    while first or removed:
        first = false
        removed = false
        var count: int = all_items.size()
        var i: int = 0
        while i < count:
            # NOTE: Count should be 2 when the item is only referenced in 'all_items'
            #       and here (+1 when getting the ref count). Can be safely removed.
            var ref_count: int = all_items[i].get_reference_count()
            if ref_count == 2:
                all_items.remove_at(i)
                removed = true
                count -= 1
            else:
                i += 1

func update_list() -> void:

    %ItemList.clear()
    if opened.is_empty():
        return

    var filtered: Array[ResourceItem]

    if %LineEditFilter.text.is_empty():
        filtered = opened
    else:
        var names: PackedStringArray = []
        for item in opened:
            names.append(item.resource.resource_path.get_file())

        var results: Array = []
        String.fuzzy_search(%LineEditFilter.text, names, results)
        results.sort_custom(
            func(a: Dictionary, b: Dictionary):
                return a.original_index < b.original_index
        )

        filtered.resize(results.size())
        var i: int = 0
        for search in results:
            filtered[i] = opened[search.original_index]
            i += 1

    %LabelNoFilterItems.visible = filtered.is_empty()

    for item in filtered:
        var idx: int = add_to_item_list(item)
        if item == current_item:
            %ItemList.select(idx)

func check_saved() -> void:
    _run_check_list = true
    _check_saved.call_deferred()

func _check_saved() -> void:
    if not _run_check_list:
        return

    _run_check_list = false

    for i in range(%ItemList.item_count):
        var item: ResourceItem = %ItemList.get_item_metadata(i)
        if item.editor.is_saved:
            %ItemList.set_item_icon_modulate(i, Color(0, 0, 0, 0))
        else:
            %ItemList.set_item_icon_modulate(i, Color(1, 1, 1, 1))


static func toast(
        message: String,
        severity: EditorToaster.Severity = EditorToaster.Severity.SEVERITY_INFO,
        tooltip: String = ''
) -> void:
    EditorInterface.get_editor_toaster().push_toast(message, severity, tooltip)
