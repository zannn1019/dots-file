import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool useDarkMode: Appearance.m3colors.darkmode
    readonly property list<string> videoExtensions: ["mp4", "webm", "mkv", "avi", "mov"]
    function fileIsVideo(name) {
        return videoExtensions.some(ext => name.toLowerCase().endsWith(`.${ext}`))
    }

    property int    currentIndex:   -1
    property string currentPath:    ""
    property string currentName:    ""
    property bool   currentIsVideo: false

    // ---- parallelogram geometry ----
    // skewPx MUST match WallpaperDirectoryItem.skewPx — it's the overlap between cards
    readonly property real skewPx:      28      // parallelogram lean in pixels
    readonly property real cardW:       130     // logical slot width (visual = cardW + skewPx)
    readonly property real cardH:       root.height - root.topBarH
    readonly property real cardSpacing: -root.skewPx   // negative = slanted edges overlap cleanly
    readonly property real popupW:      340
    readonly property real popupH:      460
    readonly property real topBarH:     46

    Process { id: applyProc }
    function applyWallpaper(path) {
        applyProc.exec(["waypaper", "--wallpaper", FileUtils.trimFileProtocol(path), "--no-post-command"])
        Wallpapers.select(path, root.useDarkMode)
    }

    function updateThumbnails() {
        const sz = Images.thumbnailSizeNameForDimensions(root.cardW, root.cardH)
        Wallpapers.generateThumbnail(sz)
    }

    Connections {
        target: Wallpapers
        function onDirectoryChanged() { root.updateThumbnails() }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (root.currentIndex >= 0) root.currentIndex = -1
            else GlobalStates.wallpaperSelectorOpen = false
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            root.currentIndex = Math.max(0, root.currentIndex - 1); event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            root.currentIndex = Math.min(strip.count - 1, root.currentIndex + 1); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.currentPath.length > 0) root.applyWallpaper(root.currentPath); event.accepted = true
        } else if (event.key === Qt.Key_Slash) {
            filterField.forceActiveFocus(); event.accepted = true
        } else if (event.text.length > 0) {
            filterField.text += event.text; filterField.forceActiveFocus(); event.accepted = true
        }
    }

    onCurrentIndexChanged: {
        if (currentIndex >= 0 && currentIndex < strip.count) {
            strip.positionViewAtIndex(currentIndex, ListView.Contain)
            root.currentPath    = Wallpapers.folderModel.get(currentIndex, "filePath") || ""
            root.currentName    = Wallpapers.folderModel.get(currentIndex, "fileName") || ""
            root.currentIsVideo = root.fileIsVideo(root.currentName)
        } else {
            root.currentPath = ""; root.currentName = ""; root.currentIsVideo = false
        }
    }

    StyledRectangularShadow { target: outerBg }

    Rectangle {
        id: outerBg
        anchors { fill: parent; margins: Appearance.sizes.elevationMargin }
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        clip: true

        // ── Top bar ──────────────────────────────────────────────
        Rectangle {
            id: topBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: root.topBarH
            color: Appearance.colors.colLayer1

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 6

                StyledText {
                    text: Translation.tr("Wallpapers")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                }

                Repeater {
                    model: [
                        { icon: "home",      name: "Home",       path: FileUtils.trimFileProtocol(Directories.home) },
                        { icon: "image",     name: "Pictures",   path: FileUtils.trimFileProtocol(Directories.pictures) },
                        { icon: "wallpaper", name: "Wallpapers", path: FileUtils.trimFileProtocol(Directories.pictures) + "/Wallpapers" },
                        { icon: "movie",     name: "Videos",     path: FileUtils.trimFileProtocol(Directories.videos) },
                    ]
                    delegate: RippleButton {
                        required property var modelData
                        toggled: Wallpapers.directory === Qt.resolvedUrl(modelData.path)
                        colBackgroundToggled: Appearance.colors.colSecondaryContainer
                        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                        buttonRadius: height / 2
                        implicitHeight: 30
                        onClicked: Wallpapers.setDirectory(modelData.path)
                        contentItem: RowLayout {
                            spacing: 3
                            MaterialSymbol {
                                text: modelData.icon; iconSize: 15
                                color: toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: modelData.name; font.pixelSize: Appearance.font.pixelSize.small
                                color: toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                AddressBar {
                    id: addressBar
                    Layout.preferredWidth: 240
                    Layout.fillHeight: false
                    directory: Wallpapers.effectiveDirectory
                    onNavigateToDirectory: path => Wallpapers.setDirectory(path.length === 0 ? "/" : path)
                    radius: 8
                }

                ToolbarTextField {
                    id: filterField
                    Layout.preferredWidth: 140
                    placeholderText: focus ? Translation.tr("Search") : Translation.tr("/ to search")
                    font.pixelSize: Appearance.font.pixelSize.small
                    onTextChanged: Wallpapers.searchQuery = text
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) { text = ""; root.forceActiveFocus(); event.accepted = true }
                    }
                }

                IconToolbarButton {
                    implicitWidth: height; text: root.useDarkMode ? "dark_mode" : "light_mode"
                    onClicked: root.useDarkMode = !root.useDarkMode
                    StyledToolTip { text: Translation.tr("Toggle light/dark mode") }
                }
                IconToolbarButton {
                    implicitWidth: height; text: "ifl"
                    onClicked: Wallpapers.randomFromCurrentFolder()
                    StyledToolTip { text: Translation.tr("Random wallpaper") }
                }
                IconToolbarButton {
                    implicitWidth: height; text: "close"
                    onClicked: GlobalStates.wallpaperSelectorOpen = false
                    StyledToolTip { text: Translation.tr("Close") }
                }
            }
        }

        // Progress bars
        StyledIndeterminateProgressBar {
            id: indeterminateBar
            anchors { top: topBar.bottom; left: parent.left; right: parent.right }
            visible: Wallpapers.thumbnailGenerationRunning && value === 0
        }
        StyledProgressBar {
            anchors.fill: indeterminateBar
            visible: Wallpapers.thumbnailGenerationRunning && value > 0
            value: Wallpapers.thumbnailGenerationProgress
        }

        // ── Parallelogram strip area ──────────────────────────────
        Item {
            id: stripArea
            anchors { top: topBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
            clip: true

            // Dark background for the card rail
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.05, 0.05, 0.07, 1)
            }

            // The strip — negative spacing makes parallelograms touch edge-to-edge
            ListView {
                id: strip
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing:     root.cardSpacing   // negative = overlap
                clip:        true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: StyledScrollBar {}
                model: Wallpapers.folderModel
                onModelChanged: root.currentIndex = -1
                Component.onCompleted: root.updateThumbnails()

                ScrollEdgeFade {
                    target: strip
                    vertical: false
                    color: Qt.rgba(0.05, 0.05, 0.07, 1)
                }

                delegate: WallpaperDirectoryItem {
                    required property var modelData
                    required property int index
                    fileModelData: modelData
                    skewPx:    root.skewPx
                    // width is the logical slot; visual parallelogram extends skewPx to the right
                    // and is handled inside the item — ListView only cares about this width
                    width:     root.cardW
                    height:    strip.height
                    isCurrent: index === root.currentIndex
                    // Raise selected card so its right-bleed renders above the next card
                    z:         index === root.currentIndex ? 2 : 1
                    onEntered:   root.currentIndex = index
                    onActivated: {
                        root.currentIndex = index
                        if (modelData.fileIsDir)
                            Wallpapers.setDirectory(modelData.filePath)
                        else if (!root.fileIsVideo(modelData.fileName))
                            root.applyWallpaper(modelData.filePath)
                    }
                }
            }

            // ── Popup preview ────────────────────────────────────
            Item {
                id: popup
                anchors.centerIn: parent
                width:  root.popupW
                height: root.popupH
                z: 20

                readonly property bool active: root.currentPath.length > 0
                property real prog: 0
                Behavior on prog { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                onActiveChanged: prog = active ? 1 : 0
                visible: prog > 0.01
                opacity: prog
                scale:   0.88 + prog * 0.12

                // Drop shadow behind card
                Rectangle {
                    anchors { fill: card; margins: -2 }
                    radius: card.radius + 2
                    color: "transparent"
                    layer.enabled: true
                    layer.effect: DropShadow {
                        radius: 40; samples: 33
                        horizontalOffset: 0; verticalOffset: 12
                        color: Qt.rgba(0, 0, 0, 0.9)
                    }
                }

                Rectangle {
                    id: card
                    anchors.fill: parent
                    radius: 14
                    color: Appearance.colors.colLayer0
                    clip: true

                    // Full-res preview image
                    ThumbnailImage {
                        id: popupImg
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: parent.height - infoBar.height
                        visible: !root.currentIsVideo
                        generateThumbnail: true
                        sourcePath: (!root.currentIsVideo && root.currentPath.length > 0) ? root.currentPath : ""
                        cache: true
                        sourceSize.width: root.popupW
                        sourceSize.height: root.popupH
                        fillMode: Image.PreserveAspectCrop
                        clip: true
                        Connections {
                            target: Wallpapers
                            function onThumbnailGenerated(dir) {
                                if (popupImg.status !== Image.Error) return
                                popupImg.source = ""; popupImg.source = popupImg.thumbnailPath
                            }
                            function onThumbnailGeneratedFile(fp) {
                                if (popupImg.status !== Image.Error) return
                                if (Qt.resolvedUrl(popupImg.sourcePath) !== Qt.resolvedUrl(fp)) return
                                popupImg.source = ""; popupImg.source = popupImg.thumbnailPath
                            }
                        }
                    }

                    // Placeholder while loading
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: parent.height - infoBar.height
                        color: Appearance.colors.colLayer1
                        visible: !root.currentIsVideo && popupImg.status !== Image.Ready
                        MaterialSymbol {
                            anchors.centerIn: parent; text: "image"; iconSize: 48
                            color: Appearance.colors.colOnLayer1; opacity: 0.2
                        }
                    }

                    // Video player loader
                    Loader {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: parent.height - infoBar.height
                        active: root.currentIsVideo && root.currentPath.length > 0
                        sourceComponent: Item {
                            clip: true
                            MediaPlayer {
                                id: vplayer
                                source: Qt.resolvedUrl(root.currentPath)
                                videoOutput: vout
                                loops: MediaPlayer.Infinite
                                Component.onCompleted: play()
                            }
                            VideoOutput { id: vout; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
                            Rectangle {
                                anchors { top: parent.top; right: parent.right; margins: 10 }
                                width: livRow.implicitWidth + 12; height: 22; radius: 4
                                color: Qt.rgba(0.85, 0.1, 0.1, 0.85)
                                Row {
                                    id: livRow; anchors.centerIn: parent; spacing: 4
                                    Rectangle {
                                        width: 7; height: 7; radius: 4; color: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                        SequentialAnimation on opacity {
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.2; duration: 500 }
                                            NumberAnimation { to: 1.0; duration: 500 }
                                        }
                                    }
                                    Text { text: "LIVE"; font.pixelSize: 10; font.weight: Font.Bold; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }

                    // Filename label (gradient overlay)
                    Rectangle {
                        anchors { left: parent.left; right: parent.right }
                        y: parent.height - infoBar.height - height
                        height: nameLabel.implicitHeight + 14
                        color: Qt.rgba(0, 0, 0, 0.65)
                        visible: root.currentName.length > 0
                        StyledText {
                            id: nameLabel
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                            text: FileUtils.trimFileExt(root.currentName).toUpperCase()
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: "white"
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Info bar with Apply button
                    Rectangle {
                        id: infoBar
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 50
                        color: Appearance.colors.colLayer1
                        RowLayout {
                            anchors { fill: parent; margins: 10 }
                            spacing: 8
                            // Active badge
                            Rectangle {
                                visible: root.currentPath === Config.options.background.wallpaperPath
                                width: activeLbl.implicitWidth + 10; height: 18; radius: 9
                                color: Appearance.colors.colPrimary
                                StyledText { id: activeLbl; anchors.centerIn: parent; text: Translation.tr("Active"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnPrimary }
                            }
                            // Format badge
                            Rectangle {
                                width: fmtLbl.implicitWidth + 10; height: 18; radius: 9
                                color: Appearance.colors.colTertiaryContainer
                                StyledText { id: fmtLbl; anchors.centerIn: parent; text: root.currentName.includes(".") ? root.currentName.split(".").pop().toUpperCase() : "DIR"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnTertiaryContainer }
                            }
                            Item { Layout.fillWidth: true }
                            RippleButton {
                                implicitHeight: 32
                                implicitWidth: applyLbl.implicitWidth + 20
                                buttonRadius: height / 2
                                colBackground: Appearance.colors.colPrimary
                                colBackgroundHover: Appearance.colors.colPrimaryHover
                                onClicked: if (root.currentPath.length > 0) root.applyWallpaper(root.currentPath)
                                contentItem: StyledText {
                                    id: applyLbl; anchors.centerIn: parent
                                    text: Translation.tr("Apply")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnPrimary
                                }
                            }
                        }
                    }
                }
            }

            // Click-outside-popup dismisses it
            MouseArea {
                anchors.fill: parent
                z: 10
                propagateComposedEvents: true
                visible: popup.visible
                onClicked: event => {
                    const m = mapToItem(popup, event.x, event.y)
                    if (m.x < 0 || m.x > popup.width || m.y < 0 || m.y > popup.height)
                        root.currentIndex = -1
                    event.accepted = false
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            if (GlobalStates.wallpaperSelectorOpen) {
                root.forceActiveFocus()
                root.currentIndex = -1
                root.updateThumbnails()
            } else {
                filterField.text = ""
                Wallpapers.searchQuery = ""
                root.currentIndex = -1
            }
        }
    }

    Connections {
        target: Wallpapers
        function onChanged() { GlobalStates.wallpaperSelectorOpen = false }
    }
}
