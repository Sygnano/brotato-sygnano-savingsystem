extends "res://ui/menus/pages/main_menu.gd"

# Adds a "Saves" button to the main menu. The title screen menus extension listens to
# saving_system_menu_button_pressed and opens the SavingSystem page.

signal saving_system_menu_button_pressed

const SAVING_SYSTEM_BUTTON_NAME := "SavingSystemButton"

var _saving_system_button: Button = null


func _ready() -> void:
	# Vanilla main_menu.gd has no _ready of its own, but its onready vars
	# (left_container...) are already set when this runs.
	_saving_system_add_button()


func _saving_system_add_button() -> void:
	if is_instance_valid(_saving_system_button):
		return

	var button: MyMenuButton = MyMenuButton.new()
	button.name = SAVING_SYSTEM_BUTTON_NAME
	button.text = "Saves"
	button.align = Button.ALIGN_LEFT
	var _error: int = button.connect("pressed", self, "_on_SavingSystemButton_pressed")
	left_container.add_child(button)

	# Right after the Continue / Start block, before the vanilla ItemSetButton. Looked
	# up by name, so buttons added by other mods do not shift the anchor.
	var anchor: Node = left_container.get_node_or_null("empty_space")
	if anchor != null:
		left_container.move_child(button, anchor.get_index() + 1)

	_saving_system_button = button


func _on_SavingSystemButton_pressed() -> void:
	emit_signal("saving_system_menu_button_pressed")
