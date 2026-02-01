@tool
## Testing node intended to quickly run scripts in-editor via a button
class_name TestNode extends Node

@export_tool_button('Run Code')
var btn_execute = execute


func execute() -> void:
    print(tan(PI/2))
