extends Node

const AUTHORNAME_MODNAME_DIR := "Sygnano-SavingSystem"
const AUTHORNAME_MODNAME_LOG_NAME := "Sygnano-SavingSystem:Main"

var mod_dir_path := ""
var extensions_dir_path := ""


func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(AUTHORNAME_MODNAME_DIR)
	extensions_dir_path = mod_dir_path.plus_file("extensions")

	# Script extensions must be installed in _init (queued and applied in one batch by
	# the mod loader before the game autoloads are instanced).
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("singletons/run_data.gd"))
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("ui/menus/title_screen/title_screen_menus.gd"))
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("ui/menus/pages/main_menu.gd"))


func _ready() -> void:
	# Except base_shop: since 1.2.0.1 it infers a type from RunData.get_next_wave(), and Godot 3
	# can only type an autoload once its node exists. In the _init batch RunData is not instanced
	# yet, so base_shop fails to parse. Here every autoload is instanced and the extension is
	# applied at once (ModLoader also reloads Shop and CoopShop on top of it).
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("ui/menus/shop/base_shop.gd"))

	# The save folder (user://SavingSystem) is created on the first snapshot.
	ModLoaderLog.info("Ready!", AUTHORNAME_MODNAME_LOG_NAME)
