import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property bool failed
    property string errorString

    Connections {
        function onReloadCompleted() {
            root.failed = false
            popupLoader.loading = true
        }
        function onReloadFailed(error: string) {
            popupLoader.active = false
            root.failed = true
            root.errorString = error
            popupLoader.loading = true
        }
        target: Quickshell
    }

    LazyLoader {
        id: popupLoader

        PanelWindow {
            id: popup

            exclusiveZone: 0
            anchors.top: true
            margins.top: 0
            width: card.width
            implicitHeight: card.implicitHeight + 50
            WlrLayershell.namespace: "quickshell:reloadPopup"
            color: "transparent"

            // ─── Card ───────────────────────────────────────────
            Rectangle {
                id: card

                readonly property string accent: root.failed ? "#f87171" : "#4ade80"

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                
                // If error: minimum 560px, up to 800px. If success: naturally wrap around the text (min 300px)
                width: root.failed 
                       ? Math.min(800, Math.max(560, innerCol.implicitWidth + 100)) 
                       : Math.max(300, innerCol.implicitWidth + 100)
                
                implicitHeight: innerCol.implicitHeight + 28

                radius: 18
                color: root.failed ? Qt.rgba(0.18, 0.04, 0.06, 0.95) : Qt.rgba(0.05, 0.28, 0.12, 0.95)
                border.color: Qt.alpha(accent, 0.35)
                border.width: 1
                clip: true

                // Entry animation — slide in from above + fade
                opacity: 0
                anchors.topMargin: -80
                Component.onCompleted: entryAnim.start()

                SequentialAnimation {
                    id: entryAnim
                    ParallelAnimation {
                        NumberAnimation {
                            target: card
                            property: "anchors.topMargin"
                            from: -80; to: 14
                            duration: 420
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.2
                        }
                        NumberAnimation {
                            target: card
                            property: "opacity"
                            from: 0; to: 1
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }
                    // After card appears, kick off the countdown
                    ScriptAction { script: countdownAnim.start() }
                }

                // Exit animation
                SequentialAnimation {
                    id: exitAnim
                    ParallelAnimation {
                        NumberAnimation {
                            target: card
                            property: "anchors.topMargin"
                            to: -100
                            duration: 340
                            easing.type: Easing.InBack
                            easing.overshoot: 0.8
                        }
                        NumberAnimation {
                            target: card
                            property: "opacity"
                            to: 0
                            duration: 260
                            easing.type: Easing.InCubic
                        }
                    }
                    ScriptAction { script: popupLoader.active = false }
                }

                // ─── Glowing left accent bar ────────────────────
                Rectangle {
                    id: accentBar
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 6
                    width: 3
                    radius: 999
                    color: card.accent

                    // Pulsing glow on the bar
                    layer.enabled: true
                    layer.effect: Glow {
                        radius: 8
                        samples: 17
                        color: card.accent
                        spread: 0.3
                        transparentBorder: true
                    }

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: true
                        NumberAnimation { to: 0.5; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }
                }

                // ─── Shimmer sweep (success only) ───────────────
                Rectangle {
                    visible: !root.failed
                    anchors.fill: parent
                    radius: card.radius
                    clip: true

                    Rectangle {
                        id: shimmer
                        width: 80
                        height: parent.height
                        rotation: 15
                        opacity: 0
                        color: "transparent"

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.07) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }

                        SequentialAnimation on x {
                            running: true
                            loops: Animation.Infinite
                            PauseAnimation { duration: 2200 }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: shimmer; property: "x"
                                    from: -100; to: card.width + 100
                                    duration: 700; easing.type: Easing.InOutQuad
                                }
                                SequentialAnimation {
                                    NumberAnimation { target: shimmer; property: "opacity"; to: 1; duration: 120 }
                                    PauseAnimation { duration: 460 }
                                    NumberAnimation { target: shimmer; property: "opacity"; to: 0; duration: 120 }
                                }
                            }
                        }
                    }
                }

                // ─── Mouse area — dismiss on click, pause on hover ──
                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: {
                        countdownAnim.stop()
                        exitAnim.start()
                    }
                }

                // ─── Content ─────────────────────────────────────
                ColumnLayout {
                    id: innerCol
                    anchors {
                        top: parent.top
                        left: parent.left
                        leftMargin: 24
                        topMargin: 14
                        bottomMargin: 14
                    }
                    spacing: 4

                    // Status icon + title
                    RowLayout {
                        spacing: 10

                        // Animated icon
                        Text {
                            id: iconText
                            text: root.failed ? "✕" : "✓"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: card.accent
                            opacity: 0

                            layer.enabled: true
                            layer.effect: Glow {
                                radius: 6
                                samples: 13
                                color: card.accent
                                spread: 0.2
                                transparentBorder: true
                            }

                            SequentialAnimation on opacity {
                                running: true
                                PauseAnimation { duration: 200 }
                                NumberAnimation { to: 1; duration: 220; easing.type: Easing.OutBack }
                            }
                            SequentialAnimation on scale {
                                running: true
                                NumberAnimation { from: 0.3; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                            }
                        }

                        Text {
                            renderType: Text.NativeRendering
                            font.family: "Google Sans Flex"
                            font.pixelSize: 15
                            font.weight: Font.SemiBold
                            text: root.failed ? "Quickshell: Reload failed" : "Quickshell reloaded"
                            color: card.accent
                            opacity: 0

                            SequentialAnimation on opacity {
                                running: true
                                PauseAnimation { duration: 100 }
                                NumberAnimation { to: 1; duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    // Error detail (only on fail)
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: errorCol.implicitHeight
                        visible: root.errorString !== "" && root.failed
                        opacity: 0

                        SequentialAnimation on opacity {
                            running: visible
                            PauseAnimation { duration: 280 }
                            NumberAnimation { to: 1; duration: 260; easing.type: Easing.OutCubic }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["wl-copy", root.errorString])
                                copyConfirmTimer.start()
                            }
                        }

                        ColumnLayout {
                            id: errorCol
                            width: parent.width
                            spacing: 2

                            Text {
                                // Max error card width is 800, minus 100 for margins = 700 max text width
                                Layout.maximumWidth: 700
                                Layout.fillWidth: true
                                renderType: Text.NativeRendering
                                font.family: "JetBrains Mono NF"
                                font.pixelSize: 11
                                text: root.errorString
                                color: Qt.rgba(1, 1, 1, 0.55)
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }

                            // Copy hint
                            Text {
                                id: copyHint
                                renderType: Text.NativeRendering
                                font.pixelSize: 10
                                text: copyConfirmTimer.running ? "✓ Copied!" : "📋 Click to copy"
                                color: copyConfirmTimer.running
                                      ? card.accent
                                      : Qt.rgba(1, 1, 1, 0.3)
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }

                        Timer {
                            id: copyConfirmTimer
                            interval: 1800
                            repeat: false
                        }
                    }
                }

                // ─── Circular countdown ring ─────────────────────
                Item {
                    id: ringArea
                    width: 36
                    height: 36
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 16

                    // Background track
                    Canvas {
                        id: ringTrack
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, 14, 0, Math.PI * 2)
                            ctx.strokeStyle = Qt.alpha(card.accent, 0.18)
                            ctx.lineWidth = 2.5
                            ctx.stroke()
                        }
                    }

                    // Sweeping arc
                    Canvas {
                        id: ringCanvas
                        anchors.fill: parent
                        property real progress: 1.0  // 1 -> 0 as time runs out

                        onProgressChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            const startAngle = -Math.PI / 2
                            const endAngle   = startAngle + progress * Math.PI * 2
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, 14, startAngle, endAngle)
                            ctx.strokeStyle = card.accent
                            ctx.lineWidth = 2.5
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }

                        // Glow on the ring
                        layer.enabled: true
                        layer.effect: Glow {
                            radius: 4
                            samples: 9
                            color: card.accent
                            spread: 0.15
                            transparentBorder: true
                        }

                        NumberAnimation {
                            id: countdownAnim
                            target: ringCanvas
                            property: "progress"
                            from: 1.0; to: 0.0
                            duration: root.failed ? 10000 : 2000
                            easing.type: Easing.Linear
                            paused: hoverArea.containsMouse
                            onFinished: exitAnim.start()
                        }
                    }

                    // Remaining seconds label
                    Text {
                        anchors.centerIn: parent
                        text: Math.ceil(ringCanvas.progress * (root.failed ? 10 : 2))
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.7)
                    }
                }
            }

            // ─── Shadow under the card ───────────────────────────
            DropShadow {
                anchors.fill: card
                source: card
                horizontalOffset: 0
                verticalOffset: 8
                radius: 24
                samples: 49
                color: Qt.alpha(root.failed ? "#f87171" : "#4ade80", 0.18)
            }
        }
    }
}
