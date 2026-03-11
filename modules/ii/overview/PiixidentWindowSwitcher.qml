pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.modules.common
import qs.modules.ii.piixident

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  PIIXIDENT WINDOW SWITCHER WRAPPER
 * ════════════════════════════════════════════════════════════════════════════
 * 
 *  Alt-Tab style window switcher with parallelogram cards and screenshots.
 * 
 *  Usage in shell.qml:
 *    PiixidentWindowSwitcher {
 *        id: windowSwitcher
 *    }
 * 
 *  IPC Commands:
 *    qs -c ii ipc call windowSwitcher open
 *    qs -c ii ipc call windowSwitcher next
 *    qs -c ii ipc call windowSwitcher prev
 *    qs -c ii ipc call windowSwitcher confirm
 *    qs -c ii ipc call windowSwitcher cancel
 */

Variants {
    id: root
    
    // ══════════════════════════════════════════════════════════════
    //  PUBLIC API
    // ══════════════════════════════════════════════════════════════
    property bool isOpen: false
    
    function open() {
        if (switcherInstance.item) {
            switcherInstance.item.open()
            isOpen = true
        }
    }
    
    function next() {
        if (switcherInstance.item) {
            switcherInstance.item.next()
        }
    }
    
    function prev() {
        if (switcherInstance.item) {
            switcherInstance.item.prev()
        }
    }
    
    function confirm() {
        if (switcherInstance.item) {
            switcherInstance.item.confirm()
            isOpen = false
        }
    }
    
    function cancel() {
        if (switcherInstance.item) {
            switcherInstance.item.cancel()
            isOpen = false
        }
    }
    
    // ══════════════════════════════════════════════════════════════
    //  IPC HANDLER
    // ══════════════════════════════════════════════════════════════
    IpcHandler {
        target: "windowSwitcher"
        
        function open(): void {
            root.open()
        }
        
        function next(): void {
            root.next()
        }
        
        function prev(): void {
            root.prev()
        }
        
        function confirm(): void {
            root.confirm()
        }
        
        function cancel(): void {
            root.cancel()
        }
    }
    
    // ══════════════════════════════════════════════════════════════
    //  WINDOW SWITCHER INSTANCE
    // ══════════════════════════════════════════════════════════════
    model: Quickshell.screens
    
    PanelWindow {
        id: window
        required property var modelData
        
        readonly property var screen: modelData
        readonly property var monitor: Hyprland.monitorFor(screen)
        
        visible: root.isOpen
        screen: modelData
        mask: Region { item: window.contentItem }
        layer: "overlay"
        color: "transparent"
        
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        
        // Load the window switcher
        Loader {
            id: switcherInstance
            anchors.fill: parent
            active: true
            
            sourceComponent: Component {
                WindowSwitcher_Piixident {
                    id: switcher
                    anchors.fill: parent
                    
                    // Bind to ii config state
                    showing: root.isOpen
                    colors: Appearance.colors
                    mainMonitor: window.monitor.name
                    
                    // Sync state back to wrapper
                    onShowingChanged: {
                        root.isOpen = showing
                    }
                }
            }
        }
        
        // Dim background
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.isOpen ? 0.5 : 0
            z: -1
            
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
