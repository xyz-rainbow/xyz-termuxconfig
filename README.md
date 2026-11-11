# xyz-termuxconfig — Universal Termux & Linux Desktop Dotfiles

Automated, modular recovery and dotfiles system for **Termux** (Android / `aarch64` ARM64, non-root), supporting multiple Linux distributions (Debian, Ubuntu, Fedora, Arch) + **GNOME (Dark Mode)** over **Termux:X11**, hardware GPU acceleration (`VirGL Vulkan`), physical keyboard translation (`esc-fix` for `Esc` & `F1–F12`), `/voice` microphone capture (`arecord` + `PulseAudio`), **CLI AI Agents (`agy`, Claude Code, OpenCode, Grok Build)** with nested rules & plugins, and **Wireless ADB (`pad-adb`)** automation.

---

## Repository Structure

```text
xyz-termuxconfig/
├── setup.sh                  # Interactive installer (dialog checklist + runtime Y/n prompts)
│                             # Modules: PACKAGES, DOTFILES, GITHUB_CONFIG, KEYBOARD, CLI_AGENTS, ADB, DESKTOP
├── packages.txt              # Complete Termux package list (including x11-repo & tur-repo)
├── config/                   # Shell, audio, Termux, and Debian GNOME configuration files
│   ├── bashrc                # Clean base ~/.bashrc (micro editor, wake-lock, pulseaudio)
│   ├── inputrc               # ~/.inputrc (low-latency key timeouts)
│   ├── asoundrc              # ~/.asoundrc (ALSA -> PulseAudio routing)
│   ├── termux.properties     # ~/.termux/termux.properties (back-key=escape, extra-keys)
│   ├── motd                  # Termux startup banner with 'desktop --start' reminder
│   ├── pulse-default.pa      # PulseAudio OpenSL ES microphone + TCP module config
│   └── debian/               # Debian 13 (Trixie) + GNOME 48 configuration & PRoot shims
│       ├── bwrap-shim.py     # PRoot-compatible /usr/bin/bwrap shim for GNOME thumbnails
│       ├── debian-packages.txt
│       ├── cursor.sources
│       ├── google-chrome-canary.sources
│       └── root-bashrc
├── plugins/
│   └── plugins.json          # Antigravity CLI plugin configuration template (swarm enabled)
├── scripts/                  # Global executables symlinked into ~/.local/bin/
│   ├── desktop               # Unified GNOME manager (--start, --stop, --reboot, --fps, --res, --zoom, --fast)
│   ├── pad-adb               # Wireless ADB manager (--start, --stop, --pair <code>, --status, --optimize)
│   ├── arecord               # PulseAudio/SoX wrapper for Antigravity CLI /voice capture
│   └── src/
│       └── esc-fix.c         # Zero-latency C PTY translator (º -> Esc, Ctrl+Alt+1..¡ -> F1-F12)
├── rules/
│   └── GEMINI.md             # Custom Antigravity CLI (agy) global rules (~/.gemini/config/GEMINI.md)
└── user_home/
    └── .config/
        ├── notes/
        │   └── pending.md    # Clean template for deferred tasks and maintenance
        └── scripts/
            ├── desktop.conf  # Saved desktop preferences (distro, PAD6_KEYBOARD_FIX, FPS, resolution, zoom, mode)
            ├── README.md
            └── GUIDE.md
```

---

## Modular Checkboxes in `setup.sh`

