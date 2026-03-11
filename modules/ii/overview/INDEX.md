# 📦 Cover/Stacking Transition - File Index

Complete implementation of a Cover/Stacking workspace transition system for Quickshell with Caelestia-inspired spring physics.

---

## 🗂️ File Structure

```
overview/
├── 📄 INDEX.md (this file)
│
├── 🎬 IMPLEMENTATION FILES
│   ├── OverviewWidget_CoverTransition.qml    ⭐ Main implementation (drop-in replacement)
│   ├── WorkspaceCoverTransition.qml          Modular transition manager
│   └── WorkspaceTileCover.qml                Individual workspace tile component
│
├── ⚙️ CONFIGURATION
│   └── hyprland_cover_transition.conf        Hyprland animation config
│
├── 🧪 TESTING & DEMO
│   └── CoverTransitionDemo.qml               Standalone demo application
│
└── 📚 DOCUMENTATION
    ├── IMPLEMENTATION_SUMMARY.md             Quick start guide & overview
    ├── COVER_TRANSITION_README.md            Detailed implementation docs
    └── TRANSITION_FLOW.txt                   Visual diagrams & flow charts
```

---

## 🚀 Quick Start (Choose One)

### 1️⃣ **Use the Complete Widget** (Recommended)

```qml
// In your Overview.qml or similar
Loader {
    source: "OverviewWidget_CoverTransition.qml"
    onLoaded: item.panelWindow = root.panelWindow
}
```

### 2️⃣ **Run the Demo First**

```bash
cd ~/.config/quickshell/ii/modules/ii/overview
qml CoverTransitionDemo.qml
```

### 3️⃣ **Integrate Manually**

See `COVER_TRANSITION_README.md` for step-by-step integration guide.

---

## 📋 File Descriptions

### Core Implementation

#### `OverviewWidget_CoverTransition.qml` ⭐
**Complete drop-in replacement for OverviewWidget.qml**

- Full workspace grid with cover transitions
- Parallelogram tiles with 40px slant, 20px inverted corners
- Spring physics: `spring: 3.5, damping: 0.25`
- Manual z-index management
- Ready to use immediately

**When to use**: You want the full implementation without modifications.

---

#### `WorkspaceCoverTransition.qml`
**Modular transition manager component**

- Handles z-index tracking
- Manages workspace state transitions
- Can be imported and used in custom layouts
- Provides transition coordination

**When to use**: Building a custom workspace overview from scratch.

---

#### `WorkspaceTileCover.qml`
**Individual workspace tile with transition support**

- Self-contained workspace tile
- Includes parallelogram geometry
- Built-in transition states
- Reusable component

**When to use**: Need individual tiles for a custom layout.

---

### Configuration

#### `hyprland_cover_transition.conf`
**Hyprland window manager configuration**

- Matches QML transition behavior
- Uses `slidefade 20%` animation
- Custom bezier curve for spring approximation
- Full animation block example

**How to use**:
```conf
# In ~/.config/hypr/hyprland.conf
source = ~/.config/quickshell/ii/modules/ii/overview/hyprland_cover_transition.conf
```

---

### Testing & Demo

#### `CoverTransitionDemo.qml`
**Standalone demonstration application**

- Visual test of transition behavior
- 4 test workspaces with buttons
- Shows z-index and state indicators
- Physics info display
- No dependencies on Quickshell services

**How to run**:
```bash
qml CoverTransitionDemo.qml
# or
quickshell CoverTransitionDemo.qml
```

---

### Documentation

#### `IMPLEMENTATION_SUMMARY.md`
**Quick start guide & feature overview**

Contains:
- ✅ Feature checklist
- 🚀 Quick start instructions
- 🎨 Key features explained
- 🔧 Customization options
- 🧪 Testing guide
- 📊 Technical specifications

**Read this first** for a high-level understanding.

---

#### `COVER_TRANSITION_README.md`
**Comprehensive implementation documentation**

Contains:
- 📦 Detailed usage instructions
- 🔧 Hyprland integration guide
- 🎨 Customization examples
- 🔍 How it works (technical deep dive)
- 🐛 Troubleshooting section
- 🎓 Advanced usage patterns

**Read this** when integrating or customizing.

---

#### `TRANSITION_FLOW.txt`
**Visual diagrams & flowcharts**

Contains:
- Frame-by-frame breakdown
- State machine diagram
- Spring physics visualization
- Parallelogram "eating edge" detail
- Comparison with other animation styles
- Implementation notes

**Read this** to understand the visual effect and timing.

---

## 🎯 Feature Highlights

| Feature | Description |
|---------|-------------|
| **Cover Effect** | New workspace slides over old one (not adjacent slide) |
| **Partial Exit** | Old workspace slides back 20% and fades to 50% |
| **Spring Physics** | `spring: 3.5, damping: 0.25` for natural motion |
| **Z-Index Control** | Manual layer management for proper stacking |
| **Parallelogram Tiles** | 40px slant with 20px inverted corners |
| **Eating Edge** | Inverted corner appears to "consume" previous workspace |
| **Hyprland Sync** | Matching window manager animations |

---

## 🔧 Technical Specs

```qml
SpringAnimation {
    spring: 3.5      // Stiffness
    damping: 0.25    // Resistance (lower = more bounce)
    mass: 1.0        // Weight
}

// Exit animation
targetX: -workspaceWidth * 0.2  // 20% slide back
targetOpacity: 0.5               // Fade to 50%

// Geometry
slantOffset: 40px                // Parallelogram angle
invertedCornerSize: 20px         // Scoop radius

// Z-index
baseZ: 0                         // Inactive workspaces
activeZ: 50                      // Current workspace
transitionZ: 100+                // Entering workspace (increments)
```

