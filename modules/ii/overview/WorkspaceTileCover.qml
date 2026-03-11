pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  WORKSPACE TILE WITH COVER/STACKING TRANSITION
 * ════════════════════════════════════════════════════════════════════════════
 * 
 *  This component demonstrates the "cover" transition effect with:
 *    • Manual z-index management (higher z for entering workspace)
 *    • Spring physics: spring 3.5, damping 0.25
 *    • Entering workspace: slides from parent.width → 0
 *    • Exiting workspace: slides to -20% with opacity fade
 *    • 40px slant parallelogram with 20px inverted corner
 */

Item {
    id: tile
    
    // ══════════════════════════════════════════════════════════════
    //  PROPERTIES
    // ══════════════════════════════════════════════════════════════
    required property int workspaceId
    required property bool isActive
    required property bool isTransitionTarget  // Set to true for entering workspace
    required property bool isTransitionSource   // Set to true for exiting workspace
    
    property real targetX: 0
    property real targetOpacity: 1.0
    property int dynamicZ: 0
    
    property bool isHovered: false
    property color baseColor: Qt.rgba(0.09, 0.10, 0.13, 0.90)
    property color hoverColor: Qt.rgba(0.13, 0.15, 0.20, 0.95)
    property color accentColor: "#40E0D0"
    
    // ══════════════════════════════════════════════════════════════
    //  GEOMETRY: Parallelogram with inverted scoop
    // ══════════════════════════════════════════════════════════════
    property real slantOffset: 40      // 40px slant on right edge
    property real invertedCornerSize: 20  // 20px inverted corner radius
    
    implicitWidth: 400
    implicitHeight: 250
    
    // Actual position follows targetX/targetOpacity with spring physics
    x: targetX
    opacity: targetOpacity
    z: dynamicZ
    
    // ══════════════════════════════════════════════════════════════
    //  SPRING ANIMATIONS (Caelestia-style physics)
    // ══════════════════════════════════════════════════════════════
    Behavior on x {
        enabled: isTransitionTarget || isTransitionSource
        SpringAnimation {
            spring: 3.5
            damping: 0.25
            mass: 1.0
        }
    }
    
    Behavior on opacity {
        enabled: isTransitionSource
        SpringAnimation {
            spring: 3.5
            damping: 0.25
            mass: 1.0
        }
    }
    
    Behavior on z {
        enabled: false  // Z changes should be instant
    }
    
    // ══════════════════════════════════════════════════════════════
    //  TRANSITION STATE MANAGEMENT
    // ══════════════════════════════════════════════════════════════
    onIsTransitionTargetChanged: {
        if (isTransitionTarget) {
            // Entering workspace: slide from right
            targetX = 0
            targetOpacity = 1.0
            dynamicZ = 100  // High z to render on top
        }
    }
    
    onIsTransitionSourceChanged: {
        if (isTransitionSource) {
            // Exiting workspace: partial slide + fade
            targetX = -tile.width * 0.2
            targetOpacity = 0.5
            // Keep existing z (stays below)
        } else if (!isActive) {
            // Reset to off-screen if not active
            targetX = 0
            targetOpacity = 1.0
            dynamicZ = 0
        }
    }
    
    onIsActiveChanged: {
        if (isActive && !isTransitionTarget) {
            // Reset to normal state when becoming active without transition
            targetX = 0
            targetOpacity = 1.0
            dynamicZ = 50
        }
    }
    
    // ══════════════════════════════════════════════════════════════
    //  VISUAL BODY: Parallelogram with inverted corner
    // ══════════════════════════════════════════════════════════════
    Item {
        id: bodyContainer
        anchors.fill: parent
        clip: true
        
        // Use Canvas for custom parallelogram shape
        Canvas {
            id: shapeCanvas
            anchors.fill: parent
            
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                
                const w = width
                const h = height
                const slant = tile.slantOffset
                const scoop = tile.invertedCornerSize
                
                // ────────────────────────────────────────────────
                //  PARALLELOGRAM PATH with INVERTED CORNER
                // ────────────────────────────────────────────────
                ctx.beginPath()
                
                // Top-left corner (normal)
                ctx.moveTo(0, 0)
                
                // Top edge to near top-right
                ctx.lineTo(w - slant - scoop, 0)
                
                // Top-right with inverted scoop
                ctx.quadraticCurveTo(
                    w - slant, 0,           // control point
                    w - slant, scoop        // end point
                )
                
                // Right edge (slanted)
                ctx.lineTo(w, h - scoop)
                
                // Bottom-right corner (slanted)
                ctx.quadraticCurveTo(
                    w, h,
                    w - scoop, h
                )
                
                // Bottom edge
                ctx.lineTo(scoop + slant, h)
                
                // Bottom-left with inverted scoop
                ctx.quadraticCurveTo(
                    slant, h,
                    slant, h - scoop
                )
                
                // Left edge (slanted)
                ctx.lineTo(0, scoop)
                
                // Top-left close with inverted scoop
                ctx.quadraticCurveTo(
                    0, 0,
                    scoop, 0
                )
                
                ctx.closePath()
                
                // Fill
                ctx.fillStyle = tile.isHovered ? tile.hoverColor : tile.baseColor
                ctx.fill()
                
                // Border
                ctx.strokeStyle = tile.isActive ? tile.accentColor : Qt.rgba(1, 1, 1, 0.07)
                ctx.lineWidth = tile.isActive ? 2 : 1
                ctx.stroke()
            }
            
            // Redraw when colors change
            Connections {
                target: tile
                function onIsHoveredChanged() { shapeCanvas.requestPaint() }
                function onIsActiveChanged() { shapeCanvas.requestPaint() }
            }
        }
        
        // ──────────────────────────────────────────────────────────
        //  SPECULAR HIGHLIGHT (top edge)
        // ──────────────────────────────────────────────────────────
        Rectangle {
            x: tile.slantOffset * 0.3
            y: 1
            width: parent.width - tile.slantOffset * 0.6
            height: 1
            radius: 0.5
            color: tile.isActive ? tile.accentColor : "white"
            opacity: tile.isActive ? 0.3 : 0.08
            
            Behavior on opacity {
                NumberAnimation { duration: 220 }
            }
        }
        
        // ──────────────────────────────────────────────────────────
        //  WORKSPACE NUMBER
        // ──────────────────────────────────────────────────────────
        Text {
            anchors.centerIn: parent
            text: tile.workspaceId
            font {
                pixelSize: parent.height * 0.5
                weight: Font.Bold
                family: Appearance.font.family.expressive
            }
            color: tile.isActive ? Qt.rgba(0.25, 0.88, 0.82, 0.44)
                 : tile.isHovered ? Qt.rgba(1, 1, 1, 0.22)
                 : Qt.rgba(1, 1, 1, 0.06)
            
            Behavior on color {
                ColorAnimation { duration: 180 }
            }
        }
    }
    
    // ══════════════════════════════════════════════════════════════
    //  INTERACTION
    // ══════════════════════════════════════════════════════════════
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: tile.isHovered = true
        onExited: tile.isHovered = false
    }
}