### Main Menu Checkboxes
1. `[ ] PACKAGES`: Internal `dialog` checklist for package groups (`CORE`, `NODE`, `PYTHON`, `EDITOR`, `TOOLS`).
2. `[ ] DOTFILES`: Restore user home folders, clean `.bashrc`, audio/terminal properties, and base scripts.
3. `[ ] GITHUB_CONFIG`: **Interactive Git & GitHub CLI authentication**. Authenticates via browser code (`gh auth login -w`), binds credential helper, and sets identity automatically without hardcoded usernames or emails.
4. `[ ] KEYBOARD`: **Xiaomi Pad 6 Hardware Keyboard fix** (independent module). Compiles `esc-fix` and sets `Esc` & `F1–F12` mappings. If unselected, leaves a universal standard keyboard layout.
5. `[ ] CLI_AGENTS`:
   - **Sub-module 1**: Select verified official CLI AI Agents (`Google Antigravity CLI`, `Claude Code`, `OpenCode AI`, `Grok Official CLI`, `DeepSeek Harness`, `Cline`, `GitLab Duo`).
   - **Sub-module 2 (Nested for agy)**: Custom session rules (`GEMINI.md`), clean template (`pending.md`), and `dialog` checklist for plugins (`Swarm`, `GitHub`, `Automation`, `Gen_UI`).
   - **PRoot Desktop Bridge**: Automatically creates `/usr/local/bin` bridges into Linux desktop containers so all CLI agents are accessible directly inside GNOME terminal emulators and IDE integrated terminals.
6. `[ ] ADB`: Install Wireless ADB manager (`pad-adb`) and apply Android 14+ Phantom Process Killer bypass.
7. `[ ] DESKTOP`:
   - **Step 1/3 (Distro)**: Radiolist selector (`Debian 13`, `Ubuntu Noble`, `Fedora`, `Arch Linux`).
   - **Step 2/3 (GNOME & Desktop Script)**: Install GNOME Desktop and configure unified `desktop` command.
   - **Step 3/3 (Modular Apps)**: 4 multi-select checklist categories tailored to selected distro:
     - **IDEs & Code Editors**: Google Antigravity IDE (VS Code ARM64 + Antigravity Integration), Cursor ARM64, VS Code Official ARM64, VSCodium ARM64, Neovim.
     - **Web Browsers**: Google Chrome Canary ARM64, Firefox ARM64, Chromium, Brave ARM64.
     - **Terminal Emulators**: Kitty, GNOME Console, Alacritty, Tilix.
     - **Essential & Extra Apps**: Vesktop ARM64 (Discord), Evince, Loupe, VLC, AbiWord, LibreOffice.

---

## Quick Restore on a Clean Termux Installation

```bash
pkg update -y && pkg install -y git dialog
git clone https://github.com/xyz-rainbow/xyz-termuxconfig.git ~/projects/xyz-termuxconfig
cd ~/projects/xyz-termuxconfig
chmod +x setup.sh
./setup.sh
```

---

## Single Module Execution (Non-Destructive)

You can run individual modules directly without touching or resetting the rest of your installation:

```bash
# Install or update a CLI AI agent (agy, claude, opencode, grok, deepseek...)
./setup.sh --agents

# Install a Desktop IDE (Antigravity IDE, Cursor, VSCode, VSCodium), Browser, or App
./setup.sh --apps

# Reconfigure or install Desktop environment
./setup.sh --desktop

# Reinstall or verify Xiaomi Pad 6 hardware keyboard (Esc & F1-F12)
./setup.sh --keyboard

# Re-authenticate GitHub CLI interactively
./setup.sh --github

# Show all available flags
./setup.sh --help
```

---

## `desktop` CLI Reference (GNOME 48 + Termux:X11 Manager)

```bash
desktop --start              # Start GNOME 48 (or focus Termux:X11 if already running)
desktop --stop               # Stop GNOME 48, X11, and background services cleanly
desktop --reboot             # Restart the desktop session
desktop --status             # Show active status, FPS/Hz, resolution, orientation, and zoom

# Orientation control (live or combined with --start)
desktop --landscape          # Force horizontal (16:10) mode (default)
desktop --vertical           # Force vertical/portrait (10:16) mode
desktop --auto               # Automatic orientation following Android window/sensor
desktop --orientation        # Query current orientation

# Display & performance tuning (live or combined with --start)
desktop --fps 120            # Sync GNOME & physical display refresh rate (30, 48, 50, 60, 90, 120, 144)
desktop --res 100%           # Adaptive resolution for floating/split windows (100%, 75%, 67%, 50%, or WxH)
desktop --zoom 150           # Scale UI/text/cursor independently of resolution (50..300)
desktop --fast               # Disable animations for instant UI response (--normal to re-enable)
```
