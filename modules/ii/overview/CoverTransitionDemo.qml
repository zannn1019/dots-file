pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  COVER TRANSITION DEMO
 * ════════════════════════════════════════════════════════════════════════════
 * 
 *  Standalone demo to test the cover/stacking transition independently.
 *  Click the buttons at the bottom to trigger workspace transitions.
 *  
 *  Usage: Run this as a standalone QML file to visualize the transition.
 */

Rectangle {
    id: demoRoot
    width: 1200
    height: 800
    color: "#0a0b10"

    // ══════════════════════════════════════════════════════════════
    //  DEMO STATE
    // ══════════════════════════════════════════════════════════════
    property int currentWorkspace: 1
    property int previousWorkspace: -1
    property int nextZ: 100
    
    onCurrentWorkspaceChanged: {
        if (currentWorkspace === -1) return
        const old = previousWorkspace
        const now = currentWorkspace
        if (old !== -1 && old !== now) {
            nextZ += 1
        }
        previousWorkspace = now
    }

    // ══════════════════════════════════════════════════════════════
    //  TITLE
    // ══════════════════════════════════════════════════════════════
    Text {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 40
        }
        text: "Cover/Stacking Transition Demo"
        font {
            pixelSize: 32
            weight: Font.Bold
        }
        color: "#40E0D0"
    }

    Text {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 80
        }
        text: "Current Workspace: " + demoRoot.currentWorkspace
        font.pixelSize: 20
        color: "#ffffff"
    }

    // ══════════════════════════════════════════════════════════════
    //  WORKSPACE CONTAINER
    // ══════════════════════════════════════════════════════════════
    Item {
        id: workspaceStack
        anchors {
            centerIn: parent
            verticalCenterOffset: 40
        }
        width: 800
        height: 500
        clip: true

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 2
            radius: 12
        }

        // ──────────────────────────────────────────────────────────
        //  WORKSPACE TILES (4 workspaces for demo)
        // ──────────────────────────────────────────────────────────
        Repeater {
            model: 4
            delegate: Item {
                id: wsContainer
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === demoRoot.currentWorkspace
                readonly property bool wasActive: wsId === demoRoot.previousWorkspace
                readonly property bool isEntering: isActive && wasActive === false && demoRoot.previousWorkspace !== -1
                readonly property bool isExiting: wasActive && !isActive

                property real targetX: 0
                property real targetOpacity: 1.0
                property int tileZ: 0

                width: workspaceStack.width
                height: workspaceStack.height

                // State machine for transitions
                states: [
                    State {
                        name: "entering"
                        when: wsContainer.isEntering
                        PropertyChanges {
                            target: wsContainer
                            targetX: 0
                            targetOpacity: 1.0
                            tileZ: demoRoot.nextZ
                        }
                    },
                    State {
                        name: "exiting"
                        when: wsContainer.isExiting
                        PropertyChanges {
                            target: wsContainer
                            targetX: -workspaceStack.width * 0.2
                            targetOpacity: 0.5
                        }
                    },
                    State {
                        name: "normal"
                        when: !wsContainer.isEntering && !wsContainer.isExiting
                        PropertyChanges {
                            target: wsContainer
                            targetX: 0
                            targetOpacity: wsContainer.isActive ? 1.0 : 0.0
                            tileZ: wsContainer.isActive ? 50 : 0
                        }
                    }
                ]

                // Visual tile
                Item {
                    id: tile
                    anchors.fill: parent
                    x: wsContainer.targetX
                    opacity: wsContainer.targetOpacity
                    z: wsContainer.tileZ
                    visible: wsContainer.isActive || wsContainer.isEntering || wsContainer.isExiting

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

                    // Parallelogram shape
                    Canvas {
                        id: canvas
                        anchors.fill: parent

                        readonly property real slant: 40
                        readonly property real scoop: 20
                        readonly property color fillColor: {
                            const hue = (wsContainer.wsId - 1) * 0.25
                            return Qt.hsla(hue, 0.6, 0.3, 0.9)
                        }

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()

                            const w = width
                            const h = height

                            // Parallelogram with inverted corners
                            ctx.beginPath()
                            ctx.moveTo(scoop, 0)
                            ctx.lineTo(w - slant - scoop, 0)
                            ctx.quadraticCurveTo(w - slant, 0, w - slant, scoop)
                            ctx.lineTo(w, h - scoop)
                            ctx.quadraticCurveTo(w, h, w - scoop, h)
                            ctx.lineTo(scoop + slant, h)
                            ctx.quadraticCurveTo(slant, h, slant, h - scoop)
                            ctx.lineTo(0, scoop)
                            ctx.quadraticCurveTo(0, 0, scoop, 0)
                            ctx.closePath()

                            // Fill
                            ctx.fillStyle = fillColor
                            ctx.fill()

                            // Border
                            ctx.strokeStyle = wsContainer.isActive ? "#40E0D0" : Qt.rgba(1, 1, 1, 0.2)
                            ctx.lineWidth = wsContainer.isActive ? 3 : 1
                            ctx.stroke()
                        }

                        Component.onCompleted: requestPaint()
                        Connections {
                            target: wsContainer
                            function onIsActiveChanged() { canvas.requestPaint() }
                        }
                    }

                    // Workspace label
                    Text {
                        anchors.centerIn: parent
                        text: "Workspace " + wsContainer.wsId
                        font {
                            pixelSize: 80
                            weight: Font.Bold
                        }
                        color: wsContainer.isActive ? Qt.rgba(0.25, 0.88, 0.82, 0.6)
                             : Qt.rgba(1, 1, 1, 0.3)
                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }

                    // Z-index indicator
                    Text {
                        anchors {
                            top: parent.top
                            right: parent.right
                            margins: 20
                        }
                        text: "z: " + tile.z
                        font.pixelSize: 18
                        color: "#ffffff"
                        opacity: 0.5
                    }

                    // State indicator
                    Text {
                        anchors {
                            top: parent.top
                            left: parent.left
                            margins: 20
                        }
                        text: {
                            if (wsContainer.isEntering) return "→ ENTERING"
                            if (wsContainer.isExiting) return "← EXITING"
                            if (wsContainer.isActive) return "● ACTIVE"
                            return "○ Inactive"
                        }
                        font {
                            pixelSize: 16
                            weight: Font.Medium
                        }
                        color: wsContainer.isEntering ? "#4CAF50"
                             : wsContainer.isExiting ? "#FF9800"
                             : wsContainer.isActive ? "#2196F3"
                             : "#666666"
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  CONTROL BUTTONS
    // ══════════════════════════════════════════════════════════════
    Row {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 60
        }
        spacing: 16

        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === demoRoot.currentWorkspace

                width: 120
                height: 50
                radius: 8
                color: isActive ? "#40E0D0" : Qt.rgba(0.2, 0.2, 0.2, 0.8)
                border.color: isActive ? "#ffffff" : Qt.rgba(1, 1, 1, 0.3)
                border.width: 2

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }

                Text {
                    anchors.centerIn: parent
                    text: "WS " + wsId
                    font {
                        pixelSize: 20
                        weight: Font.Bold
                    }
                    color: isActive ? "#000000" : "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        demoRoot.currentWorkspace = wsId
                    }
                    onEntered: parent.scale = 1.05
                    onExited: parent.scale = 1.0
                }

                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  PHYSICS INFO
    // ══════════════════════════════════════════════════════════════
    Rectangle {
        anchors {
            bottom: parent.bottom
            left: parent.left
            margins: 20
        }
        width: 280
        height: infoText.height + 24
        radius: 8
        color: Qt.rgba(0, 0, 0, 0.7)
        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1

        Text {
            id: infoText
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                margins: 12
            }
            text: "Spring Physics:\n• spring: 3.5\n• damping: 0.25\n• slide offset: 20%"
            font.pixelSize: 14
            color: "#ffffff"
            lineHeight: 1.3
        }
    }
}
