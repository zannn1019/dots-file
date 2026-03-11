pragma ComponentBehavior: Bound
import QtQuick
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
 *  OVERVIEW WIDGET WITH COVER/STACKING WORKSPACE TRANSITIONS
 * ════════════════════════════════════════════════════════════════════════════
 * 
 *  Drop-in replacement with enhanced workspace transitions:
 *    • Cover effect: new workspace slides over old one
 *    • Old workspace slides back 20% and fades to 0.5 opacity
 *    • Spring physics: spring 3.5, damping 0.25
 *    • Parallelogram tiles: 40px slant, 20px inverted corners
 *    • Manual z-index management for proper stacking
 * 
 *  To use: Replace your current OverviewWidget import with this file
 */

Item {
    id: root
    required property var panelWindow
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property var toplevels: ToplevelManager.toplevels
    readonly property int workspacesShown: Config.options.overview.rows * Config.options.overview.columns
    readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - 1) / workspacesShown)
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real scale: Config.options.overview.scale

    // ══════════════════════════════════════════════════════════════
    //  WORKSPACE TRANSITION STATE
    // ══════════════════════════════════════════════════════════════
    property int previousActiveWorkspaceId: -1
    property int currentActiveWorkspaceId: monitor.activeWorkspace?.id ?? -1
    property int nextZIndex: 100
    
    onCurrentActiveWorkspaceIdChanged: {
        if (currentActiveWorkspaceId === -1) return
        
        const oldId = previousActiveWorkspaceId
        const newId = currentActiveWorkspaceId
        
        if (oldId !== -1 && oldId !== newId) {
            // Trigger cover transition
            workspaceTransitionTimer.restart()
        }
        
        previousActiveWorkspaceId = newId
    }
    
    Timer {
        id: workspaceTransitionTimer
        interval: 50  // Small delay for property propagation
        repeat: false
        onTriggered: {
            // Z-index management handled in tile delegate
            nextZIndex += 1
        }
    }

    // ── Palette ──────────────────────────────────────────────────────
    readonly property color c0:  "#0a0b10"
    readonly property color acc: "#40E0D0"
    readonly property color accDim: Qt.rgba(0.25, 0.88, 0.82, 0.22)
    readonly property color accGlow: Qt.rgba(0.25, 0.88, 0.82, 0.08)

    // ── Workspace geometry ──────────────────────────────────────────
    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1)
        ? ((monitor.height - (monitorData?.reserved[0]??0) - (monitorData?.reserved[2]??0)) * root.scale / monitor.scale)
        : ((monitor.width  - (monitorData?.reserved[0]??0) - (monitorData?.reserved[2]??0)) * root.scale / monitor.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1)
        ? ((monitor.width  - (monitorData?.reserved[1]??0) - (monitorData?.reserved[3]??0)) * root.scale / monitor.scale)
        : ((monitor.height - (monitorData?.reserved[1]??0) - (monitorData?.reserved[3]??0)) * root.scale / monitor.scale)

    property real largeWorkspaceRadius: Appearance.rounding.large
    property real smallWorkspaceRadius: Appearance.rounding.verysmall
    property real workspaceSpacing: 12
    
    // Parallelogram geometry
    property real slantOffset: 40
    property real invertedCornerSize: 20

    property int workspaceZ:      0
    property int windowZ:         1
    property int windowDraggingZ: 99999

    property int draggingFromWorkspace:   -1
    property int draggingTargetWorkspace: -1

    implicitWidth:  shell.implicitWidth  + Appearance.sizes.elevationMargin * 2
    implicitHeight: shell.implicitHeight + Appearance.sizes.elevationMargin * 2

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []

    // Helper functions
    function getWsRow(ws) {
        var r = Math.floor((ws-1) / Config.options.overview.columns) % Config.options.overview.rows
        return Config.options.overview.orderBottomUp ? Config.options.overview.rows - r - 1 : r
    }
    function getWsColumn(ws) {
        var c = (ws-1) % Config.options.overview.columns
        return Config.options.overview.orderRightLeft ? Config.options.overview.columns - c - 1 : c
    }
    function getWsInCell(ri, ci) {
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - ri - 1 : ri)
               * Config.options.overview.columns
               + (Config.options.overview.orderRightLeft ? Config.options.overview.columns - ci - 1 : ci)
               + 1
    }

    StyledRectangularShadow { target: shell }

    // ════════════════════════════════════════════════════════════════
    //  OUTER SHELL
    // ════════════════════════════════════════════════════════════════
    Rectangle {
        id: shell
        readonly property real pad: 16
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth:  grid.implicitWidth  + pad * 2
        implicitHeight: grid.implicitHeight + pad * 2

        radius: largeWorkspaceRadius + pad
        color: Qt.rgba(0.04, 0.05, 0.08, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

        // Top rim catch-light
        Rectangle {
            anchors.top: parent.top; anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.65; height: 1; radius: 1
            color: Qt.rgba(1, 1, 1, 0.16)
        }

        // ══════════════════════════════════════════════════════════
        //  WORKSPACE TILES WITH COVER TRANSITION
        // ══════════════════════════════════════════════════════════
        Item {
            id: workspaceStack
            anchors.centerIn: parent
            implicitWidth: grid.implicitWidth
            implicitHeight: grid.implicitHeight
            clip: true

            Column {
                id: grid
                anchors.centerIn: parent
                spacing: root.workspaceSpacing

                Repeater {
                    model: Config.options.overview.rows
                    delegate: Row {
                        id: wsRow
                        required property int index
                        spacing: root.workspaceSpacing

                        Repeater {
                            model: Config.options.overview.columns
                            delegate: Item {
                                id: tileContainer
                                required property int index
                                property int col: index
                                property int wsVal: root.workspaceGroup * root.workspacesShown + getWsInCell(wsRow.index, col)
                                property bool isActive: wsVal === root.currentActiveWorkspaceId
                                property bool wasActive: wsVal === root.previousActiveWorkspaceId
                                
                                implicitWidth: root.workspaceImplicitWidth
                                implicitHeight: root.workspaceImplicitHeight

                                // ────────────────────────────────────────────
                                //  TRANSITION STATE
                                // ────────────────────────────────────────────
                                property bool isEntering: isActive && wasActive === false && root.previousActiveWorkspaceId !== -1
                                property bool isExiting: wasActive && !isActive
                                
                                property real targetX: 0
                                property real targetOpacity: 1.0
                                property int tileZ: 0

                                // Cover transition logic
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
                                            // Keep lower z
                                        }
                                    },
                                    State {
                                        name: "normal"
                                        when: !tileContainer.isEntering && !tileContainer.isExiting
                                        PropertyChanges {
                                            target: tileContainer
                                            targetX: 0
                                            targetOpacity: 1.0
                                            tileZ: tileContainer.isActive ? 50 : 0
                                        }
                                    }
                                ]

                                // ────────────────────────────────────────────
                                //  PARALLELOGRAM TILE WITH INVERTED CORNERS
                                // ────────────────────────────────────────────
                                Item {
                                    id: tile
                                    anchors.fill: parent
                                    x: tileContainer.targetX
                                    opacity: tileContainer.targetOpacity
                                    z: tileContainer.tileZ

                                    property bool isHovered: hoverArea.containsMouse
                                    property bool isDrop: false

                                    // Spring animations (Caelestia-style)
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
                                            mass: 1.0
                                        }
                                    }

                                    // Canvas for parallelogram shape
                                    Canvas {
                                        id: shapeCanvas
                                        anchors.fill: parent

                                        onPaint: {
                                            const ctx = getContext("2d")
                                            ctx.reset()

                                            const w = width
                                            const h = height
                                            const slant = root.slantOffset
                                            const scoop = root.invertedCornerSize

                                            // Parallelogram path with inverted corners
                                            ctx.beginPath()
                                            ctx.moveTo(scoop, 0)
                                            ctx.lineTo(w - slant - scoop, 0)
                                            
                                            // Top-right inverted corner
                                            ctx.quadraticCurveTo(w - slant, 0, w - slant, scoop)
                                            ctx.lineTo(w, h - scoop)
                                            
                                            // Bottom-right corner
                                            ctx.quadraticCurveTo(w, h, w - scoop, h)
                                            ctx.lineTo(scoop + slant, h)
                                            
                                            // Bottom-left inverted corner
                                            ctx.quadraticCurveTo(slant, h, slant, h - scoop)
                                            ctx.lineTo(0, scoop)
                                            
                                            // Top-left corner
                                            ctx.quadraticCurveTo(0, 0, scoop, 0)
                                            ctx.closePath()

                                            // Fill
                                            const baseCol = tile.isDrop ? Qt.rgba(0.20, 0.24, 0.28, 0.95)
                                                          : tile.isHovered ? Qt.rgba(0.13, 0.15, 0.20, 0.95)
                                                          : Qt.rgba(0.09, 0.10, 0.13, 0.90)
                                            ctx.fillStyle = baseCol
                                            ctx.fill()

                                            // Border
                                            ctx.strokeStyle = tile.isDrop ? root.acc
                                                            : tileContainer.isActive ? root.acc
                                                            : tile.isHovered ? Qt.rgba(1, 1, 1, 0.14)
                                                            : Qt.rgba(1, 1, 1, 0.05)
                                            ctx.lineWidth = (tile.isDrop || tileContainer.isActive) ? 2 : 1
                                            ctx.stroke()
                                        }

                                        Connections {
                                            target: tile
                                            function onIsHoveredChanged() { shapeCanvas.requestPaint() }
                                            function onIsDrop Changed() { shapeCanvas.requestPaint() }
                                        }
                                        Connections {
                                            target: tileContainer
                                            function onIsActiveChanged() { shapeCanvas.requestPaint() }
                                        }
                                    }

                                    // Specular highlight
                                    Rectangle {
                                        x: root.slantOffset * 0.3
                                        y: 1
                                        width: parent.width - root.slantOffset * 0.6
                                        height: 1
                                        radius: 0.5
                                        color: tileContainer.isActive ? root.acc : "white"
                                        opacity: tileContainer.isActive ? 0.3 : 0.08
                                        Behavior on opacity { NumberAnimation { duration: 220 } }
                                    }

                                    // Workspace number
                                    Text {
                                        anchors.centerIn: parent
                                        text: tileContainer.wsVal
                                        font {
                                            pixelSize: Math.round(root.workspaceImplicitHeight * 0.5)
                                            weight: Font.Bold
                                            family: Appearance.font.family.expressive
                                        }
                                        color: tileContainer.isActive ? Qt.rgba(0.25, 0.88, 0.82, 0.44)
                                             : tile.isHovered ? Qt.rgba(1, 1, 1, 0.22)
                                             : Qt.rgba(1, 1, 1, 0.06)
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                    }

                                    // Input handling
                                    MouseArea {
                                        id: hoverArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton
                                        onPressed: {
                                            if (root.draggingTargetWorkspace === -1) {
                                                GlobalStates.overviewOpen = false
                                                Hyprland.dispatch(`workspace ${tileContainer.wsVal}`)
                                            }
                                        }
                                    }
                                    DropArea {
                                        anchors.fill: parent
                                        onEntered: {
                                            root.draggingTargetWorkspace = tileContainer.wsVal
                                            if (root.draggingFromWorkspace !== tileContainer.wsVal) 
                                                tile.isDrop = true
                                        }
                                        onExited: {
                                            tile.isDrop = false
                                            if (root.draggingTargetWorkspace === tileContainer.wsVal) 
                                                root.draggingTargetWorkspace = -1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
