extends Control
class_name DialogueBox

## The panel a vendor talks through. One line at a time -- a wall of text is
## the fastest way to make someone stop reading.

var _panel: PanelContainer
var _speaker: Label
var _body: Label
var _prompt: Label
var _prompt_shown := 0


func _ready() -> void:
	add_to_group("dialogue")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-250, -210)
	_prompt.size = Vector2(500, 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	add_child(_prompt)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.position = Vector2(-360, -190)
	_panel.size = Vector2(720, 120)
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.11, 0.88)
	style.border_color = Color(1, 0.86, 0.5, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	_panel.add_child(column)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 20)
	_speaker.add_theme_color_override("font_color", Color(1, 0.86, 0.5))
	column.add_child(_speaker)

	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 18)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(688, 0)
	column.add_child(_body)


func _process(_delta: float) -> void:
	# A vendor calls show_prompt() every frame it is in range, so if nothing
	# called it this frame the player has walked away.
	if _prompt_shown > 0:
		_prompt_shown -= 1
	elif _prompt.visible:
		_prompt.visible = false


func show_prompt(text: String) -> void:
	if _panel.visible:
		return
	_prompt.text = text
	_prompt.visible = true
	_prompt_shown = 2


func show_line(speaker: String, text: String) -> void:
	_prompt.visible = false
	_speaker.text = speaker
	_body.text = text
	_panel.visible = true


func clear() -> void:
	_panel.visible = false
	_prompt.visible = false
