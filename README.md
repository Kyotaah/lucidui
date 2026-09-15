<div align="center">

<img src="https://raw.githubusercontent.com/Kyotaah/lucidui/main/assets/banner.png" alt="LucidUI — glass-morphism interface for Roblox" width="100%" />

<br />
<br />

<h1>LucidUI</h1>

<p><strong>Glass-morphism interface for Roblox.</strong><br />
Zero dependencies. No key system. No silent failures. No broken scripts.</p>

<p>
  <a href="https://github.com/Kyotaah/lucidui/releases">
    <img src="https://img.shields.io/github/v/release/Kyotaah/lucidui?style=for-the-badge&logo=github&label=version&color=58A6FF" alt="Version" />
  </a>
  <a href="https://github.com/Kyotaah/lucidui/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-58A6FF?style=for-the-badge&logo=opensourceinitiative&logoColor=white" alt="License: MIT" />
  </a>
  <a href="https://github.com/Kyotaah/lucidui/stargazers">
    <img src="https://img.shields.io/github/stars/Kyotaah/lucidui?style=for-the-badge&logo=github&color=58A6FF" alt="Stars" />
  </a>
  <a href="https://github.com/Kyotaah/lucidui/network/members">
    <img src="https://img.shields.io/github/forks/Kyotaah/lucidui?style=for-the-badge&logo=github&color=58A6FF" alt="Forks" />
  </a>
  <a href="https://github.com/Kyotaah/lucidui/issues">
    <img src="https://img.shields.io/github/issues/Kyotaah/lucidui?style=for-the-badge&logo=github&color=58A6FF" alt="Issues" />
  </a>
  <a href="#-executor-matrix">
    <img src="https://img.shields.io/badge/platforms-Desktop%20%7C%20Mobile-58A6FF?style=for-the-badge&logo=roblox&logoColor=white" alt="Platforms" />
  </a>
</p>

<p>
  <a href="#-quick-start"><strong>Quick Start</strong></a> ·
  <a href="#-features"><strong>Features</strong></a> ·
  <a href="#-api-reference"><strong>API</strong></a> ·
  <a href="#-themes"><strong>Themes</strong></a> ·
  <a href="#-executor-matrix"><strong>Executors</strong></a> ·
  <a href="#-roadmap"><strong>Roadmap</strong></a> ·
  <a href="#-faq"><strong>FAQ</strong></a>
</p>

</div>

---

<div align="center">

<h3>See it in action</h3>

<img src="https://raw.githubusercontent.com/Kyotaah/lucidui/main/assets/demo.gif" alt="LucidUI demo — window, tabs, toggle, slider, dropdown, notifications" width="90%" />

<br />
<br />

<table>
  <tr>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/Kyotaah/lucidui/main/assets/screenshot-dark.png" alt="Dark theme" />
      <br />
      <sub><b>Dark</b> — default glass theme</sub>
    </td>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/Kyotaah/lucidui/main/assets/screenshot-custom.png" alt="Custom theme editor" />
      <br />
      <sub><b>Custom Theme Editor</b> — six live color pickers</sub>
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/Kyotaah/lucidui/main/assets/screenshot-intro.png" alt="Animated intro screen" />
      <br />
      <sub><b>Intro Screen</b> — rotating gradient border, orbiting dot, particle burst</sub>
    </td>
    <td width="50%">
      <img src="https://raw.githubusercontent.com/Kyotaah/lucidui/main/assets/screenshot-config.png" alt="Config slots" />
      <br />
      <sub><b>Config Slots</b> — save and load flagged values</sub>
    </td>
  </tr>
</table>

</div>

---

## ✨ Features

LucidUI is built on four rules that the library never breaks:

- **No external dependencies.** One `loadstring`. Everything uses standard Roblox APIs.
- **No key system, no auth.** MIT, forever. No Discord lock, no premium tier.
- **No silently-failing features.** Missing executor APIs show a toast; the rest of the UI keeps working.
- **No version that breaks yesterday's scripts.** The API is stable and migration is straightforward.

| Feature | What it does |
| --- | --- |
| 🪟 **Glass-morphism window** | Draggable, resizable, collapsible to header or floating pill |
| 🎨 **Live custom theme editor** | Six color pickers apply live; save themes by name |
| 🎛️ **Seven preset themes** | Dark, Light, Nebula, Midnight, Dracula, Tokyo Night, Forest |
| 🔔 **Glass toast notifications** | Non-blocking, stacked, auto-dismiss |
| 🖼️ **Background image support** | Auto accent detection from saturated pixels |
| 💾 **Config slots** | Flag any element to persist its value across sessions |
| 🎬 **Animated intro screen** | The one moment the UI gets to show off |
| 📱 **Mobile-first** | Touch-compatible, auto-scales to viewport, compact mode |

