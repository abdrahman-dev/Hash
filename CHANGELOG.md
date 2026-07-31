# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
