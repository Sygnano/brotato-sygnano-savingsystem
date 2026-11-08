# Saving System

A [Brotato](https://store.steampowered.com/app/1942280/Brotato/) mod that adds an **automatic saving system**. Every shop visit is saved as a snapshot, so you can go back to any wave of any run.

[Steam Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3412541843)

## Features

- **Automatic snapshots:** each time you enter the shop, the run is saved exactly as the game itself saves it at that point. Purchases made in the shop afterwards don't change the snapshot.
- **Saves page:** a new **Saves** button in the main menu opens a page where you can:
  - see your runs (character, difficulty, latest wave), newest first;
  - pick a wave and see the weapons and items you had;
  - **Load** a snapshot, which resumes it through the game's normal Continue path;
  - **Export** a snapshot to the clipboard and **Import** one from it, for sharing or backups;
  - **Delete** a run and all its snapshots.
- Each run gets its own id, so snapshots stay grouped even after Continue, Retry wave, or loading an earlier snapshot.
- Before a file is loaded, it is checked: required fields, owned zone DLC, available characters. A bad file shows an error instead of crashing the game.

Snapshots are kept in `SavingSystem` inside the game's user data folder, which on Windows is `%APPDATA%\Brotato\SavingSystem`. There is one JSON file per shop visit.

## Compatibility

- Brotato 1.2.0.0 and 1.2.0.1
- Godot Mod Loader 6.3.0
- Works with other mods that extend `run_data.gd`, such as [Weapons Progression](https://steamcommunity.com/sharedfiles/filedetails/?id=3416358106)
- Snapshots made with SavingSystem 1.0.x can still be read

## Installation

- **Steam:** subscribe on the [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3412541843). The Steam build loads mods from your Workshop subscriptions.
- **Other builds:** put the release `Sygnano-SavingSystem.zip` in the game's `mods` folder.

## How it works

- `extensions/singletons/run_data.gd` gives each run an id and stores it in the vanilla run state (`get_state` / `resume_from_state`).
- `extensions/ui/menus/shop/base_shop.gd` writes the state the game just saved to a new snapshot file. This extension is installed in `_ready`, not `_init`, because the 1.2.0.1 `base_shop.gd` needs the `RunData` autoload to exist before it can parse.
- `saving_system_files.gd` handles the file format, validation and (de)serialization. Snapshots use the vanilla run state format (`ProgressDataLoaderV3`).
- `extensions/ui/menus/pages/` holds the Saves page. Save files are scanned on a background thread.

## Repository layout

This repository is the mod folder itself. In a game or decompiled project it goes in `res://mods-unpacked/Sygnano-SavingSystem/`.

```
manifest.json              mod metadata (version, game / loader compatibility)
mod_main.gd                script extensions
saving_system_files.gd     snapshot file helpers
extensions/                RunData, shop and title screen extensions, Saves page scenes
```

## Building a release

Zip this folder as `mods-unpacked/Sygnano-SavingSystem/` (the path inside the zip is relative to the project root). The mod has no imported assets.

## Author

Sygnano

## License

[MIT](LICENSE) © Sygnano. Brotato and its assets belong to Blobfish; this repository contains only the mod.
