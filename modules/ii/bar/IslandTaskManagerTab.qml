import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Task Manager tab content — top processes by CPU/RAM
ColumnLayout {
    id: root

    // Whether the island is open — drives auto-refresh
    required property bool islandOpen

    spacing: 8

    ListModel { id: processModel }

    Process {
        id: psCommand
        command: ["sh", "-c", "ps -eo pcpu,pmem,comm --sort=-pcpu | head -n 11 | tail -n +2"]

        // Clear model each time a new run starts
        onStarted: processModel.clear()

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const parts = data.trim().split(/\s+/)
                if (parts.length >= 3 && data.trim().length > 0) {
                    processModel.append({
                        cpu:  parts[0],
                        mem:  parts[1],
                        comm: parts.slice(2).join(" ")
                    })
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: root.islandOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: psCommand.start()
    }

    // ═══════════════════════════════════════════════
    //  Global usage summary pills
    // ═══════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: "monitor_heart"
            fill: 1
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colPrimary
        }

        StyledText {
            text: "Processes"
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer1
            Layout.fillWidth: true
        }

        // CPU pill
        Rectangle {
            implicitWidth: cpuLabel.implicitWidth + 16
            implicitHeight: 22
            radius: Appearance.rounding.full
            color: ResourceUsage.cpuUsage > 0.7 ? Qt.alpha(Appearance.m3colors.m3error, 0.2)
                 : Appearance.colors.colSecondaryContainer
            StyledText {
                id: cpuLabel
                anchors.centerIn: parent
                text: "CPU " + Math.round(ResourceUsage.cpuUsage * 100) + "%"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ResourceUsage.cpuUsage > 0.7 ? Appearance.m3colors.m3error
                     : Appearance.colors.colOnLayer1
            }
        }

        // RAM pill
        Rectangle {
            implicitWidth: ramLabel.implicitWidth + 16
            implicitHeight: 22
            radius: Appearance.rounding.full
            color: ResourceUsage.memoryUsedPercentage > 0.8 ? Qt.alpha(Appearance.m3colors.m3error, 0.2)
                 : Appearance.colors.colSecondaryContainer
            StyledText {
                id: ramLabel
                anchors.centerIn: parent
                text: "RAM " + Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ResourceUsage.memoryUsedPercentage > 0.8 ? Appearance.m3colors.m3error
                     : Appearance.colors.colOnLayer1
            }
        }
    }

    // ═══════════════════════════════════════════════
    //  Column headers
    // ═══════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        StyledText {
            text: "PROCESS"
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            font.weight: Font.Medium
            Layout.fillWidth: true
        }
        StyledText {
            text: "CPU"
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            font.weight: Font.Medium
            Layout.preferredWidth: 70
            horizontalAlignment: Text.AlignRight
        }
        StyledText {
            text: "MEM"
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            font.weight: Font.Medium
            Layout.preferredWidth: 70
            horizontalAlignment: Text.AlignRight
        }
    }

    // Divider
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Appearance.colors.colLayer0Border
    }

    // ═══════════════════════════════════════════════
    //  Process rows
    // ═══════════════════════════════════════════════
    Repeater {
        model: processModel

        delegate: Rectangle {
            required property string comm
            required property string cpu
            required property string mem

            width: parent?.width ?? 0
            implicitHeight: 30
            radius: Appearance.rounding.small
            color: rowHover.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"

            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                spacing: 6

                // Process name
                StyledText {
                    text: comm
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // CPU bar + value
                RowLayout {
                    spacing: 4
                    Layout.preferredWidth: 70
                    Layout.alignment: Qt.AlignVCenter

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: Math.min(30, Math.max(2, parseFloat(cpu) * 0.3))
                        height: 4
                        radius: 2
                        color: parseFloat(cpu) > 20 ? Appearance.m3colors.m3error
                             : parseFloat(cpu) > 5  ? Appearance.colors.colPrimary
                             : Appearance.colors.colSecondaryContainer
                    }

                    StyledText {
                        text: parseFloat(cpu).toFixed(1) + "%"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: parseFloat(cpu) > 20 ? Appearance.m3colors.m3error
                             : Appearance.colors.colSubtext
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 36
                    }
                }

                // MEM bar + value
                RowLayout {
                    spacing: 4
                    Layout.preferredWidth: 70
                    Layout.alignment: Qt.AlignVCenter

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: Math.min(30, Math.max(2, parseFloat(mem) * 0.3))
                        height: 4
                        radius: 2
                        color: parseFloat(mem) > 10 ? Appearance.m3colors.m3error
                             : parseFloat(mem) > 5  ? Appearance.colors.colTertiary
                             : Appearance.colors.colSecondaryContainer
                    }

                    StyledText {
                        text: parseFloat(mem).toFixed(1) + "%"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: parseFloat(mem) > 10 ? Appearance.m3colors.m3error
                             : Appearance.colors.colSubtext
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 36
                    }
                }
            }
        }
    }
}
