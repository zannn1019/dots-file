pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    readonly property real cardWidth: 420
    readonly property real elev: Appearance.sizes.elevationMargin

    Loader {
        id: islandLoader
        active: GlobalStates.islandOpen

        sourceComponent: PanelWindow {
            id: islandWindow
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:floatingIsland"
            WlrLayershell.layer: WlrLayer.Overlay

            PwObjectTracker {
                objects: [Audio.sink, Audio.source]
            }

            anchors.top:  true
            anchors.left: true

            implicitWidth:  root.cardWidth + root.elev * 2
            implicitHeight: islandCard.implicitHeight + root.elev * 2

            margins {
                top:  Appearance.sizes.barHeight + 4
                left: Math.round((islandWindow.screen.width - implicitWidth) / 2)
            }

            mask: Region { item: islandCard }

            HyprlandFocusGrab {
                windows: [islandWindow]
                active:  islandLoader.active
                onCleared: () => { if (!active) GlobalStates.islandOpen = false }
            }

            StyledRectangularShadow { target: islandCard }

            Rectangle {
                id: islandCard
                anchors {
                    fill:         parent
                    leftMargin:   root.elev
                    rightMargin:  root.elev
                    topMargin:    root.elev
                    bottomMargin: root.elev
                }
                implicitWidth:  root.cardWidth
                implicitHeight: islandColumn.implicitHeight + 24
                radius:         Appearance.rounding.large
                color:          Appearance.m3colors.m3surfaceContainer
                border.width:   1
                border.color:   Appearance.colors.colLayer0Border
                clip:           true

                // Track which tab is selected; 0 = Media, 1 = Task Manager
                property int currentTab: 0

                // Fade + scale in
                opacity: 0
                scale:   0.95
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: islandColumn
                    anchors {
                        top:    parent.top
                        left:   parent.left
                        right:  parent.right
                        margins: 12
                    }
                    spacing: 12

                    // ═══════════════════════════════════════════════
                    //  Tab bar  [ Media | Task Manager ]
                    // ═══════════════════════════════════════════════
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

                            Repeater {
                                model: [
                                    { label: "Media",        icon: "music_note" },
                                    { label: "Task Manager", icon: "monitor_heart" }
                                ]

                                delegate: RippleButton {
                                    required property var modelData
                                    required property int index

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    buttonRadius: Appearance.rounding.small
                                    colBackground:      islandCard.currentTab === index
                                                        ? Appearance.colors.colPrimary
                                                        : "transparent"
                                    colBackgroundHover: islandCard.currentTab === index
                                                        ? Appearance.colors.colPrimaryHover
                                                        : Appearance.colors.colLayer1Hover
                                    colRipple:          Appearance.colors.colLayer1Active
                                    onPressed: islandCard.currentTab = index

                                    Behavior on colBackground {
                                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                    }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialSymbol {
                                            text:     modelData.icon
                                            fill:     islandCard.currentTab === index ? 1 : 0
                                            iconSize: Appearance.font.pixelSize.normal
                                            color:    islandCard.currentTab === index
                                                      ? Appearance.m3colors.m3onPrimary
                                                      : Appearance.colors.colOnLayer1
                                            Behavior on color {
                                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                            }
                                        }

                                        StyledText {
                                            text:           modelData.label
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight:    islandCard.currentTab === index ? Font.SemiBold : Font.Normal
                                            color:          islandCard.currentTab === index
                                                            ? Appearance.m3colors.m3onPrimary
                                                            : Appearance.colors.colOnLayer1
                                            Behavior on color {
                                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ═══════════════════════════════════════════════
                    //  Tab content
                    // ═══════════════════════════════════════════════
                    StackLayout {
                        Layout.fillWidth: true
                        currentIndex: islandCard.currentTab

                        // Tab 0 — Media
                        IslandMediaTab {
                            islandWindow: islandWindow
                            activePlayer: MprisController.activePlayer
                        }

                        // Tab 1 — Task Manager
                        IslandTaskManagerTab {
                            islandOpen: GlobalStates.islandOpen
                        }
                    }

                    Item { implicitHeight: 4 }
                }
            }
        }
    }
}
