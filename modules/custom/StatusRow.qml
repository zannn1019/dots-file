import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// Minimal bottom-left stats strip: CPU, RAM, Battery
Item {
    id: root

    property color color: Appearance.colors.colOnSurface
    property color muted: ColorUtils.transparentize(Appearance.colors.colOnSurfaceVariant, 0.2)
    property color background: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.12)
    property real contentOpacity: 0.82
    property int iconSize: 16
    property int fontSize: Appearance.font.pixelSize.small
    property int spacing: 10
    property int padding: 10

    function percentText(v) {
        return Math.round(v * 100) + "%";
    }

    function ramPercent() {
        return ResourceUsage.memoryUsedPercentage;
    }

    function cpuPercent() {
        return ResourceUsage.cpuUsage;
    }

    function batteryPercent() {
        return Battery.available ? Battery.percentage : 0;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Rectangle {
        anchors.centerIn: parent
        color: background
        radius: height / 2
        implicitWidth: row.implicitWidth + padding * 2
        implicitHeight: Math.max(row.implicitHeight + padding * 2, 32)

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: root.spacing
            opacity: root.contentOpacity
            Layout.alignment: Qt.AlignVCenter

            IconAndTextPair {
                icon: "memory"
                text: percentText(ramPercent())
                color: root.color
                iconSize: root.iconSize
                fontSize: root.fontSize
            }

            Separator {
            }

            IconAndTextPair {
                icon: "speed"
                text: percentText(cpuPercent())
                color: root.color
                iconSize: root.iconSize
                fontSize: root.fontSize
            }

            Separator {
                visible: Battery.available
            }

            IconAndTextPair {
                visible: Battery.available
                icon: Battery.isCharging ? "bolt" : "battery_horiz_075"
                text: Math.round(batteryPercent() * 100) + "%"
                color: Battery.isLow && !Battery.isCharging ? Appearance.colors.colError : root.color
                iconSize: root.iconSize
                fontSize: root.fontSize
            }

        }

    }

    // Local minimal icon+text pair to avoid external dependency issues
    component IconAndTextPair: RowLayout {
        id: pair

        property string icon: ""
        property string text: ""
        property color color: root.color
        property int iconSize: root.iconSize
        property int fontSize: root.fontSize

        spacing: 6
        Layout.alignment: Qt.AlignVCenter

        MaterialSymbol {
            visible: pair.icon !== ""
            fill: 1
            text: pair.icon
            iconSize: pair.iconSize
            color: pair.color
            anchors.verticalCenter: parent.verticalCenter
            animateChange: true
        }

        StyledText {
            visible: pair.text !== ""
            text: pair.text
            font.pixelSize: pair.fontSize
            font.weight: Font.DemiBold
            color: pair.color
            animateChange: true
            Layout.alignment: Qt.AlignVCenter
        }

    }

    // Thin vertical separator
    component Separator: Rectangle {
        width: 1
        height: 16
        radius: 0.5
        color: muted
        opacity: 0.8
        Layout.alignment: Qt.AlignVCenter
    }

}
