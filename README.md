<!--
    ┌────────────────────────────────────────────────────────┐
    │  banner (optional)                                     │
    │  drop a gif at ./assets/banner.gif and uncomment:      │
    │                                                        │
    │  <img src="./assets/banner.gif" width="100%">          │
    │                                                        │
    └────────────────────────────────────────────────────────┘
-->

```
  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃                                                     ┃
  ┃      ◆   L U C I D U I                              ┃
  ┃                                                     ┃
  ┃      glass-morphism interface                       ┃
  ┃      for roblox                                     ┃
  ┃                                                     ┃
  ┃      v0.9.0   ·   MIT   ·   zero dependencies       ┃
  ┃                                                     ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

*Four rules the library follows:*

```
  →  no external dependencies
  →  no key system, no auth
  →  no silently-failing features
  →  no version that breaks yesterday's scripts
```

---

## install

```lua
local LucidUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Kyotaah/lucidui/main/dist/lucidui.lua"
))()
```

The file you load is built automatically by a GitHub Action from `src/` on every push. You don't need to touch `dist/`.

---

## quick start

```lua
local LucidUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Kyotaah/lucidui/main/dist/lucidui.lua"
))()

local Window = LucidUI:CreateWindow({ Name = "My Hub" })
Window:BuildSettingsPanel()

local Tab     = Window:CreateTab({ Name = "Main", Icon = "zap" })
local Section = Tab:CreateSection({ Name = "Features", StartExpanded = true })

Section:CreateButton({
    Name     = "Click Me",
    Callback = function()
        LucidUI:Notify({ Title = "Done", Message = "You clicked the button." })
    end,
})
```

---

## what it looks like

The window renders like this:

```
  ╭──────────────────────────────────────────────────╮
  │  ●  ●  ●                            ⚙    ─    ✕  │
  ├──────────────────────────────────────────────────┤
  │                                                  │
  │    My Hub                                        │
  │                                                  │
  │    ▎ Main     Config     About                   │
  │                                                  │
  │    ┌────────────────────────────────────────┐    │
  │    │   Enable Feature                ◯──     │    │
  │    └────────────────────────────────────────┘    │
  │                                                  │
  │    ┌────────────────────────────────────────┐    │
  │    │   Speed                          50     │    │
  │    │   ─────────●──────────────              │    │
  │    └────────────────────────────────────────┘    │
  │                                                  │
  │    ┌────────────────────────────────────────┐    │
  │    │              Click Me                   │    │
  │    └────────────────────────────────────────┘    │
  │                                                  │
  │                                         ◢◣       │
  ╰──────────────────────────────────────────────────╯
```

The colored dots in the top-right are the traffic-light controls. Orange collapses to header-only mode. Red collapses to a floating pill.

---

## elements

Every element accepts an optional `Flag` string. If set, the value is saved with the config.

| element | what it does |
|---|---|
| `Section:CreateButton` | clickable button with ripple + glow |
| `Section:CreateToggle` | on/off switch with a sliding knob |
| `Section:CreateSlider` | draggable numeric slider |
| `Section:CreateDropdown` | expanding option selector |
| `Section:CreateKeybind` | click to capture, press any key |
| `Section:CreateInput` | single-line text field |
| `Section:CreateTextDisplay` | auto-sizing read-only text block |

Each has a runnable example in the [`examples/`](./examples) folder.

---

## themes

Seven presets ship by default. Switch with `Window:SetTheme("Nebula")` or from the gear menu. Colors cross-fade over 0.3 seconds.

```
  Default       #1C1C1E  ·  #58A6FF     dark glass, blue accent
  Light         #F5F5FA  ·  #007AFF     clean light mode
  Nebula        #18102E  ·  #A97BFF     purple cosmic
  Midnight      #0C0C14  ·  #78B4FF     deep blue, soft edges
  Dracula       #282A36  ·  #BD93F9     classic purple on charcoal
  Tokyo Night   #1A1B26  ·  #7AA2F7     muted indigo
  Forest        #141E18  ·  #78C88C     green glass
```

Open **gear → Custom Theme** to build your own. Six color pickers apply live. Click **Save As** to store the theme under a name. Saved themes appear in the Theme dropdown.

---

## icons

Tabs accept an `Icon` name. Every icon is drawn with Frames, not glyphs or images — it renders identically on every device, at any DPI, with no font fallback.

```
  dot      bars     diamond   cross    plus
  check    shield   gavel     star     coins
  person   eye      lock      unlock   play
  pause    stop     bell      home     settings
  sword    target   flame     crown    zap
```

Unknown names fall back to `dot`.

---

## design notes

Each interactive element has three states:

```
  idle      flat translucent surface, thin border
  hover     accent-colored outline glows in over 150 ms
  press     surface scales to 97%, ripple blooms from tap point
