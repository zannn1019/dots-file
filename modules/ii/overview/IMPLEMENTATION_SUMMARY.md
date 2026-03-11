# 🎬 Cover/Stacking Transition - Implementation Summary

## 📋 What Was Implemented

A complete **Cover/Stacking workspace transition system** for Quickshell with:

✅ **Cover Animation**: New workspace slides from right (x: parent.width → 0)  
✅ **Partial Exit**: Old workspace slides back 20% (x: 0 → -20%) and fades to 50% opacity  
✅ **Spring Physics**: Caelestia-style (`spring: 3.5, damping: 0.25`)  
✅ **Z-Index Management**: Manual layer control for proper stacking  
✅ **Parallelogram Geometry**: 40px slant with 20px inverted corners  
✅ **Hyprland Integration**: Matching window manager animations  
✅ **Demo Component**: Standalone test file for visualization

---

## 📁 Files Created

### Core Implementation

1. **`WorkspaceCoverTransition.qml`**
   - Modular transition manager
   - Handles z-index and state tracking
   - Can be imported into any workspace component

2. **`WorkspaceTileCover.qml`**
   - Individual workspace tile with cover transition
   - Includes parallelogram shape with inverted corners
   - Self-contained animation logic

3. **`OverviewWidget_CoverTransition.qml`**
   - **⭐ RECOMMENDED: Complete drop-in replacement**
   - Full integration into your existing overview grid
   - Ready to use immediately

### Configuration & Documentation

4. **`hyprland_cover_transition.conf`**
   - Hyprland animation configuration
   - Uses `slidefade 20%` to match QML behavior
   - Custom bezier curve for spring approximation

5. **`COVER_TRANSITION_README.md`**
   - Comprehensive documentation
   - Implementation details and customization guide
   - Troubleshooting section

6. **`CoverTransitionDemo.qml`**
   - Standalone demo application
   - Visual test of transition behavior
   - Helpful for understanding the effect before integration

---

## 🚀 Quick Start Guide

### Step 1: Choose Your Integration Method

#### **Option A: Drop-in Replacement (Easiest)**

Replace your current OverviewWidget:

```qml
// In your Overview.qml or wherever you import OverviewWidget

// OLD:
// OverviewWidget {
//     panelWindow: root.panelWindow
// }

// NEW:
Loader {
    source: "OverviewWidget_CoverTransition.qml"
    onLoaded: item.panelWindow = root.panelWindow
}
```

#### **Option B: Manual Integration**

Apply the transition logic to your existing `OverviewWidget.qml`:

1. Add transition state properties (see `COVER_TRANSITION_README.md` for details)
2. Modify workspace tile delegate to use State-based transitions
3. Add parallelogram Canvas shape

### Step 2: Configure Hyprland

Add to `~/.config/hypr/hyprland.conf`:

```conf
source = ~/.config/quickshell/ii/modules/ii/overview/hyprland_cover_transition.conf
```

Then reload:

```bash
hyprctl reload
```

### Step 3: Test the Transition

1. Open workspace overview (`Super+Tab` or your keybind)
2. Click a different workspace
3. Observe:
   - New workspace slides in from right
   - Old workspace slides back 20% and fades
   - Smooth spring physics motion
   - "Eating edge" effect from inverted corners

---

## 🎨 Key Features Explained

### 1. **Cover Effect**

The entering workspace **slides over** the exiting one, creating a layered "stacking" effect:

```
Time 0:    [Old WS at x=0, z=50]
Time 1:    [Old WS at x=-20%, z=50] [New WS at x=100%, z=100]
Time 2:    [Old WS at x=-20%, z=50] [New WS at x=0, z=100] ← Cover complete
```

### 2. **Spring Physics**

Uses QML `SpringAnimation` instead of standard easing:

```qml
SpringAnimation {
    spring: 3.5   // Stiffness (fast response)
    damping: 0.25 // Low resistance (smooth overshoot)
    mass: 1.0     // Standard weight
}
```

