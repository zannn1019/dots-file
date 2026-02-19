import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string timeString: "--:--"
    property string dateString: ""

    signal tick()

    function refresh() {
        const now = new Date();
        timeString = Qt.formatDateTime(now, "HH:mm");
        dateString = Qt.formatDateTime(now, "dddd, dd MMM");
        tick();
    }

    // Animation on appear
    opacity: 0
    scale: 0.98
    Component.onCompleted: {
        refresh();
        appearAnim.start();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        StyledText {
            id: timeText

            text: root.timeString
            font.pixelSize: Appearance.font.pixelSize.huge * 2
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnSurface
            animateChange: true
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter

            Behavior on text {
                SequentialAnimation {
                    NumberAnimation {
                        target: timeText
                        property: "scale"
                        from: 0.98
                        to: 1
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: timeText
                        property: "opacity"
                        from: 0.82
                        to: 1
                        duration: 120
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignHCenter

            StyledText {
                id: dateText

                text: root.dateString
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurface
                animateChange: true
                Layout.alignment: Qt.AlignVCenter

                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation {
                            target: dateText
                            property: "opacity"
                            from: 0.65
                            to: 1
                            duration: 160
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

    }

    ParallelAnimation {
        id: appearAnim

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: 240
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "scale"
            from: 0.98
            to: 1
            duration: 320
            easing.type: Easing.OutCubic
        }

    }

}
