// Lockscreen title: "ZAN"
// Purpose-built entrance animation for lockscreen mode

import Qt5Compat.GraphicalEffects
import QtQuick

Item {
    id: root

    property color textColor: "#f5f5f5"
    property string title: "ZAN"

    width: 620
    height: 160
    anchors.centerIn: parent
    // Initial lockscreen state
    opacity: 0
    y: 12
    Component.onCompleted: lockscreenEntrance.start()

    Canvas {
        id: titleCanvas

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: parent.width
        height: 120
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.font = "700 128px 'Noto Sans', 'Inter', sans-serif";
            var grad = ctx.createLinearGradient(0, height * 0.25, 0, height * 0.85);
            grad.addColorStop(0, textColor);
            grad.addColorStop(1, "#c8ccd2");
            ctx.fillStyle = grad;
            ctx.lineWidth = 1.1;
            ctx.strokeStyle = "rgba(255, 255, 255, 0.28)";
            var letters = root.title.toUpperCase().split("");
            var spacing = 86;
            var startX = width / 2 - spacing * (letters.length - 1) / 2;
            var y = height / 2;
            for (var i = 0; i < letters.length; i++) {
                var x = startX + i * spacing;
                ctx.strokeText(letters[i], x, y);
                ctx.fillText(letters[i], x, y);
            }
        }
    }

    DropShadow {
        anchors.fill: titleCanvas
        source: titleCanvas
        horizontalOffset: 0
        verticalOffset: 3
        radius: 12
        samples: 17
        color: "#30000000"
        transparentBorder: true
    }

    // Micro underline — animated width, not scale
    Rectangle {
        id: underline

        height: 2
        radius: 1
        color: Qt.rgba(1, 1, 1)
        anchors.horizontalCenter: parent.horizontalCenter
        y: titleCanvas.height - 6
        width: 0
        opacity: 0.6
    }

    // Lockscreen entrance choreography
    SequentialAnimation {
        id: lockscreenEntrance

        running: false

        // Let compositor settle (important for lockscreen)
        PauseAnimation {
            duration: 80
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                from: 0
                to: 1
                duration: 260
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: root
                property: "y"
                from: 12
                to: 0
                duration: 260
                easing.type: Easing.OutCubic
            }

        }

        // Underline draws in — subtle but intentional
        NumberAnimation {
            target: underline
            property: "width"
            from: 0
            to: 180
            duration: 240
            easing.type: Easing.OutQuad
        }

    }

}
