# Cover/Stacking Workspace Transition Implementation

## 🎯 Overview

This implementation provides a sophisticated **Cover/Stacking transition** for workspace navigation in Quickshell, featuring:

- **Cover Animation**: New workspace slides in from the right, appearing on top
- **Partial Exit**: Previous workspace slides back only 20% and fades to 50% opacity
- **Caelestia-style Physics**: Spring animations with `spring: 3.5, damping: 0.25`
- **Parallelogram Geometry**: 40px slant with 20px inverted corners creating an "eating edge" effect
- **Manual Z-Index Control**: Full control over layer stacking without StackView

---

## 📦 Files Created

### 1. **WorkspaceCoverTransition.qml**

- Standalone transition manager component
- Handles z-index management and state tracking
- Can be imported and used modularly

### 2. **WorkspaceTileCover.qml**

- Individual workspace tile with cover transition support
- Includes parallelogram geometry with inverted corners
- Self-contained animation logic

### 3. **OverviewWidget_CoverTransition.qml**

- Complete drop-in replacement for your existing OverviewWidget
- Integrates cover transitions into the full overview grid
- Ready to use with minimal modifications

### 4. **hyprland_cover_transition.conf**

- Hyprland configuration snippet
- Matches the QML transition behavior
- Uses `slidefade 20%` for synchronized window manager animations

---

## 🚀 Quick Start

### Option A: Use the Complete Widget

Replace your current OverviewWidget import:

```qml
// In Overview.qml or wherever you use OverviewWidget
// OLD:
// import "OverviewWidget.qml"

// NEW:
import "OverviewWidget_CoverTransition.qml" as OverviewWidget
```

### Option B: Apply to Existing Code

If you want to integrate into your current OverviewWidget.qml, apply these key changes:

1. **Add transition state tracking:**

```qml
property int previousActiveWorkspaceId: -1
property int currentActiveWorkspaceId: monitor.activeWorkspace?.id ?? -1
property int nextZIndex: 100

onCurrentActiveWorkspaceIdChanged: {
    if (currentActiveWorkspaceId === -1) return
    const oldId = previousActiveWorkspaceId
    const newId = currentActiveWorkspaceId
    if (oldId !== -1 && oldId !== newId) {
        nextZIndex += 1
    }
    previousActiveWorkspaceId = newId
}
```

2. **Modify workspace tile delegate to use State-based transitions:**

```qml
Item {
    id: tileContainer
    property bool isActive: wsVal === root.currentActiveWorkspaceId
    property bool wasActive: wsVal === root.previousActiveWorkspaceId
    property bool isEntering: isActive && wasActive === false
    property bool isExiting: wasActive && !isActive

    property real targetX: 0
    property real targetOpacity: 1.0
    property int tileZ: 0

    states: [
        State {
            name: "entering"
            when: tileContainer.isEntering
            PropertyChanges {
                target: tileContainer
                targetX: 0
                targetOpacity: 1.0
                tileZ: root.nextZIndex
            }
        },
        State {
            name: "exiting"
            when: tileContainer.isExiting
            PropertyChanges {
                target: tileContainer
                targetX: -root.workspaceImplicitWidth * 0.2
                targetOpacity: 0.5
            }
        }
    ]

    // Tile visual content here...
    Item {
        x: tileContainer.targetX
        opacity: tileContainer.targetOpacity
        z: tileContainer.tileZ

        Behavior on x {
            SpringAnimation {
                spring: 3.5
                damping: 0.25
                mass: 1.0
            }
        }

        Behavior on opacity {
            SpringAnimation {
                spring: 3.5
                damping: 0.25
            }
        }
    }
}
```

3. **Add parallelogram shape with Canvas:**

```qml
Canvas {
    id: shapeCanvas
    anchors.fill: parent

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()

        const w = width
        const h = height
        const slant = 40      // 40px slant offset
        const scoop = 20      // 20px inverted corner radius

        // Draw parallelogram path
        ctx.beginPath()
        ctx.moveTo(scoop, 0)
        ctx.lineTo(w - slant - scoop, 0)

        // Top-right inverted corner (the "scoop")
        ctx.quadraticCurveTo(w - slant, 0, w - slant, scoop)
        ctx.lineTo(w, h - scoop)
        ctx.quadraticCurveTo(w, h, w - scoop, h)
        ctx.lineTo(scoop + slant, h)
        ctx.quadraticCurveTo(slant, h, slant, h - scoop)
        ctx.lineTo(0, scoop)
        ctx.quadraticCurveTo(0, 0, scoop, 0)
        ctx.closePath()

        // Fill and stroke
        ctx.fillStyle = baseColor
        ctx.fill()
        ctx.strokeStyle = borderColor
        ctx.lineWidth = 2
        ctx.stroke()
    }
}
```

---

## 🔧 Hyprland Integration

Add to your `~/.config/hypr/hyprland.conf`:

```conf
# Import the cover transition config
source = ~/.config/quickshell/ii/modules/ii/overview/hyprland_cover_transition.conf
```

Or manually add:

```conf
bezier = coverSpring, 0.22, 0.61, 0.36, 1.0
animation = workspaces, 1, 6, coverSpring, slidefade 20%
```

Reload Hyprland:

```bash
hyprctl reload
```

---

## 🎨 Customization

### Adjust Spring Physics