This creates a natural, bouncy motion that settles in ~600-800ms.

### 3. **Parallelogram Geometry**

Each workspace tile is a custom shape:

```
┌─────────────╮
│             │  ← 40px slant on right edge
│  Workspace  │
│      #      │  ← 20px inverted corner ("scoop")
└─────────────┘
```

The inverted corner creates the visual "eating edge" effect as the new workspace slides over.

### 4. **Manual Z-Index Control**

Instead of using `StackView`, this implementation manually manages z-index:

```qml
property int nextZIndex: 100

onWorkspaceChanged: {
    newWorkspace.z = nextZIndex++  // Always higher than previous
}
```

This ensures the entering workspace **always** renders on top.

---

## 🔧 Customization Options

### Adjust Spring Behavior

**More Bounce:**

```qml
SpringAnimation {
    spring: 3.5
    damping: 0.15  // Lower damping = more overshoot
}
```

**Faster/Snappier:**

```qml
SpringAnimation {
    spring: 5.0    // Higher spring = faster response
    damping: 0.35  // Higher damping = less overshoot
}
```

### Change Slide Distance

**Slide further back:**

```qml
targetX: -root.workspaceImplicitWidth * 0.3  // 30% instead of 20%
```

**Completely slide out:**

```qml
targetX: -root.workspaceImplicitWidth  // 100% off-screen
```

### Modify Parallelogram Shape

**Steeper slant:**

```qml
property real slantOffset: 60  // Was 40px
```

**Larger scoop:**

```qml
property real invertedCornerSize: 30  // Was 20px
```

### Adjust Colors

**Change accent color:**

```qml
readonly property color acc: "#FF6B6B"  // Coral red instead of turquoise
```

**Modify workspace base color:**

```qml
color: Qt.rgba(0.15, 0.15, 0.18, 0.95)  // Lighter gray
```

---

## 🧪 Testing with the Demo

Run the standalone demo to visualize the transition:

```bash
cd ~/.config/quickshell/ii/modules/ii/overview
quickshell CoverTransitionDemo.qml
```

Or if you have a QML viewer:

```bash
qml CoverTransitionDemo.qml
```

Click the "WS 1", "WS 2", etc. buttons to trigger transitions between workspaces.

**What to look for:**

- Smooth spring motion (no linear easing)
- New workspace slides from right (starts off-screen)
- Old workspace partially slides left (20%) and fades
- Z-index displayed in top-right of each workspace
- State indicator in top-left ("ENTERING", "EXITING", "ACTIVE")

---

## 📊 Technical Specifications

| Property               | Value | Purpose                               |
| ---------------------- | ----- | ------------------------------------- |
| **Spring Stiffness**   | 3.5   | Controls responsiveness and speed     |
| **Damping**            | 0.25  | Controls overshoot (lower = bouncier) |
| **Mass**               | 1.0   | Movement weight                       |
| **Exit Slide**         | -20%  | How far old workspace moves left      |
| **Exit Opacity**       | 0.5   | Fade amount for old workspace         |
| **Enter Start**        | +100% | New workspace starts off-screen right |
| **Slant Offset**       | 40px  | Parallelogram angle                   |
| **Inverted Corner**    | 20px  | "Scoop" radius for eating edge        |
| **Z-Index Base**       | 0-50  | Normal/active workspace layers        |
| **Z-Index Transition** | 100+  | Entering workspace (increments)       |

---

## 🎯 Behavior Comparison

### vs. Standard StackView

| Feature           | StackView     | Cover Transition             |
| ----------------- | ------------- | ---------------------------- |
| Animation Control | Pre-defined   | **Full manual control**      |
| Z-Index           | Automatic     | **Manual management**        |
| Physics           | Easing curves | **Spring physics**           |
| Partial Exit      | ❌            | **✅ 20% slide + fade**      |
| Custom Geometry   | Limited       | **✅ Parallelogram support** |

### vs. Standard Slide

