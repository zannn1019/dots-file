import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool barOpen: true
    property bool crosshairOpen: false
    property bool islandOpen: false
    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property bool workspaceShowNumbers: false

    onSidebarRightOpenChanged: {
        if (GlobalStates.sidebarRightOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }

    property real screenZoom: 1
    onScreenZoomChanged: {
        Quickshell.execDetached(["hyprctl", "keyword", "cursor:zoom_factor", root.screenZoom.toString()]);
    }
    Behavior on screenZoom {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"

        onPressed: {
            root.superDown = true
        }
        onReleased: {
            root.superDown = false
        }
    }

    IpcHandler {
		target: "zoom"

		function zoomIn() {
            screenZoom = Math.min(screenZoom + 0.4, 3.0)
        }

        function zoomOut() {
            screenZoom = Math.max(screenZoom - 0.4, 1)
        } 
	}

    function debugLog(message, title = "Debug Log") {
        let strMsg = String(message);
        if (typeof message === "object" && message !== null) {
            try {
                let jsonStr = JSON.stringify(message, null, 2);
                if (jsonStr !== undefined) {
                    strMsg = jsonStr;
                }
            } catch (e) {
                // fall back to String(message)
            }
        } else if (message === undefined) {
            strMsg = "undefined";
        }
        
        // Escape characters that break Pango markup in notification daemons (like Dunst/Mako)
        let safeMsg = String(strMsg).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        
        Quickshell.execDetached(["notify-send", "-a", "QML Debug", String(title), safeMsg]);
        console.log("[" + title + "]", strMsg);
    }
}