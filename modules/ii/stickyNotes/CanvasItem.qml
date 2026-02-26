pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Item {
    id: root

    property string itemId: ""
    property string itemType: "emoji"
    property string content: "⭐"
    property real itemW: 100
    property real itemH: 100
    property real itemRotation: 0
    property bool panelOpen: false
    property int animDelay: 0
    property bool isSelected: false
    property string mode: "move"

    width: root.itemW
    height: root.itemH + (root.isSelected ? 52 : 0)
    rotation: root.itemRotation

    signal moved(string id, real cx, real cy)
    signal rotated(string id, real angle)
    signal resized(string id, real w, real h)
    signal deleteRequested(string id)
    signal selectRequested(string id)

    // ── Tap to select ──
    TapHandler { onTapped: root.selectRequested(root.itemId) }

    // ── Cursor per mode ──
    HoverHandler { cursorShape: root.mode === "rotate" ? Qt.CrossCursor : root.mode === "resize" ? Qt.SizeFDiagCursor : Qt.SizeAllCursor }

    // ── Move DragHandler ──
    DragHandler {
        id: moveDrag; target: root; dragThreshold: 8
        enabled: root.mode === "move"
        onActiveChanged: if (!active) root.moved(root.itemId, root.x + root.itemW / 2, root.y + root.itemH / 2)
    }

    // ── Rotate DragHandler ──
    DragHandler {
        id: rotDrag; target: null; enabled: root.mode === "rotate"; dragThreshold: 0
        property real cx: 0; property real cy: 0
        property real startAngle: 0; property real startRot: 0
        onActiveChanged: {
            if (active) {
                var gc = root.mapToGlobal(root.itemW / 2, root.itemH / 2)
                cx = gc.x; cy = gc.y
                var gp = root.mapToGlobal(centroid.position.x, centroid.position.y)
                startAngle = Math.atan2(gp.y - cy, gp.x - cx) * 180 / Math.PI
                startRot = root.itemRotation
            } else { root.rotated(root.itemId, root.itemRotation) }
        }
        onCentroidChanged: {
            if (active) {
                var gp = root.mapToGlobal(centroid.position.x, centroid.position.y)
                var angle = Math.atan2(gp.y - cy, gp.x - cx) * 180 / Math.PI
                root.itemRotation = startRot + (angle - startAngle)
            }
        }
    }

    // ── Resize DragHandler ──
    DragHandler {
        id: resDrag; target: null; enabled: root.mode === "resize"; dragThreshold: 0
        property real origW: 0; property real origH: 0
        onActiveChanged: {
            if (active) { origW = root.itemW; origH = root.itemH }
            else root.resized(root.itemId, root.itemW, root.itemH)
        }
        onTranslationChanged: {
            root.itemW = Math.max(40, Math.min(800, origW + translation.x))
            root.itemH = Math.max(40, Math.min(800, origH + translation.y))
        }
    }

    // ── Open/close animation ──
    opacity: 0; scale: 0.3
    onPanelOpenChanged: { if (panelOpen) openDelay.restart(); else closeAnim.start() }
    Timer { id: openDelay; interval: root.animDelay; repeat: false; onTriggered: openAnim.start() }
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; from: 0.3; to: 1.0; duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 220; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "scale"; to: 0.5; duration: 260; easing.type: Easing.InBack }
    }
    ParallelAnimation {
        id: deleteAnim
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 220; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "scale"; to: 0; duration: 250; easing.type: Easing.InBack }
        onFinished: root.deleteRequested(root.itemId)
    }

    // ── Content area ──
    Item {
        id: contentArea
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: root.itemH

        // Selection ring
        Rectangle {
            anchors.fill: parent; anchors.margins: -4; radius: 8
            color: "transparent"
            border.color: root.mode === "rotate" ? "#f59e0b" : root.mode === "resize" ? "#22c55e" : "#6366f1"
            border.width: root.isSelected ? 2.5 : 0
            Behavior on border.width { NumberAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        Text {
            anchors.centerIn: parent
            visible: root.itemType === "emoji"
            text: root.content
            font.pixelSize: Math.min(root.itemW, root.itemH) * 0.72
        }

        Image {
            anchors.fill: parent
            visible: root.itemType === "image"
            source: root.itemType === "image" ? ("file://" + root.content) : ""
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
        }

        // Delete button (top-right)
        Rectangle {
            visible: root.isSelected
            anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: -10; anchors.topMargin: -10
            width: 22; height: 22; radius: 11; z: 30
            color: delH.containsMouse ? "#ef4444" : "white"
            border.color: "#ef4444"; border.width: 2
            Behavior on color { ColorAnimation { duration: 100 } }
            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: delH.containsMouse ? "white" : "#ef4444" }
            MouseArea { id: delH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deleteAnim.start() }
        }
    }

    // ── Mode selector toolbar (below item) ──
    Rectangle {
        anchors.top: contentArea.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 8
        width: 190; height: 38; radius: 19
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