| Feature         | Slide                | Cover/Stack                |
| --------------- | -------------------- | -------------------------- |
| Old Workspace   | Slides out 100%      | **Slides out 20% + fades** |
| New Workspace   | Slides in same layer | **Slides in on top layer** |
| Visual Effect   | Adjacent             | **Layered/stacked**        |
| Perceived Depth | Flat                 | **3D-like depth**          |

---

## 🐛 Common Issues & Solutions

### Issue: Transition doesn't trigger

**Cause**: State change not detected  
**Fix**: Verify `previousActiveWorkspaceId` is being updated:

```qml
onCurrentActiveWorkspaceIdChanged: {
    console.log("Workspace changed:", previousActiveWorkspaceId, "→", currentActiveWorkspaceId)
    // Should print on every workspace change
}
```

### Issue: Z-index not working (overlapping wrong)

**Cause**: Container needs `clip: true`  
**Fix**:

```qml
Item {
    id: workspaceStack
    clip: true  // ← Essential for proper layering
    // ...
}
```

### Issue: Parallelogram not visible

**Cause**: Canvas not painting  
**Fix**: Force initial paint:

```qml
Canvas {
    // ...
    Component.onCompleted: requestPaint()
}
```

### Issue: Animation too slow/fast

**Cause**: Spring physics mismatch  
**Fix**: Adjust spring/damping values:

- **Too slow**: Increase `spring` (try 4.5-5.0)
- **Too fast**: Decrease `spring` (try 2.5-3.0)
- **Too bouncy**: Increase `damping` (try 0.3-0.4)
- **Too stiff**: Decrease `damping` (try 0.15-0.2)

---

## 🎓 Advanced Usage

### Conditional Transitions

Disable transitions for instant workspace switches:

```qml
Behavior on x {
    enabled: root.enableTransitions && !root.instantMode
    SpringAnimation { ... }
}
```

### Custom Transition Curves

Use different physics for different directions:

```qml
Behavior on x {
    SpringAnimation {
        spring: tile.isEntering ? 3.5 : 2.5  // Faster entering
        damping: tile.isEntering ? 0.25 : 0.4  // Smoother exiting
    }
}
```

### Gesture-Based Transitions

Integrate with touch/swipe gestures:

```qml
MouseArea {
    anchors.fill: parent
    property real dragStartX: 0

    onPressed: dragStartX = mouseX
    onPositionChanged: {
        const delta = mouseX - dragStartX
        if (Math.abs(delta) > 100) {
            // Trigger transition
            demoRoot.currentWorkspace = delta > 0 ? prevWs : nextWs
        }
    }
}
```

---

## 📚 Further Reading

- **QML State System**: [Qt States](https://doc.qt.io/qt-6/qml-qtquick-state.html)
- **SpringAnimation**: [Qt Documentation](https://doc.qt.io/qt-6/qml-qtquick-springanimation.html)
- **Canvas 2D Context**: [Qt Canvas](https://doc.qt.io/qt-6/qml-qtquick-canvas.html)
- **Hyprland Animations**: [Wiki](https://wiki.hyprland.org/Configuring/Animations/)

---

## 🙏 Credits

Implementation inspired by:

- **Caelestia**: Spring physics parameters
- **Material Design**: Stacking card transitions
- **Hyprland**: Workspace animation capabilities
- **Your Quickshell setup**: Parallelogram geometry from existing design

---

## 📝 Next Steps

1. **Test the demo**: Run `CoverTransitionDemo.qml` to see it in action
2. **Integrate**: Use `OverviewWidget_CoverTransition.qml` as replacement
3. **Configure Hyprland**: Add the config snippet to sync window manager
4. **Customize**: Tweak spring physics and geometry to your preference
5. **Iterate**: Adjust colors, timing, and slide distance as desired

---

**Enjoy your smooth, professional workspace transitions! 🚀**

Need help? Check `COVER_TRANSITION_README.md` for detailed implementation guide.
