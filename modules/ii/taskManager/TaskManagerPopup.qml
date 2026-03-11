import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    property bool active: false

    GlobalShortcut {
        name: "toggleTaskManager"
        description: "Toggles the debugging task manager"
        onPressed: root.active = !root.active
    }

    // Keep the task manager in a LazyLoader
    LazyLoader {
        id: popupLoader
        active: root.active

        onActiveChanged: {
            if (active && popupLoader.item) {
                // Ensure data represents the latest when opened
                popupLoader.item.refreshData()
            }
        }

        PanelWindow {
            id: popup

            function refreshData() {
                psCommand.start()
            }

            exclusiveZone: 0
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:taskManager"
            color: "transparent"

            // Click outside to close
            MouseArea {
                anchors.fill: parent
                onClicked: root.active = false
            }

            Rectangle {
                id: popupBg
                anchors.centerIn: parent
                width: 660
                height: 440
                radius: 16
                color: Qt.rgba(0.05, 0.05, 0.07, 0.93)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Task Manager (Top 10 Processes)"
                            color: "white"
                            font.family: "Inter" // Standard modern font
                            font.pixelSize: 18
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        // Close Button
                        Rectangle {
                            width: 24
                            height: 24
                            color: closeMouseArea.containsMouse ? "#ffffff" : "transparent"
                            radius: 12

                            Text {
                                text: "X"
                                anchors.centerIn: parent
                                color: closeMouseArea.containsMouse ? "black" : "#ff4444"
                                font.bold: true
                            }

                            MouseArea {
                                id: closeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.active = false
                            }
                        }
                    }

                    // Header Row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                        spacing: 12

                        Text { text: "PID"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 60; font.letterSpacing: 1 }
                        Text { text: "PROCESS"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; font.letterSpacing: 1 }
                        Text { text: "CPU"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight; font.letterSpacing: 1 }
                        Text { text: "MEM"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight; font.letterSpacing: 1 }
                    }

                    // Separation Line
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.1)
                    }

                    // Process List
                    ListView {
                        id: processList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: ListModel { id: processModel }
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: processList.width
                            height: 36
                            color: hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                            radius: 8

                            MouseArea {
                                id: hoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 12

                                Text {
                                    text: model.pid
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                    font.family: "JetBrains Mono NF"
                                    font.pixelSize: 13
                                    Layout.preferredWidth: 60 - 8
                                }

                                Text {
                                    text: model.comm
                                    color: "white"
                                    elide: Text.ElideRight
                                    font.family: "Inter"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                }

                                // CPU Column with Progress bar
                                RowLayout {
                                    Layout.preferredWidth: 80
                                    spacing: 6
                                    Item { Layout.fillWidth: true } // spacer
                                    Rectangle {
                                        width: Math.min(40, Math.max(2, parseFloat(model.cpu) * 0.4))
                                        height: 4
                                        radius: 2
                                        color: parseFloat(model.cpu) > 20.0 ? "#ff5252" : (parseFloat(model.cpu) > 5.0 ? "#ffd740" : "#69f0ae")
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Text {
                                        text: parseFloat(model.cpu).toFixed(1) + "%"
                                        color: parseFloat(model.cpu) > 20.0 ? "#ff5252" : Qt.rgba(1, 1, 1, 0.7)
                                        font.family: "JetBrains Mono NF"
                                        font.pixelSize: 13
                                        horizontalAlignment: Text.AlignRight
                                        Layout.preferredWidth: 45
                                    }
                                }

                                // MEM Column with Progress bar
                                RowLayout {
                                    Layout.preferredWidth: 80
                                    spacing: 6
                                    Item { Layout.fillWidth: true } // spacer
                                    Rectangle {
                                        width: Math.min(40, Math.max(2, parseFloat(model.mem) * 0.4))
                                        height: 4
                                        radius: 2
                                        color: parseFloat(model.mem) > 10.0 ? "#ff5252" : (parseFloat(model.mem) > 5.0 ? "#b388ff" : "#4fc3f7")
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Text {
                                        text: parseFloat(model.mem).toFixed(1) + "%"
                                        color: parseFloat(model.mem) > 10.0 ? "#ff5252" : Qt.rgba(1, 1, 1, 0.7)
                                        font.family: "JetBrains Mono NF"
                                        font.pixelSize: 13
                                        horizontalAlignment: Text.AlignRight
                                        Layout.preferredWidth: 45
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Command process to fetch the data
            Process {
                id: psCommand
                command: ["sh", "-c", "ps -eo pid,pcpu,pmem,comm --sort=-pcpu | head -n 11 | tail -n +2"]

                stdout: StdioCollector {
                    id: processOutput
                    onStreamFinished: {
                        processModel.clear()
                        let outputData = processOutput.text
                        if (outputData.length > 0) {
                            let lines = outputData.trim().split("\n")
                            for (let i = 0; i < lines.length; i++) {
                                // Split by whitespace
                                let parts = lines[i].trim().split(/\s+/)
                                if (parts.length >= 4) {
                                    // Extract and join the command in case it has spaces
                                    let pidV = parts[0]
                                    let cpuV = parts[1]
                                    let memV = parts[2]
                                    let commV = parts.slice(3).join(" ")

                                    processModel.append({
                                        pid: pidV,
                                        cpu: cpuV,
                                        mem: memV,
                                        comm: commV
                                    })
                                }
                            }
                        }
                    }
                }
            }

            // Timer to periodically update the data
            Timer {
                interval: 2000 // 2 seconds
                running: root.active // Only run when popup is open
                repeat: true
                onTriggered: {
                    psCommand.start()
                }
            }
        }
    }
}
