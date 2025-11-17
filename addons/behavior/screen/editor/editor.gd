@tool
class_name BehaviorMainEditor extends HSplitContainer


const SECTION_EDITOR = &'Editor'

const THEME = preload("uid://d0tmanljmd1ao")
const CREATE = preload("uid://cd6347u3w4lsf")

const LIST_ITEM = &'bhvr_editor_list_item'


static var INSTANCE: BehaviorMainEditor = null

static var SHORTCUT_CLOSE: Shortcut

static func _static_init() -> void:
    SHORTCUT_CLOSE = Shortcut.new()
    var close_event: InputEventKey = InputEventKey.new()
    close_event.keycode = KEY_W
    close_event.ctrl_pressed = true
    close_event.command_or_control_autoremap = true
    SHORTCUT_CLOSE.events = [close_event]


enum Menu {
    CLOSE = 1,
}


class ResourceItem:
    var resource: BehaviorExtendedResource
    var editor: BehaviorResourceEditor

    ## Child items, this list is just meant to keep a reference. Should not be
    ## used to access the child items.
    var children: Array[ResourceItem]

    func _init(
            resource: BehaviorExtendedResource,
            editor: BehaviorResourceEditor = null
    ):
        self.resource = resource
        self.editor = editor
        children = []

    func get_children_editors() -> Array[BehaviorResourceEditor]:
        var result: Array[BehaviorResourceEditor] = []
        var count: int = children.size()
        result.resize(count)
        for i in range(count):
            result[i] = children[i].editor
        return result

    func update_children() -> void:
        children.clear()
        for sub_resource_name in editor.get_sub_resource_names():
            children.append(
                BehaviorMainEditor.INSTANCE.get_or_add_item(resource.get(sub_resource_name))
            )

    ## Saves the resource and updates the editor. If the resource failed to save,
    ## it returns 0. If the resource saved, it returns 1 + the number of children
    ## that also saved. Any children that fail to save will show error messages.
    func save(force: bool = false) -> int:
        var to_save: Array[ResourceItem] = [self]
        var checked: Array[ResourceItem] = []
        var saved: int = 0
        while not to_save.is_empty():
            var item: ResourceItem = to_save.pop_front()
            checked.append(item)

            if force or not item.editor.is_saved:
                if not BehaviorMainEditor.save_resource(item.resource):
                    continue

                item.editor.on_save()
                saved += 1

            for child in item.children:
                if child.editor.is_saved or checked.has(child) or to_save.has(child):
                    continue
                to_save.append(child)

        return saved

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

# Used to ensure only 1 all_items check each call
var _run_all_items: bool = false

# If the node is a "ghost"
var _is_ghost: bool = true

# If the close shortcut can be triggered
var _close_ready: bool = true


func _ready() -> void:
    # NOTE: Godot for some reason creates copies on start up and puts them in
    #       weird SubViewports, so check that my true parent is legit and otherwise
    #       skip everything else
    if get_parent().get_parent().name == &'MainScreen':
        # print('editor.gd is ready! path: %s' % str(get_path()))
        _is_ghost = false
    else:
        # print('ghost editor.gd !')
        return

    INSTANCE = self

    %LineEditFilter.right_icon = get_theme_icon(&'Search', &'EditorIcons')
    %LineEditFilter.text_changed.connect(on_filter_text_changed)

    %ItemList.item_selected.connect(on_item_selected)
    %ItemList.item_clicked.connect(on_item_clicked, CONNECT_DEFERRED)
    %ItemList.set_drag_forwarding(on_drag_start, on_drag_can_drop, on_drag_end)

    %ButtonCollapseList.icon = get_theme_icon(&'Back', &'EditorIcons')
    %ButtonCollapseList.pressed.connect(on_collapse_list)

    %ButtonRename.pressed.connect(on_rename_resource)
    %ResourceNameEdit.text_submitted.connect(on_rename_resource_submitted)

    %ButtonExtend.pressed.connect(extend_current)

    %ButtonSave.pressed.connect(save_current)

    %ButtonNew.pressed.connect(create_resource)

    %ButtonOpen.pressed.connect(open_resource)

    %ButtonMenu.pressed.connect(goto_menu.emit)

    %ExtendsContainer.visible = false
    %ButtonContainer.size_flags_horizontal = SIZE_EXPAND_FILL

    # Update UI as if nothing was selected
    select_item(null)

func _shortcut_input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return

    if SHORTCUT_CLOSE.matches_event(event):
        if event.is_pressed():
            if _close_ready and current_item != null:
                _close_ready = false
                accept_event()
                request_close_item(current_item)
        else:
            _close_ready = true

