# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-08-13

### Added

- **Lore notes & Reading UI** (`note.gd`, `note_data.gd`, `notes.tscn`, `reading_ui.gd`): 4 lore notes placed at maze cells and readable through a paginated paper UI opened with the interaction prompt.
- **Randomized note placement/content**: note cells are chosen via farthest-point sampling over the maze graph, and note content is shuffled each run.
- **Opening wake-up intro** (`intro_controller.gd`): a rising-camera sequence with a typed inner monologue and typing audio before the player takes control.
- **Flashlight system**: toggleable flashlight with click audio and an opening hint.
- **Note reading audio**: paper rustle on open and page-flip sounds when turning pages.
- **Environmental rats** (`rat_controller.gd`, `rat.tscn`): 3 squeaking rats that wander the maze via AStar2D navigation, flee the player when close, and play quiet randomized positional squeaks.
- **Expanded horror audio**: monster footstep and scream layers, chase heartbeat, and randomized ambient whisper clips that play around the player.

## [1.0.0] - 2026-08-01

First public release.

### Added

- **Procedural maze generation** (`maze_generator.gd`): runtime AStar2D-based maze that builds the world and navigation graph.
- **First-person player controller** (`player_controller.gd`): mouse-look, movement, sprint with stamina, lean effects, head-bob feel, and chase/shake feedback.
- **Monster AI** (`monster_ai.gd`): navigates the maze via navigation mesh, patrol/chase states, difficulty escalation per collected book, final-phase behavior, and death/reset handling.
- **Cursed book collectibles** (`cursed_book.gd`, `bone_collectible.tscn`): 6 floating, rotating books that trigger collection, sound, and difficulty updates.
- **Altar ritual** (`altar.gd`): after all books are collected, standing in the ritual zone for 5 seconds completes the run and triggers the victory sequence.
- **Game manager** (`game_manager.gd`): wiring of player/monster/UI, 3-life system, death sequence with respawn, game-over return to menu, final-phase escalation, and UI updates.
- **HUD** (`book_ui.gd`, `lives_ui.gd`, `stamina_crosshair.gd`): cursed-book counter, lives display, and stamina crosshair.
- **Main menu** (`main_menu.gd`): NEW GAME, SETTINGS placeholder, CREDITS, and EXIT with keyboard navigation.
- **Pause menu** (`pause_menu.gd`): Esc-driven RESUME / SETTINGS placeholder / MAIN MENU / EXIT with keyboard navigation.
- **PSX-style shaders** (`psxshader.gdshader`, `psxshader_ui.gdshader`): low-resolution, scanline, and grain post-processing.
- **Audio system**: ambient loop, player breathing, footsteps, heartbeat during chase, monster screams, ritual hum, and book pickup sounds.
- **Fade utility** (`fade.gd`): reusable screen-fade transition helper.
