@tool
extends HSplitContainer


const THEME = preload("uid://d0tmanljmd1ao")
const CREATE = preload("uid://cd6347u3w4lsf")

const EDITOR_MIND = preload("uid://dfu7q11sy44hk")
const EDITOR_VISION = preload("uid://dh5k5n1pp0xmg")

const LIST_ITEM = &'bhvr_editor_list_item'


enum Menu {
    CLOSE = 1,
}

class ResourceItem:
    var resource: Resource
    var editor: Control

    func _init(resource: Resource, editor: Control = null):
        self.resource = resource
        self.editor = editor


## Emitted when traveling to behavior menu
signal goto_menu()


var current_item: ResourceItem
var popup_menu: PopupMenu

var all_items: Array[ResourceItem]

# Copied from engine source
var grab_focus_block: bool = false


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
    var item: ResourceItem = get_or_add_resource(res)

    if item == null:
        return

    select_item(item)


func select_item(item: ResourceItem) -> void:
    if item == current_item:
        return

    if current_item:
        current_item.editor.visible = false
    else:
        %NoItem.visible = false
    current_item = item

    current_item.editor.visible = true
    if current_item.resource is BehaviorMindSettings:
        pass


    if not grab_focus_block:
        current_item.editor.grab_focus()

    %ResourceNameEdit.text = current_item.resource.resource_name
    %ResourceNameEdit.editable = false
    %ButtonRename.text = "Rename"

    # Select from list (if not selected)
    var selected: PackedInt32Array = %ItemList.get_selected_items()
    if not selected.is_empty() and item == %ItemList.get_item_metadata(selected[0]):
        return

    var idx: int = get_item_index(item)
    if idx != -1:
        %ItemList.select(idx)
        return

    # Must add to the list
    idx = add_to_item_list(item)
    move_item(idx, 0)
    %ItemList.select(0)


func get_or_add_resource(res: Resource) -> ResourceItem:
    for item in all_items:
        if item.resource == res:
            return item

    var editor: Control
    if res is BehaviorMindSettings:
        editor = EDITOR_MIND.instantiate()
        var vision := get_or_add_resource(res.sense_vision)
        #var hearing := get_or_add_resource(res.sense_hearing)
        editor.accept_editors(vision.editor, null)
    elif res is BehaviorSenseVisionSettings:
        editor = EDITOR_VISION.instantiate()
    # TODO: add other editor types
    # elif res is ... :
    else:
        push_error('Unknown resource type "%s"! Cannot open for editing.' % (res.get_script() as Script).get_global_name())
        return null

    editor.focus_mode = Control.FOCUS_ALL
    editor.visible = false
    editor.resource = res
    %Editors.add_child(editor)

    var res_item: ResourceItem = ResourceItem.new(res, editor)
    all_items.append(res_item)

    return res_item

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
            new_idx = all_items.find(%ItemList.get_item_metadata(new_idx))
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

            var item := get_or_add_resource(bvhr_res)
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
        %Editors.remove_child(item.editor)
        %ItemList.remove_item(item_idx)
        all_items.erase(item)
        current_item = null

        if %ItemList.item_count == 0:
            %NoItem.visible = true
            %ResourceNameEdit.text = ''
            return

        # Select next index
        item_idx = clampi(item_idx - 1, 0, %ItemList.item_count - 1)
        %ItemList.select(item_idx)
        %ItemList.item_selected.emit(item_idx)

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

    var item_from_idx: int = all_items.find(item_from)
    var item_to_idx: int = all_items.find(item_to)

    if item_from_idx == -1 or item_to_idx == -1:
        return

    all_items.remove_at(item_from_idx)
    all_items.insert(item_to_idx, item_from)

    %ItemList.move_item(from, to)


func save_resource() -> void:
    # Check if CTRL+S is pressed, then save the current scene as well
    if Input.is_key_pressed(KEY_S) and Input.is_key_pressed(KEY_CTRL):
        EditorInterface.save_scene()

    if not current_item:
        toast('No opened behavior resource to save.')

    var err: Error = ResourceSaver.save(current_item.resource)
    if err:
        push_error('Failed to save resource "%s"! Error: %d' % [current_item.resource.resource_path, err])


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

func update_list() -> void:

    %ItemList.clear()
    if all_items.is_empty():
        return

    var filtered: Array[ResourceItem]

    if %LineEditFilter.text.is_empty():
        filtered = all_items
    else:
        var names: PackedStringArray = []
        for item in all_items:
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
            filtered[i] = all_items[search.original_index]
            i += 1

    %LabelNoFilterItems.visible = filtered.is_empty()

    for item in filtered:
        add_to_item_list(item)


static func toast(
        message: String,
        severity: EditorToaster.Severity = EditorToaster.Severity.SEVERITY_INFO,
        tooltip: String = ''
) -> void:
    EditorInterface.get_editor_toaster().push_toast(message, severity, tooltip)
