# Piixident Integration - Quick Start

## ✅ Setup Complete!

The following has been set up:

1. ✅ Scripts copied from piixident
2. ✅ Cache directories created
3. ✅ Config adapter created (`PiixidentConfig.qml`)
4. ✅ Components adapted to use your ii config
5. ✅ Wrapper components created for easy integration

## 📝 Add to Your shell.qml

Add these components to your `shell.qml` or wherever you want them:

```qml
import "./modules/ii/wallpaperSelector" as WallpaperSelector
import "./modules/ii/overview" as Overview

ShellRoot {
    // ... your existing code ...

    // ══════════════════════════════════════════════════════════════
    //  PIIXIDENT COMPONENTS
    // ══════════════════════════════════════════════════════════════

    // Wallpaper Selector
    WallpaperSelector.PiixidentWallpaperSelector {
        id: wallpaperPicker
    }

    // Window Switcher (Alt-Tab)
    Overview.PiixidentWindowSwitcher {
        id: windowSwitcher
    }
}
```

## 🎮 IPC Commands

### Wallpaper Selector

```bash
# Toggle wallpaper picker
qs -c ii ipc call wallpaperPicker toggle

# Show
qs -c ii ipc call wallpaperPicker show

# Hide
qs -c ii ipc call wallpaperPicker hide
```

### Window Switcher

```bash
# Open window switcher
qs -c ii ipc call windowSwitcher open

# Cycle forward (like Alt+Tab)
qs -c ii ipc call windowSwitcher next

# Cycle backward (like Alt+Shift+Tab)
qs -c ii ipc call windowSwitcher prev

# Focus selected window
qs -c ii ipc call windowSwitcher confirm

# Cancel/close
qs -c ii ipc call windowSwitcher cancel
```

## ⌨️ Hyprland Keybinds

Add to your `~/.config/hypr/custom/keybinds.conf`:

```conf
##! Piixident Features

# Wallpaper Selector
bind = Super+Shift, W, exec, qs -c ii ipc call wallpaperPicker toggle

# Window Switcher (Alt-Tab)
bind = Alt, Tab, exec, qs -c ii ipc call windowSwitcher next
bind = Alt+Shift, Tab, exec, qs -c ii ipc call windowSwitcher prev
bindm = Alt, mouse:272, exec, qs -c ii ipc call windowSwitcher confirm
bind = Alt, Escape, exec, qs -c ii ipc call windowSwitcher cancel
```

## 🧪 Test It

1. **Restart Quickshell**:

   ```bash
   pkill quickshell && qs -c ii
   ```

2. **Test wallpaper selector**:

   ```bash
   qs -c ii ipc call wallpaperPicker show
   ```

3. **Test window switcher**:
   ```bash
   qs -c ii ipc call windowSwitcher open
   ```

## 🎨 Features Available

### Wallpaper Selector

- ✅ Parallelogram slice preview cards
- ✅ Smooth scrolling with physics
- ✅ Thumbnail caching
- ✅ Tag filtering (AI-powered if Ollama installed)
- ✅ Color filtering
- ✅ Type filtering (static/video/WE)
- ✅ Favorites system
- ✅ Multi-monitor support

### Window Switcher

- ✅ Alt-Tab style navigation
- ✅ Live window screenshots
- ✅ Parallelogram card design
- ✅ Keyboard navigation
- ✅ Mouse support
- ✅ Close windows with Delete key
- ✅ Multi-workspace support

## ⚙️ Configuration

Edit `modules/ii/piixident/PiixidentConfig.qml` to customize:

- `wallpaperDir` - Your wallpaper folder
- `mainMonitor` - Primary monitor name
- `ollama.url` - Ollama server (for AI features)
- Polling intervals

## 🔧 Troubleshooting

**Issue: Wallpaper selector is blank**

- Check `~/wallpaper/` exists and contains images
- Run: `ls -la ~/.cache/quickshell/ii/wallpaper/`

**Issue: Window switcher shows no windows**

- Make sure you have windows open
- Check compositor is Hyprland: `echo $HYPRLAND_INSTANCE_SIGNATURE`

**Issue: Scripts not found**

- Verify: `ls ~/.config/quickshell/ii/scripts/piixident/bash/`
- Re-copy: `cp -r ~/.config/piixident/scripts ~/.config/quickshell/ii/scripts/piixident`

**Issue: Colors look wrong**

- The components use `Appearance.colors` from your ii config
- They should match your theme automatically

## 🚀 Optional: AI Features

To enable AI wallpaper tagging:

1. Install Ollama: `curl -fsSL https://ollama.com/install.sh | sh`
2. Download a model: `ollama pull gemma3:4b`
3. Start Ollama: `ollama serve`
4. The wallpaper selector will auto-detect it

## 📂 File Structure

```
modules/ii/
├── piixident/
│   ├── PiixidentConfig.qml    ← Config adapter
│   └── qmldir                  ← Module definition
├── wallpaperSelector/
│   ├── WallpaperSelector_Piixident.qml      ← Core component (1931 lines)
│   └── PiixidentWallpaperSelector.qml       ← Wrapper for easy use
└── overview/
    ├── WindowSwitcher_Piixident.qml         ← Core component (815 lines)
    └── PiixidentWindowSwitcher.qml          ← Wrapper for easy use

scripts/piixident/
├── bash/
│   ├── apply-static-wallpaper
│   ├── apply-video-wallpaper
│   ├── wm-action
│   └── ... (30+ scripts)
└── python/
    ├── analyze-wallpapers
    ├── tag-wallpapers
    └── ...
```

---

**Ready to use!** Just add the components to your shell.qml and restart Quickshell. 🎉