---

## 🚀 Quick Start

### 1. Load the library

```lua
local LucidUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Kyotaah/lucidui/main/dist/lucidui.lua"
))()
```

> The file you load is built automatically by a GitHub Action from `src/` on every push to `main`. You never need to touch `dist/`.

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

### 4. Enable config saving (optional)

Every element accepts a `Flag` string. If set, the value is saved and restored:

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

## 📖 API Reference

### Window

| Method | Description |
| --- | --- |
| `LucidUI:CreateWindow({ Name, ... })` | Creates the main window |
| `Window:BuildSettingsPanel()` | Adds the gear menu (theme, config, about) |
| `Window:CreateTab({ Name, Icon })` | Creates a tab |
| `Window:SetTheme(name)` | Switches theme by name |
| `Window:Destroy()` | Destroys the window and all connections |

### Section

| Method | Description |
| --- | --- |
| `Tab:CreateSection({ Name, StartExpanded })` | Creates a collapsible section |

### Elements

| Element | Description |
| --- | --- |
| `Section:CreateButton({ Name, Callback, Flag? })` | Clickable button with ripple + glow |
| `Section:CreateToggle({ Name, Default, Callback, Flag? })` | On/off switch with sliding knob |
| `Section:CreateSlider({ Name, Min, Max, Default, Callback, Flag? })` | Draggable numeric slider |
| `Section:CreateDropdown({ Name, Options, Default, Callback, Flag? })` | Expanding option selector |
| `Section:CreateKeybind({ Name, Default, Callback, Flag? })` | Click to capture, press any key |
| `Section:CreateInput({ Name, Placeholder, Default, Callback, Flag? })` | Single-line text field |
| `Section:CreateTextDisplay({ Name, Text })` | Auto-sizing read-only text block |

### Notifications

```lua
LucidUI:Notify({
    Title = "Saved",
    Message = "Your config has been written.",
    Duration = 3, -- seconds (optional)
})
```

---

## 🎨 Themes

Seven presets ship by default. Switch with `Window:SetTheme("Nebula")` or from the gear menu. Colors cross-fade over **0.3 seconds**.

| Theme | Surface | Accent | Vibe |
| --- | --- | --- | --- |
| **Dark** | `#1C1C1E` | `#58A6FF` | Default glass, blue accent |
| **Light** | `#F5F5FA` | `#007AFF` | Clean light mode |
| **Nebula** | `#18102E` | `#A97BFF` | Purple cosmic |
| **Midnight** | `#0C0C14` | `#78B4FF` | Deep blue, soft edges |
| **Dracula** | `#282A36` | `#BD93F9` | Classic purple on charcoal |
| **Tokyo Night** | `#1A1B26` | `#7AA2F7` | Muted indigo |
| **Forest** | `#141E18` | `#78C88C` | Green glass |

### Custom themes

Open **Gear → Custom Theme** to build your own. Six color pickers apply live. Click **Save As** to store the theme under a name. Saved themes appear in the Theme dropdown.

```lua
Window:SetTheme("MyTheme")
```

---

## 🔣 Icons

Tabs accept an `Icon` name. Every icon is drawn with **Frames**, not glyphs or images — it renders identically on every device, at any DPI, with no font fallback.

Available icons: `dot` `bars` `diamond` `cross` `plus` `check` `shield` `gavel` `star` `coins` `person` `eye` `lock` `unlock` `play` `pause` `stop` `bell` `home` `settings` `sword` `target` `flame` `crown` `zap`

Unknown names fall back to `dot`.

---

## 🖥️ Executor Matrix

| Executor | Desktop | Mobile | Notes |
| --- | --- | --- | --- |
| **Xeno** | ✅ | — | Keyless, primary test target |
| **Delta** | ✅ | ✅ | Both platforms |
| **Wave** | ✅ | — | Paid, stable |
| **Solara** | ✅ | — | Keyless |
| **KRNL** | ✅ | — | Level 7 |
| **Fluxus** | ✅ | ✅ | Both platforms |
| **Synapse Z** | ✅ | — | Fork of Synapse X |
| **Arceus X** | — | ✅ | iOS via signing |
| **Codex** | — | ✅ | Android |
| **E-Sign** | — | ✅ | iOS signing service |

