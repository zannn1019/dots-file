import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Hyprland


// Media tab content — media player, volume, brightness, battery
ColumnLayout {
    id: root

    // The island window — needed for Brightness monitor lookup
    required property var islandWindow
    required property var activePlayer

    spacing: 8

    // ═══════════════════════════════════════════════
    //  Media player
    // ═══════════════════════════════════════════════
    Rectangle {
        Layout.fillWidth: true
        implicitHeight:   mediaRow.implicitHeight + 20
        radius:           Appearance.rounding.normal
        color:            Appearance.colors.colLayer1

        RowLayout {
            id: mediaRow
            anchors { fill: parent; margins: 10 }
            spacing: 12

            // Album art
            Rectangle {
                implicitWidth:  52
                implicitHeight: 52
                radius:         Appearance.rounding.small
                color:          Appearance.colors.colSecondaryContainer
                clip:           true

                StyledImage {
                    anchors.fill: parent
                    source:       root.activePlayer?.trackArtUrl ?? ""
                    fillMode:     Image.PreserveAspectCrop
                    visible:      (root.activePlayer?.trackArtUrl?.length ?? 0) > 0
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible:  !((root.activePlayer?.trackArtUrl?.length ?? 0) > 0)
                    text:     "music_note"
                    fill:     1
                    iconSize: Appearance.font.pixelSize.large
                    color:    Appearance.m3colors.m3onSecondaryContainer
                }
            }

            // Title + artist + progress
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    elide:          Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color:          Appearance.colors.colOnLayer1
                    text:           StringUtils.cleanMusicTitle(root.activePlayer?.trackTitle) || Translation.tr("No media")
                }
                StyledText {
                    Layout.fillWidth: true
                    elide:          Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color:          Appearance.colors.colSubtext
                    text:           root.activePlayer?.trackArtist ?? ""
                }
                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    wavy:           root.activePlayer?.isPlaying ?? false
                    highlightColor: Appearance.colors.colPrimary
                    trackColor:     Appearance.colors.colSecondaryContainer
                    value:          (root.activePlayer?.position ?? 0) / Math.max(root.activePlayer?.length ?? 1, 1)
                }
            }

            // Playback controls
            RowLayout {
                spacing: 2

                RippleButton {
                    implicitWidth: 32; implicitHeight: 32
                    buttonRadius:       Appearance.rounding.full
                    colBackground:      "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple:          Appearance.colors.colLayer1Active
                    onPressed: root.activePlayer?.previous()
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_previous"; fill: 1
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer1
                    }
                }
                RippleButton {
                    implicitWidth: 40; implicitHeight: 40
                    buttonRadius:       root.activePlayer?.isPlaying ? Appearance.rounding.normal : Appearance.rounding.full
                    colBackground:      root.activePlayer?.isPlaying ? Appearance.colors.colPrimary          : Appearance.colors.colSecondaryContainer
                    colBackgroundHover: root.activePlayer?.isPlaying ? Appearance.colors.colPrimaryHover      : Appearance.colors.colSecondaryContainerHover
                    colRipple:          root.activePlayer?.isPlaying ? Appearance.colors.colPrimaryActive     : Appearance.colors.colSecondaryContainerActive
                    onPressed: root.activePlayer?.togglePlaying()
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.activePlayer?.isPlaying ? "pause" : "play_arrow"; fill: 1
                        iconSize: Appearance.font.pixelSize.huge
                        color: root.activePlayer?.isPlaying ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3onSecondaryContainer
                    }
                }
                RippleButton {
                    implicitWidth: 32; implicitHeight: 32
                    buttonRadius:       Appearance.rounding.full
                    colBackground:      "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple:          Appearance.colors.colLayer1Active
                    onPressed: root.activePlayer?.next()
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_next"; fill: 1
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }

        Timer {
            running:  root.activePlayer?.playbackState === MprisPlaybackState.Playing
            interval: 1000
            repeat:   true
            onTriggered: root.activePlayer?.positionChanged()
        }
    }

    // ═══════════════════════════════════════════════
    //  Volume
    // ═══════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        RippleButton {
            Layout.preferredWidth:  Appearance.font.pixelSize.large
            Layout.preferredHeight: Appearance.font.pixelSize.large
            Layout.alignment:       Qt.AlignVCenter
            buttonRadius:       Appearance.rounding.full
            colBackground:      "transparent"
            colBackgroundHover: Appearance.colors.colLayer1Hover
            colRipple:          Appearance.colors.colLayer1Active
            onPressed: Audio.toggleMute()
            MaterialSymbol {
                anchors.centerIn: parent
                text:     Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                fill:     1
                iconSize: Appearance.font.pixelSize.large
                color:    Appearance.colors.colOnLayer1
            }
        }

        StyledSlider {
            Layout.fillWidth: true
            configuration:   StyledSlider.Configuration.S
            from: 0; to: 1.5
            live: true
            value: Audio.sink?.audio?.volume ?? 0
            onMoved: {
                Audio.sink.audio.volume = value
            }
            onPressedChanged: {
                if (!pressed) {
                    if (Audio.sink) Audio.sink.audio.volume = value
                }
            }
        }

        StyledText {
            text:           `${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}%`
            font.pixelSize: Appearance.font.pixelSize.small
            color:          Appearance.colors.colSubtext
            Layout.minimumWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }

    // ═══════════════════════════════════════════════
    //  Brightness
    // ═══════════════════════════════════════════════
    RowLayout {
        id: brightnessRow
        Layout.fillWidth: true
        spacing: 8
        readonly property var mon: Brightness.getMonitorForScreen(root.islandWindow?.screen)
        visible: mon !== undefined && mon !== null

        MaterialSymbol {
            text:     "light_mode"
            fill:     1
            iconSize: Appearance.font.pixelSize.large
            color:    Appearance.colors.colOnLayer1
        }

        StyledSlider {
            Layout.fillWidth: true
            configuration:   StyledSlider.Configuration.S
            from: 0; to: 1
            value:   brightnessRow.mon?.brightness ?? 0
            onMoved: brightnessRow.mon?.setBrightness(value)
        }

        StyledText {
            text:           `${Math.round((brightnessRow.mon?.brightness ?? 0) * 100)}%`
            font.pixelSize: Appearance.font.pixelSize.small
            color:          Appearance.colors.colSubtext
            Layout.minimumWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }

    // ═══════════════════════════════════════════════
    //  Battery
    // ═══════════════════════════════════════════════
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: Battery.available

        MaterialSymbol {
            text: {
                if (Battery.isCharging)        return "battery_charging_full"
                if (Battery.percentage > 0.9)  return "battery_full"
                if (Battery.percentage > 0.7)  return "battery_5_bar"
                if (Battery.percentage > 0.5)  return "battery_3_bar"
                if (Battery.percentage > 0.2)  return "battery_2_bar"
                return "battery_alert"
            }
            fill:     1
            iconSize: Appearance.font.pixelSize.large
            color:    Battery.percentage <= 0.2 && !Battery.isCharging
                ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
        }

        StyledProgressBar {
            Layout.fillWidth: true
            highlightColor: Battery.percentage <= 0.2 && !Battery.isCharging
                ? Appearance.m3colors.m3error : Appearance.colors.colPrimary
            trackColor: Appearance.colors.colSecondaryContainer
            value:      Battery.percentage
        }

        StyledText {
            text:           `${Math.round(Battery.percentage * 100)}%`
            font.pixelSize: Appearance.font.pixelSize.small
            color:          Appearance.colors.colSubtext
            Layout.minimumWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }
}
