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

    # Extend / Save As button
    btn_extend = Button.new()
    btn_extend.custom_minimum_size.x = BUTTON_WIDTH
    btn_extend.size_flags_vertical = Control.SIZE_SHRINK_CENTER

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

    if resource.is_sub_resource():
        label_res.placeholder_text = 'Sub Resource'
    else:
        label_res.text = resource.resource_path.get_file()
        label_res.placeholder_text = 'Unknown Resource'

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
            '\n\nLoading a new resource will drop this sub resource and cannot be undone!'
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
                        if err != OK:
                            BehaviorMainEditor.toast(
                                'Failed to save resource to "%s": Error %d' % [path, err],
                                EditorToaster.Severity.SEVERITY_ERROR
                            )
                            return
                        BehaviorMainEditor.toast('Saved resource to "%s"!' % path)
                        popup.call()
                )
                save.popup()
        )
    else:
        confirm.dialog_text = (
            'The current resource has unsaved changes, would you like to save it?' +
            '\n\nLoading a new resource will lose any changes made since the last save!'
        )
        confirm.confirmed.connect(
            func():
                var res: BehaviorExtendedResource = editor.get_resource()
                var err: Error = ResourceSaver.save(res)
                if err != OK:
                    BehaviorMainEditor.toast(
                        'Failed to save resource "%s": Error %d' % [res.resource_name, err],
                        EditorToaster.Severity.SEVERITY_ERROR
                    )
                    return
                BehaviorMainEditor.toast('Saved resource "%s"!' % res.resource_name)
                confirm.tree_exited.connect(popup)
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
    BehaviorMainEditor.INSTANCE.update_item(main_resource)
