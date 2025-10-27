class_name TextLog extends Control


const META_FADE_DELAY = &'log_fade_delay'
const META_FADE_TIME = &'log_fade_time'


## Emitted when a message is entered by the user
signal on_message(from_user: bool, message: String)


## If this text log can be typed into
@export var is_writable: bool = false

## Maximum number of logs to keep in history
@export var max_logs: int = 200

## Display time of a message when added to the log, before fading out
@export var message_show_time: float = 10.0

## Fade out time of a message when added to the log, after the delay time
@export var message_fade_time: float = 0.8


@onready var input: LineEdit = %input

@onready var box: Control = %box
@onready var grow_bg: ColorRect = %grow_bg
@onready var logs: VBoxContainer = %logs
@onready var scroll: ScrollContainer = %scroll


var is_expanded: bool = false:
    set(value):
        is_expanded = value
        update_expanded()

var is_input_active: bool:
    get():
        return input.is_editing() or input.has_focus()
    set(value):
        if not value:
            if input.is_editing():
                input.unedit()
        elif not input.is_editing():
            input.edit()


var base_log_entry: MarginContainer
var _logs: Array[Control]
var _oldest_idx: int = 0

var _logs_added_timer: float = 0
var _logs_added_last_second: int = 0
var _logs_added_hit_limit: bool = false

var _scroll_bottom: bool = true


func _ready() -> void:
    _logs = []
    _logs.resize(max_logs)

    base_log_entry = %log_entry.duplicate()

    # Clear all children in logs
    for child in logs.get_children():
        logs.remove_child(child)

    # Put back grow_bg node as an internal child
    logs.add_child(grow_bg, false, Node.INTERNAL_MODE_FRONT)

    update_expanded()

    input.text_submitted.connect(on_text_submitted)
    input.editing_toggled.connect(
        func(editing):
            if not editing:
                # Forcibly unfocus when leaving edit mode. Stupid.
                input.release_focus()

                # Collapse when leaving edit mode
                is_expanded = false

                # Try to capture mouse
                GlobalWorld.world.try_capture_mouse()
    )

    scroll.get_v_scroll_bar().scrolling.connect(
        func():
            if _scroll_bottom:
                _scroll_bottom = false
    )


func _process(delta: float) -> void:
    _logs_added_timer += delta

    if _logs_added_timer >= 1.0:
        if _logs_added_last_second >= max_logs:
            push_warning(
                'More than max_logs in the last second! Interrupting execution! ' +
                'You should use fewer logs, or use breakpoints instead of ' +
                'logging so much.\n' +
                'If you are fine with this, just hit "Continue" in the debugger ' +
                'and this warning will be ignored from now on.'
            )

            if not _logs_added_hit_limit:
                _logs_added_hit_limit = true
                breakpoint

        _logs_added_last_second = 0
        _logs_added_timer = 0

    var has_shown_messages: bool = false

    for entry in _logs:
        if not is_instance_valid(entry):
            continue

        if entry.has_meta(META_FADE_DELAY):
            var delay: float = entry.get_meta(META_FADE_DELAY, 0)
            delay -= delta
            if delay <= 0.0:
                entry.remove_meta(META_FADE_DELAY)
                entry.set_meta(META_FADE_TIME, message_fade_time + delay)
            else:
                entry.set_meta(META_FADE_DELAY, delay)
                has_shown_messages = true
                continue

        if entry.has_meta(META_FADE_TIME):
            var fade: float = entry.get_meta(META_FADE_TIME, 0)
            fade -= delta
            if fade <= 0.0:
                entry.remove_meta(META_FADE_TIME)
            else:
                entry.set_meta(META_FADE_TIME, fade)
                has_shown_messages = true

            if not is_expanded:
                entry.modulate.a = maxf(fade, 0.0) / message_fade_time

    if not is_expanded:
        if scroll.visible and (not has_shown_messages):
            scroll.visible = false
        elif (not scroll.visible) and has_shown_messages:
            scroll.visible = true
            scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

        if input.visible:
            input.visible = false
    elif is_writable:
        if not input.visible:
            input.visible = true
    elif input.visible:
        input.visible = false


func add_log(message: String, bg_color: Color = Color()) -> void:
    _logs_added_last_second += 1

    var log_entry := base_log_entry.duplicate()

    var bg: ColorRect = log_entry.get_node('bg')
    var text: RichTextLabel = log_entry.get_node('margin/text')

    # Fixed transparency for background
    bg_color.a8 = 72

    text.text = message
    bg.color = bg_color

    log_entry.set_meta(META_FADE_DELAY, message_show_time)

    logs.add_child(log_entry)
    while logs.get_child_count() > max_logs:
        var entry := logs.get_child(0) as Control
        if is_expanded and not _scroll_bottom:
            scroll.get_v_scroll_bar().value -= entry.size.y
        logs.remove_child(entry)

        var idx: int = _logs.find(entry)
        if idx != -1:
            _logs[idx] = null

        entry.queue_free()

    _logs[_oldest_idx] = log_entry
    _oldest_idx = posmod(_oldest_idx + 1, max_logs)

    if (not is_expanded) or _scroll_bottom:
        var v_scroll: VScrollBar = scroll.get_v_scroll_bar()
        if v_scroll.value != (v_scroll.max_value - v_scroll.page):
            v_scroll.value = v_scroll.max_value - v_scroll.page

    on_message.emit(false, message)

func update_expanded() -> void:
    # NOTE: some of these can trigger processing when changed, even if set to the
    #       same exact value. To avoid this, every change checks first if the
    #       value is already correct. That's why it looks a bit excessive.

    if is_expanded:
        if box.offset_top != 8.0:
            box.offset_top = 8.0
        if not grow_bg.visible:
            grow_bg.visible = true
        if not scroll.visible:
            scroll.visible = true
            scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE

        for entry in _logs:
            if not is_instance_valid(entry):
                continue

            if entry.modulate.a != 1.0:
                entry.modulate.a = 1.0

    else:
        if box.offset_top != 240.0:
            box.offset_top = 240.0
        if grow_bg.visible:
            grow_bg.visible = false
        if not _scroll_bottom:
            _scroll_bottom = true

        for entry in _logs:
            if not is_instance_valid(entry):
                continue

            if entry.has_meta(META_FADE_DELAY):
                if entry.modulate.a != 1.0:
                    entry.modulate.a = 1.0
            elif entry.has_meta(META_FADE_TIME):
                var fade: float = entry.get_meta(META_FADE_TIME, 0.0) / message_fade_time
                if entry.modulate.a != fade:
                    entry.modulate.a = fade
            elif entry.modulate.a != 0.0:
                entry.modulate.a = 0.0

        # Scroll to bottom
        var v_scroll: VScrollBar = scroll.get_v_scroll_bar()
        if v_scroll.ratio != 1.0:
            v_scroll.ratio = 1.0

func on_text_submitted(text: String) -> void:
    input.clear()
    on_message.emit(true, text)
