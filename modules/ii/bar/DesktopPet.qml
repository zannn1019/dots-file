import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.modules.common
import qs.services

Variants {
    id: variants
    model: Quickshell.screens
    
    delegate: PanelWindow {
        id: root
        screen: modelData
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
        color: "transparent"
        
        // Critical: Ignore input so user can click through the pet
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:desktop-pet"
        
        // Don't take keyboard focus
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property bool isSpotify: MprisController.activePlayer?.dbusName.includes("spotify") ?? false
        readonly property bool isPlaying: MprisController.activePlayer?.isPlaying ?? false
        readonly property bool shouldRun: isSpotify && isPlaying

        AnimatedImage {
            id: pet
            source: "file:///home/zan/.config/quickshell/ii/dance.gif"
            height: 120
            width: height * (120/100) // Rough aspect ratio adjustment
            fillMode: Image.PreserveAspectFit
            
            y: parent.height - height - 60 // Run just above the dock area
            
            // Mirror image when moving left (if needed, but for now we run L->R)
            mirror: false 

            visible: root.shouldRun
            playing: visible

            NumberAnimation on x {
                id: runAnim
                from: -pet.width
                to: root.width + pet.width
                duration: 12000 // 12 seconds to cross the screen
                loops: Animation.Infinite
                running: root.shouldRun
            }
            
            // Randomly reset and wait between runs to make it more "alive"
            onVisibleChanged: {
                if (visible) {
                    runAnim.restart()
                }
            }
        }
    }
}