> Only three features depend on executor-specific APIs: config saving (`writefile`, `readfile`, `isfolder`, `makefolder`), HTTP background (`getcustomasset`, `writefile`), and auto accent detection (`AssetService:CreateEditableImageAsync`). If any of those are missing, the specific feature shows a toast and the rest of the UI keeps working. **Nothing crashes.**

---

## 🛠️ Development

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
  01b_polish.lua        ripple, hover glow, UI sounds
  02_themes.lua         7 preset themes + derivation
  03_icons.lua          frame-based icon system
  04_intro.lua          animated intro with stage support
  05_notifications.lua  glass toast system
  06_window.lua         shell, drag, resize, settings container
  07_settings_a.lua     theme dropdown, custom theme, color pickers
  07_settings_b.lua     config slots, about page, executor info
  08_elements.lua       buttons, toggles, sliders, dropdowns, etc.
  09_api.lua            public API surface
```

### Testing

There is no unit test suite. Testing happens against a live Roblox session with the executor injected. If you want to help add a proper test harness, **open an issue**.

---

## 🤝 Contributing

Two ground rules:

1. **Everything goes through `Compat`.** If your change touches the file system, use `Compat.write()`, `Compat.read()`, `Compat.hasFS()`. That layer is what keeps the library working on executors without file I/O.

2. **No new dependencies.** LucidUI is one `loadstring`. Everything must work with just standard Roblox APIs.

When proposing a new element, include a **preview snippet** in the PR description showing what it looks like and how it's used.

---

## 🗺️ Roadmap

- [ ] Multi-select dropdown
- [ ] Color picker with hue wheel (replacing R/G/B sliders)
- [ ] Toast action buttons
- [ ] Per-tab accent colors
- [ ] Window edge snapping
- [ ] Tooltip system with hover delay
- [ ] Global font override (Inter / SF Pro via `rbxasset`)
- [ ] Animated status indicator in the header

Want something on this list? **Open an issue** with a description of the use case.

---

## ❓ FAQ

<details>
<summary><b>Is this a copy of Luna?</b></summary>
<br />
No. The API is intentionally similar so migrating is easy, but the implementation is entirely different. Luna has different structure, different theming, different icon handling. LucidUI was written from a blank file.
</details>

<details>
<summary><b>Can I use this in a paid script?</b></summary>
<br />
Yes. MIT license. Attribution is appreciated but not required.
</details>

<details>
<summary><b>Does it work on mobile?</b></summary>
<br />
Yes. Every element is touch-compatible and the window auto-scales to viewport size. There's a compact mode for narrow screens.
</details>

<details>
<summary><b>Why does the auto accent detector fail on some images?</b></summary>
<br />
It samples for saturated pixels. Grayscale images, very dark images, and images that are mostly white return no valid samples and fail cleanly. That's the correct behavior — the alternative is picking a random accent that looks wrong.
</details>

<details>
<summary><b>The window doesn't appear / the UI looks broken.</b></summary>
<br />
Check the FAQ section of the Lua console output. Nine times out of ten it's a missing <code>getgenv()</code> — Delta in particular sandboxes globals between lines in some builds, and the library routes everything through <code>getgenv()</code> to compensate.
</details>

<details>
<summary><b>Can it be obfuscated?</b></summary>
<br />
Yes, but we don't. See "what lucidui is not" above.
</details>

---

## 📄 License

MIT License · Copyright (c) 2026 Kyo

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

Full text in [LICENSE](https://github.com/Kyotaah/lucidui/blob/main/LICENSE.md).

---

## 🙏 Credits

Built by **Kyo** ([@Kyotaah](https://github.com/Kyotaah)).

The glass aesthetic owes a debt to Apple's UI language. The config system was inspired by Nova UI. The "just work on every executor" obsession comes from every UI library that ever broke on us mid-session.

---

<div align="center">

<br />

**If LucidUI saved you time, consider starring the repo. It helps more people find it.**

<br />

<a href="https://github.com/Kyotaah/lucidui/stargazers">
  <img src="https://img.shields.io/github/stars/Kyotaah/lucidui?style=social" alt="Star LucidUI" />
</a>

<br />
<br />

<sub>MIT · No key system · No dependencies · No broken scripts</sub>

</div>
