# Release Checklist — REMNANT v1.1.0

Use this checklist to prepare and ship the current release.

## Code & Project

- [x] Project opens without errors in Godot 4.7
- [x] No missing resources or broken scene references
- [x] No debug `print()` statements left in release code
- [x] No TODO/FIXME items that block release
- [x] No secrets, API keys, or passwords committed
- [x] No editor cache files (`.godot/`) committed
- [x] `.gitignore` covers `.godot/`, exports, and editor files

## Windows Export

- [x] `export_presets.cfg` created with a **Windows Desktop** preset
- [ ] Windows export template installed
- [ ] Test build exported successfully
- [ ] Exported `.exe` launches and runs on a clean machine
- [ ] All assets (textures, sounds, models) included in the build
- [ ] Game plays start-to-finish from the exported build

## Game Icon

- [ ] Application icon set in project settings
- [ ] Icon is a suitable square PNG (at least 256x256)
- [ ] Icon shows correctly on the exported executable

## Screenshots

- [ ] Capture title screen
- [ ] Capture gameplay (maze interior)
- [ ] Capture monster encounter
- [ ] Capture ritual/victory screen
- [ ] Add screenshots to README

## Trailer

- [ ] Record gameplay footage
- [ ] Edit into a short trailer
- [ ] Add trailer link to README / store page

## README

- [ ] Screenshots section filled in
- [ ] Controls documented accurately
- [ ] Requirements and build instructions verified
- [ ] Links (credits, license, trailer) valid

## License

- [ ] `LICENSE` file present with correct copyright holder
- [ ] License confirmed with any third-party asset licenses

## Version

- [ ] `project.godot` has `config/version="1.1.0"`
- [x] `CHANGELOG.md` reflects v1.1.0
- [ ] Game version string displayed correctly (if applicable)

## Git Tag

- [ ] Tag the release commit: `git tag -a v1.1.0 -m "REMNANT v1.1.0"`
- [ ] Push the tag: `git push origin v1.1.0`

## GitHub Release

- [ ] Create a GitHub release for `v1.1.0`
- [ ] Attach Windows build (zip of `.exe` + `.pck`)
- [ ] Attach source archive
- [ ] Add screenshots to the release
- [ ] Write release notes

## Itch.io Upload

- [ ] Create/verify itch.io project page
- [ ] Upload Windows build
- [ ] Set price to Free (or chosen price)
- [ ] Add screenshots and description
- [ ] Verify download works and game runs

## Testing

- [ ] Full playthrough on Windows
- [ ] Menu flow (start → play → pause → resume → quit)
- [ ] Death/respawn cycle and game over path
- [ ] Victory (ritual completion) path
- [ ] Audio plays correctly (ambient, chase, screams)
- [ ] Test on at least one other machine/display configuration
