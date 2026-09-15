<div align="center">

# LucidUI

A glass-morphism interface library for Roblox.

Zero dependencies. No key system. No silent failures. No broken scripts.

<sub>
  <a href="#quick-start">Quick Start</a> ·
  <a href="#features">Features</a> ·
  <a href="#api">API</a> ·
  <a href="#themes">Themes</a> ·
  <a href="#executors">Executors</a> ·
  <a href="#faq">FAQ</a>
</sub>

<br /><br />

[![Version](https://img.shields.io/github/v/release/Kyotaah/lucidui?style=flat-square&label=version&color=58A6FF)](https://github.com/Kyotaah/lucidui/releases)
[![License](https://img.shields.io/badge/license-MIT-58A6FF?style=flat-square)](https://github.com/Kyotaah/lucidui/blob/main/LICENSE.md)
[![Stars](https://img.shields.io/github/stars/Kyotaah/lucidui?style=flat-square&color=58A6FF)](https://github.com/Kyotaah/lucidui/stargazers)
[![Issues](https://img.shields.io/github/issues/Kyotaah/lucidui?style=flat-square&color=58A6FF)](https://github.com/Kyotaah/lucidui/issues)

</div>

---

## Why LucidUI

Four rules the library never breaks.

> **No external dependencies.** One `loadstring`. Everything uses standard Roblox APIs.
>
> **No key system, no auth.** MIT, forever. No Discord lock, no premium tier.
>
> **No silently-failing features.** Missing executor APIs show a toast; the rest of the UI keeps working.
>
> **No version that breaks yesterday's scripts.** The API is stable and migration is straightforward.

---

## Features

- **Glass-morphism window.** Draggable, resizable, and collapsible. Click the orange dot to shrink the window to just the title bar; the gear icon fades out while the frame animates to fit the hub name.
- **Live theme editor.** Tap any color swatch to open an HSV picker with a hue strip, SV square, hex input, and live preview. Text colors auto-adjust to stay readable against whatever background you pick.
- **17 preset themes.** Dark, Light, Nebula, Midnight, Dracula, Tokyo Night, Forest, Catppuccin Mocha, Catppuccin Latte, Nord, Gruvbox, Rosé Pine, One Dark, Synthwave '84, Solarized Dark, Ayu Mirage, Kanagawa.
- **Background image support.** Paste an image URL and the accent detector samples it on a center-weighted grid, buckets hues into a histogram, and enforces WCAG contrast so the accent always reads.
- **Config slots.** Flag any element with a name and its value persists across sessions. Saved themes and window size travel with the config.
- **Animated intro.** Music-reactive blob behind the card, rotating gradient border, orbiting logo dot, staged progress bar, expanding ring and particle burst on completion. Skippable at any moment.
- **Mobile-first input.** Every tap is distinguished from a drag, so scrolling never fires a button by accident. Windows auto-scale to the viewport.
- **Global keybinds.** RightShift toggles visibility. A configurable pill keybind (default Home) minimizes to a floating pill and restores with a second press.

---

## Quick Start

### 1. Load the library

```lua
local LucidUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Kyotaah/lucidui/main/dist/lucidui.lua"
))()
```

> `dist/lucidui.lua` is built automatically by a GitHub Action from `src/` on every push to `main`. You never need to touch it.

### 2. Create a window

```lua
local Window = LucidUI:CreateWindow({
    Name = "My Hub",
})

Window:BuildSettingsPanel()
```

### 3. Add tabs, sections, and elements

```lua
local Tab = Window:CreateTab({ Name = "Main", Icon = "zap" })

local Section = Tab:CreateSection({
    Name = "Features",
    StartExpanded = true,
})

Section:CreateButton({
    Name = "Click Me",
    Callback = function()
        LucidUI:Notify({
            Title = "Done",
            Message = "You clicked the button.",
        })
    end,
})
```

### 4. Enable config saving

Every element accepts a `Flag` string. If set, the value is written to disk and restored on the next load.

```lua
Section:CreateToggle({
    Name = "Enable Feature",
    Flag = "feature_enabled",
    Default = false,
    Callback = function(state)
        print("Feature:", state)
    end,
})
```

---

## API

### Window

| Method | Description |
| --- | --- |
| `LucidUI:CreateWindow({ Name, PillKeybind? })` | Creates the main window |
| `Window:BuildSettingsPanel()` | Adds the gear menu: theme, custom theme, saved themes, background, keybinds, configs, about |
| `Window:CreateTab({ Name, Icon })` | Creates a tab |
| `Window:SetTheme(name)` | Switches theme by name |
| `Window:SetAccent(color)` | Overrides the accent color without changing the theme |
| `Window:SetMinimized(bool)` | Collapses the window to the title bar |
| `Window:MinimizeToPill()` | Fades the window into a small floating pill |
| `Window:RestoreFromPill()` | Restores the window from the pill |
| `Window:TogglePillMode()` | Toggles between window and pill |
| `Window:SetVisible(bool)` | Shows or hides the whole GUI |
| `Window:Destroy()` | Destroys the window and all its connections |

### Section

| Method | Description |
| --- | --- |
| `Tab:CreateSection({ Name, StartExpanded? })` | Creates a collapsible section |
| `Section:SetExpanded(bool)` | Programmatically expands or collapses |

### Elements

Every element accepts a `Flag` for config persistence and returns an object with `:Set(value)` and `:Get()`.

| Element | Description |
| --- | --- |
| `CreateButton({ Name, Callback })` | Clickable button with ripple and hover glow |
| `CreateToggle({ Name, Default, Callback })` | On/off switch with sliding knob |
| `CreateSlider({ Name, Min, Max, Default, Increment?, Callback })` | Draggable numeric slider |
| `CreateDropdown({ Name, Options, Default, Callback })` | Expanding option selector |
| `CreateKeybind({ Name, Default, Callback })` | Click to capture, press any key to bind |
| `CreateInput({ Name, Placeholder, Default, Callback })` | Single-line text field |
| `CreateTextDisplay({ Title, Content })` | Read-only text block with automatic sizing |

### Notifications

```lua
LucidUI:Notify({
    Title = "Saved",
    Message = "Your config has been written.",
    Duration = 3,                            -- seconds, optional, default 4
    Accent = Color3.fromRGB(90, 210, 255),   -- optional, defaults to theme accent
})
```

---

## Themes

17 presets ship by default. Switch with `Window:SetTheme("Nebula")` or from the gear menu. Colors cross-fade over 0.3 seconds.

| Theme | Background | Accent |
| --- | --- | --- |
| **Default** | `#1C1C1E` | `#0A84FF` |
| **Light** | `#F5F5FA` | `#007AFF` |
| **Nebula** | `#18102E` | `#A064FF` |
| **Midnight** | `#0C0C14` | `#78B4FF` |
| **Dracula** | `#282A36` | `#BD93F9` |
| **Tokyo Night** | `#1A1B26` | `#7AA2F7` |
| **Forest** | `#141E18` | `#78C88C` |
| **Catppuccin Mocha** | `#1E1E2E` | `#89B4FA` |
| **Catppuccin Latte** | `#E6E9EF` | `#1E66F5` |
| **Nord** | `#2E3440` | `#88C0D0` |
| **Gruvbox** | `#282828` | `#FABD2F` |
| **Rosé Pine** | `#191724` | `#C4A7E7` |
| **One Dark** | `#282C34` | `#61AFEF` |
| **Synthwave '84** | `#262335` | `#FF7EDB` |
| **Solarized Dark** | `#002B36` | `#268BD2` |
| **Ayu Mirage** | `#1F2430` | `#FFB454` |
| **Kanagawa** | `#16161D` | `#7E9CD8` |

### Custom themes

Open **Gear → Custom Theme**. Tap any field to open the HSV color picker. Every change applies immediately. Text colors are checked against the background using WCAG relative luminance — if your pick has less than 4.5:1 contrast, it silently swaps to a readable alternative so the UI never becomes unreadable. Save the theme under a name and it appears in the dropdown.

```lua
Window:SetTheme("MyTheme")
```

### Auto accent from an image

Paste an image URL under **Gear → Background Image** and tap **Auto Accent**. The detector samples on a 60×60 grid, weights by saturation squared and distance from center, buckets hues into 36 bins, averages the peak neighborhood, then nudges the value channel until the accent hits a 3:1 contrast ratio against the current theme background.

---

## Icons

Tabs accept an `Icon` name. Every icon is drawn from Frames, not glyphs or images, so it renders identically on every device and executor with no font fallback.

```
dot      bars     diamond   cross    plus     check
shield   gavel    star      coins    person   eye
lock     unlock   play      pause    stop     bell
home     settings sword     target   flame    crown
zap
```

Unknown names fall back to `dot`.

---

## Executors

| Executor | Desktop | Mobile | Notes |
| --- | :---: | :---: | --- |
| Xeno | Yes | — | Keyless, primary test target |
| Delta | Yes | Yes | Both platforms |
| Wave | Yes | — | Paid, stable |
| Solara | Yes | — | Keyless |
| KRNL | Yes | — | Level 7 |
| Fluxus | Yes | Yes | Both platforms |
| Synapse Z | Yes | — | Fork of Synapse X |
| Arceus X | — | Yes | iOS via signing |
| Codex | — | Yes | Android |
| E-Sign | — | Yes | iOS signing service |

Only three features depend on executor-specific APIs:

- **Config saving** — needs `writefile`, `readfile`, `isfolder`, `makefolder`
- **HTTP background images** — needs `getcustomasset`, `writefile`
- **Auto accent detection** — needs `AssetService:CreateEditableImageAsync`

If any are missing, the specific feature shows a toast and the rest of the UI keeps working. Nothing crashes.

---

## Development

### Build

```bash
python build.py
```

Concatenates every file in `src/` (sorted by filename) into `dist/lucidui.lua`. The GitHub Action runs this on every push to `main`.

### Structure

```
src/
  00_compat.lua         file I/O wrapper, JSON serialization
  01_helpers.lua        services, easing, constructors, glass renderer
  01b_polish.lua        ripple, hover glow, UI sounds, BindTap
  02_themes.lua         17 preset themes and custom derivation
  03_icons.lua          frame-based icon system
  04_intro.lua          animated intro with reactive blob
  05_notifications.lua  glass toast system
  06_window.lua         shell, drag, resize, minimize, pill
  07_settings_a.lua     theme dropdown, custom theme, HSV picker
  07_settings_b.lua     background, keybinds, configs, accent detect
  08_tab.lua            tabs and sections with animated expand
  09_elements.lua       buttons, toggles, sliders, dropdowns, inputs
```

### Testing

No unit test suite. Testing happens against a live Roblox session with the executor injected. If you want to help add a proper test harness, open an issue.

---

## Contributing

Two ground rules.

> **Everything goes through `Compat`.** If your change touches the file system, use `Compat.write()`, `Compat.read()`, `Compat.hasFS()`. That layer keeps the library working on executors without file I/O.
>
> **No new dependencies.** LucidUI is one `loadstring`. Everything must work with just standard Roblox APIs.

When proposing a new element, include a preview snippet in the PR description.

---

## Roadmap

- Multi-select dropdown
- Color picker with a full hue wheel
- Toast action buttons
- Per-tab accent colors
- Window edge snapping
- Tooltip system with hover delay
- Global font override
- Animated status indicator in the header

Want something on this list? Open an issue with a description of the use case.

---

## FAQ

<details>
<summary>Is this a copy of Luna?</summary>
<br />
No. The API is intentionally similar so migrating is easy, but the implementation is entirely different. Luna has a different structure, different theming, and different icon handling. LucidUI was written from a blank file.
</details>

<details>
<summary>Can I use this in a paid script?</summary>
<br />
Yes. MIT license. Attribution is appreciated but not required.
</details>

<details>
<summary>Does it work on mobile?</summary>
<br />
Yes. Every element is touch-compatible, the window auto-scales to viewport size, and taps are distinguished from drags so scrolling never fires a button by accident. There's a compact mode for narrow screens.
</details>

<details>
<summary>Why does the auto accent detector fail on some images?</summary>
<br />
It samples for saturated pixels. Grayscale images, very dark images, and images that are mostly white return no valid samples and fail cleanly with a toast. That's the correct behavior. The alternative is picking a random accent that looks wrong.
</details>

<details>
<summary>The window doesn't appear or the UI looks broken.</summary>
<br />
Check the F9 console. Nine times out of ten it's a missing <code>getgenv()</code> — Delta in particular sandboxes globals between lines in some builds, and the library routes everything through <code>getgenv()</code> to compensate.
</details>

<details>
<summary>Can it be obfuscated?</summary>
<br />
Yes, but we don't. Keeping the source readable is part of the point.
</details>

---

## License

MIT License. Copyright (c) 2026 Kyo.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions.

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

Full text in [LICENSE](https://github.com/Kyotaah/lucidui/blob/main/LICENSE.md).

---

## Credits

Built by **Kyo** ([@Kyotaah](https://github.com/Kyotaah)).

The glass aesthetic owes a debt to Apple's UI language. The config system was inspired by Nova UI. The "just work on every executor" obsession comes from every UI library that ever broke on us mid-session.

<div align="center">

<br />

**If LucidUI saved you time, consider starring the repo.**

[![Star](https://img.shields.io/github/stars/Kyotaah/lucidui?style=social)](https://github.com/Kyotaah/lucidui/stargazers)

<br />

<sub>MIT · No key system · No dependencies · No broken scripts</sub>

</div>
