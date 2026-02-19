// Brawl Stars Style Profile HUD
// Main profile with hexagonal frame, stats badges, and selectable user profiles below

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.modules.common
import qs.services

Item {
    id: root

    property real screenWidth: 1920
    property real screenHeight: 1080
    property real scaledScreenWidth: screenWidth
    property real scaledScreenHeight: screenHeight
    // Data bindings
    readonly property real healthPercentage: Battery.available ? Battery.percentage : 1
    readonly property real staminaPercentage: 1 - ResourceUsage.memoryUsedPercentage
    readonly property bool isCharging: Battery.available && UPower.displayDevice.state === UPowerState.Charging
    readonly property string userName: SystemInfo.username || "Player"
    readonly property int cpuUsage: Math.round(ResourceUsage.cpuUsage * 100)
    readonly property int memUsage: Math.round(ResourceUsage.memoryUsedPercentage * 100)
    // Uptime in hours
    property int uptimeHours: 0
    // Profile selection
    property int selectedProfile: 0
    property var profileNames: [userName]
    // Theme palette shortcuts
    readonly property QtObject palette: Appearance.colors
    readonly property QtObject rounding: Appearance.rounding

    width: scaledScreenWidth
    height: scaledScreenHeight
    // Entrance animation
    Component.onCompleted: {
        hudContainer.opacity = 0;
        fadeIn.start();
    }

    // Get system uptime
    Process {
        id: getUptime

        command: ["sh", "-c", "awk '{print int($1/3600)}' /proc/uptime"]
        running: false
        onExited: {
            var hours = parseInt(stdout.trim());
            if (!isNaN(hours))
                uptimeHours = hours;

        }
    }

    // Timer to refresh uptime periodically
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            getUptime.running = true;
        }
    }

    // Main container
    Item {
        id: hudContainer

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 30
        anchors.topMargin: 30
        width: 340
        height: 190

        // Top section: Main profile card
        Rectangle {
            id: mainCard

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 12
            width: parent.width
            height: 110
            radius: rounding.small
            color: palette.colLayer2
            border.color: palette.colOutlineVariant
            border.width: 1
            layer.enabled: true

            // Accent top bar
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                height: 6
                radius: parent.radius
                color: palette.colPrimary
                opacity: 0.9
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14

                // Left: Hex avatar stack
                Column {
                    width: 86
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    Canvas {
                        id: hexFrame

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 76
                        height: 76
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var cx = width / 2;
                            var cy = height / 2;
                            var r = 34;
                            ctx.beginPath();
                            for (var i = 0; i < 6; i++) {
                                var angle = (Math.PI / 3) * i - Math.PI / 2;
                                var x = cx + r * Math.cos(angle);
                                var y = cy + r * Math.sin(angle);
                                if (i === 0)
                                    ctx.moveTo(x, y);
                                else
                                    ctx.lineTo(x, y);
                            }
                            ctx.closePath();
                            var grad = ctx.createLinearGradient(0, 0, width, height);
                            grad.addColorStop(0, palette.colPrimaryContainer);
                            grad.addColorStop(1, palette.colSurfaceContainerHigh);
                            ctx.fillStyle = grad;
                            ctx.fill();
                            ctx.strokeStyle = palette.colOutlineVariant;
                            ctx.lineWidth = 3;
                            ctx.stroke();
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "👤"
                            font.pixelSize: 30
                        }

                    }

                    // Info pills under avatar
                    RowLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Rectangle {
                            height: 20
                            width: 48
                            radius: 6
                            color: palette.colSecondaryContainer
                            border.color: palette.colOutlineVariant

                            Text {
                                anchors.centerIn: parent
                                text: root.uptimeHours + "h"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: palette.colOnSecondaryContainer
                            }

                        }

                        Rectangle {
                            visible: root.isCharging
                            height: 20
                            width: 32
                            radius: 6
                            color: palette.colPrimary
                            border.color: palette.colOutlineVariant

                            Text {
                                anchors.centerIn: parent
                                text: "⚡"
                                font.pixelSize: 11
                                color: palette.colOnPrimary
                            }

                        }

                    }

                }

                // Right: Details
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    // Name and status bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: root.userName
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                color: palette.colOnSurface
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: palette.colLayer1

                                Rectangle {
                                    width: Math.max(12, parent.width * root.healthPercentage)
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height
                                    radius: parent.radius

                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal

                                        GradientStop {
                                            position: 0
                                            color: palette.colPrimary
                                        }

                                        GradientStop {
                                            position: 1
                                            color: palette.colSecondary
                                        }

                                    }

                                }

                            }

                        }

                    }

                    // Stat chips
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [{
                                "icon": "⚙",
                                "label": root.cpuUsage + "%",
                                "fill": palette.colPrimary
                            }, {
                                "icon": "❤",
                                "label": Math.round(root.healthPercentage * 100),
                                "fill": palette.colError
                            }, {
                                "icon": "💾",
                                "label": root.memUsage + "%",
                                "fill": palette.colTertiary
                            }]

                            Rectangle {
                                required property var modelData

                                radius: 8
                                height: 26
                                width: 100
                                color: ColorUtils.transparentize(palette.colLayer3, 0.1)
                                border.color: palette.colOutlineVariant
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 13
                                        color: modelData.fill
                                    }

                                    Text {
                                        text: modelData.label
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: palette.colOnSurface
                                    }

                                }

                            }

                        }

                    }

                    // Dual bars
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            height: 8
                            radius: 4
                            color: palette.colLayer1

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(10, parent.width * root.healthPercentage)
                                height: parent.height
                                radius: parent.radius
                                color: palette.colPrimary
                            }

                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 8
                            radius: 4
                            color: palette.colLayer1

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(10, parent.width * root.staminaPercentage)
                                height: parent.height
                                radius: parent.radius
                                color: palette.colTertiary
                            }

                        }

                    }

                }

            }

            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 8
                radius: 22
                samples: 28
                color: ColorUtils.transparentize(palette.colShadow, 0.6)
            }

        }

    }

    NumberAnimation {
        id: fadeIn

        target: hudContainer
        property: "opacity"
        from: 0
        to: 1
        duration: 500
        easing.type: Easing.OutCubic
    }

}
