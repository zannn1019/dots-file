import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    
    readonly property int workspacesShown: Config.options.bar.workspaces.shown
    readonly property int workspaceGroup: Math.floor((monitor?.activeWorkspace?.id - 1) / root.workspacesShown)
    property list<bool> workspaceOccupied: []
    property int widgetPadding: 4
    property int workspaceButtonWidth: 26
    property real activeWorkspaceMargin: 2
    property real workspaceIconSize: workspaceButtonWidth * 0.69
    property real workspaceIconSizeShrinked: workspaceButtonWidth * 0.55
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    property int workspaceIndexInGroup: (monitor?.activeWorkspace?.id - 1) % root.workspacesShown

    property bool showNumbers: false
    Timer {
        id: showNumbersTimer
        interval: (Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100)
        repeat: false
        onTriggered: {
            root.showNumbers = true
        }
    }
    Connections {
        target: GlobalStates
        function onSuperDownChanged() {
            if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return;
            if (GlobalStates.superDown) showNumbersTimer.restart();
            else {
                showNumbersTimer.stop();
                root.showNumbers = false;
            }
        }
        function onSuperReleaseMightTriggerChanged() { 
            showNumbersTimer.stop()
        }
    }

    // Function to update workspaceOccupied
    function updateWorkspaceOccupied() {
        workspaceOccupied = Array.from({ length: root.workspacesShown }, (_, i) => {
            return Hyprland.workspaces.values.some(ws => ws.id === workspaceGroup * root.workspacesShown + i + 1);
        })
    }

    // Occupied workspace updates
    Component.onCompleted: updateWorkspaceOccupied()
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            updateWorkspaceOccupied();
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            updateWorkspaceOccupied();
        }
    }
    onWorkspaceGroupChanged: {
        updateWorkspaceOccupied();
    }

    implicitWidth: root.vertical ? Appearance.sizes.verticalBarWidth : dotsRow.implicitWidth
    implicitHeight: root.vertical ? dotsRow.implicitHeight : Appearance.sizes.barHeight

    // Scroll to switch workspaces
    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0)
                Hyprland.dispatch(`workspace r+1`);
            else if (event.angleDelta.y > 0)
                Hyprland.dispatch(`workspace r-1`);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onPressed: (event) => {
            if (event.button === Qt.BackButton) {
                Hyprland.dispatch(`togglespecialworkspace`);
            }
        }
    }

    // ── Dot / pill indicators ────────────────────────────────────────
    Grid {
        id: dotsRow
        anchors.centerIn: parent
        columns: root.vertical ? 1 : root.workspacesShown
        rows:    root.vertical ? root.workspacesShown : 1
        columnSpacing: root.vertical ? 0 : 5
        rowSpacing:    root.vertical ? 5 : 0

        Repeater {
            model: root.workspacesShown

            Item {
                id: dotItem
                required property int index
                readonly property int wsId: workspaceGroup * root.workspacesShown + index + 1
                readonly property bool isActive:   monitor?.activeWorkspace?.id === wsId
                readonly property bool isOccupied: workspaceOccupied[index] ?? false

                // Pill width when active, dot width otherwise
                readonly property real dotSize:  6
                readonly property real pillWidth: 18

                implicitWidth:  root.vertical ? dotSize : (isActive ? pillWidth : dotSize)
                implicitHeight: root.vertical ? (isActive ? pillWidth : dotSize) : dotSize

                Behavior on implicitWidth  { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.centerIn: parent
                    width:  root.vertical ? dotItem.dotSize : dotItem.implicitWidth
                    height: root.vertical ? dotItem.implicitHeight : dotItem.dotSize
                    radius: Appearance.rounding.full

                    color: dotItem.isActive
                        ? Appearance.colors.colPrimary
                        : dotItem.isOccupied
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.45)
                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.72)

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on width  { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    // Expand click target so small dots are easy to hit
                    anchors.margins: -4
                    onPressed: Hyprland.dispatch(`workspace ${dotItem.wsId}`)
                }
            }
        }
    }
}
