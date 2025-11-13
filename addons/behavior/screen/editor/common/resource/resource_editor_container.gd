@tool
class_name BehaviorResourceEditorContainer extends ExpandableContainer


## Width of the button in the title bar
const BUTTON_WIDTH = 80
## Minimum height of the title bar
const MIN_HEIGHT = 40


var editor: BehaviorResourceEditor
var main_resource: BehaviorExtendedResource
var property_name: StringName


var label_title: Label
var label_res: LineEdit
var sep_override: Control
var btn_override: CheckButton
var btn_extend: Button
var btn_load: Button
var btn_new: Button


func _ready() -> void:
    super._ready()

    if get_parent().name.begins_with('@SubViewport@'):
        # AHHHH
        return

    label_res = LineEdit.new()
    label_res.theme_type_variation = &'LabelMono'
    label_res.editable = false
    label_res.expand_to_text_length = true
    label_res.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN | Control.SIZE_EXPAND
    label_res.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    title = HBoxContainer.new()
    title.alignment = BoxContainer.ALIGNMENT_BEGIN
    title.add_theme_constant_override('separation', 8)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.tooltip_text = property_name

    label_title = Label.new()
    label_title.custom_minimum_size.y = MIN_HEIGHT
    label_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    var button_bar: HBoxContainer = HBoxContainer.new()
    button_bar.alignment = BoxContainer.ALIGNMENT_END
    button_bar.add_theme_constant_override('separation', 8)
    button_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
    button_bar.mouse_filter = Control.MOUSE_FILTER_STOP

    # Override toggle button
    btn_override = CheckButton.new()
    btn_override.visible = false
    # TODO: button things

    # New button
    btn_new = Button.new()
    btn_new.text = 'New'
    btn_new.custom_minimum_size.x = BUTTON_WIDTH
    btn_new.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    btn_new.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
    btn_new.pressed.connect(on_new)

    # Extend / Save As button
    btn_extend = Button.new()
    btn_extend.custom_minimum_size.x = BUTTON_WIDTH
    btn_extend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    btn_extend.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS

    # Load button
    btn_load = Button.new()
    btn_load.text = 'Load'
    btn_load.custom_minimum_size.x = BUTTON_WIDTH
    btn_load.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    btn_load.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
    btn_load.pressed.connect(on_load)

    # Final layout
    button_bar.add_spacer(true)
    button_bar.add_child(btn_extend)
    button_bar.add_child(btn_load)
    button_bar.add_child(btn_new)
    button_bar.add_spacer(false)

    sep_override = title.add_spacer(true)
    sep_override.visible = false

    title.add_child(btn_override)
    title.add_child(label_title)
    title.add_child(label_res)
    title.add_child(button_bar)

    # NOTE: what the fuck how does this work
    # title_bar.add_child(title)

    update_title_bar()

func get_property_resource() -> BehaviorExtendedResource:
    if not main_resource:
        return null
    return main_resource.get(property_name) as BehaviorExtendedResource

func set_resource_and_property(resource: BehaviorExtendedResource, property: StringName) -> void:
    main_resource = resource
    property_name = property

    update_title_bar()

func set_editor(editor: BehaviorResourceEditor) -> void:
    self.editor = editor
    set_expandable_control(self.editor)

func update_title_bar() -> void:
    if not is_node_ready():
        return

    var resource: BehaviorExtendedResource = get_property_resource()

    label_title.text = property_name.capitalize()

    if resource and resource.is_sub_resource():
        label_res.placeholder_text = 'Sub Resource'
        label_res.text = ''

        btn_extend.text = 'Save As'
        btn_extend.tooltip_text = (
                'Save this sub-resource as an external resource.' +
                '\nExternal resources can be loaded and shared with many resources.'
        )

        if btn_extend.pressed.is_connected(on_extend):
            btn_extend.pressed.disconnect(on_extend)
        if not btn_extend.pressed.is_connected(on_save_as):
            btn_extend.pressed.connect(on_save_as)
    else:
        if resource:
            label_res.text = resource.resource_path.get_file()
        else:
            label_res.text = ''
        label_res.placeholder_text = 'Unknown Resource'

        btn_extend.text = 'Extend'
        btn_extend.tooltip_text = (
                'Extend this resource to inherit its values.' +
                '\nExtended resources use overrides to modify attributes from a parent.'
        )

        if btn_extend.pressed.is_connected(on_save_as):
            btn_extend.pressed.disconnect(on_save_as)
        if not btn_extend.pressed.is_connected(on_extend):
            btn_extend.pressed.connect(on_extend)

