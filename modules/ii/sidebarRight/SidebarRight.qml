import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth

    PanelWindow {
        id: sidebarRoot
        visible: GlobalStates.sidebarRightOpen

        function hide() {
            GlobalStates.sidebarRightOpen = false
        }

        exclusiveZone: 0
        implicitWidth: sidebarWidth
        WlrLayershell.namespace: "quickshell:sidebarRight"
        // Hyprland 0.49: Focus is always exclusive and setting this breaks mouse focus grab
        // WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
        }

        HyprlandFocusGrab {
            id: grab
            windows: [ sidebarRoot ]
            active: GlobalStates.sidebarRightOpen
            onCleared: () => {
                if (!active) sidebarRoot.hide()
            }
        }

        Loader {
            id: sidebarContentLoader
            active: GlobalStates.sidebarRightOpen || Config?.options.sidebar.keepRightSidebarLoaded
            anchors {
                fill: parent
                margins: Appearance.sizes.hyprlandGapsOut
                leftMargin: Appearance.sizes.elevationMargin
            }
            width: sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            height: parent.height - Appearance.sizes.hyprlandGapsOut * 2

            focus: GlobalStates.sidebarRightOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    sidebarRoot.hide();
                }
            }

            sourceComponent: SidebarRightContent {}

            // ── Slide + fade in/out ──────────────────────────────
            opacity: GlobalStates.sidebarRightOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            x: GlobalStates.sidebarRightOpen ? 0 : sidebarWidth * 0.18
            Behavior on x {
                NumberAnimation {
                    duration: 360
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.5
                }
            }
        }


    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }

        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }

        function open(): void {
            GlobalStates.sidebarRightOpen = true;
        }
    }

    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Toggles right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: "Opens right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = true;
        }
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: "Closes right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = false;
        }
    }

}
