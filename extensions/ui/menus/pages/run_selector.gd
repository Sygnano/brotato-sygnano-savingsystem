extends Button

# One entry of the run list: difficulty icon, character icon and name, latest wave.

signal set_active_run(run_id)

const HOVER_STYLE = preload("res://resources/themes/button_styles/button_hover.tres")
const SELECTED_FONT_COLOR := Color(0, 0, 0)
const UNAVAILABLE_MODULATE := Color(1, 1, 1, 0.5)

onready var _character_icon: TextureRect = $"%CharacterIcon"
onready var _difficulty_icon: TextureRect = $"%DifficultyIcon"
onready var _character_name: Label = $"%CharacterName"
onready var _current_wave: Label = $"%CurrentWave"

var _run_id: String = ""
var _is_active: bool = false


func set_data(character_id: String, difficulty: int, wave: int, run_id: String) -> void:
	_run_id = run_id

	# Same lookups as the vanilla menus (character_info_panel.gd, end_run.gd).
	var character = ItemService.get_element_safe(ItemService.characters, character_id)
	if character != null:
		_character_icon.texture = character.icon
		_character_name.text = tr(character.name)
	else:
		# Character not registered (DLC not owned or mod content missing).
		_character_icon.texture = null
		_character_name.text = character_id
		_character_icon.modulate = UNAVAILABLE_MODULATE
		_character_name.modulate = UNAVAILABLE_MODULATE

	var difficulty_data = ItemService.get_element(ItemService.difficulties, Keys.empty_hash, difficulty)
	_difficulty_icon.texture = difficulty_data.icon if difficulty_data != null else null

	_current_wave.text = Text.text("WAVE", [str(wave)])


func set_active_run(run_id: String) -> void:
	_is_active = run_id == _run_id
	if _is_active:
		add_stylebox_override("normal", HOVER_STYLE)
		_set_font_color_override(true)
	else:
		remove_stylebox_override("normal")
		_set_font_color_override(false)


func _set_font_color_override(enabled: bool) -> void:
	for label in [_character_name, _current_wave]:
		if enabled:
			label.add_color_override("font_color", SELECTED_FONT_COLOR)
		else:
			label.remove_color_override("font_color")


func _on_SaveUI_button_down() -> void:
	emit_signal("set_active_run", _run_id)


func _on_SaveUI_mouse_entered() -> void:
	_set_font_color_override(true)


func _on_SaveUI_mouse_exited() -> void:
	if not _is_active:
		_set_font_color_override(false)
