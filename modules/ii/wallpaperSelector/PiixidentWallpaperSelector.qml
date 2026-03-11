pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.common
import qs.modules.ii.piixident

/*
 * ═══════════════════════════════════════════════════════════════════════════
 *  PIIXIDENT WALLPAPER SELECTOR WRAPPER
 * ═══════════════════════════════════════════════════════════════════════════
 * 
 *  Simple wrapper around piixident's wallpaper selector that provides:
 *  - toggle/show/hide functions for integration with ii config
 *  - IPC commands: qs -c ii ipc call wallpaperPicker {toggle|show|hide}
 */

Scope {
    id: root
    
    function toggle() { selector.showing = !selector.showing }
    function show() { selector.showing = true }
    function hide() { selector.showing = false }
    
    IpcHandler {
        target: "wallpaperPicker"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }
    
    WallpaperSelector_Piixident {
        id: selector
        colors: Appearance.colors
        onWallpaperChanged: {
            console.log("Piixident wallpaper changed")
        }
    }
}