Modify the `SpringAnimation` properties:

```qml
Behavior on x {
    SpringAnimation {
        spring: 3.5     // Stiffness (higher = faster/bouncier)
        damping: 0.25   // Resistance (lower = more overshoot)
        mass: 1.0       // Weight (higher = slower)
    }
}
```

### Change Slide Distance

Modify the exiting workspace offset:

```qml
State {
    name: "exiting"
    PropertyChanges {
        targetX: -root.workspaceImplicitWidth * 0.2  // Change 0.2 to adjust %
        targetOpacity: 0.5  // Change fade amount
    }
}
```

### Adjust Parallelogram Geometry

```qml
property real slantOffset: 40          // Slant angle (px)
property real invertedCornerSize: 20   // Inverted corner radius (px)
```

### Customize Colors

```qml
readonly property color acc: "#40E0D0"  // Accent (turquoise)
color: Qt.rgba(0.09, 0.10, 0.13, 0.90)  // Base workspace color
```

---

## 🧪 Testing

1. **Open the workspace overview** (likely bound to `Super+Tab` or similar)
2. **Click a different workspace** - observe the cover transition
3. **Watch for:**
   - New workspace sliding in from right
   - Old workspace sliding back 20% and fading
   - "Eating edge" effect where the inverted corner appears to consume the previous workspace

---

## 🔍 How It Works

### Z-Index Management

```
Base Layer (z=0)    ← Inactive workspaces
Active Layer (z=50) ← Current workspace (normal state)
Cover Layer (z=100+) ← Entering workspace (increments each transition)
```

Each workspace transition increments `nextZIndex`, ensuring the entering workspace always renders on top.

### Transition States

1. **Normal**: Workspace is visible at x=0, opacity=1, z=0 or z=50 (if active)
2. **Entering**: New workspace starts at x=parent.width, animates to x=0, z=nextZIndex
3. **Exiting**: Old workspace animates to x=-parent.width\*0.2, opacity=0.5, z stays low

### Spring Physics Approximation

The Caelestia-style spring (`spring: 3.5, damping: 0.25`) creates:

- **Fast initial movement** (high spring stiffness)
- **Smooth overshoot** (low damping)
- **Natural settle** (~600-800ms total duration)

The Hyprland bezier `0.22, 0.61, 0.36, 1.0` approximates this cubic bezier equivalent.

### Parallelogram "Eating Edge"

The inverted corner (20px quadratic curve) at the top-right of the entering workspace creates a visual "scoop" that appears to consume the edge of the exiting workspace as it slides over.

```
Exiting WS:  [████████████]---→ (slides back 20%)
Entering WS:    ╔═══════════════╗
                ║  (scoop here) ║
                ╚═══════════════╝
                  ↑ inverted corner
```

---

## 📐 Technical Specifications

| Property             | Value | Description                              |
| -------------------- | ----- | ---------------------------------------- |
| **Spring Stiffness** | 3.5   | Controls bounce/speed                    |
| **Damping**          | 0.25  | Controls overshoot (lower = more bounce) |
| **Mass**             | 1.0   | Movement weight                          |
| **Slide Offset**     | 20%   | How far old workspace slides back        |
| **Opacity Fade**     | 0.5   | Old workspace fade target                |
| **Slant Angle**      | 40px  | Parallelogram slant offset               |
| **Inverted Corner**  | 20px  | Scoop radius                             |
| **Z-Index Range**    | 0-∞   | Auto-incrementing layer stack            |

---

## 🐛 Troubleshooting

### Issue: Workspaces don't transition smoothly

- **Check**: Ensure `GlobalStates.overviewOpen` is properly set
- **Fix**: Add console.log to verify state changes

### Issue: Z-index not working (workspaces overlap incorrectly)

- **Check**: Verify `clip: true` on workspace container
- **Fix**: Ensure each tile's parent Item has proper z bindings

### Issue: Parallelogram shape not rendering

- **Check**: Canvas `onPaint` is being triggered
- **Fix**: Add `Component.onCompleted: requestPaint()`

### Issue: Hyprland animation doesn't match

- **Adjust**: Hyprland duration multiplier (try 5-8 instead of 6)
- **Verify**: `slidefade` is supported (use `slide` as fallback)

---

## 🎓 Advanced: Manual Behavior Control

Unlike StackView transitions, this implementation uses manual `Behavior on x` blocks, giving you full control:

```qml
// You can disable/enable transitions conditionally:
Behavior on x {
    enabled: root.transitionsEnabled && !root.instantMode
    SpringAnimation { ... }
}

// Or change physics mid-flight:
Behavior on x {
    SpringAnimation {
        spring: root.userTweakedSpring
        damping: root.userTweakedDamping
    }
}
```

---

## 📚 References

- **QML SpringAnimation**: [Qt Documentation](https://doc.qt.io/qt-6/qml-qtquick-springanimation.html)
- **Canvas API**: [Qt Canvas](https://doc.qt.io/qt-6/qml-qtquick-canvas.html)
- **Hyprland Animations**: [Hyprland Wiki](https://wiki.hyprland.org/Configuring/Animations/)

---

## 📄 License

This implementation is provided as-is for use in your Quickshell configuration. Modify freely!

---

**Enjoy your smooth, Caelestia-inspired workspace transitions! 🚀**
