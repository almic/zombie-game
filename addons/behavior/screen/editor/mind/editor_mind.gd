@tool
extends MarginContainer


var resource: BehaviorMindSettings:
    set = set_resource

var is_saved: bool = true


var _label_vision: LineEdit
var _btn_vision_extend: Button

var _label_hearing: LineEdit
var _btn_hearing_extend: Button


func _ready() -> void:
    if not resource:
        push_error('Must have a resource before adding to scene!')
        return

    setup_settings(%VisionSettings, &'vision')
    setup_settings(%HearingSettings, &'hearing')

    resource = resource


func setup_settings(container: ExpandableContainer, type: StringName) -> void:
    const btn_width = 80

    var label: LineEdit
    var btn_extend: Button
    if type == &'vision':
        _label_vision = LineEdit.new()
        _btn_vision_extend = Button.new()

        label = _label_vision
        btn_extend = _btn_vision_extend
    elif type == &'hearing':
        _label_hearing = LineEdit.new()
        _btn_hearing_extend = Button.new()

        label = _label_hearing
        btn_extend = _btn_hearing_extend

    var title_bar: HBoxContainer = HBoxContainer.new()
    title_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
    title_bar.add_theme_constant_override('separation', 8)
    title_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var title: Label = Label.new()
    title.text = type.capitalize()
    title.custom_minimum_size.y = 40
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    label.editable = false
    label.placeholder_text = 'Sub Resource'
    label.expand_to_text_length = true
    label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN | Control.SIZE_EXPAND
    label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    var button_bar: HBoxContainer = HBoxContainer.new()
    button_bar.alignment = BoxContainer.ALIGNMENT_END
    button_bar.add_theme_constant_override('separation', 8)
    button_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
    button_bar.mouse_filter = Control.MOUSE_FILTER_STOP

    # New button
    var btn_new: Button = Button.new()
    btn_new.text = 'New'
    btn_new.custom_minimum_size.x = btn_width
    btn_new.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    # Extend / Save As button
    btn_extend.custom_minimum_size.x = btn_width
    btn_extend.size_flags_vertical = Control.SIZE_SHRINK_CENTER


    # Load button
    var btn_load: Button = Button.new()
    btn_load.text = 'Load'
    btn_load.custom_minimum_size.x = btn_width
    btn_load.size_flags_vertical = Control.SIZE_SHRINK_CENTER


    # Final layout
    button_bar.add_spacer(true)
    button_bar.add_child(btn_extend)
    button_bar.add_child(btn_load)
    button_bar.add_child(btn_new)
    button_bar.add_spacer(false)


    title_bar.add_child(title)
    title_bar.add_child(label)
    title_bar.add_child(button_bar)

    container.set_title_control(title_bar)


func accept_editors(vision: Control, hearing: Control) -> void:
    %VisionSettings.set_expandable_control(vision)
    %HearingSettings.set_expandable_control(hearing)

func save(failed: bool = false) -> bool:
    if is_saved:
        return false

    if failed:
        is_saved = false
        return true

    is_saved = true
    return true

func set_resource(res: BehaviorMindSettings) -> void:
    resource = res

    update_labels(resource.sense_vision, _label_vision, set_extendable_vision)
    update_labels(resource.sense_hearing, _label_hearing, set_extendable_hearing)

func update_labels(res: Resource, label: LineEdit, extendable_func: Callable) -> void:
    if not label:
        return

    if not res.resource_scene_unique_id.is_empty():
        label.text = ''
        extendable_func.call(false)
    else:
        label.text = res.resource_path.get_file()
        extendable_func.call(true)

func set_extendable_hearing(extendable: bool) -> void:
    _set_extendable(_btn_hearing_extend, extendable, extend_hearing)

func set_extendable_vision(extendable: bool) -> void:
    _set_extendable(_btn_vision_extend, extendable, extend_vision)

## Extend the current vision resource and save it. If 'is_original' is true,
## this will just save it as a new resource.
func extend_vision(is_original: bool) -> void:
    pass

## Extend the current hearing resource and save it. If 'is_original' is true,
## this will just save it as a new resource.
func extend_hearing(is_original: bool) -> void:
    pass

func _set_extendable(btn: Button, extendable: bool, extend_func) -> void:
    for c in btn.pressed.get_connections():
        btn.pressed.disconnect(c.callable)

    if extendable:
        btn.text = 'Extend'
        btn.tooltip_text = 'Create a new resource that inherits from the current resource and load it'
        btn.pressed.connect(extend_func.bind(false))
    else:
        btn.text = 'Save As'
        btn.tooltip_text = 'Save this sub resource to the file system and reference it'
        btn.pressed.connect(extend_func.bind(true))