```

Every color is exposed via the theme table. Every easing is either `Quint.Out` or `Back.Out` — never mixed. Every animation is either `0.22s` (state change) or `0.55s` (entrance / exit). The consistency is what makes it feel expensive.

The intro screen is the only place the library breaks its own rules — rotating gradient border, orbiting dot, particle burst on finish. It's the one moment the UI gets to show off.

---

## what lucidui is not

- **Not a fork of Luna or Starlight.** Built from scratch after those libraries were deprecated or broke on specific executors.
- **Not an executor.** You still need Delta, Solara, Wave, or similar to run scripts.
- **Not protected against skidding.** Any Lua script running in an executor can be read and re-run. This is a property of Roblox, not a LucidUI limitation. We chose to accept that rather than fight it with obfuscation.
- **Not a paid library in disguise.** No key system, no Discord lock, no premium tier. MIT, forever.
- **Not finished.** The roadmap below is real — those are actual planned features.

---

## executor matrix

```
                    desktop   mobile    notes
  Xeno                ✓         —         keyless, primary test target
  Delta               ✓         ✓         both platforms
  Wave                ✓         —         paid, stable
  Solara              ✓         —         keyless
  KRNL                ✓         —         level 7
  Fluxus              ✓         ✓         both platforms
  Synapse Z           ✓         —         fork of Synapse X
  Arceus X            —         ✓         iOS via signing
  Codex               —         ✓         Android
  E-Sign              —         ✓         iOS signing service
```

Only three features depend on executor-specific APIs:

```
  config saving         →  writefile, readfile, isfolder, makefolder
  http background       →  getcustomasset, writefile
  auto accent detection →  AssetService:CreateEditableImageAsync
```

If any of those are missing, the specific feature shows a toast and the rest of the UI keeps working. Nothing crashes.

---

## development

### build

```bash
python build.py
```

Concatenates every file in `src/` (sorted by filename) into `dist/lucidui.lua`. The GitHub Action runs this on every push to `main`.

### structure

```
  src/
    00_compat.lua         file I/O wrapper, JSON serialization
    01_helpers.lua        services, easing, constructors, glass renderer
    01b_polish.lua        ripple, hover glow, UI sounds
    02_themes.lua         7 preset themes + derivation
    03_icons.lua          frame-based gear icon
    04_intro.lua          animated intro with stage support
    05_notifications.lua  glass toast system
    06_window.lua         shell, drag, resize, settings container
    07_settings_a.lua     theme dropdown, custom theme, saved themes
    07_settings_b.lua     background image, auto accent, configs, about
    08_tab.lua            tabs, sections, 25 icons
    09_elements.lua       all interactive elements
```

There's no unit test suite. Testing happens against a live Roblox session with the executor injected. If you want to help add a proper test harness, open an issue.

---

## contributing

Two ground rules:

1. **Everything goes through `Compat`.** If your change touches the file system, use `Compat.write()`, `Compat.read()`, `Compat.hasFS()`. That layer is what keeps the library working on executors without file I/O.
2. **No new dependencies.** LucidUI is one `loadstring`. Everything must work with just standard Roblox APIs.

When proposing a new element, include a preview snippet in the PR description showing what it looks like and how it's used.

---

## roadmap

```
  ☐  multi-select dropdown
  ☐  color picker with hue wheel (replacing R/G/B sliders)
  ☐  toast action buttons
  ☐  per-tab accent colors
  ☐  window edge snapping
  ☐  tooltip system with hover delay
  ☐  global font override (Inter / SF Pro via rbxasset)
  ☐  animated status indicator in the header
```

Want something on this list? Open an issue with a description of the use case.

---

## faq

**Is this a copy of Luna?**
No. The API is intentionally similar so migrating is easy, but the implementation is entirely different. Luna has different structure, different theming, different icon handling. LucidUI was written from a blank file.

**Can I use this in a paid script?**
Yes. MIT license. Attribution is appreciated but not required.

**Does it work on mobile?**
Yes. Every element is touch-compatible and the window auto-scales to viewport size. There's a compact mode for narrow screens.

**Why does the auto accent detector fail on some images?**
It samples for saturated pixels. Grayscale images, very dark images, and images that are mostly white return no valid samples and fail cleanly. That's the correct behavior — the alternative is picking a random accent that looks wrong.

**The window doesn't appear / the UI looks broken.**
Check the FAQ section of the Lua console output. Nine times out of ten it's a missing `getgenv()` — Delta in particular sandboxes globals between lines in some builds, and the library routes everything through `getgenv()` to compensate.

**Can it be obfuscated?**
Yes, but we don't. See "what lucidui is not."

---

## license

```
MIT License

Copyright (c) 2026 Kyo

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions...
```

Full text in [`LICENSE`](./LICENSE).

---

## credits

Built by **Kyo** ([@Kyotaah](https://github.com/Kyotaah)).

The glass aesthetic owes a debt to Apple's UI language. The config system was inspired by Nova UI. The "just work on every executor" obsession comes from every UI library that ever broke on us mid-session.

```
  ─── end ───
```
