extends "res://ui/menus/shop/base_shop.gd"

# Writes one SavingSystem snapshot per shop visit: the run state vanilla itself saves
# at the end of BaseShop._ready (ProgressData.save_run_state). The snapshot is a
# checkpoint of the shop as it was entered; it is not rewritten after purchases.

const SavingSystemFiles = preload("res://mods-unpacked/Sygnano-SavingSystem/saving_system_files.gd")

var _saving_system_resumed: bool = false


func _enter_tree() -> void:
	# BaseShop._ready clears RunData.resumed_from_state_in_shop, so read it before.
	# When the shop is resumed (vanilla Continue or a SavingSystem load), this shop
	# visit already has its snapshot: do not write a duplicate.
	_saving_system_resumed = RunData.resumed_from_state_in_shop


func _ready() -> void:
	# Godot runs the vanilla _ready (and the subclasses' ones) automatically; defer so
	# the snapshot is taken once the whole chain has finished.
	if not _saving_system_resumed:
		call_deferred("_saving_system_write_snapshot")


func _saving_system_write_snapshot() -> void:
	# Reuse the dictionary vanilla just built and saved (RunData.get_state() + shop data).
	var state: Dictionary = ProgressData.saved_run_state
	if not state.get("has_run_state", false):
		return
	var _path: String = SavingSystemFiles.write_serialized_state(SavingSystemFiles.serialize_run_state(state))
