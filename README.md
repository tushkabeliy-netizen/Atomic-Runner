# Atomic Runner

A Godot 4.3 Android endless-runner prototype with a Soviet retro-futurist direction, designed for portrait mobile play.

## Current playable prototype

- Portrait 720×1280 project with a third-person follow camera.
- Three lanes; swipe left/right to change lanes.
- Swipe up to jump and swipe down to slide.
- A simple low-poly runner character with a helmet, backpack, chest armor and swinging limbs.
- Procedurally placed token lines, barriers and overhead obstacles.
- Token collection, distance-based score, collision/game-over state and tap-to-restart.
- Recycled road markings, road segments, street lamps and city blocks intended to keep the route extending.
- Soviet-style city dressing, red facade bands and a muted daylight environment.

## Controls

- Swipe left/right: change lane.
- Swipe up: jump over barriers.
- Swipe down: slide under overhead obstacles.
- Keyboard arrows: equivalent controls when running on desktop.
- Tap after game over (or press Enter): restart.

## Android build

The GitHub Actions workflow at `.github/workflows/android-apk.yml` builds a debug APK and uploads it as an artifact when a matching source file is pushed to `main`, or when manually started from the Actions page.

The workflow now uses the published `barichello/godot-ci:4.3` image, prepares the Godot export templates, installs the Android build template and checks that the APK exists before uploading it.

**Build status: pending verification.** The workflow configuration has been corrected, but a successful run and a device installation test have not yet been confirmed. No tested APK is being represented as ready.

## Not implemented yet

This remains an early gameplay prototype, not the complete game design. It does not yet include final character models or animations, named Atomic Heart characters, detailed named locations and connected route branches, trains, missions, upgrades/shop, sound design, or the on-device music-library player. Those are still planned development work.
