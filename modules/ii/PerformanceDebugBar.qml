import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: performanceDebugBar

    width: parent ? parent.width : 800
    height: 36
    color: Qt.rgba(0, 0, 0, 0.85)
    anchors.bottom: parent ? parent.bottom : undefined
    z: 100
    border.color: "#4fc3f7"
    border.width: 1

    RowLayout {
        anchors.fill: parent
        spacing: 16
        padding: 8

        Text {
            text: "CPU: " + SystemInfo.cpuUsage + "%"
            color: "#fff"
            font.pixelSize: 14
        }

        Text {
            text: "RAM: " + SystemInfo.memoryUsage + "%"
            color: "#fff"
            font.pixelSize: 14
        }

        Text {
            text: "GPU: " + (SystemInfo.gpuUsage !== undefined ? SystemInfo.gpuUsage + "%" : "-")
            color: "#fff"
            font.pixelSize: 14
        }

        Text {
            text: "FPS: " + SystemInfo.fps
            color: "#fff"
            font.pixelSize: 14
        }

    }

}
