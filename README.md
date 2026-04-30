<p align="center">
  <a href="">
    <img alt="Logo" src="blob/hush.svg" width="500px">
  </a>
</p>

<br>

<p align="left">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5+-orange.svg">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-green">
  <img alt="version" src="https://img.shields.io/badge/version-1.0.0-purple">
</p>

🇺🇦

**Hush** is a lightweight **macOS menu-bar app** for building a calm soundscape: mix ambient loops, save presets, and set a sleep timer — without cluttering your Dock.

- [About](#about)
- [Features](#features)
- [How it looks](#how-it-looks)
- [Build & run](#build--run)
- [Tech](#tech)
- [Contributing](#contributing)
- [License](#license)
- [Thanks to](#thanks-to)
- [Contact](#contact)

## About

Hush lives in your menu bar and gives you a quick mixer for ambient sounds like rain, wind, café noise, and more. Turn stems on/off, adjust volumes, save favorite mixes as presets, and optionally schedule a fade-out with a sleep timer.

The idea came to me at my current workplace: sometimes other people’s *weird noises* break focus. I tried a few similar apps, but each one lacked some small-but-important features I wanted in daily use — so I decided to build my own.

## Features

- **Menu-bar first**: always one click away.
- **Ambient mixer**: combine multiple looping stems with per-sound volume control.
- **Presets**: save the current mix, load with a tap, delete with a long-press.
- **Random mix**: generate a quick randomized ambience when you don’t want to think.
- **Stop all**: instantly fade/stop every playing sound.
- **Sleep timer**: auto fade-out after a preset/custom duration.
- **About screen with changelog**: rendered from `CHANGELOG.md`.
- **Theme-aware UI**: presets and controls adapt to light/dark mode.

## How it looks

<p align="center">
  <a href="">
    <img alt="Logo" src="blob/hush_app.svg" width="300px">
  </a>
</p>

## Build & run

- **Requirements**: macOS + Xcode (SwiftUI project).
- **Run**: open `Hush.xcodeproj` and press **Run** (scheme: `Hush`).

## Tech

- **SwiftUI** for UI
- **AVAudioEngine** for multi-stem audio playback/mixing
- **Swift Concurrency** for safe audio graph orchestration
- **UserDefaults** (JSON) for persisting mixer state and presets
- Built with help of **modern AI tools**. The original prompt used as an input is available in file [promt](blob/promt.txt).

## Contributing

PRs are welcome. If you’re planning a larger change, please open an issue first so we can align on direction.

## License

[MIT licensed.](LICENSE)

## Thanks to

* [wadetregaskis](https://github.com/wadetregaskis/FluidMenuBarExtra) for FluidMenuBarExtra
* [LiYanan2004](https://github.com/LiYanan2004/MarkdownView) for MarkdownView

## Contact

Have a question or found an issue in **Hush**? Create an [issue](https://github.com/khorbushko/Hush/issues/new)!

If you would like to contribute - just create a pull request.

<br>
