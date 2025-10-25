#!/bin/bash

echo "🧪 Starting WezTerm setup for Arch Linux..."

# STEP 1: Install WezTerm
echo "📦 Installing WezTerm from official Arch repo..."
sudo pacman -Sy --noconfirm wezterm

# STEP 2: Install FiraCode Nerd Font (for ligatures + icons)
echo "🎨 Installing FiraCode Nerd Font..."
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
unzip -o FiraCode.zip > /dev/null
fc-cache -fv > /dev/null
cd ~

# STEP 3: Create WezTerm config directory
echo "📁 Creating ~/.config/wezterm directory..."
mkdir -p ~/.config/wezterm

# STEP 4: Write WezTerm config (with custom theme and full setup)
echo "🛠️ Generating wezterm.lua with Neon Contour Violet theme..."
cat > ~/.config/wezterm/wezterm.lua << 'EOF'
local wezterm = require 'wezterm'

-- 🎨 Custom Neon Contour Violet + Orange Theme
local neon_violet = wezterm.color.get_builtin_schemes()["Builtin Dark"]
neon_violet.foreground = "#D9BFFF"
neon_violet.background = "#0C0C1A"
neon_violet.cursor_bg = "#FF6F91"
neon_violet.cursor_fg = "#0C0C1A"
neon_violet.cursor_border = "#FF6F91"

neon_violet.ansi = {
  "#1A1A2E", "#FF5F6D", "#42FFB3", "#FFA54F",
  "#B682FF", "#FF69B4", "#00FFFF", "#EDEDED",
}

neon_violet.brights = {
  "#4E4E6A", "#FF7C91", "#79FFD6", "#FFD17A",
  "#D3A3FF", "#FF87B8", "#A0FFFF", "#FFFFFF",
}

wezterm.on("update-right-status", function(window, pane)
  window:set_right_status(wezterm.format({
    {Foreground={Color="#FFA54F"}},
    {Text=" DevOps Ready 🚀 "}
  }))
end)

return {
  color_schemes = {
    ["Neon Contour Violet"] = neon_violet
  },
  color_scheme = "Neon Contour Violet",

  -- 🔤 Font settings
  font = wezterm.font_with_fallback {
    "FiraCode Nerd Font",
    "JetBrainsMono Nerd Font",
    "Hack Nerd Font"
  },
  font_size = 11.5,
  line_height = 1.0,

  -- 💠 Appearance
  window_background_opacity = 0.90,
  macos_window_background_blur = 20, -- Blur in KDE via KWin
  window_decorations = "RESIZE",
  window_padding = { left = 8, right = 8, top = 4, bottom = 4 },

  -- 🐭 Mouse and clipboard
  enable_scroll_bar = false,
  hide_tab_bar_if_only_one_tab = true,
  use_fancy_tab_bar = false,
  mouse_bindings = {
    {
      event={Up={streak=1, button="Right"}},
      mods="NONE",
      action=wezterm.action{PasteFrom="Clipboard"},
    },
  },

  -- 🔑 Keybindings: ALT + hjkl navigation, splits
  keys = {
    {key="h", mods="ALT", action=wezterm.action{ActivatePaneDirection="Left"}},
    {key="l", mods="ALT", action=wezterm.action{ActivatePaneDirection="Right"}},
    {key="k", mods="ALT", action=wezterm.action{ActivatePaneDirection="Up"}},
    {key="j", mods="ALT", action=wezterm.action{ActivatePaneDirection="Down"}},

    {key="d", mods="ALT", action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
    {key="s", mods="ALT", action=wezterm.action{SplitVertical={domain="CurrentPaneDomain"}}},

    {key="Paste", mods="NONE", action=wezterm.action.PasteFrom("Clipboard")},
  },
}
EOF

echo "✅ wezterm.lua written to ~/.config/wezterm/"
echo "🎨 Theme: Neon Contour Violet (Purple with Orange neon)"
echo "🖱️  Right-click paste: Enabled"
echo "🧩  Alt+h/j/k/l: Navigate panes | Alt+d/s: Split panes"

# STEP 5: Finish
echo ""
echo "🚀 All done! Launch WezTerm using the 'wezterm' command."
echo "💡 Optional: Enable 'Blur' effect in KDE > System Settings > Desktop Effects."