---

## 📖 Reading Order

**New to this implementation?**
1. `IMPLEMENTATION_SUMMARY.md` - Overview & quick start
2. `CoverTransitionDemo.qml` - Run demo to see it in action
3. `OverviewWidget_CoverTransition.qml` - Use the complete implementation
4. `hyprland_cover_transition.conf` - Configure window manager

**Want to customize?**
1. `COVER_TRANSITION_README.md` - Detailed customization guide
2. `TRANSITION_FLOW.txt` - Understand the visual flow
3. `WorkspaceTileCover.qml` - Study individual tile component

**Building from scratch?**
1. `TRANSITION_FLOW.txt` - Understand state machine
2. `WorkspaceCoverTransition.qml` - Study transition manager
3. `COVER_TRANSITION_README.md` - Implementation patterns

---

## 🎬 Usage Examples

### Example 1: Drop-in Replacement

```qml
// In modules/ii/overview/Overview.qml
import "./OverviewWidget_CoverTransition.qml" as OverviewWidget

Item {
    OverviewWidget {
        panelWindow: root.panelWindow
    }
}
```

### Example 2: Custom Integration

```qml
import "./WorkspaceCoverTransition.qml"

Item {
    WorkspaceCoverTransition {
        id: transitionManager
        currentWorkspaceId: monitor.activeWorkspace?.id
        onWorkspaceChanged: (oldId, newId) => {
            console.log("Transitioned:", oldId, "→", newId)
        }
    }
    
    // Your custom workspace layout here
}
```

### Example 3: Hyprland Config

```conf
# In ~/.config/hypr/hyprland.conf

source = ~/.config/quickshell/ii/modules/ii/overview/hyprland_cover_transition.conf

# Or manually:
bezier = coverSpring, 0.22, 0.61, 0.36, 1.0
animation = workspaces, 1, 6, coverSpring, slidefade 20%
```

---

## 🐛 Troubleshooting Quick Links

| Issue | Solution |
|-------|----------|
| Transition doesn't trigger | See `COVER_TRANSITION_README.md` → Troubleshooting |
| Z-index not working | Check `clip: true` on container |
| Parallelogram not visible | Force `requestPaint()` on Canvas |
| Animation too slow/fast | Adjust spring/damping values |
| Hyprland doesn't match | Verify `slidefade` support |

Full troubleshooting guide: `COVER_TRANSITION_README.md`

---

## 📊 Comparison Matrix

| Feature | Standard Slide | StackView | Cover/Stack (This) |
|---------|---------------|-----------|-------------------|
| Animation Type | Bezier | Pre-defined | **SpringAnimation** |
| Z-Index | Auto | Auto | **Manual control** |
| Partial Exit | ❌ | ❌ | **✅ 20% + fade** |
| Custom Geometry | ❌ | Limited | **✅ Parallelogram** |
| Physics Control | Limited | None | **Full control** |
| Overshoot | ❌ | ❌ | **✅ Natural bounce** |

---

## 🎓 Learning Resources

### QML Documentation
- [SpringAnimation](https://doc.qt.io/qt-6/qml-qtquick-springanimation.html)
- [State System](https://doc.qt.io/qt-6/qml-qtquick-state.html)
- [Canvas 2D](https://doc.qt.io/qt-6/qml-qtquick-canvas.html)

### Hyprland Documentation
- [Animations](https://wiki.hyprland.org/Configuring/Animations/)
- [Workspace Management](https://wiki.hyprland.org/Configuring/Dispatchers/)

### Quickshell Resources
- [Quickshell Docs](https://quickshell.outfoxxed.me/)

---

## 🙏 Credits & Inspiration

- **Caelestia**: Spring physics parameters (`spring: 3.5, damping: 0.25`)
- **Material Design**: Stacking card transition concepts
- **macOS**: Mission Control workspace overview inspiration
- **Your Setup**: Parallelogram geometry from existing design

---

## 📝 Version History

**v1.0** (Current)
- Initial implementation
- Full cover/stacking transition
- Parallelogram geometry with inverted corners
- Spring physics: `spring: 3.5, damping: 0.25`
- Hyprland configuration
- Comprehensive documentation

---

## 🔮 Future Enhancements (Ideas)

- [ ] Gesture-based transitions (swipe to switch)
- [ ] Multi-monitor support with synchronized transitions
- [ ] Configurable spring physics via settings UI
- [ ] Alternative transition styles (fold, flip, etc.)
- [ ] Performance optimizations for large workspace grids
- [ ] Animation presets (snappy, smooth, bouncy)

---

## 💡 Tips

**Best Practices:**
- Test with the demo first before integrating
- Start with the complete widget, customize later
- Match Hyprland config for consistent UX
- Adjust spring/damping to your taste
- Use visual diagrams to understand flow

**Performance:**
- Canvas redraws only on state changes
- Spring animations are GPU-accelerated
- Z-index changes are instant (no animation)
- Clipping prevents off-screen rendering

**Customization:**
- All colors defined as properties (easy to theme)
- Geometry parameters are configurable
- Spring physics fully adjustable
- State machine is extensible

---

## 📞 Support

**Issues?** Check:
1. `COVER_TRANSITION_README.md` → Troubleshooting
2. `TRANSITION_FLOW.txt` → Implementation notes
3. Console output for state change logs

**Customization help?**
- See `COVER_TRANSITION_README.md` → Customization Options
- Study `WorkspaceTileCover.qml` for component structure

---

## 📄 License

This implementation is provided as-is for use in your Quickshell configuration.

Modify freely! 🚀

---

**Ready to get started?**
👉 Read `IMPLEMENTATION_SUMMARY.md` or run `CoverTransitionDemo.qml`
