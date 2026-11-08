extends "res://singletons/run_data.gd"

# Gives every run a stable id so SavingSystem can group its snapshots per run.
# The id travels inside the vanilla run state (get_state / resume_from_state), so it
# survives the vanilla run save, "Continue", "Retry wave" and SavingSystem loads
# without any parallel bookkeeping. All overrides call super first (chain-safe with
# other mods extending run_data.gd, e.g. WeaponsProgression).

const SavingSystemFiles = preload("res://mods-unpacked/Sygnano-SavingSystem/saving_system_files.gd")

var saving_system_run_id: String = ""


func reset(restart: bool = false) -> void:
	.reset(restart)
	# Every new run (title screen, end of run, restart) goes through reset().
	saving_system_run_id = SavingSystemFiles.generate_run_id()


func get_state() -> Dictionary:
	var state: Dictionary = .get_state()
	state[SavingSystemFiles.RUN_ID_KEY] = saving_system_run_id
	return state


func resume_from_state(state: Dictionary) -> void:
	.resume_from_state(state)
	var run_id: String = SavingSystemFiles.get_run_id(state)
	# Run saves written before SavingSystem 1.1.0 carry no id: start a new group.
	saving_system_run_id = run_id if run_id != "" else SavingSystemFiles.generate_run_id()
