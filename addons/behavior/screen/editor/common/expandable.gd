@tool
class_name ExpandableContainer extends VBoxContainer


var title_panel: PanelContainer
var title_bar: HBoxContainer
var icon: TextureRect

var title: Control:
    set = set_title_control

var expandable: Control

@export
var is_expanded: bool = true:
    set = set_expanded

@export
var allow_interaction: bool = true:
    set = set_interaction

var is_hovering: bool = false:
    set = set_hovering

var icon_fold: Texture2D:
    set(value):
        icon_fold = value
        update_icon()

var icon_show: Texture2D:
    set(value):
        icon_show = value
        update_icon()

@export
var icon_visible: bool:
    set = set_icon_visible, get = get_icon_visible

@export_range(0, 1, 1, 'or_greater')
var icon_separation: int:
    set = set_icon_separation

@export
var title_theme_variation: StringName = &''


func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_filter = Control.MOUSE_FILTER_STOP

    title_panel = PanelContainer.new()
    title_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

    title_bar = HBoxContainer.new()
    icon = TextureRect.new()
    icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED

    title_bar.add_child(icon, false, Node.INTERNAL_MODE_FRONT)

    title_panel.add_child(title_bar, false, Node.INTERNAL_MODE_FRONT)
    add_child(title_panel, false, Node.INTERNAL_MODE_FRONT)

    if title:
        title_bar.add_child(title)

    # Search first child and make it the expandable
    if not expandable and get_child_count() > 0:
        set_expandable_control(get_child(0))
    else:
        # Force an update
        set_expandable_control(expandable)

    if not icon_fold:
        icon_fold = get_theme_icon(&'GuiTreeArrowDown', &'EditorIcons')
    if not icon_show:
        icon_show = get_theme_icon(&'GuiTreeArrowRight', &'EditorIcons')

    is_hovering = false
    icon_separation = icon_separation
    update_icon()

func _gui_input(event: InputEvent) -> void:
    if not allow_interaction:
        return

    if event is InputEventMouseMotion:
        if title_panel.get_rect().has_point(event.position):
            if not is_hovering:
                is_hovering = true
        elif is_hovering:
            is_hovering = false
        return

    if event.is_action_pressed(&'ui_accept', false, true):
        is_expanded = not is_expanded
        accept_event()
        return

    if event is InputEventMouseButton:
        if (
                event.button_index == MouseButton.MOUSE_BUTTON_LEFT
            and event.pressed
            and title_panel.get_rect().has_point(event.position)
        ):
            is_expanded = not is_expanded
            accept_event()
            return

func _notification(what: int) -> void:
    if what == NOTIFICATION_MOUSE_EXIT:
        if is_hovering:
            is_hovering = false


func _draw() -> void:
    if is_expanded and expandable:
        var type: StringName = &'ExpandableContainer'
        if not theme_type_variation.is_empty():
            type = theme_type_variation

        var stylebox: StyleBox = get_theme_stylebox(&'background', type)

        # Use content margins to shift the expanded panel box
        var rect: Rect2 = Rect2(0, title_panel.size.y, size.x, size.y - title_panel.size.y)
        if stylebox.content_margin_top > 0:
            rect.position.y += stylebox.content_margin_top
            rect.size.y -= stylebox.content_margin_top
        if stylebox.content_margin_bottom > 0:
            rect.size.y -= stylebox.content_margin_bottom
        if stylebox.content_margin_left > 0:
            rect.position.x += stylebox.content_margin_left
            rect.size.x -= stylebox.content_margin_left
        if stylebox.content_margin_right > 0:
            rect.size.x -= stylebox.content_margin_right

        draw_style_box(stylebox, rect)


func update_icon() -> void:
    if is_expanded:
        icon.texture = icon_fold
    else:
        icon.texture = icon_show

func set_expanded(expanded: bool) -> void:
    is_expanded = expanded
    is_hovering = is_hovering # NOTE: trigger stylebox update
    update_icon()
    queue_redraw()

    if not expandable:
        return

    expandable.visible = is_expanded

func set_hovering(hovering: bool) -> void:
    is_hovering = hovering

    var type: StringName = &'FoldableContainer'
    if not title_theme_variation.is_empty():
        type = title_theme_variation

    var style: StyleBox
    if is_hovering:
        if is_expanded:
            style = get_theme_stylebox(&'title_hover_panel', type)
        else:
            style = get_theme_stylebox(&'title_collapsed_hover_panel', type)
    elif is_expanded:
        style = get_theme_stylebox(&'title_panel', type)
    else:
        style = get_theme_stylebox(&'title_collapsed_panel', type)

    style.set_content_margin_all(0)
    style.content_margin_left = 8
    title_panel.add_theme_stylebox_override(&'panel', style)

func set_interaction(allowed: bool) -> void:
    allow_interaction = allowed
    if is_hovering:
        is_hovering = false
        queue_redraw()

func set_title_control(control: Control) -> void:
    if title:
        title_bar.remove_child(title)

    title = control

    if is_node_ready():
        title_bar.add_child(title)

func set_expandable_control(control: Control) -> void:
    if expandable and expandable.get_parent() == self:
        remove_child(expandable)

    expandable = control

    if not expandable:
        return

    expandable.visible = is_expanded

    if is_node_ready():
        if expandable.get_parent():
            expandable.reparent(self, false)
        else:
            add_child(expandable)
        move_child(expandable, 0)

func set_expandable_separation(separation: int) -> void:
    add_theme_constant_override('separation', separation)

func set_icon_separation(separation: int) -> void:
    icon_separation = separation
    if title_bar:
        title_bar.add_theme_constant_override('separation', separation)

func set_icon_visible(value: bool) -> void:
    if not icon:
        ready.connect((func(): icon.visible = value), CONNECT_ONE_SHOT)
        return
    icon.visible = value

func get_icon_visible() -> bool:
    return icon.visible