func save_state(config: ConfigFile) -> void:
    if _is_ghost:
        return

    # print('saving editor state')
    var resource_paths: PackedStringArray
    var open_count: int = opened.size()
    var total: int = 0
    var i: int = 0

    resource_paths.resize(open_count)
    while i < open_count:
        var path: String = opened[i].resource.resource_path
        if path.is_absolute_path():
            resource_paths[total] = path
            total += 1
        i += 1

    if total < open_count:
        resource_paths.resize(total)

    config.set_value(SECTION_EDITOR, 'opened', resource_paths)
    if current_item:
        var path: String = current_item.resource.resource_path
        if path.is_absolute_path():
            config.set_value(SECTION_EDITOR, 'current', path)


func load_state(config: ConfigFile) -> void:
    if _is_ghost:
        return

    # print('loading editor state, path: %s' % str(get_path()))
    var last_opened = config.get_value(SECTION_EDITOR, 'opened', PackedStringArray())
    if last_opened is PackedStringArray:
        for path in last_opened:
            if path.is_empty():
                continue

            var resource: Resource = ResourceLoader.load(path, '', ResourceLoader.CACHE_MODE_REPLACE)
            if not is_instance_of(resource, BehaviorExtendedResource):
                continue

            var item: ResourceItem = get_or_add_item(resource)
            if not item:
                continue

            open_item(item, false)

    var last_active = config.get_value(SECTION_EDITOR, 'current', "")
    if last_active is String and (not last_active.is_empty()):
        var resource: Resource = ResourceLoader.load(last_active)
        if is_instance_of(resource, BehaviorExtendedResource):
            var item: ResourceItem = get_or_add_item(resource)
            if item:
                open_item(item)


func edit(res: Resource) -> void:
    if _is_ghost:
        return

    var item: ResourceItem = get_or_add_item(res, true)

    if item == null:
        return

    open_item(item)

func select_item(item: ResourceItem) -> void:
    if _is_ghost:
        return

    if item != null and item == current_item:
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
        %ButtonExtend.visible = false
        %ExtendsContainer.visible = false
        %ButtonContainer.size_flags_horizontal = SIZE_EXPAND_FILL
        return

    %NoItem.visible = false

    %ButtonRename.visible = true
    %ButtonRename.text = "Rename"

    %ButtonExtend.visible = true
    %ButtonSave.visible = true

    %ResourceNameEdit.visible = true
    %ResourceNameEdit.editable = false
    %ResourceNameEdit.text = current_item.resource.resource_name

    if current_item.resource.base:
        %ExtendsContainer.visible = true
        %ButtonContainer.size_flags_horizontal = SIZE_FILL
        %LabelExtends.text = current_item.resource.base.resource_path.get_file()
    else:
        %ExtendsContainer.visible = false
        %ButtonContainer.size_flags_horizontal = SIZE_EXPAND_FILL

    # Give editor any child editors
    current_item.editor.accept_editors(current_item.get_children_editors())

    # Ensure the editor is on the main window
    if current_item.editor.get_parent():
        current_item.editor.reparent(%Editors, false)
    else:
        %Editors.add_child(current_item.editor)
    current_item.editor.visible = true

    if not grab_focus_block:
        current_item.editor.grab_focus()

    # Select from list (if not selected)
    var selected: PackedInt32Array = %ItemList.get_selected_items()
    if not selected.is_empty() and current_item == %ItemList.get_item_metadata(selected[0]).get_ref():
        return

    var idx: int = get_item_index(current_item)
    if idx != -1:
        %ItemList.select(idx)
        return

    # Temporarily add to the list, put at the top
    idx = add_to_item_list(item)
    move_item(idx, 0)
    %ItemList.select(0)
    check_saved()


## Ensures a resource is in the "all items" list. This does not open or select
## the item. This is mainly responsible for instancing a ResourceItem
func get_or_add_item(resource: BehaviorExtendedResource, reload: bool = false) -> ResourceItem:
    if _is_ghost:
        return null

    for item in all_items:
        if item.resource == resource:
            return item

    if reload:
        resource = ResourceLoader.load(resource.resource_path, '', ResourceLoader.CACHE_MODE_REPLACE)

    # print('Creating item for resource "%s"' % resource.resource_path)

    var editor: BehaviorResourceEditor = BehaviorResourceEditor.get_editor_for_resource(resource)
    if not editor:
        push_error('Unknown resource type "%s"!' % (resource.get_script() as Script).get_global_name())
        return null

    editor.focus_mode = Control.FOCUS_ALL
    editor.visible = false
    editor.set_resource(resource)

    var item: ResourceItem = ResourceItem.new(resource, editor)
    item.update_children()
    item.editor.accept_editors(item.get_children_editors())
    all_items.append(item)

    return item

