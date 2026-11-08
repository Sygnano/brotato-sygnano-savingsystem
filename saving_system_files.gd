extends Reference

# Shared helpers for the SavingSystem snapshot files.
# Reference this script with preload(); it has no class_name on purpose
# (a mod's class_name is not a global name in the shipped game).
#
# File format: one JSON file per shop visit in SAVE_DIR. The content is the
# vanilla run state exactly as ProgressDataLoaderV3.serialize_run_state() writes
# it inside run_v3_<profile>.json ("current_run_state"). The run id lives in the
# state itself under RUN_ID_KEY (added by the RunData extension in get_state()).

const LOG_NAME := "Sygnano-SavingSystem:Files"
const SAVE_DIR := "user://SavingSystem"
const RUN_ID_KEY := "saving_system_run_id"
# Top-level key written by SavingSystem 1.0.x files, read for backward compatibility.
const LEGACY_RUN_ID_KEY := "run_id"

# Keys read without a has()/get() guard by ProgressDataLoaderV3.deserialize_run_state,
# RunData.resume_from_state and BaseShop._ready (resumed branch). A file missing one
# of them would raise a script error when loaded, so it is rejected up front.
const REQUIRED_RUN_STATE_KEYS := [
	"has_run_state", "players_data", "enemy_scaling", "nb_of_waves", "retries",
	"current_zone", "current_wave", "current_difficulty", "bonus_gold",
	"elites_spawn", "bosses_spawn", "shop_effects_checked", "elites_killed_this_run",
	"bosses_killed_this_run", "loot_aliens_killed_this_run",
	"challenges_completed_this_run", "locked_shop_items", "current_background",
	"max_endless_wave_record_beaten", "is_endless_run", "is_coop_run", "enabled_dlcs",
	"tracked_item_effects", "shop_items", "reroll_count", "paid_reroll_count",
	"initial_free_rerolls", "free_rerolls", "item_steals"
]
# Keys read without a guard by PlayerRunData.deserialize.
const REQUIRED_PLAYER_KEYS := [
	"current_character", "current_level", "current_xp", "gold", "selected_weapon",
	"weapons", "items", "appearances", "unique_effects", "effects", "active_sets",
	"active_set_effects", "additional_weapon_effects", "tier_iv_weapon_effects",
	"tier_i_weapon_effects", "chal_recycling_current", "consumables_picked_up_this_run"
]
# Same int casts as ProgressData.load_with_generic_loader applies after loading a
# run save (JSON numbers come back as floats).
const INT_KEYS := ["nb_of_waves", "current_wave", "current_difficulty", "bonus_gold", "retries"]
const INT_ARRAY_KEYS := ["reroll_count", "paid_reroll_count", "initial_free_rerolls", "free_rerolls"]


static func generate_run_id() -> String:
	# No RNG on purpose: the global RNG drives gameplay.
	return "%d%06d" % [OS.get_unix_time(), OS.get_ticks_usec() % 1000000]


static func get_run_id(serialized_state: Dictionary) -> String:
	for key in [RUN_ID_KEY, LEGACY_RUN_ID_KEY]:
		var value = serialized_state.get(key)
		match typeof(value):
			TYPE_STRING:
				if value != "":
					return value
			TYPE_INT, TYPE_REAL:
				return str(int(value))
	return ""


static func ensure_save_dir() -> int:
	var dir: Directory = Directory.new()
	if dir.dir_exists(SAVE_DIR):
		return OK
	var error: int = dir.make_dir_recursive(SAVE_DIR)
	if error != OK:
		ModLoaderLog.error("Could not create %s (error %d)" % [SAVE_DIR, error], LOG_NAME)
	return error


