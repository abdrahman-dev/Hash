# HUSH

A first-person survival horror game built with Godot 4.7. You are trapped inside a procedurally generated maze while a monster hunts you. Collect the six cursed books and complete the ritual at the altar to lift the curse.

## Features

- **Procedurally generated maze** — every run uses a freshly generated layout.
- **Hunting monster AI** — an enemy that navigates the maze, hunts the player, and escalates in difficulty as you progress.
- **Objective system** — collect all 6 cursed books scattered across the maze.
- **Altar ritual** — stand at the altar for 5 seconds after collecting every book to win.
- **Life system** — 3 lives; getting caught triggers a death sequence and respawn.
- **Dynamic audio** — heartbeat picks up during a chase, monster screams, and ambient horror soundscape.
- **PSX-style visuals** — low-resolution post-processing shaders for a retro horror look.
- **Full menu flow** — title screen, credits, in-game pause menu, game over and victory screens.

## Screenshots

_TBD — screenshots will be added here for the first release._

## Controls

| Action        | Key           |
| ------------- | ------------- |
| Move          | `W` `A` `S` `D` |
| Look around   | Mouse          |
| Sprint        | `Shift`        |
| Pause / Resume| `Esc`          |
| Menu navigate | `Up` / `Down`  |
| Menu confirm  | `Enter`        |

## Requirements

- **Godot 4.7** (standard build) to open the project and export the game.

## Built With

- [Godot Engine 4.7](https://godotengine.org/)
- GDScript
- GL Compatibility renderer
- Jolt Physics

## How to Run

1. Install [Godot 4.7](https://godotengine.org/download/).
2. Open the project by importing `project.godot` in the Godot project manager.
3. Press **F5** (or click **Play**) to run the game.
4. Select **NEW GAME** on the title screen.

### Windows export

1. Open **Project > Export** in the editor.
2. Create a **Windows Desktop** preset (this repo does not ship an `export_presets.cfg`).
3. Add a Windows export template (installed via the editor's template manager).
4. Click **Export Project** and choose an output folder.

## Project Structure

```
hush/
├── Scenes/        # Godot scenes (player, monster, world, menu, collectibles, ...)
├── Scripts/       # GDScript logic for all gameplay and UI systems
├── shaders/       # PSX-style post-processing shaders
├── Sounds/        # Audio assets (ambient, screams, footsteps, whispers)
├── Textures/      # Models, textures, and imported 3D assets
├── project.godot  # Godot project configuration
```

## Credits

- **DimlitGames** — development
- 3D assets and audio sourced from publicly available asset packs.

## License

This project is licensed under the [MIT License](LICENSE).

## Roadmap

- [ ] Full release polish pass on gameplay tuning and balance
- [ ] Additional maze themes and rooms
- [ ] Enhanced monster behavior and encounters
- [ ] Settings menu (graphics, audio)
- [ ] Save/load support
- [ ] Steam / console distribution
