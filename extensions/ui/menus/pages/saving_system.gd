extends Control

# "Saves" page of the title screen: browse the SavingSystem snapshots per run and per
# wave, preview the weapons and items, load, export / import (clipboard) and delete.

signal back_button_pressed
# Emitted after the selected run has been put into ProgressData.saved_run_state; the
# title screen menus extension then runs the vanilla Continue path.
signal continue_run_requested

const SavingSystemFiles = preload("res://mods-unpacked/Sygnano-SavingSystem/saving_system_files.gd")
const RUN_SELECTOR_SCENE = preload("res://mods-unpacked/Sygnano-SavingSystem/extensions/ui/menus/pages/run_selector.tscn")
const WAVE_SELECTOR_SCENE = preload("res://mods-unpacked/Sygnano-SavingSystem/extensions/ui/menus/pages/wave_selector.tscn")
const LOG_NAME := "Sygnano-SavingSystem:Page"

onready var _back_button: Button = $"%BackButton"
onready var _load_button: Button = $"%LoadButton"
onready var _export_button: Button = $"%ExportButton"
onready var _delete_run_button: Button = $"%DeleteRunButton"
onready var _delete_toggle: CheckButton = $"%DeleteToggle"
onready var _runs_container: Container = $"%SavesContainer"
onready var _waves_container: Container = $"%WavesContainer"
onready var _weapons_container = $"%WeaponsContainer"
onready var _items_container = $"%ItemsContainer"
onready var _menu_container: Control = $"%MenuContainer"
onready var _no_saves_found_panel: Control = $"%NoSavesFoundPanel"
onready var _notification_popup = $"%NotificationPopup"
onready var _loading_label: Label = $"%LoadingLabel"

# run_id -> {"run_id", "character_id", "wave", "difficulty", "saves": [save_entry]}
# save_entry = {"path": String, "modified": int, "data": Dictionary (serialized state)}
var _runs: Dictionary = {}
var _active_run_id: String = ""
var _active_save_entry: Dictionary = {}
var _active_state: Dictionary = {}

var _thread: Thread = Thread.new()


func init() -> void:
	if _thread.is_active():
		return

	_runs = {}
	_clear_selection()
	_clear_container(_runs_container)
	_clear_container(_waves_container)

	_loading_label.show()
	_weapons_container.hide()
	_items_container.hide()
	_set_actions_disabled(true)

	# The thread only reads files and parses JSON; everything touching the scene tree
	# or the game singletons happens back on the main thread in _on_scan_done.
	var error: int = _thread.start(self, "_scan_save_files", SavingSystemFiles.SAVE_DIR)
	if error != OK:
		ModLoaderLog.error("Could not start the scan thread (error %d)" % error, LOG_NAME)
		_on_scan_done()


func _exit_tree() -> void:
	# Leaving the title screen while a scan is running: join the thread before the
	# Thread object is freed. The deferred _on_scan_done is dropped with this node.
	if _thread.is_active():
		var _entries = _thread.wait_to_finish()


# Thread function. Must not touch members, nodes or game singletons.
func _scan_save_files(dir_path: String) -> Array:
	var entries: Array = []
	var dir: Directory = Directory.new()
	if dir.open(dir_path) == OK:
		var file: File = File.new()
		var _error: int = dir.list_dir_begin(true, true)
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension().to_lower() == "json":
				var path: String = dir_path.plus_file(file_name)
				var data = SavingSystemFiles.read_json_file(path)
				if SavingSystemFiles.is_valid_serialized_state(data):
					entries.push_back({"path": path, "modified": file.get_modified_time(path), "data": data})
				else:
					entries.push_back({"path": path, "invalid": true})
			file_name = dir.get_next()
		dir.list_dir_end()

	call_deferred("_on_scan_done")
	return entries


