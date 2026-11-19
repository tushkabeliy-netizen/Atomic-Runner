# Atomic Runner

A Godot 4 Android endless-runner prototype with a Soviet retro-futurist visual direction.

## Current prototype

- Portrait layout and third-person follow camera.
- Three lanes with swipe and keyboard controls.
- Jump and slide actions.
- Procedurally generated obstacle/token rows that continue as the run progresses.
- Token pickups, distance score, collision/game-over state, and tap-to-restart.
- Procedural city blocks and industrial street dressing.

## Controls

- Swipe left/right: change lane.
- Swipe up: jump.
- Swipe down: slide.
- Keyboard arrows: equivalent controls when running on desktop.
- Tap after game over (or press Enter): restart.

## Android build

The repository includes a GitHub Actions workflow at `.github/workflows/android-apk.yml` that attempts to export a debug APK and publish it as an Actions artifact.

**Build status: not yet verified.** The source changes have been committed, but the workflow has not yet been confirmed successful and no tested APK is available. A successful Actions run is required before an APK can be shared as installable.

## Not implemented yet

This is not the finished game design. It does not yet include final character models/animations, named Atomic Heart characters, full location routes, trains, missions, upgrades/shop, sound design, or the device music-library player. Those remain future development work.
