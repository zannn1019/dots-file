import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.panels.lock
import qs.modules.common.widgets
import qs.modules.custom
import qs.modules.ii.mediaControls
import qs.services

Item {
    id: root

    required property LockContext context
    readonly property bool requirePasswordToPower: Config.options.lock.security.requirePasswordToPower
    property bool ctrlHeld: false
    property bool overlayVisible: false

    // ── Animation phases ──
    property real chainProgress: 0.0    // 0→1: target endpoint moves corner→center
    property real lockIconScale: 0.0    // 0→1: center lock pops in
    property real chainFade: 1.0        // 1→0.14: chains dim after lock
    property real uiOpacity: 0.0        // 0→1: password card
    property bool uiVisible: false
    property bool lockIconLocked: false  // false=open, true=locked
    property bool unlockAnimating: false // true while playing unlock animation


    // ── Physics sim state (plain JS, no bindings) ──
    property var simChains: []          // array of {nodes:[{x,y,px,py}], segLen}
    property bool simReady: false
    property real simPhase: 0           // 0=approach, 1=locked/taut

    focus: true

    function forceFieldFocus() { passwordBox.forceActiveFocus(); }
    function showOverlay() { root.overlayVisible = true; forceFieldFocus(); }
    onOverlayVisibleChanged: { if (overlayVisible) forceFieldFocus(); }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F12 || event.key === Qt.Key_Print) {
            const ts = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
            Quickshell.execDetached(["bash", "-c", `grim /home/zan/Pictures/lockscreen-${ts}.png`]);
            return;
        }
        root.context.resetClearTimer();
        if (event.key === Qt.Key_Control) root.ctrlHeld = true;
        if (event.key === Qt.Key_Escape) { root.context.currentText = ""; root.overlayVisible = false; }
        showOverlay();
    }
    Keys.onReleased: (event) => { if (event.key === Qt.Key_Control) root.ctrlHeld = false; }
    Connections { function onShouldReFocus() { forceFieldFocus(); } target: context }

    Component.onCompleted: {
        root.overlayVisible = false;
        initTimer.start();
    }

    // Give the size time to settle, then init
    Timer {
        id: initTimer; interval: 60; repeat: false
        onTriggered: {
            initSim();
            physicsTimer.start();
            lockSeq.start();
        }
    }

    // ── MAIN SEQUENCE ─────────────────────────────────────────────
    SequentialAnimation {
        id: lockSeq
        // Phase 1: chains whip to center
        NumberAnimation {
            target: root; property: "chainProgress"
            from: 0; to: 1.0; duration: 380
            easing.type: Easing.OutQuart
        }
        // Phase 2: physics settles
        ScriptAction { script: { root.simPhase = 1; } }
        PauseAnimation { duration: 120 }
        // Phase 3: chains dim + UI fades in + lock icon sequence
        ScriptAction { script: { root.uiVisible = true; } }
        ParallelAnimation {
            NumberAnimation { target: root; property: "chainFade"; to: 1.0; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "uiOpacity"; to: 1.0;  duration: 340; easing.type: Easing.OutCubic }
            // Lock icon pops in
            SequentialAnimation {
                PauseAnimation { duration: 100 }
                NumberAnimation { target: root; property: "lockIconScale"; from: 0; to: 1.20; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
                NumberAnimation { target: root; property: "lockIconScale"; to: 1.0; duration: 160; easing.type: Easing.InOutCubic }
            }
        }
        // Lock snaps shut (open → locked)
        PauseAnimation { duration: 420 }
        ScriptAction { script: { root.lockIconLocked = true; } }
        NumberAnimation { target: root; property: "lockIconScale"; to: 1.10; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "lockIconScale"; to: 1.0;  duration: 180; easing.type: Easing.OutBounce }
        ScriptAction { script: { physicsTimer.stop(); chainCanvas.requestPaint(); } }
    }

    // ── UNLOCK ANIMATION ──────────────────────────────────────────────
    function animateAndUnlock(ctrl) {
        if (root.unlockAnimating) return;
        root.unlockAnimating = true;
        unlockAnim.ctrl = (ctrl === true);
        unlockAnim.start();
    }

    SequentialAnimation {
        id: unlockAnim
        property bool ctrl: false

        // Step 1: Lock springs open
        ScriptAction { script: {
            root.lockIconLocked = false;
        }}
        NumberAnimation { target: root; property: "lockIconScale"; to: 1.22; duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        NumberAnimation { target: root; property: "lockIconScale"; to: 1.0;  duration: 120; easing.type: Easing.OutCubic }

        PauseAnimation { duration: 80 }

        // Step 2: Chains retract to corners + UI fades + lock fades
        ScriptAction { script: {
            root.simPhase = 0;   // un-pin chain tips so gravity takes over
            physicsTimer.start(); // re-run physics
        }}
        ParallelAnimation {
            NumberAnimation { target: root; property: "chainProgress"; to: 0.0; duration: 550; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "chainFade";     to: 0.0; duration: 500; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "uiOpacity";     to: 0.0; duration: 380; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "lockIconScale"; to: 0.0; duration: 420; easing.type: Easing.InCubic }
        }

        // Step 3: Unlock
        ScriptAction { script: {
            physicsTimer.stop();
            root.context.tryUnlock(unlockAnim.ctrl);
        }}
    }

    // Abort unlock animation if wrong password
    Connections {
        target: GlobalStates
        function onScreenUnlockFailedChanged() {
            if (GlobalStates.screenUnlockFailed && root.unlockAnimating) {
                unlockAnim.stop();
                root.unlockAnimating = false;
                // Restore state
                root.lockIconLocked = true;
                root.lockIconScale  = 1.0;
                root.chainProgress  = 1.0;
                root.chainFade      = 1.0;
                root.uiOpacity      = 1.0;
                root.simPhase       = 1;
                chainCanvas.requestPaint();
            }
        }
    }

    // ── PHYSICS INIT ─────────────────────────────────────────────────
    function initSim() {
        var w = root.width, h = root.height;
        var cx = w / 2, cy = h / 2;
        var nc = 16;  // nodes per chain

        var corners = [
            { x: 0, y: 0 },
            { x: w, y: 0 },
            { x: 0, y: h },
            { x: w, y: h }
        ];

        var newChains = [];
        for (var ci = 0; ci < corners.length; ci++) {
            var cor = corners[ci];
            var nodes = [];
            var ang = Math.atan2(cy - cor.y, cx - cor.x);
            var totalDist = Math.sqrt((cx - cor.x) * (cx - cor.x) + (cy - cor.y) * (cy - cor.y));
            var segLen = totalDist / (nc - 1);

            for (var i = 0; i < nc; i++) {
                // Start ALL nodes at corner (coiled up)
                var jitter = i * 0.5;
                nodes.push({
                    x:  cor.x + Math.cos(ang) * jitter,
                    y:  cor.y + Math.sin(ang) * jitter,
                    px: cor.x + Math.cos(ang) * jitter - Math.cos(ang) * 0.1,
                    py: cor.y + Math.sin(ang) * jitter - Math.sin(ang) * 0.1
                });
            }
            newChains.push({
                nodes:   nodes,
                corner:  { x: cor.x, y: cor.y },
                segLen:  segLen,
                target:  { x: cx, y: cy }
            });
        }
        root.simChains = newChains;
        root.simReady = true;
    }

    // ── 60 FPS PHYSICS TIMER ─────────────────────────────────────────
    Timer {
        id: physicsTimer
        interval: 16; repeat: true; running: false
        onTriggered: { stepSim(); chainCanvas.requestPaint(); }
    }

    function stepSim() {
        if (!root.simReady) return;
        var chains = root.simChains;
        var nc     = 16;
        var gravity    = 280;      // px/s² downward
        var damping    = 0.985;
        var iterations = 12;       // constraint iterations
        var dt         = 0.016;    // seconds per frame
        var prog       = root.chainProgress;
        var cx = root.width  / 2;
        var cy = root.height / 2;

        for (var ci = 0; ci < chains.length; ci++) {
            var chain = chains[ci];
            var nodes = chain.nodes;
            var segL  = chain.segLen;

            // ── Verlet integrate ──
            for (var i = 1; i < nc; i++) {
                var n  = nodes[i];
                var vx = (n.x - n.px) * damping;
                var vy = (n.y - n.py) * damping;

                // Gravity (downward)
                vy += gravity * dt * dt;

                // Attraction of the free end toward animated target
                if (i === nc - 1) {
                    var tx = chain.corner.x + (chain.target.x - chain.corner.x) * prog;
                    var ty = chain.corner.y + (chain.target.y - chain.corner.y) * prog;

                    if (root.simPhase >= 1) {
                        // Phase 1+: hard-pin the tip at center
                        nodes[nc - 1].x = cx;
                        nodes[nc - 1].y = cy;
                        nodes[nc - 1].px = cx;
                        nodes[nc - 1].py = cy;
                        continue;
                    }

                    var dfx = tx - n.x;
                    var dfy = ty - n.y;
                    var d2  = dfx * dfx + dfy * dfy;
                    if (d2 > 0.5) {
                        var d = Math.sqrt(d2);
                        var force = 900 * dt * dt;
                        vx += (dfx / d) * force;
                        vy += (dfy / d) * force;
                    }
                }

                var npx = n.x; var npy = n.y;
                n.x = n.x + vx;
                n.y = n.y + vy;
                n.px = npx; n.py = npy;
            }

            // ── Pin first node at corner ──
            nodes[0].x = chain.corner.x; nodes[0].y = chain.corner.y;
            nodes[0].px = chain.corner.x; nodes[0].py = chain.corner.y;

            // ── Distance constraints (FABRIK-style iterative) ──
            for (var iter = 0; iter < iterations; iter++) {
                // Forward pass
                for (var j = 0; j < nc - 1; j++) {
                    var a = nodes[j], b = nodes[j + 1];
                    var ddx = b.x - a.x, ddy = b.y - a.y;
                    var dist = Math.sqrt(ddx * ddx + ddy * ddy);
                    if (dist < 0.0001) continue;
                    var corr = (dist - segL) / dist * 0.5;
                    var mx = ddx * corr, my = ddy * corr;
                    if (j > 0)          { a.x += mx; a.y += my; }
                    if (j < nc - 2 || root.simPhase < 1) { b.x -= mx; b.y -= my; }
                }
            }

            // Re-pin (constraints may have moved pinned nodes slightly)
            nodes[0].x = chain.corner.x; nodes[0].y = chain.corner.y;
            if (root.simPhase >= 1) {
                nodes[nc - 1].x = cx; nodes[nc - 1].y = cy;
            }
        }
    }

    // ── BACKGROUND ────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "transparent" }



    // ── BACKGROUND CLICK ──────────────────────────────────────────────
    MouseArea { anchors.fill: parent; z: -1; onPressed: root.showOverlay() }

    // ── CHAIN CANVAS ──────────────────────────────────────────────────
    Canvas {
        id: chainCanvas
        anchors.fill: parent
        opacity: root.chainFade

        onPaint: {
            var c = getContext("2d");
            c.clearRect(0, 0, width, height);
            if (!root.simReady) return;

            var chains = root.simChains;
            var nc = 16;
            var kappa = 0.5523;

            for (var ci = 0; ci < chains.length; ci++) {
                var nodes = chains[ci].nodes;
                var segL  = chains[ci].segLen;

                for (var i = 0; i < nc - 1; i++) {
                    var a = nodes[i], b = nodes[i + 1];
                    var mx = (a.x + b.x) * 0.5;
                    var my = (a.y + b.y) * 0.5;
                    var ang = Math.atan2(b.y - a.y, b.x - a.x);

                    // Oval link dimensions
                    var isPerp = (i % 2 !== 0);
                    var rx = isPerp ? segL * 0.22 : segL * 0.44;
                    var ry = isPerp ? segL * 0.44 : segL * 0.22;

                    // Clamp to avoid giant distorted links when nodes bunch up
                    var seg = Math.sqrt((b.x-a.x)*(b.x-a.x)+(b.y-a.y)*(b.y-a.y));
                    var sf = Math.min(1.0, seg / segL);
                    rx *= sf; ry *= sf;

                    c.save();
                    c.translate(mx, my);
                    c.rotate(ang);

                    // Glow pass
                    c.beginPath();
                    c.moveTo(-rx, 0);
                    c.bezierCurveTo(-rx, -ry*kappa, -rx*kappa, -ry, 0, -ry);
                    c.bezierCurveTo( rx*kappa, -ry,  rx, -ry*kappa, rx, 0);
                    c.bezierCurveTo( rx,  ry*kappa,  rx*kappa,  ry, 0,  ry);
                    c.bezierCurveTo(-rx*kappa,  ry, -rx,  ry*kappa, -rx, 0);
                    c.closePath();
                    c.strokeStyle = "rgba(140, 195, 255, 0.18)";
                    c.lineWidth = 6 * sf;
                    c.stroke();

                    // Main link
                    c.beginPath();
                    c.moveTo(-rx, 0);
                    c.bezierCurveTo(-rx, -ry*kappa, -rx*kappa, -ry, 0, -ry);
                    c.bezierCurveTo( rx*kappa, -ry,  rx, -ry*kappa, rx, 0);
                    c.bezierCurveTo( rx,  ry*kappa,  rx*kappa,  ry, 0,  ry);
                    c.bezierCurveTo(-rx*kappa,  ry, -rx,  ry*kappa, -rx, 0);
                    c.closePath();
                    c.strokeStyle = "rgba(190, 225, 255, 1.0)";
                    c.lineWidth = 2.2;
                    c.stroke();

                    c.restore();
                }

                // Tip glow (while still approaching)
                if (root.chainProgress < 1.0) {
                    var tip = nodes[nc - 1];
                    c.beginPath(); c.arc(tip.x, tip.y, 7, 0, Math.PI * 2);
                    c.fillStyle = "rgba(200, 230, 255, 0.70)"; c.fill();
                    c.beginPath(); c.arc(tip.x, tip.y, 14, 0, Math.PI * 2);
                    c.fillStyle = "rgba(140, 195, 255, 0.18)"; c.fill();
                }
            }

        }
    }


    // ── CENTER LOCK ICON ─────────────────────────────────────────────
    Item {
        anchors.centerIn: parent
        width: 100; height: 100
        opacity: root.lockIconScale > 0 ? 1 : 0
        scale: root.lockIconScale
        transformOrigin: Item.Center

        // Outer glow ring
        Rectangle {
            anchors.centerIn: parent
            width: 96; height: 96; radius: 48
            color: "transparent"
            border.width: 1
            border.color: root.lockIconLocked
                ? Qt.rgba(0.65, 0.82, 1.0, 0.55)
                : Qt.rgba(1, 1, 1, 0.18)
            Behavior on border.color { ColorAnimation { duration: 350 } }
        }

        // Glass backing
        Rectangle {
            anchors.centerIn: parent
            width: 76; height: 76; radius: 38
            color: root.lockIconLocked
                ? Qt.rgba(0.65, 0.82, 1.0, 0.10)
                : Qt.rgba(0.04, 0.04, 0.10, 0.75)
            Behavior on color { ColorAnimation { duration: 350 } }
            border.width: 1
            border.color: root.lockIconLocked
                ? Qt.rgba(0.65, 0.82, 1.0, 0.40)
                : Qt.rgba(1, 1, 1, 0.12)
            Behavior on border.color { ColorAnimation { duration: 350 } }

            // Lock symbol — switches open→closed
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.overlayVisible
                    ? "lock_open"
                    : (root.lockIconLocked ? "lock" : "lock_open")
                iconSize: 30; fill: 1
                color: root.lockIconLocked
                    ? Qt.rgba(0.68, 0.85, 1.0, 0.95)
                    : Qt.rgba(0.80, 0.78, 0.90, 0.55)
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

    // ── FLOATING CLOCK (top) ──────────────────────────────────────────
    Column {
        id: clockSection
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.14
        spacing: 8
        opacity: root.uiOpacity
        visible: root.uiVisible

        // Big time
        Text {
            id: bigClock
            anchors.horizontalCenter: parent.horizontalCenter
            text: "--:--"
            font.family: Appearance.font.family.numbers
            font.pixelSize: 110
            font.weight: Font.Thin
            font.letterSpacing: 4
            color: Qt.rgba(1, 1, 1, 0.92)
            renderType: Text.NativeRendering
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: bigClock.text = Qt.formatDateTime(new Date(), "HH:mm")
            }
        }

        // Day + date
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Text {
                id: dayText
                text: "--"
                font.family: Appearance.font.family.main
                font.pixelSize: 14; font.weight: Font.Medium; font.letterSpacing: 2
                color: Qt.rgba(0.65, 0.82, 1.0, 0.85)
                Timer {
                    interval: 60000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: dayText.text = Qt.formatDateTime(new Date(), "dddd").toUpperCase()
                }
            }

            Text {
                text: "·"
                font.pixelSize: 14
                color: Qt.rgba(1, 1, 1, 0.25)
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: dateText
                text: "--"
                font.family: Appearance.font.family.main
                font.pixelSize: 14; font.letterSpacing: 1.5
                color: Qt.rgba(1, 1, 1, 0.42)
                Timer {
                    interval: 60000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: dateText.text = Qt.formatDateTime(new Date(), "d MMMM yyyy").toUpperCase()
                }
            }
        }
    }

    // ── FLOATING PASSWORD (bottom) ────────────────────────────────────
    Column {
        id: pwSection
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.12
        width: 360
        spacing: 14
        opacity: root.uiOpacity
        visible: root.uiVisible

        // Error message
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: GlobalStates.screenUnlockFailed
            text: Translation.tr("Incorrect password")
            font.family: Appearance.font.family.main; font.pixelSize: 12
            color: Qt.rgba(1.0, 0.42, 0.42, 0.90)
        }

        // Password row
        Item {
            width: parent.width
            height: root.overlayVisible ? 50 : 42
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            // Idle: user hint pill
            Rectangle {
                anchors.centerIn: parent
                width: hintRow.implicitWidth + 28; height: 38; radius: 19
                color: Qt.rgba(1, 1, 1, 0.06)
                visible: !root.overlayVisible
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Row {
                    id: hintRow; anchors.centerIn: parent; spacing: 8
                    MaterialSymbol {
                        text: "lock"; iconSize: 13; fill: 1
                        color: Qt.rgba(0.65, 0.82, 1.0, 0.65)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Press any key to unlock"
                        font.family: Appearance.font.family.main; font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.38)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Active: password field pill
            Rectangle {
                anchors { fill: parent }
                radius: height / 2
                color: Qt.rgba(0.04, 0.04, 0.10, 0.82)
                border.width: 1
                border.color: GlobalStates.screenUnlockFailed
                    ? Qt.rgba(1.0, 0.35, 0.35, 0.55)
                    : Qt.rgba(0.65, 0.82, 1.0, root.overlayVisible ? 0.30 : 0.12)
                Behavior on border.color { ColorAnimation { duration: 220 } }
                visible: root.overlayVisible
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }

                SequentialAnimation {
                    id: wrongShake
                    NumberAnimation { target: passwordBox; property: "anchors.leftMargin"; to: -5; duration: 40 }
                    NumberAnimation { target: passwordBox; property: "anchors.leftMargin"; to: 18; duration: 40 }
                    NumberAnimation { target: passwordBox; property: "anchors.leftMargin"; to: -2; duration: 30 }
                    NumberAnimation { target: passwordBox; property: "anchors.leftMargin"; to:  5; duration: 30 }
                    NumberAnimation { target: passwordBox; property: "anchors.leftMargin"; to: 16; duration: 25 }
                }
                Connections {
                    target: GlobalStates
                    function onScreenUnlockFailedChanged() { if (GlobalStates.screenUnlockFailed) wrongShake.restart(); }
                }

                ToolbarTextField {
                    id: passwordBox
                    anchors { fill: parent; leftMargin: 22; rightMargin: 54 }
                    font.pixelSize: Appearance.font.pixelSize.small
                    enabled: !root.context.unlockInProgress
                    echoMode: TextInput.Password; inputMethodHints: Qt.ImhSensitiveData; clip: true
                    placeholderText: Translation.tr("Enter password…")
                    onTextChanged: root.context.currentText = this.text
                    onAccepted: root.animateAndUnlock(ctrlHeld)
                    Keys.onPressed: (event) => { root.context.resetClearTimer(); }
                    Connections {
                        function onCurrentTextChanged() { passwordBox.text = root.context.currentText; }
                        target: root.context
                    }
                }

                // Submit button
                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 6
                    width: 36; height: 36; radius: 18
                    color: Qt.rgba(0.65, 0.82, 1.0, 0.90)
                    scale: submitHov.containsMouse ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                    MouseArea {
                        id: submitHov; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.animateAndUnlock(root.ctrlHeld)
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent; text: "arrow_forward"; iconSize: 17
                        color: Qt.rgba(0.04, 0.04, 0.08, 1)
                    }
                }
            }
        }

        // Screenshot button
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 26; radius: 13; width: ssRow.implicitWidth + 18
            color: ssArea.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.03)
            Behavior on color { ColorAnimation { duration: 120 } }
            Row {
                id: ssRow; anchors.centerIn: parent; spacing: 5
                Text { text: "📷"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "Screenshot"; font.family: Appearance.font.family.main; font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.30); anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                id: ssArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const ts = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
                    Quickshell.execDetached(["bash", "-c", `grim /home/zan/Pictures/lockscreen-${ts}.png`]);
                }
            }
        }
    }
}

