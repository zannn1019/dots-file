pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  WORKSPACE COVER TRANSITION MANAGER
 * ════════════════════════════════════════════════════════════════════════════
 * 
 *  Implements a "cover/stacking" transition where:
 *    • New workspace slides in from right (x: parent.width → 0)
 *    • Old workspace slides back 20% (x: 0 → -parent.width * 0.2) + fades to 0.5
 *    • Z-index ensures new workspace always renders on top
 *    • Spring physics: spring 3.5, damping 0.25 (Caelestia-style)
 * 
 *  Usage:
 *    WorkspaceCoverTransition {
 *        currentWorkspaceId: monitor.activeWorkspace?.id
 *        onWorkspaceChanged: (oldId, newId) => { ... }
 *    }
 */

Item {
    id: root
    
    // ══════════════════════════════════════════════════════════════
    //  PUBLIC API
    // ══════════════════════════════════════════════════════════════
    property int currentWorkspaceId: -1
    property int previousWorkspaceId: -1
    
    // Container for workspace visual items
    property Item workspaceContainer: null
    
    // Transition state
    property bool isTransitioning: false
    
    // Signal emitted when workspace changes
    signal workspaceChanged(int oldId, int newId)
    
    // ══════════════════════════════════════════════════════════════
    //  Z-INDEX MANAGEMENT
    // ══════════════════════════════════════════════════════════════
    property int baseZ: 0
    property int currentZ: baseZ
    
    function getNextZ() {
        currentZ += 1
        return currentZ
    }
    
    // ══════════════════════════════════════════════════════════════
    //  WORKSPACE TRACKING
    // ══════════════════════════════════════════════════════════════
    property var workspaceItems: ({})  // Maps workspace ID to Item
    
    function registerWorkspace(wsId, item) {
        workspaceItems[wsId] = item
        item.z = baseZ
    }
    
    function unregisterWorkspace(wsId) {
        delete workspaceItems[wsId]
    }
    
    // ══════════════════════════════════════════════════════════════
    //  COVER TRANSITION LOGIC
    // ══════════════════════════════════════════════════════════════
    onCurrentWorkspaceIdChanged: {
        if (currentWorkspaceId === -1 || currentWorkspaceId === previousWorkspaceId) 
            return
        
        const oldId = previousWorkspaceId
        const newId = currentWorkspaceId
        
        const oldItem = workspaceItems[oldId]
        const newItem = workspaceItems[newId]
        
        if (!newItem) {
            previousWorkspaceId = newId
            return
        }
        
        isTransitioning = true
        
        // ──────────────────────────────────────────────────────────
        //  NEW WORKSPACE (Entering from right)
        // ──────────────────────────────────────────────────────────
        // Assign higher z-index to render on top
        newItem.z = getNextZ()
        
        // Start position: off-screen right
        newItem.x = workspaceContainer ? workspaceContainer.width : 800
        newItem.opacity = 1.0
        
        // Animate to final position (0, 0) with spring physics
        newItem.targetX = 0
        
        // ──────────────────────────────────────────────────────────
        //  OLD WORKSPACE (Exiting - partial slide + fade)
        // ──────────────────────────────────────────────────────────
        if (oldItem) {
            // Keep old z-index (it stays below)
            oldItem.targetX = -((workspaceContainer ? workspaceContainer.width : 800) * 0.2)
            oldItem.targetOpacity = 0.5
        }
        
        // Emit signal
        workspaceChanged(oldId, newId)
        previousWorkspaceId = newId
        
        // Reset transition flag after animation duration
        transitionCompleteTimer.restart()
    }
    
    Timer {
        id: transitionCompleteTimer
        interval: 800  // Match spring animation settle time
        repeat: false
        onTriggered: {
            root.isTransitioning = false
        }
    }
    
    // ══════════════════════════════════════════════════════════════
    //  SPRING ANIMATION COMPONENTS (Caelestia-style physics)
    // ══════════════════════════════════════════════════════════════
    // These should be applied to workspace items via Behavior blocks
    // 
    // Example usage in workspace tile:
    //   property real targetX: 0
    //   property real targetOpacity: 1
    //   
    //   Behavior on x {
    //       SpringAnimation { 
    //           spring: 3.5
    //           damping: 0.25
    //       }
    //   }
    //   
    //   Behavior on opacity {
    //       SpringAnimation {
    //           spring: 3.5
    //           damping: 0.25
    //       }
    //   }
    //
    // Then bind: x: targetX; opacity: targetOpacity
}