func update_item(resource: BehaviorExtendedResource, mark_changed: bool = false) -> void:
    for item in all_items:
        if item.resource == resource:
            item.update_children()
            item.editor.accept_editors(item.get_children_editors())
            if mark_changed:
                item.editor.on_change()
            check_all_items()
            break

func get_item_index(item: ResourceItem) -> int:
    for i in range(%ItemList.item_count):
        if item == %ItemList.get_item_metadata(i).get_ref():
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
    var item: ResourceItem = %ItemList.get_item_metadata(idx).get_ref()

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
            new_idx = opened.find(%ItemList.get_item_metadata(new_idx).get_ref())
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

            var res: Resource = ResourceLoader.load(file, '', ResourceLoader.CACHE_MODE_REPLACE)
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
        check_saved()

        return

func on_filter_text_changed(filter: String) -> void:
    update_list()

func on_item_clicked(idx: int, at_pos: Vector2, mouse_button: int) -> void:
    if mouse_button == MouseButton.MOUSE_BUTTON_LEFT:
        select_item(%ItemList.get_item_metadata(idx).get_ref())
        return
    elif mouse_button == MouseButton.MOUSE_BUTTON_RIGHT:
        show_popup_menu(idx)
        return

func on_item_selected(idx: int) -> void:
    grab_focus_block = !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) # Quote: "amazing hack, simply amazing"
    select_item(%ItemList.get_item_metadata(idx).get_ref())
    grab_focus_block = false

func on_popup_id_pressed(id: int, item_idx: int) -> void:
    if item_idx < 0 or item_idx >= %ItemList.item_count:
        return

    var item: ResourceItem = %ItemList.get_item_metadata(item_idx).get_ref()
    if id == Menu.CLOSE:
        request_close_item(item)
        return

func request_close_item(item: ResourceItem) -> void:
    if item.editor.is_saved:
        close_item(item)
        return

    var confirm: AcceptDialog = AcceptDialog.new()
    confirm.theme = self.theme
    confirm.title = 'Resource has unsaved changes'
    confirm.ok_button_text = 'Save & Close'

    confirm.dialog_text = (
            'This resource has been modified since it was last saved:\n\n' +
            item.resource.resource_path + '\n\n' +
            'Would you like to save it?'
    )

    confirm.add_button('Close Anyway', false, &'close')
    confirm.add_cancel_button('Cancel')

    confirm.confirmed.connect(
        func():
            confirm.queue_free()
            var res_name: String = item.resource.resource_name
            if res_name.is_empty():
                res_name = item.resource.resource_path
            if item.save(true):
                confirm.tree_exited.connect(close_item.bind(item))
                return
    )

    confirm.custom_action.connect(
        func(action: StringName):
            if action == &'close':
                confirm.queue_free()
                confirm.tree_exited.connect(close_item.bind(item))
    )

    confirm.canceled.connect(confirm.queue_free)

    EditorInterface.popup_dialog_centered(confirm)

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

    current_item.resource.resource_name = new_name
    current_item.editor.on_change()

    %ResourceNameEdit.editable = false
    %ResourceNameEdit.text = current_item.resource.resource_name
    %ButtonRename.text = "Rename"

func add_to_item_list(item: ResourceItem) -> int:
    var idx: int = %ItemList.add_item(item.resource.resource_path.get_file())
    %ItemList.set_item_icon(idx, get_theme_icon("Warning", "EditorIcons"))
    %ItemList.set_item_icon_modulate(idx, Color(0, 0, 0, 0))
    %ItemList.set_item_metadata(idx, weakref(item))
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

func open_resource() -> void:
    EditorInterface.popup_quick_open((
        func(path: String):
            if path.is_empty():
                return
            var res: BehaviorExtendedResource = ResourceLoader.load(path)
            if not res:
                push_error('Failed to open resource at "%s" for editing!' % path)
                return
            edit(res)
    ), [&'BehaviorExtendedResource'])

func move_item(from: int, to: int) -> void:
    if from == to:
        return

    # If fewer than two items, ignore
    if %ItemList.item_count < 2:
        return

    var item_from: ResourceItem = %ItemList.get_item_metadata(from).get_ref()
    var item_to: ResourceItem = %ItemList.get_item_metadata(to).get_ref()

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
    if select_next and %ItemList.item_count > 0:
        selected = true
        var items: PackedInt32Array = %ItemList.get_selected_items()
        if items.is_empty():
            # Try to pick the new item at the same index
            var next: int = clampi(idx, 0, %ItemList.item_count - 1)
            select_item(%ItemList.get_item_metadata(next).get_ref())

    if not selected:
        select_item(null)

    check_all_items()

