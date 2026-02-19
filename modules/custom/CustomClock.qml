import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import qs.modules.common

Item {
    id: root

    property string timeString: "--:--"
    property string dayString: ""

    width: parent ? parent.width : 800
    height: parent ? parent.height : 400

    opacity: 0
    scale: 0.98

    Component.onCompleted: {
        refresh();
        appear.start();
    }

    function refresh() {
        const now = new Date();
        timeString = Qt.formatDateTime(now, "HH:mm");
        dayString = Qt.formatDateTime(now, "dddd, dd MMM");
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: refresh()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 6
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

        Text {
            id: timeText
            text: root.timeString
            font.pixelSize: 96
            font.weight: Font.Medium
            color: Appearance.colors.colOnSurface
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter

            Behavior on text {
                SequentialAnimation {
                    NumberAnimation { target: timeText; property: "scale"; from: 0.98; to: 1; duration: 140; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            id: dayText
            text: root.dayString
            font.pixelSize: 22
            color: Appearance.colors.colOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter

            Behavior on text {
                SequentialAnimation {
                    NumberAnimation { target: dayText; property: "opacity"; from: 0.4; to: 1; duration: 200 }
                }
            }
        }

        Rectangle {
            height: 2
            width: timeText.paintedWidth + 40
            radius: 1
            color: ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colOnSurface, 0.2)
            opacity: 0.5
            Layout.alignment: Qt.AlignHCenter

            NumberAnimation on width {
                from: 0
                to: timeText.paintedWidth + 40
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
    }

    ParallelAnimation {
        id: appear
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; from: 0.98; to: 1; duration: 320; easing.type: Easing.OutCubic }
    }
}
        repeat: true
        triggeredOnStart: true
        onTriggered: root.dayString = Qt.formatDateTime(new Date(), "dddd, dd MMM")
    }

}
