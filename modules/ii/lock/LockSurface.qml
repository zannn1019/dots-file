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
    property real chainProgress: 0
    // 0→1: target endpoint moves corner→center
    property real lockIconScale: 0
    // 0→1: center lock pops in
    property real chainFade: 1
    // 1→0.14: chains dim after lock
    property real uiOpacity: 0
    // 0→1: password card
    property bool uiVisible: false
    property bool lockIconLocked: false // false=open, true=locked
    property bool unlockAnimating: false // true while playing unlock animation
    // ── Physics sim state (plain JS, no bindings) ──
    property var simChains: []
    // array of {nodes:[{x,y,px,py}], segLen}
    property bool simReady: false
    property real simPhase: 0 // 0=approach, 1=locked/taut
    property real windTime: 0 // accumulates for idle wind oscillation
    property real lockIconRotation: 0 // 0=straight, animated during unlock
    property bool unlockPhysics: false // true during unlock: stronger gravity, less damping
    // Path to pre-lock screenshot; reloaded each time the screen locks
    property string bgImagePath: "/tmp/qs-lockbg.png"
    // Bump this to force the Image to reload the file
    property int bgImageVersion: 0

    function forceFieldFocus() {
        passwordBox.forceActiveFocus();
    }

    function showOverlay() {
        root.overlayVisible = true;
        forceFieldFocus();
    }

    // ── UNLOCK ANIMATION ──────────────────────────────────────────────
    function animateAndUnlock(ctrl) {
        if (root.unlockAnimating)
            return ;

        root.unlockAnimating = true;
        unlockAnim.ctrl = (ctrl === true);
        unlockAnim.start();
    }

    // ── WHIP IMPULSE ────────────────────────────────────────────────
    // Give all chain nodes an outward burst toward their corner
    function applyWhipImpulse() {
        if (!root.simReady)
            return ;

        var chains = root.simChains;
        var nc = 16;
        var cx = root.width / 2, cy = root.height / 2;
        for (var ci = 0; ci < chains.length; ci++) {
            var nodes = chains[ci].nodes;
            var cor = chains[ci].corner;
            // Unit vector: center → corner (outward direction)
            var dx = cor.x - cx, dy = cor.y - cy;
            var len = Math.sqrt(dx * dx + dy * dy);
            var ux = dx / len, uy = dy / len;
            for (var ni = 1; ni < nc; ni++) {
                // Linear: nodes near center (high ni) have most stored tension
                var t = ni / (nc - 1);
                // 0=corner end, 1=center tip
                var impulse = t * 45 + 6;
                // 6px at corner end → 51px at tip
                // px offset → Verlet treats it as velocity on next tick
                nodes[ni].px = nodes[ni].x - ux * impulse;
                nodes[ni].py = nodes[ni].y - uy * impulse; // pure outward, gravity handles the fall
            }
        }
    }

    // ── PHYSICS INIT ─────────────────────────────────────────────────
    function initSim() {
        var w = root.width, h = root.height;
        var cx = w / 2, cy = h / 2;
        var nc = 16; // nodes per chain
        var corners = [{
            "x": 0,
            "y": 0
        }, {
            "x": w,
            "y": 0
        }, {
            "x": 0,
            "y": h
        }, {
            "x": w,
            "y": h
        }];
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
                    "x": cor.x + Math.cos(ang) * jitter,
                    "y": cor.y + Math.sin(ang) * jitter,
                    "px": cor.x + Math.cos(ang) * jitter - Math.cos(ang) * 0.1,
                    "py": cor.y + Math.sin(ang) * jitter - Math.sin(ang) * 0.1
                });
            }
            newChains.push({
                "nodes": nodes,
                "corner": {
                    "x": cor.x,
                    "y": cor.y
                },
                "segLen": segLen,
                "target": {
                    "x": cx,
                    "y": cy
                }
            });
        }
        root.simChains = newChains;
        root.simReady = true;
    }

    function stepSim() {
        if (!root.simReady)
            return ;

        var chains = root.simChains;
        var nc = 16;
        // Boost gravity + reduce damping when chains are released for dramatic fall
        var gravity = root.unlockPhysics ? 560 : 310;
        // px/s²
        var damping = root.unlockPhysics ? 0.97 : 0.985;
        var iterations = 12; // constraint iterations
        var dt = 0.016; // seconds per frame
        var prog = root.chainProgress;
        var cx = root.width / 2;
        var cy = root.height / 2;
        for (var ci = 0; ci < chains.length; ci++) {
            var chain = chains[ci];
            var nodes = chain.nodes;
            var segL = chain.segLen;
            // ── Verlet integrate ──
            for (var i = 1; i < nc; i++) {
                var n = nodes[i];
                var vx = (n.x - n.px) * damping;
                var vy = (n.y - n.py) * damping;
                // Gravity (downward)
                vy += gravity * dt * dt;
                // ── Idle wind (when locked) ──
                if (root.simPhase >= 1) {
                    root.windTime += dt * 0.35;
                    var midFactor = Math.sin(Math.PI * i / (nc - 1));
                    vx += (Math.sin(root.windTime * 0.7 + ci * 1.1) * 52 + Math.sin(root.windTime * 1.9 + ci * 0.7 + i * 0.15) * 16) * midFactor * dt * dt;
                    vy += Math.sin(root.windTime * 1.3 + ci * 0.9 + i * 0.1) * 10 * midFactor * dt * dt;
                    // Extra natural sag bias: pulls mid-nodes down more than ends
                    vy += 38 * midFactor * dt * dt;
                }
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
                    var d2 = dfx * dfx + dfy * dfy;
                    if (d2 > 0.5) {
                        var d = Math.sqrt(d2);
                        var force = 900 * dt * dt;
                        vx += (dfx / d) * force;
                        vy += (dfy / d) * force;
                    }
                }
                var npx = n.x;
                var npy = n.y;
                n.x = n.x + vx;
                n.y = n.y + vy;
                n.px = npx;
                n.py = npy;
            }
            // ── Pin first node at corner ──
            nodes[0].x = chain.corner.x;
            nodes[0].y = chain.corner.y;
            nodes[0].px = chain.corner.x;
            nodes[0].py = chain.corner.y;
            // ── Distance constraints (FABRIK-style iterative) ──
            for (var iter = 0; iter < iterations; iter++) {
                // Forward pass
                for (var j = 0; j < nc - 1; j++) {
                    var a = nodes[j], b = nodes[j + 1];
                    var ddx = b.x - a.x, ddy = b.y - a.y;
                    var dist = Math.sqrt(ddx * ddx + ddy * ddy);
                    if (dist < 0.0001)
                        continue;

                    var corr = (dist - segL) / dist * 0.5;
                    var mx = ddx * corr, my = ddy * corr;
                    if (j > 0) {
                        a.x += mx;
                        a.y += my;
                    }
                    if (j < nc - 2 || root.simPhase < 1) {
                        b.x -= mx;
                        b.y -= my;
                    }
                }
            }
            // Re-pin (constraints may have moved pinned nodes slightly)
            nodes[0].x = chain.corner.x;
            nodes[0].y = chain.corner.y;
            if (root.simPhase >= 1) {
                nodes[nc - 1].x = cx;
                nodes[nc - 1].y = cy;
            }
        }
    }

    focus: true
    onOverlayVisibleChanged: {
        if (overlayVisible)
            forceFieldFocus();

    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F12 || event.key === Qt.Key_Print) {
            const ts = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
            Quickshell.execDetached(["bash", "-c", `grim /home/zan/Pictures/lockscreen-${ts}.png`]);
            return ;
        }
        root.context.resetClearTimer();
        if (event.key === Qt.Key_Control)
            root.ctrlHeld = true;

        if (event.key === Qt.Key_Escape) {
            root.context.currentText = "";
            root.overlayVisible = false;
        }
        showOverlay();
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Control)
            root.ctrlHeld = false;

    }
    Component.onCompleted: {
        root.overlayVisible = false;
        initTimer.start();
    }

    Connections {
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked)
                root.bgImageVersion++;

        }

        target: GlobalStates
    }

    Connections {
        function onShouldReFocus() {
            forceFieldFocus();
        }

        target: context
    }

    // Give the size time to settle, then init
    Timer {
        id: initTimer

        interval: 60
        repeat: false
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
            target: root
            property: "chainProgress"
            from: 0
            to: 1
            duration: 380
            easing.type: Easing.OutQuart
        }

        // Phase 2: physics settles
        ScriptAction {
            script: {
                root.simPhase = 1;
            }
        }

        PauseAnimation {
            duration: 120
        }
        // Phase 3: chains dim + UI fades in + lock icon sequence

        ScriptAction {
            script: {
                root.uiVisible = true;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "chainFade"
                to: 1
                duration: 420
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: root
                property: "uiOpacity"
                to: 1
                duration: 340
                easing.type: Easing.OutCubic
            }
            // Lock icon pops in

            SequentialAnimation {
                PauseAnimation {
                    duration: 100
                }

                NumberAnimation {
                    target: root
                    property: "lockIconScale"
                    from: 0
                    to: 1.2
                    duration: 300
                    easing.type: Easing.OutBack
                    easing.overshoot: 2
                }

                NumberAnimation {
                    target: root
                    property: "lockIconScale"
                    to: 1
                    duration: 160
                    easing.type: Easing.InOutCubic
                }

            }

        }
        // Lock snaps shut (open → locked)

        PauseAnimation {
            duration: 420
        }

        ScriptAction {
            script: {
                root.lockIconLocked = true;
            }
        }

        NumberAnimation {
            target: root
            property: "lockIconScale"
            to: 1.1
            duration: 100
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: root
            property: "lockIconScale"
            to: 1
            duration: 180
            easing.type: Easing.OutBounce
        }

        ScriptAction {
            script: {
                physicsTimer.interval = 33;
                physicsTimer.start();
                chainCanvas.requestPaint();
            }
        }

    }

    SequentialAnimation {
        id: unlockAnim

        property bool ctrl: false

        // ─ Phase A: Lock key-turn (lock_open + rotate 20° + bloom) ───
        ScriptAction {
            script: {
                root.lockIconLocked = false;
            }
        }

        ParallelAnimation {
            // Rotate like turning a key
            NumberAnimation {
                target: root
                property: "lockIconRotation"
                to: 22
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 1.8
            }

            // Bloom scale up
            NumberAnimation {
                target: root
                property: "lockIconScale"
                to: 1.55
                duration: 180
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }

        }

        PauseAnimation {
            duration: 60
        }

        // ─ Phase B: Flash + whip ──────────────────────────────
        ScriptAction {
            script: {
                root.simPhase = 0;
                root.unlockPhysics = true; // boost gravity + reduce damping
                physicsTimer.interval = 16;
                physicsTimer.start();
                root.applyWhipImpulse();
            }
        }

        ParallelAnimation {
            // Let physics play for 350ms BEFORE fading — watch them fall
            SequentialAnimation {
                PauseAnimation {
                    duration: 350
                }

                NumberAnimation {
                    target: root
                    property: "chainFade"
                    to: 0
                    duration: 300
                    easing.type: Easing.InCubic
                }

            }

            // Lock icon sucks in
            SequentialAnimation {
                PauseAnimation {
                    duration: 40
                }

                NumberAnimation {
                    target: root
                    property: "lockIconScale"
                    to: 0
                    duration: 260
                    easing.type: Easing.InBack
                    easing.overshoot: 2
                }

            }

            SequentialAnimation {
                PauseAnimation {
                    duration: 40
                }

                NumberAnimation {
                    target: root
                    property: "lockIconRotation"
                    to: -10
                    duration: 260
                    easing.type: Easing.InCubic
                }

            }
            // UI blasts out immediately

            NumberAnimation {
                target: root
                property: "uiOpacity"
                to: 0
                duration: 200
                easing.type: Easing.OutCubic
            }

        }

        // ─ Phase C: Unlock ────────────────────────────────────
        ScriptAction {
            script: {
                physicsTimer.stop();
                root.unlockPhysics = false;
                root.context.tryUnlock(unlockAnim.ctrl);
                root.unlockAnimating = false;
            }
        }

    }

    Connections {
        function onScreenUnlockFailedChanged() {
            if (!GlobalStates.screenUnlockFailed)
                return ;

            // Stop animation regardless of unlockAnimating flag
            if (unlockAnim.running)
                unlockAnim.stop();

            root.unlockAnimating = false;
            // Restore all visual state
            root.unlockPhysics = false;
            root.lockIconLocked = true;
            root.lockIconScale = 1;
            root.lockIconRotation = 0;
            root.chainProgress = 1;
            root.chainFade = 1;
            root.uiOpacity = 1;
            root.simPhase = 1;
            // Stop physics and hard-reset node positions to locked state
            physicsTimer.stop();
            if (root.simReady) {
                var chains = root.simChains;
                var cx = root.width / 2, cy = root.height / 2;
                for (var ci = 0; ci < chains.length; ci++) {
                    var nodes = chains[ci].nodes;
                    var cor = chains[ci].corner;
                    var n = nodes.length;
                    for (var ni = 0; ni < n; ni++) {
                        var t = ni / (n - 1);
                        nodes[ni].x = cor.x + (cx - cor.x) * t;
                        nodes[ni].y = cor.y + (cy - cor.y) * t;
                        nodes[ni].px = nodes[ni].x;
                        nodes[ni].py = nodes[ni].y;
                    }
                }
            }
            chainCanvas.requestPaint();
        }

        target: GlobalStates
    }

    // ── 60 FPS PHYSICS TIMER ─────────────────────────────────────────
    Timer {
        id: physicsTimer

        interval: 16
        repeat: true
        running: false
        onTriggered: {
            stepSim();
            chainCanvas.requestPaint();
        }
    }

    // ── BACKGROUND ────────────────────────────────────────────────────
    // Solid fallback (shown if screenshot not ready)
    Rectangle {
        anchors.fill: parent
        color: "#08090f"
        z: -10
    }

    // Screenshot taken just before lock — displayed blurred
    Item {
        anchors.fill: parent
        z: -9
        clip: true

        // Dark vignette overlay so the lock UI stays readable
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.08, 0.1, 0.2, 0.55)
        }

        Image {
            id: bgShot

            // Append version as a dummy query so the Image re-reads the file
            source: root.bgImagePath + "?v=" + root.bgImageVersion
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
            cache: false
            visible: status === Image.Ready
        }

        // Gaussian blur via Qt5Compat (already imported)
        FastBlur {
            anchors.fill: bgShot
            source: bgShot
            radius: 30
            visible: bgShot.visible
        }

    }

    // ── BACKGROUND CLICK ──────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: root.showOverlay()
    }

    // ── CHAIN CANVAS ──────────────────────────────────────────────────
    Canvas {
        id: chainCanvas

        anchors.fill: parent
        opacity: root.chainFade
        onPaint: {
            var c = getContext("2d");
            c.clearRect(0, 0, width, height);
            if (!root.simReady)
                return ;

            var chains = root.simChains;
            var nc = 16;
            var kappa = 0.5523;
            for (var ci = 0; ci < chains.length; ci++) {
                var nodes = chains[ci].nodes;
                var segL = chains[ci].segLen;
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
                    var seg = Math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y));
                    var sf = Math.min(1, seg / segL);
                    rx *= sf;
                    ry *= sf;
                    // ── Organic micro-variation per link ──
                    // Deterministic pseudo-random tilt and size nudge so every link
                    // looks hand-forged rather than stamped from a die.
                    var seed = (ci * 17 + i * 7);
                    var tiltNudge = (((seed * 1619 + 3571) % 100) / 100 - 0.5) * 0.18; // ±0.09 rad
                    var sizeNudge = 1 + (((seed * 2311 + 1237) % 100) / 100 - 0.5) * 0.12; // ±6% size
                    rx *= sizeNudge;
                    ry *= sizeNudge;
                    c.save();
                    c.translate(mx, my);
                    c.rotate(ang + tiltNudge);
                    // Wide outer glow pass (diffuse bloom)
                    c.beginPath();
                    var grx = rx * 1.35, gry = ry * 1.35;
                    c.moveTo(-grx, 0);
                    c.bezierCurveTo(-grx, -gry * kappa, -grx * kappa, -gry, 0, -gry);
                    c.bezierCurveTo(grx * kappa, -gry, grx, -gry * kappa, grx, 0);
                    c.bezierCurveTo(grx, gry * kappa, grx * kappa, gry, 0, gry);
                    c.bezierCurveTo(-grx * kappa, gry, -grx, gry * kappa, -grx, 0);
                    c.closePath();
                    c.strokeStyle = "rgba(120, 180, 255, 0.09)";
                    c.lineWidth = 11 * sf;
                    c.stroke();
                    // Inner glow pass
                    c.beginPath();
                    c.moveTo(-rx, 0);
                    c.bezierCurveTo(-rx, -ry * kappa, -rx * kappa, -ry, 0, -ry);
                    c.bezierCurveTo(rx * kappa, -ry, rx, -ry * kappa, rx, 0);
                    c.bezierCurveTo(rx, ry * kappa, rx * kappa, ry, 0, ry);
                    c.bezierCurveTo(-rx * kappa, ry, -rx, ry * kappa, -rx, 0);
                    c.closePath();
                    c.strokeStyle = "rgba(160, 210, 255, 0.22)";
                    c.lineWidth = 5.5 * sf;
                    c.stroke();
                    // Main link
                    c.beginPath();
                    c.moveTo(-rx, 0);
                    c.bezierCurveTo(-rx, -ry * kappa, -rx * kappa, -ry, 0, -ry);
                    c.bezierCurveTo(rx * kappa, -ry, rx, -ry * kappa, rx, 0);
                    c.bezierCurveTo(rx, ry * kappa, rx * kappa, ry, 0, ry);
                    c.bezierCurveTo(-rx * kappa, ry, -rx, ry * kappa, -rx, 0);
                    c.closePath();
                    c.strokeStyle = "rgba(195, 228, 255, 1.0)";
                    c.lineWidth = 2;
                    c.stroke();
                    // Specular highlight: a short bright stroke along the top edge
                    c.beginPath();
                    c.moveTo(-rx * 0.4, -ry * 0.92);
                    c.bezierCurveTo(-rx * 0.15, -ry * 1.02, rx * 0.15, -ry * 1.02, rx * 0.4, -ry * 0.92);
                    c.strokeStyle = "rgba(240, 248, 255, 0.45)";
                    c.lineWidth = 1.1;
                    c.stroke();
                    c.restore();
                }
                // Tip glow (while still approaching)
                if (root.chainProgress < 1) {
                    var tip = nodes[nc - 1];
                    // Outer soft halo
                    var grad = c.createRadialGradient(tip.x, tip.y, 0, tip.x, tip.y, 22);
                    grad.addColorStop(0, "rgba(200, 235, 255, 0.85)");
                    grad.addColorStop(0.4, "rgba(150, 200, 255, 0.35)");
                    grad.addColorStop(1, "rgba(100, 160, 255, 0)");
                    c.beginPath();
                    c.arc(tip.x, tip.y, 22, 0, Math.PI * 2);
                    c.fillStyle = grad;
                    c.fill();
                    // Bright core dot
                    c.beginPath();
                    c.arc(tip.x, tip.y, 4.5, 0, Math.PI * 2);
                    c.fillStyle = "rgba(220, 242, 255, 0.95)";
                    c.fill();
                }
            }
        }
    }

    // ── CENTER LOCK ICON ─────────────────────────────────────────────
    Item {
        anchors.centerIn: parent
        width: 140
        height: 140
        opacity: root.lockIconScale > 0 ? 1 : 0
        scale: root.lockIconScale
        rotation: root.lockIconRotation
        transformOrigin: Item.Center

        // Far outer ambient bloom
        Rectangle {
            anchors.centerIn: parent
            width: 136
            height: 136
            radius: 68
            color: "transparent"
            border.width: 1
            border.color: root.lockIconLocked ? Qt.rgba(0.65, 0.82, 1, 0.18) : Qt.rgba(1, 1, 1, 0.06)

            Behavior on border.color {
                ColorAnimation {
                    duration: 400
                }

            }

        }

        // Outer glow ring
        Rectangle {
            anchors.centerIn: parent
            width: 116
            height: 116
            radius: 58
            color: "transparent"
            border.width: 1.5
            border.color: root.lockIconLocked ? Qt.rgba(0.65, 0.82, 1, 0.6) : Qt.rgba(1, 1, 1, 0.18)

            Behavior on border.color {
                ColorAnimation {
                    duration: 350
                }

            }

        }

        // Glass backing
        Rectangle {
            anchors.centerIn: parent
            width: 94
            height: 94
            radius: 47
            color: root.lockIconLocked ? Qt.rgba(0.65, 0.82, 1, 0.12) : Qt.rgba(0.04, 0.04, 0.1, 0.75)
            border.width: 1
            border.color: root.lockIconLocked ? Qt.rgba(0.65, 0.82, 1, 0.45) : Qt.rgba(1, 1, 1, 0.12)

            // Lock symbol — switches open→closed
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.overlayVisible ? "lock_open" : (root.lockIconLocked ? "lock" : "lock_open")
                iconSize: 38
                fill: 1
                color: root.lockIconLocked ? Qt.rgba(0.68, 0.85, 1, 0.95) : Qt.rgba(0.8, 0.78, 0.9, 0.55)

                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }

                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 350
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 350
                }

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
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: bigClock.text = Qt.formatDateTime(new Date(), "HH:mm")
            }

            // Subtle breathing — makes the clock feel alive
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.72
                    duration: 4000
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    to: 0.92
                    duration: 4000
                    easing.type: Easing.InOutSine
                }

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
                font.pixelSize: 14
                font.weight: Font.Medium
                font.letterSpacing: 2
                color: Qt.rgba(0.65, 0.82, 1, 0.85)

                Timer {
                    interval: 60000
                    running: true
                    repeat: true
                    triggeredOnStart: true
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
                font.pixelSize: 14
                font.letterSpacing: 1.5
                color: Qt.rgba(1, 1, 1, 0.42)

                Timer {
                    interval: 60000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: dateText.text = Qt.formatDateTime(new Date(), "d MMMM yyyy").toUpperCase()
                }

            }

        }

    }

    // ── FLOATING PASSWORD (bottom) ────────────────────────────────────
    Column {
        // Screenshot button
        // Rectangle {
        //     anchors.horizontalCenter: parent.horizontalCenter
        //     height: 26
        //     radius: 13
        //     width: ssRow.implicitWidth + 18
        //     color: ssArea.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)
        //     Row {
        //         id: ssRow
        //         anchors.centerIn: parent
        //         spacing: 5
        //         Text {
        //             text: "📷"
        //             font.pixelSize: 11
        //             anchors.verticalCenter: parent.verticalCenter
        //         }
        //         Text {
        //             text: "Screenshot"
        //             font.family: Appearance.font.family.main
        //             font.pixelSize: 10
        //             color: Qt.rgba(1, 1, 1, 0.3)
        //             anchors.verticalCenter: parent.verticalCenter
        //         }
        //     }
        //     MouseArea {
        //         id: ssArea
        //         anchors.fill: parent
        //         hoverEnabled: true
        //         cursorShape: Qt.PointingHandCursor
        //         onClicked: {
        //             const ts = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
        //             Quickshell.execDetached(["bash", "-c", `grim /home/zan/Pictures/lockscreen-${ts}.png`]);
        //         }
        //     }
        //     Behavior on color {
        //         ColorAnimation {
        //             duration: 120
        //         }
        //     }
        // }

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
            font.family: Appearance.font.family.main
            font.pixelSize: 12
            color: Qt.rgba(1, 0.42, 0.42, 0.9)
        }

        // Password row
        Item {
            width: parent.width
            height: root.overlayVisible ? 50 : 42

            // Idle: user hint pill
            Rectangle {
                anchors.centerIn: parent
                width: hintRow.implicitWidth + 28
                height: 38
                radius: 19
                color: Qt.rgba(1, 1, 1, 0.06)
                visible: !root.overlayVisible
                opacity: visible ? 1 : 0

                Row {
                    id: hintRow

                    anchors.centerIn: parent
                    spacing: 8

                    MaterialSymbol {
                        text: "lock"
                        iconSize: 13
                        fill: 1
                        color: Qt.rgba(0.65, 0.82, 1, 0.65)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Press any key to unlock"
                        font.family: Appearance.font.family.main
                        font.pixelSize: 12
                        color: Qt.rgba(1, 1, 1, 0.38)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }

                }

            }

            // Active: password field pill
            Rectangle {
                id: pwPill

                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: GlobalStates.screenUnlockFailed ? Qt.rgba(1, 0.35, 0.35, 0.55) : Qt.rgba(0.65, 0.82, 1, root.overlayVisible ? 0.3 : 0.12)
                visible: root.overlayVisible
                opacity: visible ? 1 : 0

                anchors {
                    fill: parent
                }

                // Frosted glass layers — stacked from back to front
                // Layer 1: deep translucent fill
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.rgba(0.04, 0.06, 0.14, 0.36)
                    z: -2
                }

                // Layer 2: faint blue-white sheen (simulates scattered light)
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"

                    // Top highlight strip
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 1
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        height: 1
                        radius: 1
                        color: Qt.rgba(0.75, 0.88, 1, 0.18)
                        z: 1
                    }

                }

                SequentialAnimation {
                    id: wrongShake

                    NumberAnimation {
                        target: passwordBox
                        property: "anchors.leftMargin"
                        to: -5
                        duration: 40
                    }

                    NumberAnimation {
                        target: passwordBox
                        property: "anchors.leftMargin"
                        to: 18
                        duration: 40
                    }

                    NumberAnimation {
                        target: passwordBox
                        property: "anchors.leftMargin"
                        to: -2
                        duration: 30
                    }

                    NumberAnimation {
                        target: passwordBox
                        property: "anchors.leftMargin"
                        to: 5
                        duration: 30
                    }

                    NumberAnimation {
                        target: passwordBox
                        property: "anchors.leftMargin"
                        to: 16
                        duration: 25
                    }

                }

                Connections {
                    function onScreenUnlockFailedChanged() {
                        if (GlobalStates.screenUnlockFailed)
                            wrongShake.restart();

                    }

                    target: GlobalStates
                }

                ToolbarTextField {
                    id: passwordBox

                    font.pixelSize: Appearance.font.pixelSize.small
                    enabled: !root.context.unlockInProgress
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    clip: true
                    colBackground: "transparent"
                    placeholderText: Translation.tr("Enter password…")
                    onTextChanged: root.context.currentText = this.text
                    onAccepted: root.animateAndUnlock(ctrlHeld)
                    Keys.onPressed: (event) => {
                        root.context.resetClearTimer();
                    }

                    anchors {
                        fill: parent
                        leftMargin: 22
                        rightMargin: 54
                    }

                    Connections {
                        function onCurrentTextChanged() {
                            passwordBox.text = root.context.currentText;
                        }

                        target: root.context
                    }

                }

                // Submit button
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 6
                    width: 36
                    height: 36
                    radius: 18
                    color: Qt.rgba(0.65, 0.82, 1, 0.9)
                    scale: submitHov.containsMouse ? 1.08 : 1

                    MouseArea {
                        id: submitHov

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.animateAndUnlock(root.ctrlHeld)
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_forward"
                        iconSize: 17
                        color: Qt.rgba(0.04, 0.04, 0.08, 1)
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 130
                            easing.type: Easing.OutBack
                        }

                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 220
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                    }

                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

}
