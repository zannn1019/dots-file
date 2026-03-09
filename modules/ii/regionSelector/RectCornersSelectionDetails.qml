import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property real regionX
    required property real regionY
    required property real regionWidth
    required property real regionHeight
    required property real mouseX
    required property real mouseY
    required property color color
    required property color overlayColor
    property bool showAimLines: Config.options.regionSelector.rect.showAimLines
    property real borderRadius: 12
    property real handleSize: 14
    property real borderWidth: 1
    property real ropeWidth: 3
    property color handleColor: root.color
    property int ropeSegments: 20
    property real ropeGravity: 0.6
    property real ropeDamping: 0.98
    // Rope physics data stored in JS arrays
    property var ropes: []
    property bool initialized: false

    function initRopes() {
        var r = [];
        for (var i = 0; i < 4; i++) {
            var rope = {
                "nodes": []
            };
            for (var j = 0; j <= root.ropeSegments; j++) {
                rope.nodes.push({
                    "x": 0,
                    "y": 0,
                    "ox": 0,
                    "oy": 0
                });
            }
            r.push(rope);
        }
        root.ropes = r;
        root.initialized = true;
        resetRopePositions();
    }

    function getRopeEndpoints(index) {
        var sx = root.regionX;
        var sy = root.regionY;
        var sw = root.regionWidth;
        var sh = root.regionHeight;
        var pw = ropeCanvas.width;
        var ph = ropeCanvas.height;
        switch (index) {
        case 0:
            return {
                "x1": sx,
                "y1": sy,
                "x2": 0,
                "y2": 0
            };
        case 1:
            return {
                "x1": sx + sw,
                "y1": sy,
                "x2": pw,
                "y2": 0
            };
        case 2:
            return {
                "x1": sx,
                "y1": sy + sh,
                "x2": 0,
                "y2": ph
            };
        case 3:
            return {
                "x1": sx + sw,
                "y1": sy + sh,
                "x2": pw,
                "y2": ph
            };
        }
        return {
            "x1": 0,
            "y1": 0,
            "x2": 0,
            "y2": 0
        };
    }

    function resetRopePositions() {
        if (!root.initialized)
            return ;

        var r = root.ropes;
        for (var i = 0; i < 4; i++) {
            var ep = getRopeEndpoints(i);
            var nodes = r[i].nodes;
            for (var j = 0; j <= root.ropeSegments; j++) {
                var t = j / root.ropeSegments;
                var px = ep.x1 + (ep.x2 - ep.x1) * t;
                var py = ep.y1 + (ep.y2 - ep.y1) * t;
                nodes[j].x = px;
                nodes[j].y = py;
                nodes[j].ox = px;
                nodes[j].oy = py;
            }
        }
        root.ropes = r;
    }

    function simulate() {
        if (!root.initialized)
            return ;

        var r = root.ropes;
        var gravity = root.ropeGravity;
        var damping = root.ropeDamping;
        var segs = root.ropeSegments;
        for (var i = 0; i < 4; i++) {
            var ep = getRopeEndpoints(i);
            var nodes = r[i].nodes;
            var dx = ep.x2 - ep.x1;
            var dy = ep.y2 - ep.y1;
            var ropeLen = Math.sqrt(dx * dx + dy * dy) * 1.15;
            var segLen = ropeLen / segs;
            // Verlet integration with gravity
            for (var j = 1; j < segs; j++) {
                var n = nodes[j];
                var vx = (n.x - n.ox) * damping;
                var vy = (n.y - n.oy) * damping;
                n.ox = n.x;
                n.oy = n.y;
                n.x += vx;
                n.y += vy + gravity;
            }
            // Pin endpoints
            nodes[0].x = ep.x1;
            nodes[0].y = ep.y1;
            nodes[segs].x = ep.x2;
            nodes[segs].y = ep.y2;
            // Distance constraints (iterate for stability)
            for (var iter = 0; iter < 5; iter++) {
                for (var j = 0; j < segs; j++) {
                    var a = nodes[j];
                    var b = nodes[j + 1];
                    var cdx = b.x - a.x;
                    var cdy = b.y - a.y;
                    var dist = Math.sqrt(cdx * cdx + cdy * cdy);
                    if (dist < 0.001)
                        dist = 0.001;

                    var diff = (segLen - dist) / dist * 0.5;
                    var offX = cdx * diff;
                    var offY = cdy * diff;
                    if (j !== 0) {
                        a.x -= offX;
                        a.y -= offY;
                    }
                    if (j + 1 !== segs) {
                        b.x += offX;
                        b.y += offY;
                    }
                }
                // Re-pin endpoints
                nodes[0].x = ep.x1;
                nodes[0].y = ep.y1;
                nodes[segs].x = ep.x2;
                nodes[segs].y = ep.y2;
            }
        }
        root.ropes = r;
    }

    Component.onCompleted: {
        initRopes();
    }

    Timer {
        id: physicsTimer

        interval: 16
        repeat: true
        running: true
        onTriggered: {
            if (!root.initialized)
                root.initRopes();

            root.simulate();
            ropeCanvas.requestPaint();
        }
    }

    // Overlay darkening — 4 rectangles around selection
    Rectangle {
        z: 1
        color: root.overlayColor
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.regionY
    }

    Rectangle {
        z: 1
        color: root.overlayColor
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height - root.regionY - root.regionHeight
    }

    Rectangle {
        z: 1
        color: root.overlayColor
        x: 0
        y: root.regionY
        width: root.regionX
        height: root.regionHeight
    }

    Rectangle {
        z: 1
        color: root.overlayColor
        x: root.regionX + root.regionWidth
        y: root.regionY
        width: parent.width - root.regionX - root.regionWidth
        height: root.regionHeight
    }

    // Selection border with rounded corners
    Rectangle {
        id: selectionBorder

        z: 2
        x: root.regionX
        y: root.regionY
        width: root.regionWidth
        height: root.regionHeight
        color: "transparent"
        border.color: root.color
        border.width: root.borderWidth
        radius: root.borderRadius
    }

    // === ROPE CANVAS WITH VERLET PHYSICS ===
    Canvas {
        id: ropeCanvas

        z: 2
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!root.initialized || root.ropes.length < 4)
                return ;

            ctx.strokeStyle = root.color;
            ctx.lineWidth = root.ropeWidth;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.globalAlpha = 0.35;
            for (var i = 0; i < 4; i++) {
                var nodes = root.ropes[i].nodes;
                ctx.beginPath();
                ctx.moveTo(nodes[0].x, nodes[0].y);
                for (var j = 1; j < nodes.length; j++) {
                    ctx.lineTo(nodes[j].x, nodes[j].y);
                }
                ctx.stroke();
            }
        }
    }

    // === CORNER HANDLES (circles) ===
    Rectangle {
        z: 3
        width: root.handleSize
        height: root.handleSize
        radius: root.handleSize / 2
        color: root.handleColor
        x: root.regionX - root.handleSize / 2
        y: root.regionY - root.handleSize / 2
    }

    Rectangle {
        z: 3
        width: root.handleSize
        height: root.handleSize
        radius: root.handleSize / 2
        color: root.handleColor
        x: root.regionX + root.regionWidth - root.handleSize / 2
        y: root.regionY - root.handleSize / 2
    }

    Rectangle {
        z: 3
        width: root.handleSize
        height: root.handleSize
        radius: root.handleSize / 2
        color: root.handleColor
        x: root.regionX - root.handleSize / 2
        y: root.regionY + root.regionHeight - root.handleSize / 2
    }

    Rectangle {
        z: 3
        width: root.handleSize
        height: root.handleSize
        radius: root.handleSize / 2
        color: root.handleColor
        x: root.regionX + root.regionWidth - root.handleSize / 2
        y: root.regionY + root.regionHeight - root.handleSize / 2
    }

    Rectangle {
        z: 3
        width: root.handleSize
        height: root.handleSize
        radius: root.handleSize / 2
        color: root.handleColor
        x: root.regionX + root.regionWidth / 2 - root.handleSize / 2
        y: root.regionY - root.handleSize / 2
    }

    Rectangle {
        z: 3
        width: root.handleSize
        height: root.handleSize
        radius: root.handleSize / 2
        color: root.handleColor
        x: root.regionX + root.regionWidth / 2 - root.handleSize / 2
        y: root.regionY + root.regionHeight - root.handleSize / 2
    }

    Rectangle {
        z: 3
        width: root.handleSize
        height: root.handleSize
        radius: root.handleSize / 2
        color: root.handleColor
        x: root.regionX - root.handleSize / 2
        y: root.regionY + root.regionHeight / 2 - root.handleSize / 2
    }

    Rectangle {
        z: 3
        width: root.handleSize
        height: root.handleSize
        radius: root.handleSize / 2
        color: root.handleColor
        x: root.regionX + root.regionWidth - root.handleSize / 2
        y: root.regionY + root.regionHeight / 2 - root.handleSize / 2
    }

    // Size label
    StyledText {
        z: 4
        anchors.top: selectionBorder.bottom
        anchors.right: selectionBorder.right
        anchors.margins: 8
        color: root.color
        text: `${Math.round(root.regionWidth)} x ${Math.round(root.regionHeight)}`
    }

    // Coord lines
    Rectangle {
        visible: root.showAimLines
        opacity: 0.15
        z: 2
        x: root.mouseX
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: root.color
    }

    Rectangle {
        visible: root.showAimLines
        opacity: 0.15
        z: 2
        y: root.mouseY
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: root.color
    }

}
