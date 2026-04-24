# Quick Display

Quick Display is a simple Android app for saving and quickly switching between frequently used barcodes, QR codes, and images.

It is designed for fast access with a minimal interface, making it useful for things like transport codes, access QR codes, membership barcodes, or personal photos you want ready on demand.

## Features

- Save multiple images in separate quick-access slots
- Tap to switch between saved items instantly
- Replace or remove the image in the current slot
- Rotate the current image
- Remember the last selected slot
- Switch between light and dark display backgrounds
- Downscale oversized images during import for smoother performance

## Project Info

- Platform: Android
- Language: Java
- Min SDK: 30
- Target SDK: 36
- Build system: Gradle

## Getting Started

1. Open the project in Android Studio.
2. Make sure the required Android SDK is installed.
3. Sync the Gradle project.
4. Run the app on an Android device or emulator.

## Build

Debug build:

```bash
./gradlew assembleDebug
```

Release build:

```bash
./gradlew assembleRelease
```

On Windows, use:

```bash
gradlew.bat assembleDebug
gradlew.bat assembleRelease
```

## Notes

- Signing keys and local secrets are ignored by `.gitignore` and should not be committed.
- The current app package name is `com.jensen.ShowLastImage`.
- The app display name can be updated independently from the package name.

## Status

This project is currently being prepared for Google Play release.
