pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false
    property int targetWorkspaceId: -1

    Variants {
        id: overviewVariants
        model: Quickshell.screens

        Loader {
            id: panelLoader
            required property var modelData
            active: false
            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    if (GlobalStates.overviewOpen)
                        panelLoader.active = true;
                }
            }
            sourceComponent: PanelWindow {
                id: root
                property string searchingText: ""
                readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
                property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
                screen: panelLoader.modelData

                WlrLayershell.namespace: "quickshell:wTaskView"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                color: "transparent"

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                TaskViewContent {
                    id: taskViewContent
                    anchors.fill: parent

                    Component.onCompleted: {
                        taskViewContent.forceActiveFocus();
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            GlobalStates.overviewOpen = false;
                        }
                    }

                    Connections {
                        target: GlobalStates
                        function onOverviewOpenChanged() {
                            if (!GlobalStates.overviewOpen)
                                taskViewContent.close();
                        }
                    }
                    onClosed: panelLoader.active = false
                }
            }
        }
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }

    GlobalShortcut {
        name: "altTabMoveWorkspace"
        description: "Alt+Tab move focused window to another workspace"
        // hook this to your actual keybinding mechanism; if supported:
        // keys: ["Alt+Tab"]

        onPressed: {
            if (!GlobalStates.overviewOpen) {
                GlobalStates.overviewOpen = true;
                const workspaces = Hyprland.workspaces;
                const activeId = Hyprland.activeWorkspace?.id ?? -1;
                targetWorkspaceId = workspaces.length > 1
                    ? workspaces.find(w => w.id !== activeId)?.id ?? activeId
                    : activeId;
            } else {
                // advance to next workspace
                const ids = Hyprland.workspaces.map(w => w.id);
                const idx = Math.max(0, ids.indexOf(targetWorkspaceId));
                targetWorkspaceId = ids[(idx + 1) % ids.length];
            }
        }

        onReleased: {
            if (targetWorkspaceId >= 0) {
                Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspace", String(targetWorkspaceId)]);
                Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(targetWorkspaceId)]);
            }
            GlobalStates.overviewOpen = false;
            targetWorkspaceId = -1;
        }
    }
}