static func is_valid_serialized_state(data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	for key in REQUIRED_RUN_STATE_KEYS:
		if not data.has(key):
			return false
	if not data.has_run_state or typeof(data.players_data) != TYPE_ARRAY or data.players_data.empty():
		return false
	for player_data in data.players_data:
		if typeof(player_data) != TYPE_DICTIONARY:
			return false
		for key in REQUIRED_PLAYER_KEYS:
			if not player_data.has(key):
				return false
	return true


# Serialized (JSON-ready) state -> run state ready for ProgressData.saved_run_state /
# RunData.resume_from_state. Main thread only: it reads ItemService and ChallengeService.
# Content that is not registered (DLC not owned, removed mod) is dropped by the vanilla
# deserializers, exactly like a vanilla run save.
static func deserialize_run_state(serialized_state: Dictionary) -> Dictionary:
	# The vanilla deserializers modify their input; keep the caller's copy intact.
	var state: Dictionary = ProgressDataLoaderV3.new().deserialize_run_state(serialized_state.duplicate(true))

	for key in INT_KEYS:
		if state.has(key) and typeof(state[key]) == TYPE_REAL:
			state[key] = int(state[key])
	for key in INT_ARRAY_KEYS:
		if state.has(key) and typeof(state[key]) == TYPE_ARRAY:
			for i in state[key].size():
				if typeof(state[key][i]) == TYPE_REAL:
					state[key][i] = int(state[key][i])

	var run_id: String = get_run_id(serialized_state)
	if run_id != "":
		state[RUN_ID_KEY] = run_id
	return state


static func serialize_run_state(state: Dictionary) -> Dictionary:
	return ProgressDataLoaderV3.new().serialize_run_state(state)


# Writes a serialized run state to a new file in SAVE_DIR. Returns the path, or "" on error.
static func write_serialized_state(serialized_state: Dictionary, prefix: String = "") -> String:
	if ensure_save_dir() != OK:
		return ""

	var run_id: String = get_run_id(serialized_state)
	if run_id == "":
		run_id = generate_run_id()
		serialized_state[RUN_ID_KEY] = run_id

	var character_id: String = "unknown"
	var first_player = serialized_state.players_data[0]
	if typeof(first_player) == TYPE_DICTIONARY and typeof(first_player.get("current_character")) == TYPE_STRING:
		character_id = first_player.current_character

	var file_name: String = "%s%s_%d_%d_%s.json" % [
		prefix, _sanitize(character_id), int(serialized_state.current_wave), OS.get_unix_time(), _sanitize(run_id)
	]
	var path: String = SAVE_DIR.plus_file(file_name)
	var tmp_path: String = path + ".tmp"

	var file: File = File.new()
	var error: int = file.open(tmp_path, File.WRITE)
	if error != OK:
		ModLoaderLog.error("Could not open %s for writing (error %d)" % [tmp_path, error], LOG_NAME)
		return ""
	file.store_string(JSON.print(serialized_state))
	file.close()

	var dir: Directory = Directory.new()
	# Opened like vanilla does before copy/rename (ProgressDataLoaderV3.save_content).
	var _opened: int = dir.open(SAVE_DIR)
	error = dir.rename(tmp_path, path)
	if error != OK:
		ModLoaderLog.error("Could not rename %s to %s (error %d)" % [tmp_path, path, error], LOG_NAME)
		var _removed = dir.remove(tmp_path)
		return ""

	ModLoaderLog.info("Saved %s" % path, LOG_NAME)
	return path


# Returns the parsed JSON content of a file, or null if it cannot be read or parsed.
# Thread-safe: only uses local File/JSON objects.
static func read_json_file(path: String):
	var file: File = File.new()
	if file.open(path, File.READ) != OK:
		return null
	var content: String = file.get_as_text()
	file.close()
	var parse_result: JSONParseResult = JSON.parse(content)
	if parse_result.error != OK:
		return null
	return parse_result.result


static func _sanitize(value: String) -> String:
	var result: String = ""
	for i in value.length():
		var c: String = value[i]
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			result += c
	return result if result != "" else "unknown"
