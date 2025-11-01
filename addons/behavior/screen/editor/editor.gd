@tool
extends HSplitContainer


const CREATE = preload("uid://cd6347u3w4lsf")


## Emitted when traveling to behavior menu
signal goto_menu()


var current_resource: Resource


func _ready() -> void:
    %ButtonCollapseList.icon = get_theme_icon("Back", "EditorIcons")
    %ButtonCollapseList.pressed.connect(on_collapse_list)

    %ButtonRename.pressed.connect(on_rename_resource)
    %ResourceNameEdit.text_submitted.connect(on_rename_resource_submitted)

    %ButtonSave.pressed.connect(save_resource)

    %ButtonNew.pressed.connect(create_resource)

    %ButtonMenu.pressed.connect(goto_menu.emit)


func edit(res: Resource) -> void:
    current_resource = res

    %ResourceNameEdit.text = current_resource.resource_name
    %ResourceNameEdit.editable = false
    %ButtonRename.text = "Rename"

    # TODO: open new editor and add to list


func on_collapse_list() -> void:
    if collapsed:
        %ResourceList.visible = true
        %ButtonCollapseList.icon = get_theme_icon("Back", "EditorIcons")
        dragger_visibility = SplitContainer.DRAGGER_VISIBLE
        collapsed = false
        return

    %ResourceList.visible = false
    %ButtonCollapseList.icon = get_theme_icon("Forward", "EditorIcons")
    dragger_visibility = SplitContainer.DRAGGER_HIDDEN_COLLAPSED
    collapsed = true


func on_rename_resource() -> void:
    if not %ResourceNameEdit.editable:
        %ResourceNameEdit.text = current_resource.resource_name
        %ResourceNameEdit.editable = true
        %ButtonRenameResource.text = "Confirm"
        return

    on_rename_resource_submitted(%ResourceNameEdit.text)


func on_rename_resource_submitted(new_name: String) -> void:
    var old_name: String = current_resource.resource_name
    current_resource.resource_name = new_name

    var err: Error = ResourceSaver.save(current_resource)
    if err:
        push_error('Error renaming resource from "' + old_name + '" to "' + new_name + '": ' + str(err))
        current_resource.resource_name = old_name
        return

    %ResourceNameEdit.editable = false
    %ResourceNameEdit.text = current_resource.resource_name
    %ButtonRename.text = "Rename"


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


func save_resource() -> void:
    # Check if CTRL+S is pressed, then save the current scene as well
    if Input.is_key_pressed(KEY_S) and Input.is_key_pressed(KEY_CTRL):
        EditorInterface.save_scene()

    # TODO: save currently opened resource

    # var err: Error = ResourceSaver.save(current_resource)
    # if err:
    #     push_error('Failed to save resource "%s"! Error: ' + str(err))
