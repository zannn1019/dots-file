import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.piixident
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    // Color adapter: Convert ii colors to piixident format
    property var piixidentColors: ({
        surfaceContainer: Qt.color(Appearance.m3colors.m3surfaceContainer),
        primary: Qt.color(Appearance.m3colors.m3primary),
        onSurface: Qt.color(Appearance.m3colors.m3onSurface),
        surface: Qt.color(Appearance.m3colors.m3surface),
        onSurfaceVariant: Qt.color(Appearance.m3colors.m3onSurfaceVariant)
    })

    // Use piixident wallpaper selector directly
    WallpaperSelector_Piixident {
        id: piixidentSelector
        colors: piixidentColors
        onWallpaperChanged: {
            console.log("Piixident wallpaper changed")
        }
    }

    Loader {
        id: wallpaperSelectorLoader
        // DISABLED: Using Piixident wallpaper selector instead
        active: false // was: GlobalStates.wallpaperSelectorOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            anchors.top: true
            margins {
                top: Config?.options.bar.vertical ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
            }

            mask: Region {
                item: content
            }

            implicitHeight: Appearance.sizes.wallpaperSelectorHeight
            implicitWidth: Appearance.sizes.wallpaperSelectorWidth

            HyprlandFocusGrab { // Click outside to close
                id: grab
                windows: [ panelWindow ]
                active: wallpaperSelectorLoader.active
                onCleared: () => {
                    if (!active) GlobalStates.wallpaperSelectorOpen = false;
                }
            }

            WallpaperSelectorContent {
                id: content
                anchors {
                    fill: parent
                }
            }
        }
    }

    function toggleWallpaperSelector() {
        if (Config.options.wallpaperSelector.useSystemFileDialog) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }
        // USE PIIXIDENT SELECTOR
        piixidentSelector.showing = !piixidentSelector.showing
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
            root.toggleWallpaperSelector();
        }

        function random(): void {
            Wallpapers.randomFromCurrentFolder();
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Toggle wallpaper selector"
        onPressed: {
            root.toggleWallpaperSelector();
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorRandom"
        description: "Select random wallpaper in current folder"
        onPressed: {
            Wallpapers.randomFromCurrentFolder();
        }
    }
}
