@tool
extends VBoxContainer


var current_resource: Resource
var editor_save: Callable


func _ready() -> void:
    %ButtonRenameResource.pressed.connect(on_rename_resource)
    %ResourceNameEdit.text_submitted.connect(on_rename_resource_submitted)

    %ButtonSaveResource.pressed.connect(save_resource)

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
    editor_save.call()
    ResourceSaver.save(current_resource)
    EditorInterface.save_scene()
