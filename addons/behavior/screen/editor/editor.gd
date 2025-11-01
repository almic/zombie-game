@tool
extends HSplitContainer


## Emitted when traveling to behavior menu
signal goto_menu()


var current_resource: Resource
var editor_save: Callable


func _ready() -> void:
    %ButtonRenameResource.pressed.connect(on_rename_resource)
    %ResourceNameEdit.text_submitted.connect(on_rename_resource_submitted)

    %ButtonSaveResource.pressed.connect(save_resource)
    %ButtonCollapseList.icon = get_theme_icon("Back", "EditorIcons")
    %ButtonCollapseList.pressed.connect(on_collapse_list)

    %ButtonMenu.pressed.connect(goto_menu.emit)


func edit(res: Resource) -> void:
    current_resource = res

    %ResourceNameEdit.text = current_resource.resource_name
    %ResourceNameEdit.editable = false
    %ButtonRenameResource.text = "Rename"

    %Menu.visible = false
    %Editor.visible = true

    if current_resource is BehaviorMindSettings:
        %MindEditor.visible = true
        %MindEditor.edit(current_resource)
        editor_save = %MindEditor.save


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
    %ButtonRenameResource.text = "Rename"


func save_resource() -> void:
    # Check if CTRL+S is pressed, then save the current scene as well
    if Input.is_key_pressed(KEY_S) and Input.is_key_pressed(KEY_CTRL):
        EditorInterface.save_scene()

    var updated: bool = editor_save.call()
    if not updated:
        return

    var err: Error = ResourceSaver.save(current_resource)
    if err:
        push_error('Failed to save resource "%s"! Error: ' + str(err))
        editor_save.call(true)
        return