func _on_scan_done() -> void:
	var entries: Array = []
	if _thread.is_active():
		var result = _thread.wait_to_finish()
		if result is Array:
			entries = result

	var valid_entries: Array = []
	for entry in entries:
		if entry.get("invalid", false):
			ModLoaderLog.warning("Skipped unreadable or incomplete save file %s" % entry.path, LOG_NAME)
		else:
			valid_entries.push_back(entry)
	_build_runs(valid_entries)

	_loading_label.hide()
	_weapons_container.show()
	_items_container.show()
	_refresh_runs_container()

	if _runs.empty():
		_menu_container.hide()
		_no_saves_found_panel.show()
		_back_button.grab_focus()
	else:
		_menu_container.show()
		_no_saves_found_panel.hide()
		_load_button.grab_focus()


func _build_runs(entries: Array) -> void:
	entries.sort_custom(self, "_sort_by_most_recent")
	_runs = {}
	for entry in entries:
		var data: Dictionary = entry.data
		var run_id: String = SavingSystemFiles.get_run_id(data)
		if run_id == "":
			# File without any run id: show it as its own run.
			run_id = entry.path

		var wave: int = int(data.current_wave)
		if not _runs.has(run_id):
			var character_id = data.players_data[0].current_character
			_runs[run_id] = {
				"run_id": run_id,
				"character_id": character_id if character_id is String else "",
				"wave": wave,
				"difficulty": int(data.current_difficulty),
				"saves": []
			}
		var run: Dictionary = _runs[run_id]
		run.wave = int(max(run.wave, wave))
		run.saves.push_back(entry)

	for run in _runs.values():
		run.saves.sort_custom(self, "_sort_by_wave_then_most_recent")


func _sort_by_most_recent(a: Dictionary, b: Dictionary) -> bool:
	return a.modified > b.modified


func _sort_by_wave_then_most_recent(a: Dictionary, b: Dictionary) -> bool:
	var wave_a: int = int(a.data.current_wave)
	var wave_b: int = int(b.data.current_wave)
	if wave_a != wave_b:
		return wave_a > wave_b
	return a.modified > b.modified


func _refresh_runs_container() -> void:
	_clear_container(_runs_container)
	_clear_container(_waves_container)

	for run in _runs.values():
		var run_selector = RUN_SELECTOR_SCENE.instance()
		_runs_container.add_child(run_selector)
		run_selector.set_data(run.character_id, run.difficulty, run.wave, run.run_id)
		var _error: int = run_selector.connect("set_active_run", self, "_on_set_active_run")

	if not _runs.empty():
		_on_set_active_run(_runs.keys()[0])


func _on_set_active_run(run_id: String) -> void:
	if not _runs.has(run_id):
		return

	_active_run_id = run_id
	for child in _runs_container.get_children():
		child.set_active_run(run_id)

	_clear_container(_waves_container)
	for save_entry in _runs[run_id].saves:
		var wave_selector = WAVE_SELECTOR_SCENE.instance()
		_waves_container.add_child(wave_selector)
		wave_selector.set_data(save_entry, int(save_entry.data.current_wave))
		var _error: int = wave_selector.connect("select_save", self, "_on_select_save")

	if _waves_container.get_child_count() > 0:
		_on_select_save(_runs[run_id].saves[0])


func _on_select_save(save_entry: Dictionary) -> void:
	for child in _waves_container.get_children():
		child.set_selected(child._save_entry == save_entry)

	_active_save_entry = save_entry
	# Deserialized with the vanilla run-save loader; unknown content is dropped the same way.
	_active_state = SavingSystemFiles.deserialize_run_state(save_entry.data)

	var weapons: Array = []
	var items: Array = []
	if _active_state.get("has_run_state", false) and not _active_state.players_data.empty():
		weapons = _active_state.players_data[0].weapons
		items = _active_state.players_data[0].items
	_weapons_container.set_data("WEAPONS", Category.WEAPON, weapons)
	_items_container.set_data("ITEMS", Category.ITEM, items, true, true)

	_set_actions_disabled(false)


