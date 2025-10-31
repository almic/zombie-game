@tool
extends Control


var current_resource: Resource

var _is_renaming: bool


func _ready() -> void:
    %CreateNew.new_resource.connect(_edit)
    %CreateNew.visible = true

    %Main.visible = false

    %ButtonRenameResource.pressed.connect(on_rename_resource)
    %ResourceNameEdit.text_submitted.connect(on_rename_resource_submitted)


func _edit(res: Resource) -> void:
    current_resource = res

    %ResourceName.text = res.resource_name
    %ResourceName.visible = true
    %ResourceNameEdit.visible = false
    %ButtonRenameResource.text = "Rename"
    _is_renaming = false

    %CreateNew.visible = false
    %Main.visible = true

    if res is BehaviorMindSettings:
        %MindEditor.visible = true


func on_rename_resource() -> void:
    if not _is_renaming:
        %ResourceNameEdit.text = %ResourceName.text
        %ResourceName.visible = false
        %ResourceNameEdit.visible = true
        %ButtonRenameResource.text = "Confirm"
        _is_renaming = true
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

    %ResourceName.text = current_resource.resource_name
    %ButtonRenameResource.text = "Rename"
    %ResourceNameEdit.visible = false
    %ResourceName.visible = true
    _is_renaming = false
