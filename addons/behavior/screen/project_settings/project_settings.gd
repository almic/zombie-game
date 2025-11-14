@tool
extends Control

const GROUP_ITEM = preload("uid://dsx2ght6i0kuv")


## Emitted when traveling to behavior menu
signal goto_menu()


var group_item_base: HBoxContainer

var has_unsaved: bool = false


func _ready() -> void:
    # print('ready project_settings.gd at path: %s' % str(get_path()))
    if get_parent().get_parent().name != &'MainScreen':
        # fake
        return

    group_item_base = GROUP_ITEM.instantiate()
    (group_item_base.get_node('delete') as Button).icon = get_theme_icon("Remove", "EditorIcons")

    %ButtonAddSoundGroup.icon = get_theme_icon("Add", "EditorIcons")
    %ButtonAddVisionGroup.icon = get_theme_icon("Add", "EditorIcons")

    %ButtonAddSoundGroup.pressed.connect(popup_add_group.bind(add_sound_group, 'Sound'))
    %ButtonAddVisionGroup.pressed.connect(popup_add_group.bind(add_vision_group, 'Vision'))

    %ButtonSave.pressed.connect(save_all)
    %ButtonMenu.pressed.connect(goto_menu.emit)

    ProjectSettings.settings_changed.connect(refresh_groups)
    tree_exiting.connect((
        func():
            if ProjectSettings.settings_changed.is_connected(refresh_groups):
                ProjectSettings.settings_changed.disconnect(refresh_groups)
    ), CONNECT_ONE_SHOT)
    refresh_groups()


func popup_add_group(next: Callable, type: String) -> void:
    var confirm: ConfirmationDialog = ConfirmationDialog.new()
    confirm.title = 'Create %s Group' % type
    confirm.dialog_text = 'Type a group name'
    confirm.ok_button_text = 'Create'

    var name_edit: LineEdit = LineEdit.new()
    name_edit.text_changed.connect(
        # Allow only underscores and lowercase ascii letters
        func(text: String):
            var cursor_pos: int = name_edit.caret_column
            var result: String = ""
            var stripped: bool = false
            for ch in text:
                if ch == ' ' or ch == '_' or ch == '-':
                    result += '_'
                    continue
                var c = ord(ch)
                if c >= ord('A') and c <= ord('Z'):
                    result += char(c + 32)
                    continue
                if c >= ord('a') and c <= ord('z'):
                    result += ch
                    continue
                cursor_pos = max(0, cursor_pos - 1)
                stripped = true

            if stripped:
                EditorInterface.get_editor_toaster().push_toast("Only ascii letters and underscores are allowed for group names!")

            name_edit.text = result
            name_edit.caret_column = cursor_pos
    )

    confirm.add_child(name_edit)
    confirm.register_text_enter(name_edit)
    confirm.confirmed.connect((
        func():
            # Ensure text is formatted well
            name_edit.text_changed.emit(name_edit.text)
            next.call(name_edit.text)
    ), CONNECT_ONE_SHOT)

    EditorInterface.popup_dialog_centered(confirm)


func add_sound_group(group_name: String) -> void:
    group_name = (
          BehaviorSystemConstants.GLOBAL_GROUP_PREFIX
        + BehaviorSystemConstants.SOUND_GROUP_PREFIX
        + group_name
    )

    ProjectSettings.set_setting(group_name, '')
    save_all()
    refresh_groups()


func add_vision_group(group_name: String) -> void:
    group_name = (
          BehaviorSystemConstants.GLOBAL_GROUP_PREFIX
        + BehaviorSystemConstants.VISION_GROUP_PREFIX
        + group_name
    )

    ProjectSettings.set_setting(group_name, '')
    save_all()
    refresh_groups()


