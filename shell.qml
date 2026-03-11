//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the shell smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import qs.modules.common
import qs.modules.ii.background
import qs.modules.ii.bar
import qs.modules.ii.cheatsheet
import qs.modules.ii.dock
import qs.modules.ii.lock
import qs.modules.ii.mediaControls
import qs.modules.ii.notificationPopup
import qs.modules.ii.onScreenDisplay
import qs.modules.ii.onScreenKeyboard
import qs.modules.ii.overview
import qs.modules.ii.polkit
import qs.modules.ii.regionSelector
import qs.modules.ii.screenCorners
import qs.modules.ii.sessionScreen
import qs.modules.ii.sidebarLeft
import qs.modules.ii.sidebarRight
import qs.modules.ii.stickyNotes
import qs.modules.ii.overlay
import qs.modules.ii.verticalBar
import qs.modules.ii.wallpaperSelector

import qs.modules.waffle.actionCenter
import qs.modules.waffle.background
import qs.modules.waffle.bar
import qs.modules.waffle.lock
import qs.modules.waffle.notificationCenter
import qs.modules.waffle.onScreenDisplay
import qs.modules.waffle.polkit
import qs.modules.waffle.startMenu
import qs.modules.waffle.sessionScreen
import qs.modules.waffle.taskView

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

ShellRoot {
    id: root

    // Force initialization of some singletons
    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Hyprsunset.load()
        FirstRunExperience.load()
        ConflictKiller.load()
        Cliphist.refresh()
        Wallpapers.load()
        Updates.load()
    }
    
    // Connect piixident wallpaper picker to the original WallpaperSelector
    Connections {
        target: wallpaperPickerLoader
        function onLoaded() {
            // Find the original WallpaperSelector Scope and inject the piixident instance
            for (let i = 0; i < root.children.length; i++) {
                let child = root.children[i]
                if (child.objectName === "iiWallpaperSelector" && child.item) {
                    child.item.wallpaperPickerInstance = wallpaperPickerLoader.item
                    console.log("Connected piixident wallpaper picker to original WallpaperSelector")
                    break
                }
            }
        }
    }

    // Load enabled stuff
    // Well, these loaders only *allow* them to be loaded, to always load or not is defined in each component
    // The media controls for example is not loaded if it's not opened
    PanelLoader { identifier: "iiBar"; extraCondition: !Config.options.bar.vertical; component: Bar {} }
    PanelLoader { identifier: "iiBackground"; component: Background {} }
    PanelLoader { identifier: "iiCheatsheet"; component: Cheatsheet {} }
    PanelLoader { identifier: "iiDock"; extraCondition: Config.options.dock.enable; component: Dock {} }
    PanelLoader { identifier: "iiFloatingIsland"; component: FloatingIsland {} }
    PanelLoader { identifier: "iiLock"; component: Lock {} }
    PanelLoader { identifier: "iiMediaControls"; component: MediaControls {} }
    PanelLoader { identifier: "iiNotificationPopup"; component: NotificationPopup {} }
    PanelLoader { identifier: "iiOnScreenDisplay"; component: OnScreenDisplay {} }
    PanelLoader { identifier: "iiOnScreenKeyboard"; component: OnScreenKeyboard {} }
    PanelLoader { identifier: "iiOverlay"; component: Overlay {} }
    PanelLoader { identifier: "iiOverview"; component: Overview {} }
    PanelLoader { identifier: "iiPolkit"; component: Polkit {} }
    PanelLoader { identifier: "iiRegionSelector"; component: RegionSelector {} }
    PanelLoader { identifier: "iiScreenCorners"; component: ScreenCorners {} }
    PanelLoader { identifier: "iiSessionScreen"; component: SessionScreen {} }
    PanelLoader { identifier: "iiSidebarLeft"; component: SidebarLeft {} }
    PanelLoader { identifier: "iiSidebarRight"; component: SidebarRight {} }
    PanelLoader { identifier: "iiStickyNotes"; component: StickyNotes {} }
    PanelLoader { identifier: "iiVerticalBar"; extraCondition: Config.options.bar.vertical; component: VerticalBar {} }
    PanelLoader { objectName: "iiWallpaperSelector"; identifier: "iiWallpaperSelector"; component: WallpaperSelector {} }

    // Piixident Components (always loaded, controlled by their `open` property)
    Loader {
        id: wallpaperPickerLoader
        active: true
        source: "modules/ii/wallpaperSelector/PiixidentWallpaperSelector.qml"
        onLoaded: item.objectName = "wallpaperPicker"
    }
    
    Loader {
        id: windowSwitcherLoader
        active: true
        source: "modules/ii/overview/PiixidentWindowSwitcher.qml"
        onLoaded: item.objectName = "windowSwitcher"
    }

    PanelLoader { identifier: "wActionCenter"; component: WaffleActionCenter {} }
    PanelLoader { identifier: "wBar"; component: WaffleBar {} }
    PanelLoader { identifier: "wBackground"; component: WaffleBackground {} }
    PanelLoader { identifier: "wLock"; component: WaffleLock {} }
    PanelLoader { identifier: "wNotificationCenter"; component: WaffleNotificationCenter {} }
    PanelLoader { identifier: "wOnScreenDisplay"; component: WaffleOSD {} }
    PanelLoader { identifier: "wPolkit"; component: WafflePolkit {} }
    PanelLoader { identifier: "wStartMenu"; component: WaffleStartMenu {} }
    PanelLoader { identifier: "wSessionScreen"; component: WaffleSessionScreen {} }
    PanelLoader { identifier: "wTaskView"; component: WaffleTaskView {} }
    ReloadPopup {}

    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && Config.options.enabledPanels.includes(identifier) && extraCondition
    }

    // Panel families
    property list<string> families: ["ii", "waffle"]
    property var panelFamilies: ({
        "ii": ["iiBar", "iiBackground", "iiCheatsheet", "iiDock", "iiFloatingIsland", "iiLock", "iiMediaControls", "iiNotificationPopup", "iiOnScreenDisplay", "iiOnScreenKeyboard", "iiOverlay", "iiOverview", "iiPolkit", "iiRegionSelector", "iiScreenCorners", "iiSessionScreen", "iiSidebarLeft", "iiSidebarRight", "iiStickyNotes", "iiVerticalBar", "iiWallpaperSelector"],
        "waffle": ["wActionCenter", "wBar", "wBackground", "wLock", "wNotificationCenter", "wOnScreenDisplay", "wTaskView", "wPolkit", "wSessionScreen", "wStartMenu", "iiCheatsheet", "iiNotificationPopup", "iiOnScreenKeyboard", "iiOverlay", "iiRegionSelector", "iiWallpaperSelector"],
    })
    function cyclePanelFamily() {
        const currentIndex = families.indexOf(Config.options.panelFamily)
        const nextIndex = (currentIndex + 1) % families.length
        Config.options.panelFamily = families[nextIndex]
        Config.options.enabledPanels = panelFamilies[Config.options.panelFamily]
    }

    IpcHandler {
        target: "panelFamily"

        function cycle(): void {
            root.cyclePanelFamily()
        }
    }

    GlobalShortcut {
        name: "panelFamilyCycle"
        description: "Cycles panel family"

        onPressed: root.cyclePanelFamily()
    }
}

