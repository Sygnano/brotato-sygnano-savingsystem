extends Button

# One entry of the wave list of the selected run.

signal select_save(save_entry)

const HOVER_STYLE = preload("res://resources/themes/button_styles/button_hover.tres")
const SELECTED_FONT_COLOR := Color(0, 0, 0)

var _save_entry: Dictionary = {}


func set_data(save_entry: Dictionary, wave: int) -> void:
	_save_entry = save_entry
	text = Text.text("WAVE", [str(wave)])


func set_selected(selected: bool) -> void:
	if selected:
		add_stylebox_override("normal", HOVER_STYLE)
		add_color_override("font_color", SELECTED_FONT_COLOR)
	else:
		remove_stylebox_override("normal")
		remove_color_override("font_color")


func _on_SaveWaveSelector_pressed() -> void:
	emit_signal("select_save", _save_entry)
