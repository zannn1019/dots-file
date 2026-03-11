# Piixident Components Integration Guide

## 📁 Files Copied

- **WallpaperSelector_Piixident.qml** - Advanced wallpaper picker with AI tagging, parallelogram slices
- **WindowSwitcher_Piixident.qml** - Alt-Tab window switcher with screenshots (in overview/)

## 🔧 Configuration Mapping Needed

The piixident components use a `Config` object. You need to either:

### Option A: Create a Piixident Config Adapter

Create `modules/ii/piixident/PiixidentConfig.qml`:

```qml
import QtQuick
import qs.modules.common

QtObject {
    // Paths
    property string scriptsDir: Directories.home + "/.config/piixident/scripts"
    property string cacheDir: Directories.cache + "/piixident"
    property string wallpaperDir: Directories.home + "/wallpaper"
    property string homeDir: Directories.home

    // For Wallpaper Engine support (optional)
    property string weDir: ""
    property string weAssetsDir: ""

    // Monitor
    property string mainMonitor: "eDP-1"  // Update with your monitor

    // Ollama (AI wallpaper analysis - optional)
    property var ollama: QtObject {
        property string url: "http://localhost:11434"
        property string model: "gemma3:4b"
    }

    // Matugen (dynamic colors - optional)
    property var matugen: QtObject {
        property string schemeType: "scheme-fidelity"
    }

    // Polling intervals
    property int ollamaStatusPollMs: 5000
}
```

### Option B: Quick Adapter (Simpler)

Wrap the components with property bindings:

```qml
// In your shell.qml or wherever you want to use it
Loader {
    id: wallpaperPicker
    active: false
    sourceComponent: Component {
        Item {
            // Create a simple Config shim
            QtObject {
                id: configShim
                property string scriptsDir: Directories.home + "/.config/piixident/scripts"
                property string cacheDir: Directories.cache + "/piixident"
                property string wallpaperDir: Wallpapers.directory
                property string mainMonitor: "eDP-1"
                property int ollamaStatusPollMs: 5000
                // Add other properties as needed
            }

            // Load the component
            Loader {
                anchors.fill: parent
                source: "wallpaperSelector/WallpaperSelector_Piixident.qml"
                onLoaded: {
                    item.colors = Appearance.colors  // Bind your color scheme
                    item.showing = Qt.binding(() => GlobalStates.wallpaperPickerOpen)
                }
            }
        }
    }
}
```

## 📦 Dependencies Required

### Scripts (from piixident)

The WallpaperSelector needs these bash/python scripts:

- `scripts/bash/wm-action` - Window manager actions
- `scripts/bash/apply-static-wallpaper` - Apply wallpaper
- `scripts/python/analyze-wallpapers` - AI analysis (optional)
- `scripts/python/tag-wallpapers` - Tagging system (optional)

Copy them:

```bash
mkdir -p ~/.config/quickshell/ii/scripts/bash
mkdir -p ~/.config/quickshell/ii/scripts/python
cp -r ~/.config/piixident/scripts/bash/* ~/.config/quickshell/ii/scripts/bash/
cp -r ~/.config/piixident/scripts/python/* ~/.config/quickshell/ii/scripts/python/
```

Or symlink to use piixident's scripts directly:

```bash
ln -s ~/.config/piixident/scripts ~/.config/quickshell/ii/scripts/piixident
```

### Cache Directories

```bash
mkdir -p ~/.cache/quickshell/ii/wallpaper/thumbs
mkdir -p ~/.cache/quickshell/ii/wallpaper/we-thumbs
```

## 🎨 Features

### WallpaperSelector

- **Parallelogram slice preview** - Smooth 3D-like cards
- **AI tagging** (Ollama) - Auto-describe wallpapers
- **Color analysis** - Filter by dominant colors
- **Tag filtering** - Search by keywords
- **Type filtering** - Static/video/Wallpaper Engine
- **Favorites** - Star your favorites
- **Thumbnails** - Cached previews
- **Multi-monitor** - Per-monitor wallpapers

### WindowSwitcher

- **Alt-Tab style** - Cycle through windows
- **Screenshots** - Live window thumbnails
- **Parallelogram cards** - Matches wallpaper selector style
- **Keyboard navigation** - Arrow keys, Enter, Esc
- **Close windows** - Delete key to close
- **Multi-workspace** - Shows windows from all workspaces

## 🔗 Integration Points

### WallpaperSelector Signals/Functions

```qml
WallpaperSelector_Piixident {
    showing: GlobalStates.wallpaperPickerOpen
    colors: Appearance.colors

    onWallpaperChanged: {
        // Reload your wallpaper/colors
        Wallpapers.reload()
    }
}
```

### WindowSwitcher Signals/Functions

```qml
WindowSwitcher_Piixident {
    showing: GlobalStates.windowSwitcherOpen
    colors: Appearance.colors
    mainMonitor: monitor.name

    function open() { showing = true }
    function next() { /* cycle forward */ }
    function prev() { /* cycle back */ }
    function confirm() { /* focus selected */ }
    function cancel() { showing = false }
}
```

### Keybinds

Add to your Hyprland keybinds:

```conf
# Window switcher (Alt+Tab)
bind = Alt, Tab, exec, qs -c ii ipc call windowSwitcher next
bind = Alt+Shift, Tab, exec, qs -c ii ipc call windowSwitcher prev
bindm = Alt, mouse:272, exec, qs -c ii ipc call windowSwitcher confirm

# Wallpaper picker
bind = Super, W, exec, qs -c ii ipc call wallpaperPicker toggle
```

## ⚠️ Important Notes

1. **Config object is required** - Components expect `Config.scriptsDir`, `Config.cacheDir`, etc.
2. **Scripts are essential** - Wallpaper application won't work without bash scripts
3. **Ollama is optional** - AI features can be disabled if you don't have Ollama
4. **Cache structure** - Thumbnails are generated on first view (may take time)
5. **Wallpaper directory** - Must contain images/videos in `~/wallpaper/` or configure path

## 🚀 Quick Start

1. **Copy scripts** (if not using existing piixident scripts):

   ```bash
   cp -r ~/.config/piixident/scripts ~/.config/quickshell/ii/scripts/piixident
   ```

2. **Create Config adapter** (see Option A above)

3. **Add to your shell.qml**:

   ```qml
   import "./piixident/PiixidentConfig.qml" as PiixidentConfig

   WallpaperSelector_Piixident {
       id: wallpaperPicker
       // Config will be available in scope
   }
   ```

4. **Test**:
   ```bash
   qs -c ii ipc call wallpaperPicker showing true
   ```

## 📝 TODO

- [ ] Adapt Config references to use your existing Config system
- [ ] Set up script paths (copy or symlink)
- [ ] Create cache directories
- [ ] Configure monitor names
- [ ] Test wallpaper application
- [ ] Set up IPC commands for keybinds
- [ ] Optional: Install Ollama for AI features
- [ ] Optional: Set up Wallpaper Engine integration

---

**Need help?** The components are ~2000 lines combined. Start with just the WallpaperSelector and test thoroughly before adding WindowSwitcher.
