import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

// A parallelogram-shaped wallpaper card.
// The image is NEVER distorted — it always uses PreserveAspectCrop.
// The parallelogram shape is achieved with an OpacityMask whose maskSource
// is a Shape that draws a solid parallelogram polygon.
Item {
    id: root
    required property var fileModelData
    property bool isDirectory: fileModelData.fileIsDir
    readonly property list<string> videoExtensions: ["mp4", "webm", "mkv", "avi", "mov"]
    readonly property bool isVideo: videoExtensions.some(
        ext => fileModelData.fileName.toLowerCase().endsWith(`.${ext}`))
    property bool useThumbnail: Images.isValidImageByName(fileModelData.fileName) || root.isVideo
    property bool isActive:  fileModelData.filePath === Config.options.background.wallpaperPath
    property bool isCurrent: false

    // How far (in px) the top-left/bottom-right corners lean rightward.
    // Must match skewPx in WallpaperSelectorContent so edges align.
    property real skewPx: 28

    signal activated()
    signal entered()
    signal exited()

    // ── The mask: a solid parallelogram drawn by a Shape ─────────────────
    // Vertices (clockwise):
    //   top-left:     (skewPx, 0)
    //   top-right:    (width + skewPx, 0)
    //   bottom-right: (width, height)
    //   bottom-left:  (0, height)
    Shape {
        id: maskShape
        width:  root.width + root.skewPx
        height: root.height
        // Must be rendered off-screen (or at least invisible) but still
        // produce a valid layer texture for OpacityMask.
        visible: false
        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor:   "white"
            // Start at top-left
            startX: root.skewPx; startY: 0
            PathLine { x: root.width + root.skewPx; y: 0               }
            PathLine { x: root.width;                y: root.height     }
            PathLine { x: 0;                          y: root.height     }
            PathLine { x: root.skewPx;               y: 0               }
        }
    }

    // ── Content area (same size as the mask) ─────────────────────────────
    Item {
        id: contentArea
        width:  root.width + root.skewPx
        height: root.height

        // Apply the parallelogram mask to the whole content area
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: maskShape
        }

        // ── Thumbnail / directory icon ────────────────────────────────
        Loader {
            id: thumbLoader
            anchors.fill: parent
            active: root.useThumbnail
            sourceComponent: ThumbnailImage {
                id: thumbImg
                generateThumbnail: false
                sourcePath: fileModelData.filePath
                cache: false
                fillMode: Image.PreserveAspectCrop
                clip: true
                Connections {
                    target: Wallpapers
                    function onThumbnailGenerated(directory) {
                        if (thumbImg.status !== Image.Error) return
                        if (FileUtils.parentDirectory(thumbImg.sourcePath) !== directory) return
                        thumbImg.source = ""; thumbImg.source = thumbImg.thumbnailPath
                    }
                    function onThumbnailGeneratedFile(filePath) {
                        if (thumbImg.status !== Image.Error) return
                        if (Qt.resolvedUrl(thumbImg.sourcePath) !== Qt.resolvedUrl(filePath)) return
                        thumbImg.source = ""; thumbImg.source = thumbImg.thumbnailPath
                    }
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: !root.useThumbnail
            sourceComponent: DirectoryIcon { fileModelData: root.fileModelData }
        }

        // Loading placeholder
        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colLayer1
            visible: root.useThumbnail && (thumbLoader.item?.status !== Image.Ready ?? true)
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.isDirectory ? "folder" : "image"
                iconSize: 30
                color: Appearance.colors.colOnLayer1
                opacity: 0.3
            }
        }

        // Hover / selected tint overlay
        Rectangle {
            anchors.fill: parent
            color: root.isCurrent ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.22)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Active wallpaper indicator — bottom bar
        Rectangle {
            visible: root.isActive
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 3
            color: Appearance.colors.colPrimary
        }

        // Left edge separator line (follows slant via x offset)
        Rectangle {
            x:      root.skewPx - 1
            y:      0
            width:  1
            height: root.height
            color:  Qt.rgba(0, 0, 0, 0.4)
            transform: Rotation {
                origin.x: 0; origin.y: 0
                angle: -Math.atan2(root.skewPx, root.height) * (180 / Math.PI)
            }
        }

        // Video play badge
        Rectangle {
            visible: root.isVideo
            anchors { top: parent.top; right: parent.right; margins: 6 }
            width: 28; height: 28; radius: 14
            color: Qt.rgba(0, 0, 0, 0.65)
            MaterialSymbol {
                anchors.centerIn: parent
                text: "play_arrow"; iconSize: 16; color: "white"
            }
        }
    }

    // ── Hit area: full logical slot ───────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.entered()
        onExited:  root.exited()
        onClicked: root.activated()
    }
}
