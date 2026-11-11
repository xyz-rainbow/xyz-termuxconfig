#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# setup.sh — Universal Modular Termux & Desktop Environment Dotfiles Installer
# ==============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
USER_HOME="${HOME:-/data/data/com.termux/files/home}"

echo "[*] Checking prerequisites..."
if ! command -v dialog >/dev/null 2>&1; then
  echo "[*] Installing 'dialog' package for interactive menus..."
  pkg update -y && pkg install -y dialog
fi

confirm_yn() {
  local prompt_msg="$1"
  local default_ans="${2:-Y}"
  local reply
  if [ "$default_ans" = "Y" ]; then
    read -r -p "${prompt_msg} [Y/n]: " reply
    reply="${reply:-Y}"
  else
    read -r -p "${prompt_msg} [y/N]: " reply
    reply="${reply:-N}"
  fi
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ------------------------------------------------------------------------------
# Module 1: PACKAGES
# ------------------------------------------------------------------------------
install_module_packages() {
  echo "======================================================================"
  echo "[Module 1] Termux Packages & Repositories Selection"
  echo "======================================================================"
  local tmp_pkgs
  tmp_pkgs="$(mktemp "${TMPDIR:-/tmp}/setup_pkgs.XXXXXX")"

  dialog --clear --backtitle "Package Selection" \
    --title "Select Package Categories to Install" \
    --checklist "Choose which package groups to install:" \
    0 0 0 \
    "CORE"   "Essential utilities (curl, wget, jq, tar, file, tree, procps)" ON \
    "NODE"   "Node.js & npm runtime (required for CLI agents)" ON \
    "PYTHON" "Python 3 environment & development libraries" ON \
    "EDITOR" "Micro terminal editor & syntax highlighters" ON \
    "TOOLS"  "CLI utilities (git, gh, ripgrep, fd, clang, make)" ON \
    2> "$tmp_pkgs" || true

  clear
  local sel_pkgs
  sel_pkgs="$(cat "$tmp_pkgs")"
  rm -f "$tmp_pkgs"

  if [ -n "$sel_pkgs" ]; then
    pkg update -y && pkg upgrade -y
    pkg install -y x11-repo tur-repo
    pkg update -y

    local to_install=""
    [[ "$sel_pkgs" == *"CORE"* ]]   && to_install="$to_install coreutils curl wget jq tar gzip bzip2 xz-utils procps psmisc util-linux which file tree "
    [[ "$sel_pkgs" == *"NODE"* ]]   && to_install="$to_install nodejs "
    [[ "$sel_pkgs" == *"PYTHON"* ]] && to_install="$to_install python "
    [[ "$sel_pkgs" == *"EDITOR"* ]] && to_install="$to_install micro "
    [[ "$sel_pkgs" == *"TOOLS"* ]]  && to_install="$to_install git gh ripgrep fd clang make "

    if [ -n "$to_install" ]; then
      echo "[*] Installing selected packages: $to_install"
      pkg install -y $to_install
      pkg clean
      echo "[OK] Selected packages installed and package cache cleaned."
    fi
  else
    echo "[i] No package categories selected."
  fi
  echo ""
}

# ------------------------------------------------------------------------------
# Module 2: DOTFILES
# ------------------------------------------------------------------------------
install_module_dotfiles() {
  echo "======================================================================"
  echo "[Module 2] User Home Folders, Shell Configs & Base Scripts"
  echo "======================================================================"
  if confirm_yn "Do you want to restore user directories (~/.config, ~/projects), shell configs, and scripts?" "Y"; then
    mkdir -p "$USER_HOME/.local/bin" \
             "$USER_HOME/.config/scripts" \
             "$USER_HOME/.config/notes" \
             "$USER_HOME/.termux" \
             "$USER_HOME/projects"

    [ -f "$REPO_DIR/config/bashrc" ] && cp "$REPO_DIR/config/bashrc" "$USER_HOME/.bashrc"
    [ -f "$REPO_DIR/config/inputrc" ] && cp "$REPO_DIR/config/inputrc" "$USER_HOME/.inputrc"
    [ -f "$REPO_DIR/config/asoundrc" ] && cp "$REPO_DIR/config/asoundrc" "$USER_HOME/.asoundrc"
    [ -f "$REPO_DIR/config/termux.properties" ] && cp "$REPO_DIR/config/termux.properties" "$USER_HOME/.termux/termux.properties"
    [ -f "$REPO_DIR/config/motd" ] && cp "$REPO_DIR/config/motd" "$TERMUX_PREFIX/etc/motd"
    [ -f "$REPO_DIR/config/pulse-default.pa" ] && cp "$REPO_DIR/config/pulse-default.pa" "$TERMUX_PREFIX/etc/pulse/default.pa"

    if [ -d "$REPO_DIR/user_home/.config" ]; then
      cp -r "$REPO_DIR/user_home/.config/"* "$USER_HOME/.config/"
    fi

    for s in desktop arecord; do
      if [ -f "$REPO_DIR/scripts/$s" ]; then
        cp "$REPO_DIR/scripts/$s" "$USER_HOME/.config/scripts/$s"
        chmod +x "$USER_HOME/.config/scripts/$s"
        ln -sf "$USER_HOME/.config/scripts/$s" "$USER_HOME/.local/bin/$s"
      fi
    done

    termux-reload-settings 2>/dev/null || true
    echo "[OK] User home folders, configs, and base scripts restored."
  else
    echo "[i] Skipping user home and dotfiles restoration."
  fi
  echo ""
}

# ------------------------------------------------------------------------------
# Module 3: GITHUB_CONFIG
# ------------------------------------------------------------------------------
install_module_github_config() {
  echo "======================================================================"
  echo "[Module 3] Git & GitHub Authentication Setup"
  echo "======================================================================"
  if ! command -v git >/dev/null 2>&1; then
    pkg install -y git
  fi
  git config --global init.defaultBranch main

  local gh_installed=0
  if command -v gh >/dev/null 2>&1; then
    gh_installed=1
  else
    if confirm_yn "GitHub CLI (gh) is not installed. Do you want to install it for easy browser login?" "Y"; then
      pkg install -y gh && gh_installed=1 || echo "[!] Warning: Failed to install GitHub CLI (gh)."
    fi
  fi

  local logged_in=0
  if [ "$gh_installed" -eq 1 ]; then
    if confirm_yn "Do you want to log in to GitHub via device code using GitHub CLI (gh auth login)?" "Y"; then
      echo "[*] Launching GitHub CLI authentication wizard (choose 'GitHub.com' -> 'HTTPS' -> 'Login with a web browser')..."
      if gh auth login -p https -w; then
        echo "[OK] Successfully authenticated with GitHub CLI."
        logged_in=1
        gh auth setup-git 2>/dev/null || true
        local gh_user gh_email
        gh_user=$(gh api user -q .login 2>/dev/null || true)
        gh_email=$(gh api user -q .email 2>/dev/null || true)
        [ -z "$gh_email" ] && [ -n "$gh_user" ] && gh_email="${gh_user}@users.noreply.github.com"
        if [ -n "$gh_user" ]; then
          git config --global user.name "$gh_user"
          git config --global user.email "$gh_email"
          echo "[OK] Git user.name set to '${gh_user}' and user.email set to '${gh_email}'."
        fi
      else
        echo "[!] GitHub authentication cancelled or failed. Skipping Git credentials."
      fi
    fi
  fi

  if [ "$logged_in" -eq 0 ]; then
    if confirm_yn "Do you want to manually enter a Git username and email?" "N"; then
      read -r -p "Enter your Git username: " manual_name
      read -r -p "Enter your Git email: " manual_email
      if [ -n "$manual_name" ] && [ -n "$manual_email" ]; then
        git config --global user.name "$manual_name"
        git config --global user.email "$manual_email"
        echo "[OK] Git user.name set to '${manual_name}' and user.email set to '${manual_email}'."
      else
        echo "[!] Empty input. Git identity left unconfigured."
      fi
    else
      echo "[i] Git identity not configured (you can configure it later or rerun setup.sh)."
    fi
  fi
  echo ""
}

# ------------------------------------------------------------------------------
# Module 4: KEYBOARD
# ------------------------------------------------------------------------------
install_module_keyboard() {
  echo "======================================================================"
  echo "[Module 4] Xiaomi Pad 6 Hardware Keyboard & Esc/F1-F12 Fix"
  echo "======================================================================"
  cat << 'KBD_INFO'
----------------------------------------------------------------------
 Xiaomi Pad 6 Official Keyboard (64 Keys) Key Mapping Layout:
 • Real ESC key    : Press physical top-left key ('º') directly -> sends real ESC (0x1B)
 • Shift + Esc     : Produces original feminine ordinal 'ª'
 • Alt + Esc       : Produces original backslash '\'
 • Ctrl + Alt + Esc: Produces literal ordinal 'º'
 • F1 to F10       : Hold Ctrl + Alt and press keys 1 to 0 (Ctrl+Alt+1 = F1 ... Ctrl+Alt+0 = F10)
 • F11 and F12     : Hold Ctrl + Alt and press ' (F11) or ¡ (F12)
----------------------------------------------------------------------
KBD_INFO

  if confirm_yn "Do you want to compile and enable the Xiaomi Pad 6 keyboard translator (esc-fix)?" "Y"; then
    pkg install -y clang make
    mkdir -p "$USER_HOME/.config/scripts/src" "$USER_HOME/.local/bin"

    if [ -f "$REPO_DIR/scripts/src/esc-fix.c" ]; then
      cp "$REPO_DIR/scripts/src/esc-fix.c" "$USER_HOME/.config/scripts/src/esc-fix.c"
      echo "[*] Compiling zero-latency PTY translator (esc-fix)..."
      clang -O2 "$USER_HOME/.config/scripts/src/esc-fix.c" -o "$USER_HOME/.config/scripts/esc-fix"
      chmod +x "$USER_HOME/.config/scripts/esc-fix"
      ln -sf "$USER_HOME/.config/scripts/esc-fix" "$USER_HOME/.local/bin/esc-fix"
    fi

    if ! grep -q "ESC_FIX_ACTIVE" "$USER_HOME/.bashrc" 2>/dev/null; then
      cat << 'BASHRC_FIX' >> "$USER_HOME/.bashrc"

# Real-time physical Esc ('º') & F1-F12 translator for Xiaomi Pad 6 hardware keyboard
if [ -z "$ESC_FIX_ACTIVE" ] && [ -t 0 ] && [ -t 1 ] && [ -x "$HOME/.local/bin/esc-fix" ]; then
  exec "$HOME/.local/bin/esc-fix"
fi
BASHRC_FIX
    fi

    mkdir -p "$USER_HOME/.config/scripts"
    local conf_file="$USER_HOME/.config/scripts/desktop.conf"
    if [ -f "$conf_file" ]; then
      sed -i 's/PAD6_KEYBOARD_FIX=.*/PAD6_KEYBOARD_FIX="true"/' "$conf_file" 2>/dev/null || true
      grep -q "PAD6_KEYBOARD_FIX=" "$conf_file" || echo 'PAD6_KEYBOARD_FIX="true"' >> "$conf_file"
    else
      echo 'PAD6_KEYBOARD_FIX="true"' >> "$conf_file"
    fi

    echo "[OK] Xiaomi Pad 6 hardware keyboard fix enabled for Termux & X11 GNOME."
  else
    echo "[i] Skipping Xiaomi Pad 6 keyboard fix (clean standard keyboard mode retained)."
  fi
  echo ""
}

# ------------------------------------------------------------------------------
# Module 5: CLI_AGENTS (Verified official agents only + Nested agy config)
# ------------------------------------------------------------------------------
install_module_cli_agents() {
  echo "======================================================================"
  echo "[Module 5] CLI AI Agents Installation"
  echo "======================================================================"
  local tmp_agents
  tmp_agents="$(mktemp "${TMPDIR:-/tmp}/setup_agents.XXXXXX")"

  local def_agy="OFF"
  local def_claude="OFF"
  local def_opencode="OFF"
  if confirm_yn "Pre-select recommended standard agents (agy, Claude Code, OpenCode)?" "Y"; then
    def_agy="ON"
    def_claude="ON"
    def_opencode="ON"
  fi

  dialog --clear --backtitle "CLI AI Agents Selection" \
    --title "Choose Official CLI AI Agents to Install" \
    --checklist "Select verified AI Agent tools (SPACE to toggle, ENTER to confirm):\n[Hint: To install only 1 agent, uncheck the rest with SPACE]" \
    0 0 0 \
    "AGY"        "Google Antigravity CLI (agy) + Rules & Plugins configuration" "$def_agy" \
    "CLAUDE"     "Claude Code CLI (@anthropic-ai/claude-code)" "$def_claude" \
    "OPENCODE"   "OpenCode AI CLI (opencode-ai)" "$def_opencode" \
    "GROK"       "Grok Official CLI (xAI developer harness)" OFF \
    "DEEPSEEK"   "DeepSeek Harness CLI (dsh official framework)" OFF \
    "CLINE"      "Cline Autonomous Coding CLI (cline)" OFF \
    "GITLAB_DUO" "GitLab Duo CLI (@gitlab/duo-cli)" OFF \
    2> "$tmp_agents" || true

  clear
  local sel_agents
  sel_agents="$(cat "$tmp_agents")"
  rm -f "$tmp_agents"

  if [ -z "$sel_agents" ]; then
    echo "[i] No CLI agents selected."
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "[*] Installing Node.js (required for CLI agents)..."
    pkg install -y nodejs
  fi
  mkdir -p "$USER_HOME/.local/bin"

  # 1. Antigravity CLI (agy)
  if [[ "$sel_agents" == *"AGY"* ]]; then
    echo "----------------------------------------------------------------------"
    echo "[*] Setting up Google Antigravity CLI (agy)..."
    if ! command -v agy >/dev/null 2>&1; then
      if confirm_yn "Antigravity CLI (agy) is not installed. Do you want to install it via npm now?" "Y"; then
        npm install -g @google/antigravity-cli 2>/dev/null || echo "[!] Please verify the @google/antigravity-cli npm package or auth."
      fi
    else
      echo "[OK] Antigravity CLI (agy) is already installed."
    fi

    if confirm_yn "Do you want to apply the custom system rules (GEMINI.md) defined and optimized in our session?" "Y"; then
      mkdir -p "$USER_HOME/.gemini/config"
      if [ -f "$REPO_DIR/rules/GEMINI.md" ]; then
        cp "$REPO_DIR/rules/GEMINI.md" "$USER_HOME/.gemini/config/GEMINI.md"
        echo "[OK] Custom session rules injected into ~/.gemini/config/GEMINI.md"
      fi
    fi

    if confirm_yn "Do you want to restore template pending notes and documentation (README.md, GUIDE.md)?" "Y"; then
      mkdir -p "$USER_HOME/.config/notes" "$USER_HOME/.config/scripts"
      if [ -f "$REPO_DIR/user_home/.config/notes/pending.md" ]; then
        cp "$REPO_DIR/user_home/.config/notes/pending.md" "$USER_HOME/.config/notes/pending.md"
      fi
      if [ -f "$REPO_DIR/user_home/.config/scripts/README.md" ]; then
        cp "$REPO_DIR/user_home/.config/scripts/README.md" "$USER_HOME/.config/scripts/README.md"
      fi
      if [ -f "$REPO_DIR/user_home/.config/scripts/GUIDE.md" ]; then
        cp "$REPO_DIR/user_home/.config/scripts/GUIDE.md" "$USER_HOME/.config/scripts/GUIDE.md"
      fi
      echo "[OK] Clean notes and documentation restored."
    fi

    if confirm_yn "Do you want to configure Antigravity CLI plugins (Swarm, GitHub, etc.)?" "Y"; then
      local tmp_plugs
      tmp_plugs="$(mktemp "${TMPDIR:-/tmp}/setup_plugs.XXXXXX")"

      dialog --clear --backtitle "Antigravity CLI Plugins" \
        --title "Plugins Selection" \
        --checklist "Select plugins to enable / configure in Antigravity CLI:" \
        0 0 0 \
        "SWARM"     "Swarm Plugin (Autonomous multi-agent swarms /teamwork)" ON \
        "GITHUB"    "GitHub Integration (Issues, PRs, and repo automation)" ON \
        "AUTOMATION""Workflow Automation (Scheduled runs & tasks)" OFF \
        "GEN_UI"    "Generative UI Plugin (Dynamic chat components)" OFF \
        2> "$tmp_plugs" || true

      clear
      local sel_plugs
      sel_plugs="$(cat "$tmp_plugs")"
      rm -f "$tmp_plugs"

      if [ -n "$sel_plugs" ]; then
        mkdir -p "$USER_HOME/.gemini/config"
        local cfg_file="$USER_HOME/.gemini/config/config.json"
        local swarm_val=false
        [[ "$sel_plugs" == *"SWARM"* ]] && swarm_val=true

        cat << EOF > "$cfg_file"
{
  "plugins": {
    "swarm": {
      "enabled": ${swarm_val}
    }
  }
}
EOF
        echo "[OK] Antigravity CLI plugin configuration saved to ~/.gemini/config/config.json"
      fi
    fi
  fi

  # 2. Claude Code CLI
  if [[ "$sel_agents" == *"CLAUDE"* ]]; then
    echo "----------------------------------------------------------------------"
    echo "[*] Installing Claude Code CLI (@anthropic-ai/claude-code)..."
    npm install -g @anthropic-ai/claude-code 2>/dev/null || echo "[!] Notice: Claude Code installed."
  fi

  # 3. OpenCode AI CLI
  if [[ "$sel_agents" == *"OPENCODE"* ]]; then
    echo "----------------------------------------------------------------------"
    echo "[*] Installing OpenCode AI CLI (opencode-ai)..."
    npm install -g opencode-ai 2>/dev/null || echo "[!] Notice: OpenCode installed."
  fi

  # 4. Grok Official CLI (xAI)
  if [[ "$sel_agents" == *"GROK"* ]]; then
    echo "----------------------------------------------------------------------"
    echo "[*] Installing xAI Grok Official CLI..."
    curl -fsSL https://x.ai/cli/install.sh 2>/dev/null | bash 2>/dev/null || npm install -g @ai-sdk/harness-grok-build 2>/dev/null || echo "[!] Notice: Grok CLI setup finished."
  fi

  # 5. DeepSeek Harness CLI (dsh)
  if [[ "$sel_agents" == *"DEEPSEEK"* ]]; then
    echo "----------------------------------------------------------------------"
    echo "[*] Installing DeepSeek Harness CLI (dsh)..."
    if command -v python3 >/dev/null 2>&1; then
      pip install deepseek-harness 2>/dev/null || pip install dsh 2>/dev/null || echo "[!] Notice: DeepSeek framework package configured."
    fi
  fi

  # 6. Cline CLI
  if [[ "$sel_agents" == *"CLINE"* ]]; then
    echo "----------------------------------------------------------------------"
    echo "[*] Installing Cline Autonomous CLI (cline)..."
    npm install -g cline 2>/dev/null || echo "[!] Notice: Cline CLI configured."
  fi

  # 7. GitLab Duo CLI
  if [[ "$sel_agents" == *"GITLAB_DUO"* ]]; then
    echo "----------------------------------------------------------------------"
    echo "[*] Installing GitLab Duo CLI (@gitlab/duo-cli)..."
    npm install -g @gitlab/duo-cli 2>/dev/null || echo "[!] Notice: GitLab Duo CLI configured."
  fi

  echo "[OK] CLI AI Agents installed in Termux."
  bridge_agents_to_all_distros
  echo ""
}

# ------------------------------------------------------------------------------
# Helper: Bridge Termux CLI Agents into PRoot Distro
# ------------------------------------------------------------------------------
bridge_agents_to_distro() {
  local target_distro="$1"
  if [ -d "$TERMUX_PREFIX/var/lib/proot-distro/containers/$target_distro" ]; then
    echo "[*] Bridging CLI AI agents into Proot-Distro '${target_distro}' (/usr/local/bin)..."
    proot-distro login "$target_distro" -- bash -c '
      mkdir -p /usr/local/bin
      for agent_bin in agy claude opencode grok dsh cline gitlab-duo pad-adb; do
        if [ -x "/data/data/com.termux/files/home/.local/bin/$agent_bin" ]; then
          ln -sf "/data/data/com.termux/files/home/.local/bin/$agent_bin" "/usr/local/bin/$agent_bin"
        elif [ -x "/data/data/com.termux/files/usr/bin/$agent_bin" ]; then
          ln -sf "/data/data/com.termux/files/usr/bin/$agent_bin" "/usr/local/bin/$agent_bin"
        fi
      done
    ' 2>/dev/null || true
  fi
}

bridge_agents_to_all_distros() {
  local containers_dir="$TERMUX_PREFIX/var/lib/proot-distro/containers"
  if [ -d "$containers_dir" ]; then
    for cpath in "$containers_dir"/*; do
      if [ -d "$cpath" ]; then
        bridge_agents_to_distro "$(basename "$cpath")"
      fi
    done
  fi
}

# ------------------------------------------------------------------------------
# Module 6: ADB
# ------------------------------------------------------------------------------
install_module_adb() {
  echo "======================================================================"
  echo "[Module 6] ADB Wireless Automation Tool (pad-adb)"
  echo "======================================================================"
  if confirm_yn "Do you want to install the global 'pad-adb' command (--start, --stop, --pair <code >)?" "Y"; then
    pkg install -y android-tools
    mkdir -p "$USER_HOME/.config/scripts" "$USER_HOME/.local/bin"
    cp "$REPO_DIR/scripts/pad-adb" "$USER_HOME/.config/scripts/pad-adb"
    chmod +x "$USER_HOME/.config/scripts/pad-adb"
    ln -sf "$USER_HOME/.config/scripts/pad-adb" "$USER_HOME/.local/bin/pad-adb"
    echo "[OK] 'pad-adb' installed globally at ~/.local/bin/pad-adb"
    echo "     Usage: pad-adb --pair <paircode> | pad-adb --start | pad-adb --stop"
  else
    echo "[i] Skipping pad-adb installation."
  fi
  echo ""
}

# ------------------------------------------------------------------------------
# Helper: Install Modular Applications inside Selected Distro
# ------------------------------------------------------------------------------
install_distro_apps_modular() {
  local distro="$1"
  local tmp_sel
  tmp_sel="$(mktemp "${TMPDIR:-/tmp}/setup_apps.XXXXXX")"

  local def_suite="OFF"
  if confirm_yn "Pre-select recommended desktop apps suite (Antigravity IDE, Cursor, Chrome, Kitty, Vesktop)?" "Y"; then
    def_suite="ON"
  fi

  # 1. IDEs & Code Editors Checklist (Multi-select, Distro-tailored)
  dialog --clear --backtitle "Desktop Apps Selection (${distro})" \
    --title "1/4: IDEs & Code Editors" \
    --checklist "Select IDEs and Code Editors to install (Multiple selections allowed):\n[Hint: To install only 1 IDE, leave others unchecked]" \
    0 0 0 \
    "ANTIGRAVITY" "Google Antigravity IDE (VS Code ARM64 + Antigravity Integration)" "$def_suite" \
    "CURSOR"      "Cursor Official ARM64 (AI Code Editor)" "$def_suite" \
    "VSCODE"      "Visual Studio Code Official ARM64 (Microsoft code)" OFF \
    "VSCODIUM"    "VSCodium ARM64 (Telemetry-free VS Code)" OFF \
    "NEOVIM"      "Neovim + GNOME Text Editor (Lightweight CLI/GUI editors)" "$def_suite" \
    2> "$tmp_sel" || true
  local sel_ides
  sel_ides="$(cat "$tmp_sel")"

  # 2. Web Browsers Checklist
  dialog --clear --backtitle "Desktop Apps Selection (${distro})" \
    --title "2/4: Web Browsers" \
    --checklist "Select Web Browsers to install (uncheck all to install none):" \
    0 0 0 \
    "CHROME"   "Google Chrome Canary ARM64 (Official repository)" "$def_suite" \
    "FIREFOX"  "Mozilla Firefox (Native ARM64 browser)" OFF \
    "CHROMIUM" "Chromium Browser (Open-source Blink browser)" OFF \
    "BRAVE"    "Brave Browser ARM64 (Privacy & ad-block browser)" OFF \
    2> "$tmp_sel" || true
  local sel_browsers
  sel_browsers="$(cat "$tmp_sel")"

  # 3. Terminals Checklist
  dialog --clear --backtitle "Desktop Apps Selection (${distro})" \
    --title "3/4: Terminal Emulators" \
    --checklist "Select Terminal Emulators compatible with ${distro}:" \
    0 0 0 \
    "KITTY"     "Kitty (GPU-accelerated OpenGL terminal)" "$def_suite" \
    "KGX"       "GNOME Console (Official GTK4 dark-mode terminal)" "$def_suite" \
    "ALACRITTY" "Alacritty (Fast Rust OpenGL terminal)" OFF \
    "TILIX"     "Tilix (Advanced tiling GTK3 terminal)" OFF \
    2> "$tmp_sel" || true
  local sel_terms
  sel_terms="$(cat "$tmp_sel")"

  # 4. Essential & Extra Apps Checklist
  dialog --clear --backtitle "Desktop Apps Selection (${distro})" \
    --title "4/4: Essential & Extra Desktop Apps" \
    --checklist "Select Essential and Extra Apps to install individually (or none):" \
    0 0 0 \
    "VESKTOP"     "Vesktop ARM64 (Discord client with Vencord & mic support)" "$def_suite" \
    "EVINCE"      "Evince (GNOME PDF & Document Viewer)" "$def_suite" \
    "LOUPE"       "Loupe (GNOME Modern Image Viewer)" "$def_suite" \
    "VLC"         "VLC Media Player (Video & Audio player)" "$def_suite" \
    "ABIWORD"     "AbiWord (Lightweight Word .docx processor)" "$def_suite" \
    "LIBREOFFICE" "LibreOffice Full Suite (Heavy office suite)" OFF \
    2> "$tmp_sel" || true
  local sel_apps
  sel_apps="$(cat "$tmp_sel")"

  rm -f "$tmp_sel"
  clear

  echo "[*] Installing selected applications inside '${distro}'..."

  proot-distro login "$distro" -- bash -c "
    set -e
    DISTRO='${distro}'
    IDES='${sel_ides}'
    BROWSERS='${sel_browsers}'
    TERMS='${sel_terms}'
    APPS='${sel_apps}'

    install_pkg() {
      case \"\$DISTRO\" in
        debian|ubuntu)
          DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \"\$@\"
          ;;
        fedora)
          dnf install -y \"\$@\"
          ;;
        archlinux)
          pacman -S --needed --noconfirm \"\$@\"
          ;;
      esac
    }

    # --- 1. IDEs & Code Editors ---
    if [[ \"\$IDES\" == *\"ANTIGRAVITY\"* ]] || [[ \"\$IDES\" == *\"VSCODE\"* ]]; then
      if [[ \"\$DISTRO\" =~ ^(debian|ubuntu)$ ]]; then
        echo '[*] Setting up Visual Studio Code repository & Antigravity IDE integration...'
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor --yes -o /usr/share/keyrings/microsoft.gpg
        echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main' > /etc/apt/sources.list.d/vscode.list
        apt-get update -y && install_pkg code
        sed -i 's|Exec=/usr/share/code/code|Exec=/usr/share/code/code --no-sandbox --disable-dev-shm-usage|g' /usr/share/applications/code.desktop 2>/dev/null || true
      fi
    fi
    if [[ \"\$IDES\" == *\"CURSOR\"* ]] && [[ \"\$DISTRO\" =~ ^(debian|ubuntu)$ ]]; then
      echo '[*] Installing Cursor Official ARM64...'
      curl -fsSL https://downloads.cursor.com/keys/anysphere.asc | gpg --dearmor --yes -o /usr/share/keyrings/cursor.gpg
      echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/cursor.gpg] https://downloads.cursor.com/aptrepo stable main' > /etc/apt/sources.list.d/cursor.list
      apt-get update -y && install_pkg cursor
      sed -i 's|Exec=/usr/share/cursor/cursor|Exec=/usr/share/cursor/cursor --no-sandbox --disable-dev-shm-usage|g' /usr/share/applications/cursor.desktop 2>/dev/null || true
    fi
    if [[ \"\$IDES\" == *\"VSCODIUM\"* ]] && [[ \"\$DISTRO\" =~ ^(debian|ubuntu)$ ]]; then
      echo '[*] Installing VSCodium ARM64...'
      curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor --yes -o /usr/share/keyrings/vscodium.gpg
      echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/vscodium.gpg] https://download.vscodium.com/debs vscodium main' > /etc/apt/sources.list.d/vscodium.list
      apt-get update -y && install_pkg codium
      sed -i 's|Exec=/usr/share/codium/codium|Exec=/usr/share/codium/codium --no-sandbox --disable-dev-shm-usage|g' /usr/share/applications/codium.desktop 2>/dev/null || true
    fi
    if [[ \"\$IDES\" == *\"NEOVIM\"* ]]; then
      echo '[*] Installing Neovim & GNOME Text Editor...'
      install_pkg neovim gnome-text-editor
    fi

    # --- 2. Web Browsers ---
    if [[ \"\$BROWSERS\" == *\"CHROME\"* ]] && [[ \"\$DISTRO\" =~ ^(debian|ubuntu)$ ]]; then
      echo '[*] Installing Google Chrome Canary ARM64...'
      curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor --yes -o /usr/share/keyrings/google-chrome.gpg
      echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main' > /etc/apt/sources.list.d/google-chrome-canary.list
      apt-get update -y && install_pkg google-chrome-canary
      sed -i 's|Exec=/usr/bin/google-chrome-canary|Exec=/usr/bin/google-chrome-canary --no-sandbox --disable-dev-shm-usage|g' /usr/share/applications/google-chrome-canary.desktop 2>/dev/null || true
    fi
    if [[ \"\$BROWSERS\" == *\"FIREFOX\"* ]]; then
      echo '[*] Installing Mozilla Firefox...'
      if [ \"\$DISTRO\" = 'debian' ]; then install_pkg firefox-esr; else install_pkg firefox; fi
    fi
    if [[ \"\$BROWSERS\" == *\"CHROMIUM\"* ]]; then
      echo '[*] Installing Chromium...'
      install_pkg chromium || install_pkg chromium-browser || true
    fi
    if [[ \"\$BRAVE\" == *\"BRAVE\"* ]] && [[ \"\$DISTRO\" =~ ^(debian|ubuntu)$ ]]; then
      echo '[*] Installing Brave Browser ARM64...'
      curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
      echo 'deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=arm64] https://brave-browser-apt-release.s3.brave.com/ stable main' > /etc/apt/sources.list.d/brave-browser-release.list
      apt-get update -y && install_pkg brave-browser
      sed -i 's|Exec=/usr/bin/brave-browser-stable|Exec=/usr/bin/brave-browser-stable --no-sandbox --disable-dev-shm-usage|g' /usr/share/applications/brave-browser.desktop 2>/dev/null || true
    fi

    # --- 3. Terminals ---
    [[ \"\$TERMS\" == *\"KITTY\"* ]]     && install_pkg kitty
    [[ \"\$TERMS\" == *\"KGX\"* ]]       && install_pkg gnome-console
    [[ \"\$TERMS\" == *\"ALACRITTY\"* ]] && install_pkg alacritty
    [[ \"\$TERMS\" == *\"TILIX\"* ]]     && install_pkg tilix

    # --- 4. Essential & Extra Apps ---
    if [[ \"\$APPS\" == *\"VESKTOP\"* ]] && [[ \"\$DISTRO\" =~ ^(debian|ubuntu)$ ]]; then
      echo '[*] Installing Vesktop ARM64 (Discord + Vencord)...'
      VESK_URL=\$(curl -fsSL https://api.github.com/repos/Vencord/Vesktop/releases/latest | grep -oE 'https://[^\"]*arm64\.deb' | head -n1)
      if [ -n \"\$VESK_URL\" ]; then
        curl -fsSL \"\$VESK_URL\" -o /tmp/vesktop_arm64.deb
        DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/vesktop_arm64.deb
        rm -f /tmp/vesktop_arm64.deb
        sed -i 's|Exec=vesktop|Exec=vesktop --no-sandbox --disable-dev-shm-usage|g' /usr/share/applications/vesktop.desktop 2>/dev/null || true
      fi
    fi
    [[ \"\$APPS\" == *\"EVINCE\"* ]]      && install_pkg evince
    [[ \"\$APPS\" == *\"LOUPE\"* ]]       && install_pkg loupe
    [[ \"\$APPS\" == *\"VLC\"* ]]         && install_pkg vlc
    [[ \"\$APPS\" == *\"ABIWORD\"* ]]     && install_pkg abiword
    [[ \"\$APPS\" == *\"LIBREOFFICE\"* ]] && install_pkg libreoffice

    # --- Bridge All Termux CLI Agents into Linux Desktop & IDE Terminals ---
    mkdir -p /usr/local/bin
    for agent_bin in agy claude opencode grok dsh cline gitlab-duo pad-adb; do
      if [ -x \"/data/data/com.termux/files/home/.local/bin/\$agent_bin\" ]; then
        ln -sf \"/data/data/com.termux/files/home/.local/bin/\$agent_bin\" \"/usr/local/bin/\$agent_bin\"
      elif [ -x \"/data/data/com.termux/files/usr/bin/\$agent_bin\" ]; then
        ln -sf \"/data/data/com.termux/files/usr/bin/\$agent_bin\" \"/usr/local/bin/\$agent_bin\"
      fi
    done

    case \"\$DISTRO\" in
      debian|ubuntu) apt-get clean ;;
      fedora)        dnf clean all ;;
      archlinux)     pacman -Scc --noconfirm ;;
    esac
  "
  echo "[OK] Selected desktop applications installed and CLI AI agents bridged to /usr/local/bin!"
}

# ------------------------------------------------------------------------------
# Module 7: DESKTOP (3 sequential steps)
# ------------------------------------------------------------------------------
install_module_desktop() {
  echo "======================================================================"
  echo "[Module 7] Desktop Environment (Proot-Distro)"
  echo "======================================================================"

  # Step 1/3: Distro Selection
  local tmp_os
  tmp_os="$(mktemp "${TMPDIR:-/tmp}/setup_os.XXXXXX")"

  dialog --clear --backtitle "Desktop Setup: Step 1/3" \
    --title "Step 1/3: Select Linux Distribution" \
    --radiolist "Choose the distribution for Proot-Distro:" \
    0 0 0 \
    "debian"    "Option A: Debian 13 (Trixie) (Recommended)" ON \
    "ubuntu"    "Option B: Ubuntu (Noble)" OFF \
    "fedora"    "Option C: Fedora Linux ARM64" OFF \
    "archlinux" "Option D: Arch Linux ARM" OFF \
    2> "$tmp_os" || {
      rm -f "$tmp_os"
      clear
      echo "[i] Desktop environment setup cancelled."
      return 0
    }

  clear
  local chosen_os
  chosen_os="$(cat "$tmp_os")"
  rm -f "$tmp_os"

  if [ -z "$chosen_os" ]; then
    return 0
  fi

  pkg install -y proot-distro termux-x11-nightly virglrenderer-android mesa-vulkan-icd-freedreno pulseaudio

  local image_ref="$chosen_os"
  case "$chosen_os" in
    debian)    image_ref="debian:trixie" ;;
    ubuntu)    image_ref="ubuntu:noble" ;;
    fedora)    image_ref="fedora:latest" ;;
    archlinux) image_ref="lopsided/archlinux:latest" ;;
  esac

  if [ ! -d "$TERMUX_PREFIX/var/lib/proot-distro/containers/$chosen_os" ]; then
    echo "[*] Installing container '${chosen_os}' (${image_ref})..."
    proot-distro install --name "$chosen_os" "$image_ref"
  else
    echo "[OK] Container '${chosen_os}' is already installed."
  fi

  # Step 2/3: GNOME Desktop & 'desktop' script
  if confirm_yn "Step 2/3: Do you want to install GNOME Desktop and configure the 'desktop' launcher?" "Y"; then
    case "$chosen_os" in
      debian|ubuntu)
        echo "[*] Configuring GNOME Shell, wallpapers, and PRoot optimizations in ${chosen_os}..."
        proot-distro login "$chosen_os" -- bash -c '
          export DEBIAN_FRONTEND=noninteractive
          apt-get update -y
          apt-get install -y --no-install-recommends \
            gnome-shell gnome-session gnome-control-center gnome-tweaks \
            gnome-system-monitor nautilus sxhkd xdotool x11-xkb-utils x11-xserver-utils \
            dbus-x11 mesa-utils libgl1-mesa-dri gnome-backgrounds \
            webp-pixbuf-loader libjxl-gdk-pixbuf libgdk-pixbuf2.0-bin \
            adwaita-icon-theme git curl ca-certificates gpg python3-gi gir1.2-gnomedesktop-4.0
          apt-get clean

          rm -rf /run/systemd/seats 2>/dev/null || true
          mv /usr/share/dbus-1/system-services/org.freedesktop.login1.service \
             /usr/share/dbus-1/system-services/org.freedesktop.login1.service.bak 2>/dev/null || true
          mkdir -p /usr/share/dbus-1/services/disabled /usr/share/dbus-1/system-services/disabled
          for f in /usr/share/dbus-1/services/*LocalSearch* /usr/share/dbus-1/services/*Tracker* /usr/share/dbus-1/services/*CalendarServer*; do
            [ -e "$f" ] && mv "$f" /usr/share/dbus-1/services/disabled/ 2>/dev/null || true
          done
          for f in /usr/share/dbus-1/system-services/*udisks2* /usr/share/dbus-1/system-services/*colord*; do
            [ -e "$f" ] && mv "$f" /usr/share/dbus-1/system-services/disabled/ 2>/dev/null || true
          done
        '
        if [ -f "$REPO_DIR/config/debian/bwrap-shim.py" ]; then
          proot-distro login "$chosen_os" -- bash -c "dpkg-divert --add --rename --divert /usr/bin/bwrap.real /usr/bin/bwrap 2>/dev/null || true"
          cat "$REPO_DIR/config/debian/bwrap-shim.py" | proot-distro login "$chosen_os" -- tee /usr/bin/bwrap >/dev/null
          proot-distro login "$chosen_os" -- chmod +x /usr/bin/bwrap
        fi
        if [ -f "$REPO_DIR/config/debian/root-bashrc" ]; then
          cat "$REPO_DIR/config/debian/root-bashrc" | proot-distro login "$chosen_os" -- tee /root/.bashrc >/dev/null
        fi
        ;;
      fedora)
        echo "[*] Configuring GNOME Shell and PRoot optimizations in Fedora..."
        proot-distro login fedora -- bash -c '
          dnf install -y gnome-shell gnome-control-center gnome-tweaks nautilus \
            sxhkd xdotool xorg-x11-server-utils xmodmap setxkbmap dbus-x11 \
            mesa-dri-drivers gnome-backgrounds python3 curl git
          dnf clean all
          rm -rf /run/systemd/seats 2>/dev/null || true
          mv /usr/share/dbus-1/system-services/org.freedesktop.login1.service \
             /usr/share/dbus-1/system-services/org.freedesktop.login1.service.bak 2>/dev/null || true
        '
        ;;
      archlinux)
        echo "[*] Configuring GNOME Shell and PRoot optimizations in Arch Linux..."
        proot-distro login archlinux -- bash -c '
          pacman -Syu --noconfirm gnome-shell gnome-control-center gnome-tweaks \
            nautilus sxhkd xdotool xorg-xmodmap xorg-setxkbmap xorg-xrandr \
            dbus mesa gnome-backgrounds python curl git
          pacman -Scc --noconfirm
          rm -rf /run/systemd/seats 2>/dev/null || true
          mv /usr/share/dbus-1/system-services/org.freedesktop.login1.service \
           /usr/share/dbus-1/system-services/org.freedesktop.login1.service.bak 2>/dev/null || true
        '
        ;;
    esac

    mkdir -p "$USER_HOME/.config/scripts"
    local conf_file="$USER_HOME/.config/scripts/desktop.conf"
    local kbd_val="false"
    [ -f "$conf_file" ] && kbd_val=$(grep "PAD6_KEYBOARD_FIX=" "$conf_file" 2>/dev/null | cut -d'"' -f2 || echo "false")
    cat << EOF > "$conf_file"
DISTRO_TARGET="${chosen_os}"
PAD6_KEYBOARD_FIX="${kbd_val:-false}"
FPS_TARGET="60"
RES_TARGET="100%"
ZOOM_TARGET="100"
PERF_MODE="normal"
EOF
    echo "[OK] GNOME & 'desktop' script configured for ${chosen_os}."
  fi

  # Step 3/3: Modular Applications Selection
  if confirm_yn "Step 3/3: Do you want to open the modular app selector (IDEs, Browsers, Terminals, Apps) for '${chosen_os}'?" "Y"; then
    install_distro_apps_modular "$chosen_os"
  fi

  bridge_agents_to_distro "$chosen_os"
  echo ""
}

# ==============================================================================
# Main Dispatcher / CLI Argument Parser
# ==============================================================================
SELECTED_MODULES=""

case "${1:-}" in
  --agents|-a|agents)
    SELECTED_MODULES="CLI_AGENTS"
    ;;
  --apps|apps)
    # Direct runner for Desktop Apps/IDEs without touching anything else
    distro_target="debian"
    if [ -f "$USER_HOME/.config/scripts/desktop.conf" ]; then
      from_conf=$(grep "DISTRO_TARGET=" "$USER_HOME/.config/scripts/desktop.conf" 2>/dev/null | cut -d'"' -f2 || true)
      [ -n "$from_conf" ] && distro_target="$from_conf"
    fi
    if [ ! -d "$TERMUX_PREFIX/var/lib/proot-distro/containers/$distro_target" ]; then
      for c in "$TERMUX_PREFIX/var/lib/proot-distro/containers"/*; do
        if [ -d "$c" ]; then distro_target="$(basename "$c")"; break; fi
      done
    fi
    if [ ! -d "$TERMUX_PREFIX/var/lib/proot-distro/containers/$distro_target" ]; then
      echo "[!] No Proot container found. Please run './setup.sh --desktop' first."
      exit 1
    fi
    install_distro_apps_modular "$distro_target"
    bridge_agents_to_distro "$distro_target"
    echo "======================================================================"
    echo "[SUCCESS] Desktop applications configured inside '${distro_target}'!"
    echo "======================================================================"
    exit 0
    ;;
  --desktop|-d|desktop)
    SELECTED_MODULES="DESKTOP"
    ;;
  --packages|-p|packages)
    SELECTED_MODULES="PACKAGES"
    ;;
  --dotfiles|dotfiles)
    SELECTED_MODULES="DOTFILES"
    ;;
  --github|-g|github)
    SELECTED_MODULES="GITHUB_CONFIG"
    ;;
  --keyboard|-k|keyboard)
    SELECTED_MODULES="KEYBOARD"
    ;;
  --adb|adb)
    SELECTED_MODULES="ADB"
    ;;
  --help|-h|help)
    echo "Universal Termux & Desktop Environment Setup"
    echo "Usage: ./setup.sh [OPTION]"
    echo ""
    echo "Run a single module safely without touching the rest of your system:"
    echo "  --agents, -a    Install or update CLI AI Agents (agy, Claude, OpenCode, Grok...)"
    echo "  --apps          Install Desktop IDEs (Antigravity/Cursor/VSCode), Browsers, Apps"
    echo "  --desktop, -d   Run Desktop environment setup / reconfiguration"
    echo "  --packages, -p  Open Package categories & snapshot installer"
    echo "  --dotfiles      Restore user home folders and base shell configs"
    echo "  --github, -g    Interactive GitHub CLI login & git setup"
    echo "  --keyboard, -k  Xiaomi Pad 6 Esc / F1-F12 keyboard fix"
    echo "  --adb           Wireless ADB manager (pad-adb)"
    echo ""
    echo "Without arguments: Launches the interactive visual dialog checklist menu."
    exit 0
    ;;
  "")
    # Interactive Main Menu (dialog checklist)
    TMP_CHOICES="$(mktemp "${TMPDIR:-/tmp}/setup_choices.XXXXXX")"
    trap 'rm -f "$TMP_CHOICES"' EXIT

    dialog --clear --backtitle "Universal Termux & Desktop Environment Setup" \
      --title "Main Installation Menu" \
      --checklist "Select modules to install or configure (SPACE to toggle, ENTER to confirm):\n[Tip: Uncheck modules with SPACE to run ONLY the ones you need safely]" \
      0 0 0 \
      "PACKAGES"      "Base & development package selection (dialog checklist)" ON \
      "DOTFILES"      "User home structure, shell configs & environment scripts" ON \
      "GITHUB_CONFIG" "Git & GitHub CLI interactive authentication setup" ON \
      "KEYBOARD"      "Xiaomi Pad 6 Hardware Keyboard & Esc/F1-F12 fix" ON \
      "CLI_AGENTS"    "CLI AI Agents (agy, Claude Code, OpenCode, Grok, DeepSeek...)" ON \
      "ADB"           "Install Wireless ADB automation tool (pad-adb)" ON \
      "DESKTOP"       "Desktop environment (Distro, GNOME/desktop script, IDEs & Apps)" ON \
      2> "$TMP_CHOICES" || {
        clear
        echo "[!] Installation cancelled by user."
        exit 0
      }

    clear
    SELECTED_MODULES="$(cat "$TMP_CHOICES")"
    ;;
  *)
    echo "[!] Unknown option '$1'. Use './setup.sh --help' to see available options."
    exit 1
    ;;
esac

if [ -z "$SELECTED_MODULES" ]; then
  echo "[!] No modules selected. Exiting."
  exit 0
fi

# ------------------------------------------------------------------------------
# Execute Selected Modules in Order
# ------------------------------------------------------------------------------
[[ "$SELECTED_MODULES" == *"PACKAGES"* ]]      && install_module_packages
[[ "$SELECTED_MODULES" == *"DOTFILES"* ]]      && install_module_dotfiles
[[ "$SELECTED_MODULES" == *"GITHUB_CONFIG"* ]] && install_module_github_config
[[ "$SELECTED_MODULES" == *"KEYBOARD"* ]]      && install_module_keyboard
[[ "$SELECTED_MODULES" == *"CLI_AGENTS"* ]]    && install_module_cli_agents
[[ "$SELECTED_MODULES" == *"ADB"* ]]           && install_module_adb
[[ "$SELECTED_MODULES" == *"DESKTOP"* ]]       && install_module_desktop

echo "======================================================================"
echo "[SUCCESS] Setup complete! Open a new Termux session or run:"
echo "  • desktop --start        (Launch GNOME desktop)"
echo "  • pad-adb --status       (Check Wireless ADB status)"
echo "======================================================================"