func on_load() -> void:
    var resource: BehaviorExtendedResource = get_property_resource()
    var resource_script: Script = resource.get_script() as Script

    var type_name: StringName = resource_script.get_global_name()
    if type_name.is_empty():
        push_error('Resource script at "%s" is missing a "class_name" declaration! Please fix!' % resource_script.resource_path)
        return

    var popup: Callable = EditorInterface.popup_quick_open.bind(
            on_load_resource_property,
            [type_name]
    )

    if not editor:
        popup.call()
        return

    if editor.is_saved and not resource.is_sub_resource():
        popup.call()
        return

    var confirm: ConfirmationDialog = ConfirmationDialog.new()
    confirm.theme = self.theme
    confirm.title = 'Resource has unsaved changes'
    confirm.ok_button_text = 'Save & Load'

    var load_button: Button = confirm.add_button('Load Anyway', true, &'load')
    if resource.is_sub_resource():
        confirm.dialog_text = (
            'The current resource is a sub resource, would you like to save it ' +
            'as a new resource first?' +
            '\n\nLoading a new resource will discard this sub resource and cannot be undone!'
        )

        confirm.confirmed.connect(
            func():
                var save: EditorFileDialog = EditorFileDialog.new()
                save.access = EditorFileDialog.ACCESS_RESOURCES
                save.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
                save.filters = PackedStringArray(['*.tres ; Text Resource', '*.res ; Binary Resource'])
                save.current_file = 'new_resource.tres'
                save.file_selected.connect(
                    func(path: String):
                        var err: Error = ResourceSaver.save(editor.get_resource(), path, ResourceSaver.FLAG_CHANGE_PATH)
                        if err == OK:
                            BehaviorMainEditor.toast('Saved resource to "%s"!' % path)
                            popup.call()
                        else:
                            BehaviorMainEditor.toast(
                                'Failed to save resource to "%s": Error %d' % [path, err],
                                EditorToaster.Severity.SEVERITY_ERROR
                            )
                )
                save.popup()
        )
    else:
        confirm.dialog_text = (
            'The current resource has unsaved changes, would you like to save it?' +
            '\n\nLoading a new resource will discard any changes made since the last save!'
        )
        confirm.confirmed.connect(
            func():
                var res: BehaviorExtendedResource = editor.get_resource()
                var err: Error = ResourceSaver.save(res)
                if err == OK:
                    BehaviorMainEditor.toast('Saved resource "%s"!' % res.resource_name)
                    confirm.tree_exited.connect(popup)
                else:
                    BehaviorMainEditor.toast(
                        'Failed to save resource "%s": Error %d' % [res.resource_name, err],
                        EditorToaster.Severity.SEVERITY_ERROR
                    )
        )

    confirm.custom_action.connect(
        func(action: StringName):
            if action != &'load':
                return
            confirm.queue_free()
            confirm.tree_exited.connect(popup)
    )

    EditorInterface.popup_dialog_centered(confirm)
    load_button.grab_focus() # NOTE: Select this one by default

func on_load_resource_property(path: String) -> void:
    if path.is_empty():
        return
    var resource: BehaviorExtendedResource = ResourceLoader.load(path) as BehaviorExtendedResource
    if not resource:
        EditorInterface.get_editor_toaster().push_toast(
            'Cannot load resource at path "%s"!' % path,
            EditorToaster.SEVERITY_ERROR
        )
        return
    main_resource.set(property_name, resource)
    BehaviorMainEditor.INSTANCE.update_item(main_resource, true)

