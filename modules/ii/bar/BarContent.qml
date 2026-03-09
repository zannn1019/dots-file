import qs.modules.ii.bar.weather
import qs.modules.ii.dock
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    property string hostname: "localhost"
    Process {
        id: hostnameProc
        running: true
        command: ["cat", "/etc/hostname"]
        stdout: SplitParser {
            onRead: data => root.hostname = data.trim()
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  LEFT — Floating Pill (Sidebar + Workspaces)
    // ══════════════════════════════════════════════════════════════
    Rectangle {
        id: leftFloatingPill
        anchors {
            verticalCenter: parent.verticalCenter
            left:           parent.left
            leftMargin:     12
        }
        width:  leftRow.implicitWidth + 24
        height: parent.height - 12
        color:  "transparent"
        radius: height / 2

        WheelHandler {
            onWheel: event => {
                if (event.angleDelta.y > 0)
                    root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + 0.05)
                else
                    root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness - 0.05)
            }
        }

        RowLayout {
            id: leftRow
            anchors.centerIn: parent
            spacing: 8

            LeftSidebarButton {
                Layout.alignment: Qt.AlignVCenter
            }

            Workspaces {
                Layout.alignment: Qt.AlignVCenter
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onPressed: event => {
                        if (event.button === Qt.RightButton)
                            GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  CENTER — Floating Pill (User@Host)
    // ══════════════════════════════════════════════════════════════
    Rectangle {
        id: centerFloatingPill
        anchors {
            verticalCenter:   parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
        }

        width:  centerRow.implicitWidth + 32
        height: parent.height - 12
        radius: height / 2
        color:  centerPillMouse.containsMouse
                    ? (GlobalStates.islandOpen ? Appearance.colors.colLayer2Active : Appearance.colors.colLayer2Hover)
                    : (GlobalStates.islandOpen ? Appearance.colors.colLayer2Hover  : "transparent")

        Behavior on width {
            NumberAnimation {
                duration: 350
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
            }
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        RowLayout {
            id: centerRow
            anchors.centerIn: parent
            spacing: 8

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                font.pixelSize:   Appearance.font.pixelSize.normal
                color:            Appearance.colors.colOnLayer1
                text:             `${SystemInfo.username}@${root.hostname}`
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text:     GlobalStates.islandOpen ? "expand_less" : "expand_more"
                fill:     0
                iconSize: Appearance.font.pixelSize.normal
                color:    Appearance.colors.colSubtext
            }
        }

        MouseArea {
            id: centerPillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onPressed: GlobalStates.islandOpen = !GlobalStates.islandOpen
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  RIGHT — Floating Pill (Sync + Clock + Power)
    // ══════════════════════════════════════════════════════════════
    Rectangle {
        id: rightFloatingPill
        anchors {
            verticalCenter: parent.verticalCenter
            right:          parent.right
            rightMargin:    12
        }
        width:  rightRow.implicitWidth + 24
        height: parent.height - 12
        color:  "transparent"
        radius: height / 2

        WheelHandler {
            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume()
                else
                    Audio.decrementVolume()
            }
        }

        RowLayout {
            id: rightRow
            anchors.centerIn: parent
            spacing: 10

            MaterialSymbol {
                text:     "sync"
                iconSize: Appearance.font.pixelSize.large
                color:    Appearance.colors.colOnLayer0
                RotationAnimator on rotation {
                    running:  Updates.checking
                    loops:    Animation.Infinite
                    from:     0
                    to:       360
                    duration: 1000
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: Updates.refresh()
                }
            }

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.normal
                color:          Appearance.colors.colOnLayer0
                text:           DateTime.time
                MouseArea {
                    anchors.fill: parent
                    onPressed: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }
            }

            MaterialSymbol {
                text:     "power_settings_new"
                iconSize: Appearance.font.pixelSize.large
                color:    Appearance.colors.colOnLayer0
                MouseArea {
                    anchors.fill: parent
                    onPressed: GlobalStates.sessionOpen = !GlobalStates.sessionOpen
                }
            }
        }
    }
}