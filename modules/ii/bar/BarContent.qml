import qs.modules.ii.bar.weather
import qs.modules.ii.dock
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    property string hostname: "localhost"
    Process {
        id: hostnameProc
        running: true
        command: ["cat", "/etc/hostname"]
        stdout: SplitParser {
            onRead: data => root.hostname = data.trim()
        }
    }

    property var lyricsData: []
    property string lyricState: "CLEAR"
    property string currentLyricText: ""
    property string currentLyricFormatted: ""
    readonly property bool isSpotify: MprisController.activePlayer?.dbusName.includes("spotify") ?? false

    Process {
        id: notifySync
        property string msg: ""
    }

    Process {
        id: lyricsProc
        running: root.isSpotify
        command: ["python3", "/home/zan/.config/quickshell/ii/scripts/piixident/python/ytm-lyrics-pipe"]
        stdout: SplitParser {
            onRead: data => {
                let msg = data.trim();
                if (msg === "CLEAR") {
                    root.lyricState = "CLEAR";
                    root.lyricsData = [];
                } else if (msg === "SEARCHING") {
                    root.lyricState = "SEARCHING";
                    root.lyricsData = [];
                } else if (msg === "NOLYRICS") {
                    root.lyricState = "NOLYRICS";
                    root.lyricsData = [];
                } else if (msg.startsWith("{")) {
                    try {
                        let parsed = JSON.parse(msg);
                        root.lyricsData = parsed.lines || [];
                        root.lyricState = "FOUND";
                        
                        // Inform the user if highlighting is available for this song
                        let hasWords = root.lyricsData.some(l => l.words && l.words.length > 0);
                        notifySync.msg = hasWords ? "Word-level sync: ON" : "Word-level sync: OFF (Line only)";
                        notifySync.running = false;
                        notifySync.running = true;
                    } catch (e) {
                        console.log("Failed to parse lyrics JSON");
                    }
                }
            }
        }
    }

    property real lastMprisPos: 0
    property real lastMprisUpdate: 0
    property int lyricsOffsetMs: 200 // Default to 200ms (scroll on center pill to tune manually)

    property bool showingOffset: false
    Timer {
        id: offsetFeedbackTimer
        interval: 1500
        onTriggered: root.showingOffset = false
    }

    onLyricsOffsetMsChanged: {
        root.showingOffset = true
        offsetFeedbackTimer.restart()
    }

    // Reset interpolation state when active player changes
    Connections {
        target: MprisController
        function onActivePlayerChanged() {
            root.lastMprisPos = 0
            root.lastMprisUpdate = Date.now()
        }
    }

    Timer {
        id: lyricTimer
        interval: 32 // Higher refresh (approx 30fps) for buttery smooth interpolation
        running: root.isSpotify && MprisController.activePlayer?.isPlaying && root.lyricState === "FOUND"
        repeat: true
        onTriggered: {
            if (!MprisController.activePlayer) return;
            
            let mprisPos = MprisController.activePlayer.position;
            let now = Date.now();

            // Detect when the MPRIS position actually changes (polling usually happens every 500ms-1s)
            // Or if the gap between now and last update is suspiciously large (e.g. after a pause/freeze)
            let drift = (now - root.lastMprisUpdate);
            if (mprisPos !== root.lastMprisPos || drift > 2000) {
                root.lastMprisPos = mprisPos;
                root.lastMprisUpdate = now;
            }

            // Interpolate the "real" time based on the last update and wall-clock time
            let elapsedSec = (now - root.lastMprisUpdate) / 1000;
            // Clamp elapsedSec to prevent massive jumps if the system clock hangs
            if (elapsedSec > 2.0) elapsedSec = 0; 
            
            let smoothedPosSec = root.lastMprisPos + elapsedSec;

            // Apply global offset
            let posMs = (smoothedPosSec * 1000) + root.lyricsOffsetMs;
            let foundLine = null;
            for (let i = 0; i < root.lyricsData.length; i++) {
                let line = root.lyricsData[i];
                if (posMs >= line.start && posMs <= line.end) {
                    foundLine = line;
                    break;
                }
            }
            
            if (foundLine) {
                root.currentLyricText = foundLine.text;
                
                // Spotify-style word highlighting
                if (foundLine.words && foundLine.words.length > 0) {
                    let richText = "";
                    for (let i = 0; i < foundLine.words.length; i++) {
                        let w = foundLine.words[i];
                        let isActive = posMs >= w.start;
                        // Use pure white for active and a muted gray for future for maximum contrast
                        let hexColor = isActive ? "#FFFFFF" : "#555555";
                        richText += `<font color="${hexColor}">${w.word}</font> `;
                    }
                    root.currentLyricFormatted = richText.trim();
                } else {
                    root.currentLyricFormatted = foundLine.text;
                }
            } else {
                root.currentLyricText = "";
                root.currentLyricFormatted = "";
            }
        }
    }

    property string centerDisplayText: {
        if (root.showingOffset) {
            return `Sync Offset: ${root.lyricsOffsetMs > 0 ? "+" : ""}${root.lyricsOffsetMs}ms`;
        }

        let text = `${SystemInfo.username}@${root.hostname}`;
        
        let player = MprisController.activePlayer;
        if (player && player.playbackState !== MprisPlaybackState.Stopped) {
            let trackInfo = `${player.trackTitle || "Unknown"} — ${player.trackArtist || "Unknown"}`;
            
            if (root.lyricState === "FOUND" && root.currentLyricText !== "") {
                text = root.currentLyricFormatted;
            } else if (root.lyricState === "SEARCHING") {
                text = "Searching lyrics... " + trackInfo;
            } else {
                // NOLYRICS or CLEAR but stopped? If player is playing but no lyrics, fallback to info.
                text = trackInfo;
            }
        }
        return text;
    }

    // ══════════════════════════════════════════════════════════════
    //  LEFT — Floating Pill (Sidebar + Workspaces)
    // ══════════════════════════════════════════════════════════════
    Rectangle {
        id: leftFloatingPill
        anchors {
            verticalCenter: parent.verticalCenter
            left:           parent.left
            leftMargin:     12
        }
        width:  leftRow.implicitWidth + 24
        height: parent.height - 12
        color:  "transparent"
        radius: height / 2

        WheelHandler {
            onWheel: event => {
                if (event.angleDelta.y > 0)
                    root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + 0.05)
                else
                    root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness - 0.05)
            }
        }

        RowLayout {
            id: leftRow
            anchors.centerIn: parent
            spacing: 8

            LeftSidebarButton {
                Layout.alignment: Qt.AlignVCenter
            }

            Workspaces {
                Layout.alignment: Qt.AlignVCenter
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onPressed: event => {
                        if (event.button === Qt.RightButton)
                            GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  CENTER — Floating Pill (User@Host)
    // ══════════════════════════════════════════════════════════════
    Rectangle {
        id: centerFloatingPill
        anchors {
            verticalCenter:   parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
        }

        width:  centerRow.implicitWidth + 32
        height: parent.height - 12
        radius: height / 2
        color:  centerPillMouse.containsMouse
                    ? (GlobalStates.islandOpen ? Appearance.colors.colLayer2Active : Appearance.colors.colLayer2Hover)
                    : (GlobalStates.islandOpen ? Appearance.colors.colLayer2Hover  : "transparent")

        Behavior on width {
            NumberAnimation {
                duration: 350
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
            }
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }


        AnimatedImage {
            id: animeDance
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: -50 // Push out past the pill boundary!
            
            // Scaled up immensely to pop out and decorate the bar!
            height: centerFloatingPill.height * 1.7
            width: height * 1.2
            fillMode: Image.PreserveAspectFit
            
            source: "file:///home/zan/.config/quickshell/ii/dance.gif"
            
            property bool isMediaPlaying: MprisController.activePlayer?.isPlaying ?? false
            visible: isMediaPlaying
            playing: visible
            
            Behavior on opacity { NumberAnimation { duration: 300 } }
            opacity: visible ? 1 : 0
        }

        RowLayout {
            id: centerRow
            spacing: 8

            // Invisible spacer forcing the centered row to shift right so the anime girl isn't covering the text
            Item {
                Layout.preferredWidth: animeDance.visible ? (animeDance.width / 1.7) : 0
                Layout.preferredHeight: 1
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 300 } }
            }

            StyledText {
                id: centerText
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 500
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize:   Appearance.font.pixelSize.normal
                font.family:      "Noto Sans CJK JP"
                color:            Appearance.colors.colOnLayer1
                text:             root.centerDisplayText
                textFormat:       Text.RichText // Use RichText for better color tag support
                elide:            Text.ElideRight

                // Gorgeous, mind-blowing bouncy snap transition for Karaoke lyrics
                transformOrigin: Item.Center

                property string lineKey: root.currentLyricText
                Behavior on lineKey {
                    id: lineChangeBehavior
                    enabled: root.currentLyricText !== ""
                    
                    SequentialAnimation {
                        // 1. Shrink and softly vanish the old lyric away (100ms)
                        ParallelAnimation {
                            NumberAnimation { target: centerText; property: "opacity"; to: 0; duration: 100; easing.type: Easing.InSine }
                            NumberAnimation { target: centerText; property: "scale"; to: 0.90; duration: 100; easing.type: Easing.InSine }
                        }
                        
                        // 2. Secretly change the text behind the scenes and prepare the new lyric scaled up
                        PropertyAction { target: centerText; property: "text" }
                        PropertyAction { target: centerText; property: "scale"; value: 1.10 }
                        
                        // 3. Forcefully bounce the new lyric into view exactly on the beat (200ms)
                        ParallelAnimation {
                            NumberAnimation { target: centerText; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                            NumberAnimation { target: centerText; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                        }
                    }
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text:     GlobalStates.islandOpen ? "expand_less" : "expand_more"
                fill:     0
                iconSize: Appearance.font.pixelSize.normal
                color:    Appearance.colors.colSubtext
            }
        }

        MouseArea {
            id: centerPillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onWheel: event => {
                if (event.angleDelta.y > 0)
                    root.lyricsOffsetMs += 50
                else
                    root.lyricsOffsetMs -= 50
            }
            onPressed: GlobalStates.islandOpen = !GlobalStates.islandOpen
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  RIGHT — Floating Pill (Sync + Clock + Power)
    // ══════════════════════════════════════════════════════════════
    Rectangle {
        id: rightFloatingPill
        anchors {
            verticalCenter: parent.verticalCenter
            right:          parent.right
            rightMargin:    12
        }
        width:  rightRow.implicitWidth + 24
        height: parent.height - 12
        color:  "transparent"
        radius: height / 2

        WheelHandler {
            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume()
                else
                    Audio.decrementVolume()
            }
        }

        RowLayout {
            id: rightRow
            anchors.centerIn: parent
            spacing: 10

            MaterialSymbol {
                text:     "sync"
                iconSize: Appearance.font.pixelSize.large
                color:    Appearance.colors.colOnLayer0
                RotationAnimator on rotation {
                    running:  Updates.checking
                    loops:    Animation.Infinite
                    from:     0
                    to:       360
                    duration: 1000
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: Updates.refresh()
                }
            }

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.normal
                color:          Appearance.colors.colOnLayer0
                text:           DateTime.time
                MouseArea {
                    anchors.fill: parent
                    onPressed: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }
            }

            MaterialSymbol {
                text:     "power_settings_new"
                iconSize: Appearance.font.pixelSize.large
                color:    Appearance.colors.colOnLayer0
                MouseArea {
                    anchors.fill: parent
                    onPressed: GlobalStates.sessionOpen = !GlobalStates.sessionOpen
                }
            }
        }
    }
}