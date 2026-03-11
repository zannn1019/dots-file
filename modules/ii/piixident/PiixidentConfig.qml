import QtQuick
import qs.modules.common
pragma Singleton

QtObject {
    // TODO: Make this dynamic

    id: root

    // ══════════════════════════════════════════════════════════════
    //  PATHS
    // ══════════════════════════════════════════════════════════════
    readonly property string homeDir: Directories.home
    readonly property string scriptsDir: Directories.home + "/.config/quickshell/ii/scripts/piixident"
    readonly property string cacheDir: {
        let cachePath = Directories.cache;
        if (cachePath.startsWith("file://"))
            cachePath = cachePath.replace(/^file:\/\//, "");

        return cachePath + "/ii";
    }
    // Wallpaper directory - try to use the configured path, fallback to Pictures/Wallpapers
    readonly property string wallpaperDir: {
        let configPath = Config.options.background.wallpaperPath;
        if (configPath && configPath.length > 0) {
            if (configPath.startsWith("file://"))
                configPath = configPath.replace(/^file:\/\//, "");

            return configPath.replace(/\/[^\/]*$/, "");
        }
        // Fallback to Pictures/Wallpapers
        return Directories.pictures + "/Wallpapers";
    }
    // Wallpaper Engine paths (optional - leave empty if not used)
    readonly property string weDir: ""
    readonly property string weAssetsDir: ""
    readonly property string steamWorkshopDir: ""
    // ══════════════════════════════════════════════════════════════
    //  MONITOR
    // ══════════════════════════════════════════════════════════════
    readonly property string mainMonitor: "eDP-1"
    // ══════════════════════════════════════════════════════════════
    //  OLLAMA (AI wallpaper analysis - optional)
    // ══════════════════════════════════════════════════════════════
    readonly property QtObject
    ollama: QtObject {
        property string url: "http://localhost:11434"
        property string model: "gemma3:4b"
        property string vramReclaimModel: "gemma3:27b"
    }

    // ══════════════════════════════════════════════════════════════
    //  MATUGEN (dynamic colors - optional)
    // ══════════════════════════════════════════════════════════════
    readonly property QtObject
    matugen: QtObject {
        property string schemeType: "scheme-fidelity"
        property string kdeColorScheme: "PiixidentMatugen"
    }

    // ══════════════════════════════════════════════════════════════
    //  POLLING INTERVALS
    // ══════════════════════════════════════════════════════════════
    readonly property int ollamaStatusPollMs: 5000
    readonly property int systemStatsFastSec: 3
    readonly property int systemStatsSlowSec: 30
    // ══════════════════════════════════════════════════════════════
    //  STYLE / FONTS (for compatibility with piixident selector)
    // ══════════════════════════════════════════════════════════════
    readonly property QtObject
    style: QtObject {
        property string fontFamily: "Inter"
        property string fontFamilyCode: "JetBrains Mono"
        property string fontFamilyNerdIcons: "Symbols Nerd Font"
    }

}
