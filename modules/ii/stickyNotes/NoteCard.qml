pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Item {
    id: root
    property real noteWidth: 200
    property real noteRotation: 0
    width: Math.max(160, root.noteWidth)
    height: cardRect.height + (root.isSelected ? 52 : 0)
    rotation: root.noteRotation

    property string noteId: ""
    property string noteTitle: ""
    property string noteBody: ""
    property string noteColor: "#FFE566"
    property string noteSticker: ""
    property string authorName: "Me"
    property var availableColors: []
    property int animDelay: 0
    property bool panelOpen: false
    property bool isSelected: false
    property string mode: "move"       // "move" | "resize" | "rotate"
    property bool colorPickerOpen: false
    property bool stickerPickerOpen: false

    signal titleEdited(string id, string value)
    signal bodyEdited(string id, string value)
    signal colorChanged(string id, string color)
    signal stickerChanged(string id, string sticker)
    signal deleteRequested(string id)
    signal moved(string id, real cx, real cy)
    signal resized(string id, real w)
    signal rotated(string id, real angle)
    signal selectRequested(string id)

    Timer { id: titleTimer; interval: 450; repeat: false; onTriggered: root.titleEdited(root.noteId, titleArea.text) }
    Timer { id: bodyTimer;  interval: 450; repeat: false; onTriggered: root.bodyEdited(root.noteId, bodyArea.text) }

    // ── Tap to select ──
    TapHandler {
        onTapped: root.selectRequested(root.noteId)
    }

    // ── Move drag (only in move mode) ──
    DragHandler {
        id: dragger
        target: root
        dragThreshold: 8
        enabled: root.mode === "move"
        onActiveChanged: if (!active) root.moved(root.noteId, root.x + root.width / 2, root.y + root.height / 2)
    }

    // ── Rotate drag (entire card in rotate mode) ──
    DragHandler {
        id: rotDragger
        target: null
        enabled: root.mode === "rotate"
        dragThreshold: 0

        property real cx: 0; property real cy: 0
        property real startAngle: 0; property real startRot: 0

        onActiveChanged: {
            if (active) {
                var gc = root.mapToGlobal(root.width / 2, root.height / 2)
                cx = gc.x; cy = gc.y
                var gp = root.mapToGlobal(centroid.position.x, centroid.position.y)
                startAngle = Math.atan2(gp.y - cy, gp.x - cx) * 180 / Math.PI
                startRot = root.noteRotation
            } else {
                root.rotated(root.noteId, root.noteRotation)
            }
        }
        onCentroidChanged: {
            if (active) {
                var gp = root.mapToGlobal(centroid.position.x, centroid.position.y)
                var angle = Math.atan2(gp.y - cy, gp.x - cx) * 180 / Math.PI
                root.noteRotation = startRot + (angle - startAngle)
            }
        }
    }

    // ── Resize drag (entire card in resize mode) ──
    DragHandler {
        id: resDragger
        target: null
        enabled: root.mode === "resize"
        yAxis.enabled: false

        property real origW: 0
        onActiveChanged: {
            if (active) origW = root.noteWidth
            else root.resized(root.noteId, root.noteWidth)
        }
        onTranslationChanged: root.noteWidth = Math.max(160, Math.min(600, origW + translation.x))
    }

    // ── Open/close animation ──
    opacity: 0; scale: 0.5
    onPanelOpenChanged: { if (panelOpen) openDelay.restart(); else closeAnim.start() }
    Timer { id: openDelay; interval: root.animDelay; repeat: false; onTriggered: openAnim.start() }
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; from: 0.45; to: 1.0; duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 260; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "scale"; to: 0.6; duration: 300; easing.type: Easing.InBack }
    }
    ParallelAnimation {
        id: deleteAnim
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 220; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "scale"; to: 0; duration: 250; easing.type: Easing.InBack }
        onFinished: root.deleteRequested(root.noteId)
    }

    // ── Mode cursor ──
    HoverHandler {
        cursorShape: root.mode === "rotate" ? Qt.CrossCursor : root.mode === "resize" ? Qt.SizeHorCursor : Qt.SizeAllCursor
    }

    // Shadow
    Rectangle { anchors.fill: cardRect; anchors.topMargin: 7; anchors.leftMargin: 5; radius: cardRect.radius; color: Qt.rgba(0, 0, 0, 0.16); z: -1 }

    // ── Card ──
    Rectangle {
        id: cardRect
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: noteColumn.implicitHeight + 52 + (root.noteSticker !== "" ? 46 : 0)
        radius: 6
        color: root.noteColor

        // Selection highlight
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: parent.radius + 3
            color: "transparent"
            border.color: root.mode === "rotate" ? "#f59e0b" : root.mode === "resize" ? "#22c55e" : "#6366f1"
            border.width: root.isSelected ? 2.5 : 0
            Behavior on border.width { NumberAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        // Folded corner
        Item { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 20; height: 20; clip: true
            Rectangle { width: 28; height: 28; rotation: 45; color: Qt.darker(root.noteColor, 1.25); anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.rightMargin: -14; anchors.bottomMargin: -14 } }

        // Sticker emoji
        Text { visible: root.noteSticker !== ""; text: root.noteSticker; font.pixelSize: 36
            anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: -10; anchors.rightMargin: -10; z: 15; rotation: 12
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.stickerChanged(root.noteId, "") } }

        // Controls (on hover/select)
        Row {
            id: controlRow
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: 8; anchors.rightMargin: root.noteSticker !== "" ? 32 : 8
            spacing: 4; z: 20
            opacity: root.isSelected || root.colorPickerOpen || root.stickerPickerOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Rectangle { width: 26; height: 26; radius: 13; color: cpH.containsMouse ? Qt.rgba(0,0,0,0.18) : Qt.rgba(0,0,0,0.1); Behavior on color { ColorAnimation { duration:100 } }
                Rectangle { anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: "#fff"; opacity: 0.8
                    Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 4; color: Qt.darker(root.noteColor, 1.5) } }
                MouseArea { id: cpH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.colorPickerOpen = !root.colorPickerOpen; root.stickerPickerOpen = false } } }
            Rectangle { width: 26; height: 26; radius: 13; color: spH.containsMouse ? Qt.rgba(0,0,0,0.18) : Qt.rgba(0,0,0,0.1); Behavior on color { ColorAnimation { duration:100 } }
                Text { anchors.centerIn: parent; text: "⭐"; font.pixelSize: 12 }
                MouseArea { id: spH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.stickerPickerOpen = !root.stickerPickerOpen; root.colorPickerOpen = false } } }
            Rectangle { width: 26; height: 26; radius: 13; color: dH.containsMouse ? Qt.rgba(0.8,0.1,0.1,0.25) : Qt.rgba(0,0,0,0.1); Behavior on color { ColorAnimation { duration:100 } }
                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: dH.containsMouse ? "#cc2222" : Qt.rgba(0,0,0,0.45) }
                MouseArea { id: dH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deleteAnim.start() } }
        }

        // Color picker
        Rectangle { anchors.top: controlRow.bottom; anchors.right: parent.right; anchors.rightMargin: 8; anchors.topMargin: 4
            width: root.availableColors.length * 27 + 16; height: 40; radius: 12; color: "#1a1a2a"
            border.color: Qt.rgba(1,1,1,0.15); border.width: 1; z: 30; visible: root.colorPickerOpen
            scale: root.colorPickerOpen ? 1.0 : 0.7; opacity: root.colorPickerOpen ? 1 : 0; transformOrigin: Item.TopRight
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Row { anchors.centerIn: parent; spacing: 6
                Repeater { model: root.availableColors
                    delegate: Rectangle { required property var modelData; required property int index
                        width: 20; height: 20; radius: 10; color: modelData
                        border.color: modelData === root.noteColor ? "#fff" : "transparent"; border.width: 2
                        scale: sh.containsMouse ? 1.3 : 1; Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                        MouseArea { id: sh; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.colorChanged(root.noteId, parent.color.toString()); root.colorPickerOpen = false } } } } } }

        // Sticker picker
        Rectangle { id: stickerPanel; anchors.top: controlRow.bottom; anchors.right: parent.right; anchors.rightMargin: 8; anchors.topMargin: 4
            width: 188; height: 88; radius: 12; color: "#1a1a2a"; border.color: Qt.rgba(1,1,1,0.15); border.width: 1; z: 30
            visible: root.stickerPickerOpen; scale: root.stickerPickerOpen ? 1.0 : 0.7; opacity: root.stickerPickerOpen ? 1 : 0; transformOrigin: Item.TopRight
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
            property var stickers: ["⭐","🔥","💡","✅","❗","🎯","💬","🚀","❤️","🎉","📌","⚡","🌈","🎨","🏆"]
            Grid { anchors.centerIn: parent; columns: 5; spacing: 6
                Repeater { model: stickerPanel.stickers
                    delegate: Rectangle { required property var modelData; required property int index; width: 28; height: 28; radius: 6
                        color: sHov.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"; Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 16 }
                        MouseArea { id: sHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.stickerChanged(root.noteId, parent.modelData); root.stickerPickerOpen = false } } } } } }

        // Content
        Column {
            id: noteColumn
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.leftMargin: 14; anchors.rightMargin: 14
            anchors.topMargin: root.noteSticker !== "" ? 50 : 14
            spacing: 6
            Behavior on anchors.topMargin { NumberAnimation { duration: 200 } }
            TextArea { id: titleArea; width: parent.width - 60; placeholderText: "Note…"
                font.pixelSize: 19
                font.weight: Font.Bold
                font.family: "Caveat"
                color: "#1a1a2e"
                placeholderTextColor: Qt.rgba(0,0,0,0.25)
                wrapMode: TextArea.Wrap
                background: Item {}
                padding: 0
                topPadding: 0
                bottomPadding: 0
                Component.onCompleted: text = root.noteTitle
                onTextChanged: titleTimer.restart() }
            TextArea { id: bodyArea; width: parent.width; placeholderText: "Type something…"
                font.pixelSize: 14
                font.family: "Caveat"
                color: Qt.rgba(0,0,0,0.65)
                placeholderTextColor: Qt.rgba(0,0,0,0.2)
                wrapMode: TextArea.Wrap
                background: Item {}
                padding: 0
                topPadding: 0
                bottomPadding: 4
                implicitHeight: Math.max(contentHeight, 56)
                Component.onCompleted: text = root.noteBody
                onTextChanged: bodyTimer.restart() }
        }

        // Author badge
        Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.leftMargin: 12; anchors.bottomMargin: 10
            width: bTxt.implicitWidth + 20; height: 24; radius: 12; color: Qt.darker(root.noteColor, 1.22)
            Text { id: bTxt; anchors.centerIn: parent; text: root.authorName; font.pixelSize: 11; font.weight: Font.Medium; color: Qt.rgba(0,0,0,0.65) } }
    }

    // ── Mode selector toolbar (below card, visible when selected) ──
    Rectangle {
        id: modeBar
        anchors.top: cardRect.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 8
        width: 190; height: 38
        radius: 19
        color: "#1a1a2e"
        border.color: Qt.rgba(1,1,1,0.1); border.width: 1
        visible: root.isSelected
        opacity: root.isSelected ? 1 : 0
        scale: root.isSelected ? 1.0 : 0.7
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        Row {
            anchors.centerIn: parent; spacing: 4

            Repeater {
                model: [
                    { id: "move",   icon: "✥", label: "Move" },
                    { id: "resize", icon: "⤡", label: "Resize" },
                    { id: "rotate", icon: "↻", label: "Rotate" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: 56; height: 28; radius: 14
                    color: root.mode === modelData.id
                        ? (modelData.id === "rotate" ? "#f59e0b" : modelData.id === "resize" ? "#22c55e" : "#6366f1")
                        : (mH.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row { anchors.centerIn: parent; spacing: 3
                        Text { text: parent.modelData.icon; font.pixelSize: 12; color: "white"; opacity: 0.9 }
                        Text { text: parent.modelData.label; font.pixelSize: 10; font.weight: Font.Medium; color: "white"; opacity: root.mode === parent.modelData.id ? 1 : 0.5 }
                    }
                    MouseArea { id: mH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = parent.modelData.id }
                }
            }
        }
    }
}