func on_new() -> void:
    var property_info: Dictionary = main_resource.get_property_info(property_name)
    var type_name: StringName = property_info.class_name
    var resource_script: GDScript = BehaviorExtendedResource.get_script_from_name(type_name)

    if not resource_script:
        push_error('Cannot create instances of type "%s", unable to get GDScript base!' % type_name)
        return

    var popup: Callable = on_new_resource_property.bind(resource_script)

    if not editor:
        popup.call()
        return

    var resource: BehaviorExtendedResource = get_property_resource()

    if editor.is_saved and not resource.is_sub_resource():
        popup.call()
        return

    var confirm: ConfirmationDialog = ConfirmationDialog.new()
    confirm.theme = self.theme
    confirm.title = 'Resource has unsaved changes'
    confirm.ok_button_text = 'Save'

    var discard_button: Button = confirm.add_button('Discard Changes', true, &'discard')
    if resource.is_sub_resource():
        confirm.dialog_text = (
            'The current resource is a sub resource, would you like to save it ' +
            'as a new resource first?' +
            '\n\nCreating a new resource will discard this sub resource and cannot be undone!'
        )

        confirm.confirmed.connect(
            func():
                var save: EditorFileDialog = EditorFileDialog.new()
                save.access = EditorFileDialog.ACCESS_RESOURCES
                save.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
                save.filters = PackedStringArray(['*.tres ; Text Resource', '*.res ; Binary Resource'])
                save.current_file = 'new_resource.tres'
                save.file_selected.connect(
                    func(path: String):
                        var err: Error = ResourceSaver.save(editor.get_resource(), path, ResourceSaver.FLAG_CHANGE_PATH)
                        if err == OK:
                            BehaviorMainEditor.toast('Saved resource to "%s"!' % path)
                            popup.call()
                        else:
                            BehaviorMainEditor.toast(
                                'Failed to save resource to "%s": Error %d' % [path, err],
                                EditorToaster.Severity.SEVERITY_ERROR
                            )
                )
                save.popup()
        )
    else:
        confirm.dialog_text = (
            'The current resource has unsaved changes, would you like to save it?' +
            '\n\nCreating a new resource will discard any changes made since the last save!'
        )
        confirm.confirmed.connect(
            func():
                var res: BehaviorExtendedResource = editor.get_resource()
                var err: Error = ResourceSaver.save(res)
                if err == OK:
                    BehaviorMainEditor.toast('Saved resource "%s"!' % res.resource_name)
                    confirm.tree_exited.connect(popup)
                else:
                    BehaviorMainEditor.toast(
                        'Failed to save resource "%s": Error %d' % [res.resource_name, err],
                        EditorToaster.Severity.SEVERITY_ERROR
                    )
        )

    confirm.custom_action.connect(
        func(action: StringName):
            if action != &'discard':
                return
            confirm.queue_free()
            confirm.tree_exited.connect(popup)
    )

    EditorInterface.popup_dialog_centered(confirm)
    discard_button.grab_focus() # NOTE: Select this one by default

func on_new_resource_property(type_script: GDScript, base: BehaviorExtendedResource = null) -> void:
    var new_resource: BehaviorExtendedResource = type_script.new() as BehaviorExtendedResource
    if not new_resource:
        push_error('Failed to create new resource type "%s"!' % type_script.get_global_name())
        return

    new_resource.base = base

    var set_new_resource: Callable = (
        func():
            main_resource.set(property_name, new_resource)
            new_resource._on_load(new_resource.resource_path)
            BehaviorMainEditor.INSTANCE.update_item(main_resource, true)
    )

    var save_or_sub: AcceptDialog = AcceptDialog.new()
    save_or_sub.title = 'Save as external, or use as sub-resource?'
    save_or_sub.dialog_text = (
            'Would you like to save this resource now as an external resource, ' +
            'or use it as a sub-resource that is stored within the parent resource?' +
            '\n\nChoosing cancel will NOT create a new resource, keeping the current resource.'
    )
    save_or_sub.get_label().custom_minimum_size.x = 400
    save_or_sub.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD
    save_or_sub.ok_button_text = 'Save External'
    save_or_sub.add_button('Use Sub-Resource', false, &'sub')
    save_or_sub.add_cancel_button('Cancel')

    save_or_sub.confirmed.connect(
        func():
            save_or_sub.queue_free()
            var save_dialog: EditorFileDialog = EditorFileDialog.new()
            save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
            save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
            save_dialog.filters = PackedStringArray(['*.tres ; Text Resource', '*.res ; Binary Resource'])
            save_dialog.current_file = 'new_resource.tres'
            save_dialog.file_selected.connect(
                func(path: String):
                    new_resource.take_over_path(path)
                    var err: Error = ResourceSaver.save(new_resource)
                    if err == OK:
                        BehaviorMainEditor.toast('Saved resource to "%s"!' % path)
                    else:
                        BehaviorMainEditor.toast(
                            'Failed to save resource to "%s": Error %d' % [path, err],
                            EditorToaster.Severity.SEVERITY_ERROR
                        )
                    set_new_resource.call()
            )
            save_or_sub.tree_exited.connect(save_dialog.popup)
    )
    save_or_sub.custom_action.connect(
        func(action: StringName):
            if action != &'sub':
                return

            save_or_sub.queue_free()
            # Immitate Godot's name system
            var sub_id: String = type_script.get_global_name() + '_' + Resource.generate_scene_unique_id()
            new_resource.resource_scene_unique_id = sub_id
            new_resource.resource_path = main_resource.resource_path + '::' + sub_id
            set_new_resource.call()
    )

    EditorInterface.popup_dialog_centered(save_or_sub)