func extend_current() -> void:
    if not current_item:
        toast('No opened behavior resource to extend.', EditorToaster.SEVERITY_WARNING)
        return

    var script_type: GDScript = current_item.resource.get_script() as GDScript
    if not script_type:
        push_error('Failed to extend resource, could not get resource script!')
        return

    var extended_resource: BehaviorExtendedResource = script_type.new() as BehaviorExtendedResource
    if not extended_resource:
        push_error('Failed to create new resource from base type!')
        return

    extended_resource.base = current_item.resource

    var save_dialog: EditorFileDialog = EditorFileDialog.new()
    save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
    save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
    save_dialog.filters = PackedStringArray(['*.tres ; Text Resource', '*.res ; Binary Resource'])
    save_dialog.current_file = 'extended_resource.tres'
    save_dialog.file_selected.connect(
        func(path: String):
            if path.is_empty():
                return
            extended_resource.take_over_path(path)
            var err: Error = ResourceSaver.save(extended_resource)
            if err == OK:
                BehaviorMainEditor.toast('Saved resource to "%s"!' % path)
            else:
                BehaviorMainEditor.toast(
                    'Failed to save resource to "%s": Error %d' % [path, err],
                    EditorToaster.Severity.SEVERITY_ERROR
                )
            edit(extended_resource)
    )
    save_dialog.popup()


func save_current() -> void:
    # Check if CTRL+S is pressed, then save the current scene as well
    var shortcut_used: bool = Input.is_key_pressed(KEY_S) and Input.is_key_pressed(KEY_CTRL)

    if shortcut_used:
        if not is_visible_in_tree():
            # Do not save from CTRL+S if the window is not visible
            return
        EditorInterface.save_scene()

    if not current_item:
        toast('No opened behavior resource to save.', EditorToaster.SEVERITY_WARNING)
        return

    current_item.save(shortcut_used)

static func save_resource(resource: BehaviorExtendedResource, show_toast: bool = true) -> bool:
    var err: Error = ResourceSaver.save(resource)
    if err == OK:
        if show_toast:
            var res_name: String = resource.resource_name
            if res_name.is_empty():
                res_name = resource.resource_path
            toast('Saved resource "%s"!' % res_name)
        return true

    if show_toast:
        var msg: String = 'Failed to save resource "%s"! Error: %d' % [resource.resource_path, err]
        toast(msg, EditorToaster.SEVERITY_ERROR)
        push_error(msg)

    return false

func save_all() -> void:
    for item in opened:
        item.save(true)

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

func check_all_items() -> void:
    _run_all_items = true
    _check_all_items.call_deferred()

func _check_all_items() -> void:
    if not _run_all_items:
        return

    # print('Checking all items')
    _run_all_items = false

    # print('current_item = ' + str(current_item))
    var first: bool = true
    var removed: bool = false
    # var count_removed: int = 0
    while first or removed:
        first = false
        removed = false
        var count: int = all_items.size()
        var i: int = 0
        while i < count:
            # NOTE: Count should be 2 when the item is only referenced in 'all_items'
            #       and here (+1 when getting the ref count). Can be safely removed.
            var item: ResourceItem = all_items[i]
            var ref_count: int = item.get_reference_count()
            if ref_count == 2:
                # print('freed item "%s"' % item.resource.resource_path)
                item.editor.queue_free()
                item.editor = null
                item.resource = null
                all_items.remove_at(i)
                removed = true
                count -= 1
                # count_removed += 1
            else:
                # print('item "%s" has %d refs' % [item.resource.resource_path, ref_count])
                i += 1
    # print('Freed %d items' % count_removed)

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
    check_saved()

func check_saved() -> void:
    _run_check_list = true
    _check_saved.call_deferred()

func _check_saved() -> void:
    if not _run_check_list:
        return

    _run_check_list = false

    for i in range(%ItemList.item_count):
        var item: ResourceItem = %ItemList.get_item_metadata(i).get_ref()
        if item.editor.is_saved:
            %ItemList.set_item_icon_modulate(i, Color(0, 0, 0, 0))
        else:
            %ItemList.set_item_icon_modulate(i, Color(1, 1, 1, 1))

func is_saved() -> bool:
    for item in opened:
        if not item.editor.is_saved:
            return false
    return true

func get_unsaved() -> PackedStringArray:
    var unsaved: PackedStringArray
    for item in opened:
        if not item.editor.is_saved:
            unsaved.append(item.resource.resource_path)
    return unsaved

static func toast(
        message: String,
        severity: EditorToaster.Severity = EditorToaster.Severity.SEVERITY_INFO,
        tooltip: String = ''
) -> void:
    EditorInterface.get_editor_toaster().push_toast(message, severity, tooltip)
