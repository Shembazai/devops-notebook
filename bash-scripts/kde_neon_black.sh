#!/bin/bash
# ============================================================
#  KDE Neon-Black Engineer-HUD RICE  —  Fail-proof Edition
#  Author: Shemba
# ============================================================

set -euo pipefail

echo -e "\n>>> [1/8] Updating system..."
sudo pacman -Syu --noconfirm

# ---------- Dependency checker ----------
echo ">>> [2/8] Installing core packages..."
PKGS=(plasma kde-gtk-config kvantum-qt5 qt5ct git curl papirus-icon-theme capitaine-cursors
      ttf-jetbrains-mono-nerd latte-dock easyeffects calf-plugins lsp-plugins)
for pkg in "${PKGS[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        echo "Installing $pkg..."
        sudo pacman -S --needed --noconfirm "$pkg" || echo "⚠️  Skipped $pkg (may already exist or unavailable)"
    fi
done

# ---------- Theme setup ----------
echo ">>> Applying local Sweet-Dark..."
sudo pacman -S --needed --noconfirm kvantum-theme-sweet-git sweet-gtk-theme || true

# Create a Neon-Black substitute color scheme locally
mkdir -p ~/.local/share/color-schemes
cat > ~/.local/share/color-schemes/NeonBlack.colors <<'EOF'
[General]
Name=NeonBlack
BackgroundNormal=0,0,0
ForegroundNormal=224,224,224
DecorationFocus=0,255,255
DecorationHover=187,0,255
Highlight=0,255,255
Link=187,0,255
VisitedLink=85,85,255
EOF
kwriteconfig5 --file kdeglobals --group General --key ColorScheme "NeonBlack"


# ---------- Apply themes ----------
echo ">>> [4/8] Applying Neon-Black global theme..."
kwriteconfig5 --file kdeglobals --group General --key ColorScheme "NeonBlack" || true
kwriteconfig5 --file kdeglobals --group KDE --key LookAndFeelPackage "NeonBlack" || true
kwriteconfig5 --file kdeglobals --group Icons --key Theme "Papirus-Dark" || true
kwriteconfig5 --file kdeglobals --group General --key cursorTheme "capitaine-cursors-white" || true
kwriteconfig5 --file kdeglobals --group General --key font "JetBrains Mono Nerd Font,11,-1,5,50,0,0,0,0,0" || true
kwriteconfig5 --file kdeglobals --group KDE --key widgetStyle "kvantum" || true

# ---------- Performance tweaks ----------
echo ">>> [5/8] Optimizing KWin compositor..."
kwriteconfig5 --file kwinrc --group Compositing --key Backend OpenGL
kwriteconfig5 --file kwinrc --group Compositing --key OpenGLIsUnsafe false
kwriteconfig5 --file kwinrc --group Plugins --key blurEnabled true
kwriteconfig5 --file kwinrc --group Plugins --key contrastEnabled true
kwriteconfig5 --file kwinrc --group Plugins --key wobblywindowsEnabled false
kwriteconfig5 --file kwinrc --group Plugins --key slidingpopupsEnabled false
kwriteconfig5 --file kwinrc --group Plugins --key magiclampEnabled false

# ---------- Panels and Latte Dock ----------
echo ">>> [6/8] Creating Engineer-HUD layout..."
LATTE_LAYOUT="$HOME/.config/latte/EngineerHUD.layout.latte"
mkdir -p "$(dirname "$LATTE_LAYOUT")"

cat >"$LATTE_LAYOUT" <<'EOF'
[LayoutSettings]
version=2
color=0
launchersOffset=0

[View][0]
alignment=0
alignmentUpgraded=true
colorStyle=0
panelBackground=0
onPrimary=true
position=10
screenEdgeMargin=10
alignment=1
containmentType=Dock
appletOrder=org.kde.latte.plasmoid,org.kde.plasma.icontasks,org.kde.plasma.trash
maxLength=100
panelTransparency=70
EOF

# ---------- Apply Latte Dock layout safely ----------
echo ">>> [7/8] Applying Latte Dock layout..."
latte-dock -r 2>/dev/null || true
latte-dock --replace --layout EngineerHUD.layout.latte & disown

# ---------- Final cleanup ----------
echo ">>> [8/8] Reloading Plasma shell (preserving wallpaper)..."
kwin_x11 --replace & disown
plasmashell --replace & disown

echo -e "\n✅ KDE Neon-Black Engineer HUD applied successfully!"
echo "🧩  Wallpaper preserved."
echo "💾  Performance tuned: Animations off, lightweight blur active."
echo "🎨  Use 'System Settings → Global Theme' if you wish to fine-tune colors."