func on_save_as() -> void:
    if not editor:
        push_error('No editor, cannot save the sub-resource!')
        return

    var resource: BehaviorExtendedResource = editor.get_resource()
    if not resource:
        push_error('No resource in the editor, cannot save the sub-resource!')
        return

    var save: EditorFileDialog = EditorFileDialog.new()
    save.access = EditorFileDialog.ACCESS_RESOURCES
    save.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
    save.filters = PackedStringArray(['*.tres ; Text Resource', '*.res ; Binary Resource'])
    save.current_file = 'new_resource.tres'
    save.file_selected.connect(
        func(path: String):
            resource.take_over_path(path)
            var err: Error = ResourceSaver.save(resource)
            if err == OK:
                BehaviorMainEditor.toast('Saved resource to "%s"!' % path)
                update_title_bar()
            else:
                BehaviorMainEditor.toast(
                    'Failed to save resource to "%s": Error %d' % [path, err],
                    EditorToaster.Severity.SEVERITY_ERROR
                )
    )
    save.popup()

func on_extend() -> void:
    var property_info: Dictionary = main_resource.get_property_info(property_name)
    var type_name: StringName = property_info.class_name
    var resource_script: GDScript = BehaviorExtendedResource.get_script_from_name(type_name)

    if not resource_script:
        push_error('Cannot create instances of type "%s", unable to get GDScript base!' % type_name)
        return

    var resource: BehaviorExtendedResource = get_property_resource()
    if not resource:
        push_error('Cannot extend resource, current resource is null!')
        return

    if resource.is_sub_resource():
        push_error('Cannot extend a sub-resource! This is a bug!')
        return

    var popup: Callable = on_new_resource_property.bind(resource_script, resource)

    if (not editor) or editor.is_saved:
        popup.call()
        return

    var confirm: ConfirmationDialog = ConfirmationDialog.new()
    confirm.theme = self.theme
    confirm.title = 'Resource has unsaved changes'
    confirm.ok_button_text = 'Save'

    var discard_button: Button = confirm.add_button('Discard Changes', true, &'discard')

    confirm.dialog_text = (
        'The current resource has unsaved changes, would you like to save it?' +
        '\n\nExtending this resource will discard any changes made since the last save!'
    )
    confirm.confirmed.connect(
        func():
            var res: BehaviorExtendedResource = editor.get_resource()
            var err: Error = ResourceSaver.save(res)
            if err == OK:
                BehaviorMainEditor.toast('Saved resource "%s"!' % res.resource_name)
                confirm.tree_exited.connect(popup)
            else:
                BehaviorMainEditor.toast(
                    'Failed to save resource "%s": Error %d' % [res.resource_name, err],
                    EditorToaster.Severity.SEVERITY_ERROR
                )
    )

    confirm.custom_action.connect(
        func(action: StringName):
            if action != &'discard':
                return
            confirm.queue_free()
            confirm.tree_exited.connect(popup)
    )

    EditorInterface.popup_dialog_centered(confirm)
    discard_button.grab_focus() # NOTE: Select this one by default
