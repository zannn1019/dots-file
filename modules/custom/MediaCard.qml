import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool shown: false
    property int hiddenOffset: -120
    
    // Real MPRIS data
    property var player: MprisController.activePlayer
    property string songTitle: player?.trackTitle ?? "No media playing"
    property string artistName: player?.trackArtist ?? ""
    property string albumArt: player?.trackArtUrl ?? ""
    property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing
    
    // Track position - live tracking
    property int currentSeconds: 0
    property int totalSeconds: 0
    property real progress: totalSeconds > 0 ? (currentSeconds / totalSeconds) : 0
    
    // Album art download
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(albumArt)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property bool artDownloaded: false
    property string displayedArtUrl: artDownloaded ? Qt.resolvedUrl(artFilePath) : ""
    
    // Animation properties
    property real cardScale: shown ? 1 : 0.9
    property real contentOpacity: shown ? 1 : 0
    property real albumRotation: 0
    
    // Dynamic colors from album art
    property color dominantColor: "#8B7355"
    property color accentColor: "#6B5D4F"
    
    // Visualizer properties
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000
    property int visualizerSmoothing: 2
    
    function updateTime() {
        if (player) {
            currentSeconds = Math.floor(player.position / 1000000);
            totalSeconds = Math.floor(player.length / 1000000);
        }
    }
    
    function formatTime(seconds) {
        if (!seconds || seconds === 0) return "0:00";
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    }

    width: 400
    height: 100
    scale: cardScale
    opacity: shown ? 1 : 0
    y: shown ? 0 : hiddenOffset

    Component.onCompleted: {
        showTimer.start();
        updateTime();
    }

    anchors {
        horizontalCenter: parent.horizontalCenter
        top: parent.top
        topMargin: 30
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) {
                shown = false;
                showTimer.restart();
            }
        }
    }
    
    Connections {
        target: root.player
        function onPositionChanged() { 
            updateTime(); 
        }
        function onLengthChanged() { 
            updateTime(); 
        }
        function onPlaybackStateChanged() {
            updateTime();
        }
    }
    
    onPlayerChanged: {
        updateTime();
    }

    Timer {
        id: showTimer
        interval: 500
        onTriggered: shown = true
    }
    
    // Update time every second
    Timer {
        running: root.player !== null && root.isPlaying
        interval: 500
        repeat: true
        onTriggered: updateTime()
    }
    
    // Download album art
    Process {
        id: coverArtDownloader
        property string targetFile: root.albumArt
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: (exitCode, exitStatus) => {
            root.artDownloaded = true;
        }
    }
    
    onAlbumArtChanged: {
        if (root.albumArt.length === 0) return;
        coverArtDownloader.targetFile = root.albumArt;
        coverArtDownloader.artFilePath = root.artFilePath;
        root.artDownloaded = false;
        coverArtDownloader.running = true;
    }
    
    // Vinyl rotation animation when playing
    NumberAnimation on albumRotation {
        running: root.isPlaying
        from: albumRotation
        to: albumRotation + 360
        duration: 3000
        loops: Animation.Infinite
    }

    // Design matching the reference image
    Rectangle {
        id: cardBackground
        anchors.fill: parent
        radius: 16
        opacity: root.contentOpacity
        color: "transparent"
        clip: true
        
        // Background album art with blur
        Image {
            id: bgArt
            anchors.fill: parent
            source: root.displayedArtUrl
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
        }
        
        FastBlur {
            anchors.fill: parent
            source: bgArt
            radius: 64
            visible: root.displayedArtUrl !== ""
        }
        
        // Dark overlay
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5
        }
        
        // Wave visualizer
        WaveVisualizer {
            anchors.fill: parent
            live: root.isPlaying
            points: root.visualizerPoints
            maxVisualizerValue: root.maxVisualizerValue
            smoothing: root.visualizerSmoothing
            color: "#ffffff"
        }
        
        // Subtle gradient for depth
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { 
                    position: 0.0
                    color: Qt.rgba(0, 0, 0, 0.2)
                }
                GradientStop { 
                    position: 1.0
                    color: "transparent"
                }
            }
        }
        
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 4
            radius: 12
            samples: 25
            color: "#80000000"
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12
            
            // Album art - vinyl rotation effect
            Item {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80
                Layout.alignment: Qt.AlignVCenter
                
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "#40000000"
                    
                    Behavior on rotation {
                        enabled: !root.isPlaying
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                    
                    Image {
                        anchors.fill: parent
                        source: root.displayedArtUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: root.displayedArtUrl !== ""
                        asynchronous: true
                        
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: 80
                                height: 80
                                radius: 8
                            }
                        }
                    }
                    
                    // Vinyl record circles
                    Repeater {
                        model: 2
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - (index * 30)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: "#20ffffff"
                            border.width: 1
                            visible: root.displayedArtUrl !== ""
                        }
                    }
                    
                    // Center hole
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        radius: 6
                        color: "#40000000"
                        border.color: "#30ffffff"
                        border.width: 1
                        visible: root.displayedArtUrl !== ""
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        font.pixelSize: 36
                        color: "#ffffff"
                        opacity: 0.5
                        visible: root.displayedArtUrl === ""
                    }
                }
            }
            
            // Middle section - song info and progress
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 4
                spacing: 4
                
                Item { Layout.fillHeight: true }
                
                // Song title
                Text {
                    Layout.fillWidth: true
                    text: root.songTitle
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#ffffff"
                    elide: Text.ElideRight
                }
                
                // Artist name
                Text {
                    Layout.fillWidth: true
                    text: root.artistName
                    font.pixelSize: 13
                    color: "#ffffff"
                    opacity: 0.85
                    elide: Text.ElideRight
                }
                
                // Clickable progress bar with glow
                // Rectangle {
                //     Layout.fillWidth: true
                //     Layout.preferredHeight: 6
                //     Layout.topMargin: 8
                //     radius: 3
                //     color: "#50ffffff"
                    
                //     Rectangle {
                //         id: progressFill
                //         width: parent.width * root.progress
                //         height: parent.height
                //         radius: parent.radius
                //         color: "#ffffff"
                        
                //         layer.enabled: true
                //         layer.effect: Glow {
                //             samples: 15
                //             color: "#60ffffff"
                //             spread: 0.3
                //         }
                        
                //         Behavior on width {
                //             NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                //         }
                //     }
                    
                //     MouseArea {
                //         anchors.fill: parent
                //         onClicked: (mouse) => {
                //             if (root.player && root.totalSeconds > 0) {
                //                 const clickProgress = mouse.x / width;
                //                 const newPosition = clickProgress * root.totalSeconds * 1000000;
                //                 root.player.position = newPosition;
                //             }
                //         }
                //     }
                // }
                
                Item { Layout.fillHeight: true }
            }
            
            // Right section - control buttons
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 4
                spacing: 6
                
                // Previous button
                RoundButton {
                    iconText: "⏮"
                    onClicked: if (root.player) root.player.previous()
                }
                
                // Play/Pause button with pulse animation
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 24
                    color: "#9B8B6F"
                    
                    property bool hovered: false
                    property real pulseScale: 1.0
                    scale: hovered ? 1.1 : pulseScale
                    
                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                    
                    // Pulsing animation when playing
                    SequentialAnimation on pulseScale {
                        running: root.isPlaying
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.05; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
                    
                    layer.enabled: root.isPlaying
                    layer.effect: Glow {
                        samples: 20
                        color: "#409B8B6F"
                        spread: 0.4
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "⏸" : "▶"
                        font.pixelSize: 20
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        onClicked: if (root.player) root.player.togglePlaying()
                    }
                }
                
                // Next button
                RoundButton {
                    iconText: "⏭"
                    onClicked: if (root.player) root.player.next()
                }
            }
        }
    }
    
    // Small round button component
    component RoundButton: Rectangle {
        id: btn
        property string iconText: ""
        property bool hovered: false
        signal clicked()
        
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: 16
        color: hovered ? "#60ffffff" : "#40ffffff"
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        
        Text {
            anchors.centerIn: parent
            text: btn.iconText
            font.pixelSize: 14
            color: "#ffffff"
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: btn.hovered = true
            onExited: btn.hovered = false
            onClicked: btn.clicked()
        }
    }



    Behavior on opacity {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutCubic
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: 1000
            easing.type: Easing.OutBack
            easing.overshoot: 1.3
        }
    }
    
    Behavior on scale {
        NumberAnimation {
            duration: 900
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }
    
    Behavior on contentOpacity {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutCubic
        }
    }
    
    Behavior on rotation {
        NumberAnimation {
            duration: 800
            easing.type: Easing.OutCubic
        }
    }

}