func refresh_groups() -> void:
    for child in %VisionGroups.get_children():
        child.queue_free()
    for child in %SoundGroups.get_children():
        child.queue_free()

    %LabelNoVisionGroups.visible = true
    %LabelNoSoundGroups.visible = true

    var groups: Dictionary = ProjectSettings.get_global_groups()
    for group in groups:
        var group_name: StringName = group
        var group_desc: String = groups.get(group)

        var group_prefix: String
        var group_type: String
        var group_list: VBoxContainer

        if group_name.begins_with(BehaviorSystemConstants.SOUND_GROUP_PREFIX):
            group_prefix = BehaviorSystemConstants.SOUND_GROUP_PREFIX
            group_list = %SoundGroups
            group_type = 'Sound'
            %LabelNoSoundGroups.visible = false
        elif group_name.begins_with(BehaviorSystemConstants.VISION_GROUP_PREFIX):
            group_prefix = BehaviorSystemConstants.VISION_GROUP_PREFIX
            group_list = %VisionGroups
            group_type = 'Vision'
            %LabelNoVisionGroups.visible = false
        else:
            continue

        var group_item := group_item_base.duplicate()
        var display_name: StringName = group_name.get_slice(group_prefix, 1)
        (group_item.get_node('name') as Label).text = display_name
        var desc_edit: LineEdit = (group_item.get_node('description') as LineEdit)
        desc_edit.text = group_desc
        desc_edit.text_changed.connect(func(_s: String): has_unsaved = true)
        desc_edit.text_submitted.connect(func(_s: String): save_all())
        (group_item.get_node('delete') as Button).pressed.connect(
                delete_group.bind(group_name, group_type, display_name)
        )
        group_list.add_child(group_item)

func delete_group(group_name: StringName, type: String, display: String) -> void:
    var confirm: ConfirmationDialog = ConfirmationDialog.new()
    confirm.title = 'Delete Group'
    confirm.ok_button_text = 'Delete'

    var vbox: VBoxContainer = VBoxContainer.new()

    var main_label: Label = Label.new()
    main_label.text = 'Are you sure you wish to delete the %s group' % type
    main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(main_label)

    var display_label: Label = Label.new()
    display_label.add_theme_font_size_override('font_size', 20)
    display_label.text = display
    display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(display_label)

    var group_box: HBoxContainer = HBoxContainer.new()
    group_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    group_box.add_theme_constant_override('separation', 0)

    var full_label: Label = Label.new()
    full_label.add_theme_font_size_override('font_size', 14)
    full_label.add_theme_color_override('font_color', Color8(255, 255, 255, 160))
    full_label.text = 'Full name:'
    group_box.add_child(full_label)

    var group_label: Label = Label.new()
    var group_label_style: StyleBoxFlat = StyleBoxFlat.new()
    group_label_style.content_margin_top = 3.0
    group_label_style.content_margin_bottom = 3.0
    group_label_style.content_margin_left = 6.0
    group_label_style.content_margin_right = 6.0
    group_label_style.bg_color = Color8(0, 0, 0, 48)

    group_label.add_theme_stylebox_override('normal', group_label_style)
    var mono: SystemFont = SystemFont.new()
    mono.font_names = ['Office Code Pro D', 'Courier', 'monospace']
    group_label.add_theme_font_override('font', mono)
    group_label.add_theme_color_override('font_color', Color8(255, 255, 255, 160))
    group_label.text = group_name
    group_box.add_child(group_label)

    vbox.add_child(group_box)

    confirm.add_child(vbox)

    confirm.confirmed.connect((
        func():
            ProjectSettings.set_setting(BehaviorSystemConstants.GLOBAL_GROUP_PREFIX + group_name, null)
            save_all()
    ), CONNECT_ONE_SHOT)

    EditorInterface.popup_dialog_centered(confirm)

## Saves the current UI states to project settings
func save_all() -> void:
    # Check if CTRL+S is pressed, then save the current scene as well
    if is_visible_in_tree() and Input.is_key_pressed(KEY_S) and Input.is_key_pressed(KEY_CTRL):
        EditorInterface.save_scene()

    var groups := [
        [%VisionGroups, BehaviorSystemConstants.VISION_GROUP_PREFIX],
        [%SoundGroups, BehaviorSystemConstants.SOUND_GROUP_PREFIX],
    ]

    for g in groups:
        for item in g[0].get_children():
            var group_name: String = (item.get_node('name') as Label).text
            group_name = BehaviorSystemConstants.GLOBAL_GROUP_PREFIX + g[1] + group_name
            var group_desc: String = (item.get_node('description') as LineEdit).text
            ProjectSettings.set_setting(group_name, group_desc)

    ProjectSettings.save()
    has_unsaved = false

func is_saved() -> bool:
    return not has_unsaved