func _on_BackButton_pressed() -> void:
	emit_signal("back_button_pressed")


func _onLoadButton_pressed() -> void:
	if _active_state.empty():
		return

	var error_message: String = _get_load_error(_active_state)
	if error_message != "":
		_send_notification_popup("Cannot load this save", error_message)
		return

	var previous_run_state: Dictionary = ProgressData.saved_run_state
	ProgressData.saved_run_state = _active_state

	# Same validation the main menu applies to the vanilla saved run
	# (zone DLC owned, characters available).
	if not ProgressData.check_dlc_valid_for_saved_run_state():
		ProgressData.saved_run_state = previous_run_state
		_send_notification_popup("Cannot load this save", "It needs DLC content that is not available")
		return

	RunData.cancel_resume()
	emit_signal("continue_run_requested")

	if not RunData.resumed_from_state_in_shop:
		# The vanilla Continue path refused the run: put the previous run back.
		ProgressData.saved_run_state = previous_run_state
		_send_notification_popup("Cannot load this save", "The game refused to resume this run")


func _get_load_error(state: Dictionary) -> String:
	if not state.get("has_run_state", false) or state.players_data.empty():
		return "The save file is incomplete"
	if state.get("is_streamplay_run", false):
		return "Streamplay runs cannot be resumed"
	for player_data in state.players_data:
		if player_data.current_character == null:
			return "Its character is not available (DLC not owned or mod missing)"
	return ""


func _on_RefreshButton_pressed() -> void:
	init()


func _on_ImportButton_pressed() -> void:
	var parse_result: JSONParseResult = JSON.parse(OS.get_clipboard())
	if parse_result.error != OK or not SavingSystemFiles.is_valid_serialized_state(parse_result.result):
		_send_notification_popup("Failed to import", "The clipboard does not contain a valid save")
		return

	var path: String = SavingSystemFiles.write_serialized_state(parse_result.result, "imported_")
	if path == "":
		_send_notification_popup("Failed to import", "Cannot write the save file")
		return

	_send_notification_popup("Import successful", "Save file successfully imported")
	init()


func _on_ExportButton_pressed() -> void:
	if _active_save_entry.empty():
		return
	# Export the file content as written (lossless), not a re-serialized copy.
	OS.set_clipboard(JSON.print(_active_save_entry.data))
	_send_notification_popup("Export successful", "Export code has been copied to clipboard")


func _on_DeleteToggle_toggled(button_pressed: bool) -> void:
	_delete_run_button.disabled = not button_pressed or not _runs.has(_active_run_id)


func _on_DeleteRunButton_pressed() -> void:
	if not _runs.has(_active_run_id):
		return

	var dir: Directory = Directory.new()
	var _opened: int = dir.open(SavingSystemFiles.SAVE_DIR)
	var failed: int = 0
	for save_entry in _runs[_active_run_id].saves:
		if dir.file_exists(save_entry.path) and dir.remove(save_entry.path) != OK:
			failed += 1
			ModLoaderLog.error("Could not delete %s" % save_entry.path, LOG_NAME)

	if failed > 0:
		_send_notification_popup("Delete failed", "%d file(s) could not be deleted" % failed)
	else:
		_send_notification_popup("Run deleted", "Run deleted from saves")
	init()


func _set_actions_disabled(disabled: bool) -> void:
	_load_button.disabled = disabled
	_export_button.disabled = disabled
	_delete_toggle.pressed = false
	_delete_toggle.disabled = disabled
	_delete_run_button.disabled = true


func _clear_selection() -> void:
	_active_run_id = ""
	_active_save_entry = {}
	_active_state = {}


func _send_notification_popup(title: String, description: String) -> void:
	# Reuses the vanilla challenge popup as a toast.
	var toast: ChallengeData = ChallengeData.new()
	toast.name = title
	toast.description = description
	_notification_popup.popup(toast)


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
