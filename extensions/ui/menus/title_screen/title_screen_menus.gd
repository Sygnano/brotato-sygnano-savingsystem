extends "res://ui/menus/title_screen/title_screen_menus.gd"

# Adds the SavingSystem page to the title screen menus, like the vanilla title-screen
# pages (MenuItemSets, MenuMods...). Extends TitleScreenMenus rather than Menus so the
# page is not instanced in the in-game pause menu (IngameMenus also extends Menus).

const SAVING_SYSTEM_PAGE_PATH := "res://mods-unpacked/Sygnano-SavingSystem/extensions/ui/menus/pages/saving_system.tscn"

var _saving_system_page: Control = null


func _ready() -> void:
	# Menus._ready runs first (Godot calls every _ready of the script chain).
	# load() at runtime instead of preload(): this script is compiled while the mod
	# loader installs extensions, and a preload would pull vanilla scenes in too early.
	_saving_system_page = load(SAVING_SYSTEM_PAGE_PATH).instance()
	_saving_system_page.hide()
	add_child(_saving_system_page)

	var _error: int = _saving_system_page.connect("back_button_pressed", self, "_on_SavingSystem_back_button_pressed")
	_error = _saving_system_page.connect("continue_run_requested", self, "_on_SavingSystem_continue_run_requested")

	if _main_menu != null and _main_menu.has_signal("saving_system_menu_button_pressed"):
		if not _main_menu.is_connected("saving_system_menu_button_pressed", self, "_on_MainMenu_saving_system_menu_button_pressed"):
			_error = _main_menu.connect("saving_system_menu_button_pressed", self, "_on_MainMenu_saving_system_menu_button_pressed")


func _on_MainMenu_saving_system_menu_button_pressed() -> void:
	switch(_main_menu, _saving_system_page)


func _on_SavingSystem_back_button_pressed() -> void:
	switch(_saving_system_page, _main_menu)


func _on_SavingSystem_continue_run_requested() -> void:
	# The page has put the selected run into ProgressData.saved_run_state: resume it
	# through the exact vanilla "Continue" path (DLC check, hourglass challenge,
	# platform activity, RunData.continue_current_run_in_shop, coop_resume/shop scene).
	_main_menu._on_ContinueButton_pressed()
