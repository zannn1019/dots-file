import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.common
import qs.modules.ii.piixident

// Full-screen app launcher with parallelogram slice UI
Scope {
    id: appLauncher

    // External bindings
    property var colors
    property bool showing: false
    // Font bindings (pass from parent context)
    property string fontIcons: "Material Symbols Rounded"
    property string fontBody: "Rubik"
    property string mainMonitor: PiixidentConfig.mainMonitor
    // Slice geometry constants
    property int sliceWidth: 135
    property int expandedWidth: 924
    property int sliceHeight: 520
    property int skewOffset: 35
    property int sliceSpacing: -22
    // Paths and card dimensions
    property string homeDir: PiixidentConfig.homeDir
    property string scriptsDir: PiixidentConfig.scriptsDir
    property string cacheFile: PiixidentConfig.cacheDir + "/app-launcher/list.jsonl"
    property int cardWidth: 1600
    property int topBarHeight: 50
    property int cardHeight: sliceHeight + topBarHeight + 60
    property bool cardVisible: false
    property bool cacheLoading: false
    property int cacheProgress: 0
    property int cacheTotal: 0
    property string searchText: ""
    property string sourceFilter: ""
    // Frequency-based search ranking (learns from selections)
    property string freqCachePath: PiixidentConfig.cacheDir + "/app-launcher/freq.json"
    property var freqData: ({
    })
    property int lastContentX: 0
    property int lastIndex: 0

    function loadFreqData() {
        try {
            appLauncher.freqData = JSON.parse(freqFile.text());
        } catch (e) {
            appLauncher.freqData = {
            };
        }
    }

    function saveFreqData() {
        freqFile.setText(JSON.stringify(freqData));
    }

    // Record user selection to boost future search ranking
    function recordSelection(appName) {
        var query = searchText.toLowerCase().trim();
        if (query === "")
            return ;

        var fd = freqData;
        for (var len = 2; len <= query.length; len++) {
            var prefix = query.substring(0, len);
            if (!fd[prefix])
                fd[prefix] = {
            };

            if (!fd[prefix][appName])
                fd[prefix][appName] = 0;

            fd[prefix][appName] += 1;
        }
        freqData = fd;
        saveFreqData();
    }

    function getFreqScore(appName) {
        var query = searchText.toLowerCase().trim();
        if (query === "" || !freqData[query])
            return 0;

        return freqData[query][appName] || 0;
    }

    function resetScroll() {
        appLauncher.lastContentX = 0;
        appLauncher.lastIndex = 0;
        sliceListView.currentIndex = 0;
        if (filteredModel.count > 0)
            sliceListView.positionViewAtIndex(0, ListView.Beginning);

    }

    // Filter apps by search text and source, sort by frequency score
    function updateFilteredModel() {
        var query = searchText.toLowerCase();
        var sf = sourceFilter;
        var results = [];
        for (var i = 0; i < appModel.count; i++) {
            var item = appModel.get(i);
            if (item.hidden)
                continue;

            if (query !== "" && item.name.toLowerCase().indexOf(query) === -1 && item.categories.toLowerCase().indexOf(query) === -1 && item.displayName.toLowerCase().indexOf(query) === -1 && item.tags.toLowerCase().indexOf(query) === -1)
                continue;

            if (sf === "steam" && item.source !== "steam")
                continue;

            if (sf === "desktop" && item.source !== "desktop")
                continue;

            if (sf === "game" && item.categories.indexOf("Game") === -1)
                continue;

            results.push({
                "name": item.name,
                "exec": item.exec,
                "icon": item.icon,
                "thumb": item.thumb,
                "iconPath": item.iconPath,
                "categories": item.categories,
                "source": item.source,
                "steamAppId": item.steamAppId,
                "terminal": item.terminal,
                "background": item.background,
                "customIcon": item.customIcon,
                "displayName": item.displayName,
                "tags": item.tags
            });
        }
        if (query !== "") {
            var freqMap = freqData[query] || {
            };
            results.sort(function(a, b) {
                var freqA = freqMap[a.name] || 0;
                var freqB = freqMap[b.name] || 0;
                if (freqA !== freqB)
                    return freqB - freqA;

                return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
            });
        }
        if (results.length === filteredModel.count) {
            var same = true;
            for (var k = 0; k < results.length; k++) {
                if (results[k].name !== filteredModel.get(k).name) {
                    same = false;
                    break;
                }
            }
            if (same)
                return ;

        }
        filteredModel.clear();
        for (var j = 0; j < results.length; j++) {
            filteredModel.append(results[j]);
        }
        if (filteredModel.count > 0) {
            sliceListView.currentIndex = 0;
            sliceListView.positionViewAtIndex(0, ListView.Beginning);
        }
    }

    // Launch an app, record selection for search ranking
    function launchApp(appExec, isTerminal, appName) {
        console.log("hello world");
        if (appName)
            recordSelection(appName);

        var cmd = appExec;
        if (isTerminal)
            cmd = "kitty " + cmd;

        appRunner.command = ["setsid", "-f", "sh", "-c", cmd];
        appRunner.running = true;
        GlobalStates.overviewOpen = false;
    }

    // Show/hide lifecycle (reset search, load freq data, rebuild cache)
    onShowingChanged: {
        console.log("[AppLauncher] showing:", showing, "cardVisible:", cardVisible);
        if (showing) {
            searchText = "";
            searchInput.text = "";
            loadFreqData();
            cardShowTimer.restart();
            if (appModel.count === 0)
                buildCache.running = true;
            else
                updateFilteredModel();
        } else {
            // Stop timers FIRST to prevent race condition:
            // if cardShowTimer fires after cardVisible=false, it sets cardVisible=true,
            // which means next open sees it already true and the fade-in never restarts.
            cardShowTimer.stop();
            focusTimer.stop();
            cardVisible = false;
            searchText = "";
            searchInput.text = "";
        }
    }
    onSearchTextChanged: {
        updateFilteredModel();
        if (searchInput.text !== searchText)
            searchInput.text = searchText;

    }
    onSourceFilterChanged: updateFilteredModel()

    Timer {
        id: cardShowTimer

        interval: 50
        onTriggered: appLauncher.cardVisible = true
    }

    Timer {
        id: focusTimer

        interval: 50
        onTriggered: sliceListView.forceActiveFocus()
    }

    FileView {
        id: freqFile

        path: appLauncher.freqCachePath
        preload: true
    }

    // App data models and search/filter logic
    ListModel {
        id: appModel
    }

    ListModel {
        id: filteredModel
    }

    // Cache builder process (runs python build-app-cache)
    Process {
        id: buildCache

        command: ["python3", PiixidentConfig.scriptsDir + "/python/build-app-cache"]
        running: false
        onRunningChanged: {
            if (running) {
                appLauncher.cacheLoading = true;
                appLauncher.cacheProgress = 0;
                appLauncher.cacheTotal = 0;
            }
        }
        onExited: {
            appLauncher.cacheLoading = false;
            appModel.clear();
            loadApps.running = false; // Reset state first
            loadApps.running = true; // Trigger reload
        }

        stdout: SplitParser {
            onRead: (line) => {
                if (line.startsWith("progress:")) {
                    const parts = line.split(":");
                    if (parts.length === 3) {
                        appLauncher.cacheProgress = parseInt(parts[1]);
                        appLauncher.cacheTotal = parseInt(parts[2]);
                    }
                } else if (line === "done") {
                }
            }
        }

    }

    // JSONL cache loader process
    Process {
        id: loadApps

        command: ["bash", "-c", "if [ -f '" + appLauncher.cacheFile + "' ]; then cat '" + appLauncher.cacheFile + "'; fi"]
        running: false
        onRunningChanged: {
            if (!running)
                appLauncher.updateFilteredModel();

        }
        onExited: {
            appLauncher.updateFilteredModel();
        }

        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var obj = JSON.parse(line);
                    appModel.append({
                        "name": obj.name || "",
                        "exec": obj.exec || "",
                        "icon": obj.icon || "",
                        "thumb": obj.thumb || "",
                        "iconPath": obj.iconPath || "",
                        "categories": obj.categories || "",
                        "source": obj.source || "desktop",
                        "steamAppId": obj.steamAppId || "",
                        "terminal": obj.terminal || false,
                        "background": obj.background || "",
                        "customIcon": obj.customIcon || "",
                        "displayName": obj.displayName || "",
                        "hidden": obj.hidden || false,
                        "tags": obj.tags || ""
                    });
                } catch (e) {
                }
            }
        }

    }

    // Desktop file watcher (inotifywait monitors .desktop dirs for changes)
    Process {
        id: desktopWatcher

        running: true
        command: ["bash", "-c", "dirs=(); for d in /usr/share/applications " + "\"$HOME/.local/share/applications\" " + "/var/lib/flatpak/exports/share/applications " + "\"$HOME/.local/share/flatpak/exports/share/applications\"; do " + "[ -d \"$d\" ] && dirs+=(\"$d\"); done; " + "[ ${#dirs[@]} -eq 0 ] && exit 1; " + "exec inotifywait -m -r -e create,delete,modify,moved_to,moved_from " + "--include '\\.desktop$' \"${dirs[@]}\""]
        onExited: desktopWatcherRestart.start()

        stdout: SplitParser {
            onRead: (line) => {
                desktopWatcherDebounce.restart();
            }
        }

    }

    // Restart watcher if it exits unexpectedly
    Timer {
        id: desktopWatcherRestart

        interval: 5000
        onTriggered: desktopWatcher.running = true
    }

    // Debounce rapid .desktop changes into a single cache rebuild
    Timer {
        id: desktopWatcherDebounce

        interval: 2000
        onTriggered: {
            if (!buildCache.running)
                buildCache.running = true;

        }
    }

    // App launcher process
    Process {
        id: appRunner

        command: ["true"]
    }

    // Full-screen overlay panel
    PanelWindow {
        id: launcherPanel

        screen: Quickshell.screens.find((s) => {
            return s.name === appLauncher.mainMonitor;
        }) ?? Quickshell.screens[0]
        visible: appLauncher.showing
        color: "transparent"
        WlrLayershell.namespace: "app-launcher-parallel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                GlobalStates.overviewOpen = false;
                event.accepted = true;
            }
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        HyprlandFocusGrab {
            windows: [launcherPanel]
            active: false // Disabled - causes immediate closure
            onCleared: () => {
                console.log("[AppLauncher] HyprlandFocusGrab cleared");
                if (appLauncher.cardVisible)
                    GlobalStates.overviewOpen = false;

            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            opacity: appLauncher.cardVisible ? 1 : 0
            z: -1 // Behind everything else

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }

            }

        }

        MouseArea {
            // Pass the event through to slices / filter bar below us

            anchors.fill: parent
            // z: 5 puts this ABOVE sliceListView (z: 0) but BELOW cardContainer (z: 10)
            // so the background dim area receives clicks, but filter bar / slice area
            // still pass events downward via mouse.accepted = false
            z: 5
            onClicked: function(mouse) {
                var cardX = cardContainer.x;
                var cardY = cardContainer.y;
                var cardW = cardContainer.width;
                var cardH = cardContainer.height;
                var inCard = mouse.x >= cardX && mouse.x <= cardX + cardW && mouse.y >= cardY && mouse.y <= cardY + cardH;
                if (inCard)
                    mouse.accepted = false;
                else
                    GlobalStates.overviewOpen = false;
            }
        }

        // Card container with fade-in animation
        Item {
            id: cardContainer

            property bool animateIn: appLauncher.cardVisible

            z: 10 // Explicitly above background
            width: appLauncher.cardWidth
            height: appLauncher.cardHeight
            anchors.centerIn: parent
            visible: appLauncher.cardVisible
            opacity: 0
            onAnimateInChanged: {
                fadeInAnim.stop();
                if (animateIn) {
                    opacity = 0;
                    fadeInAnim.start();
                    focusTimer.restart();
                }
            }

            NumberAnimation {
                id: fadeInAnim

                target: cardContainer
                property: "opacity"
                from: 0
                to: 1
                duration: 400
                easing.type: Easing.OutCubic
            }

            Item {
                id: backgroundRect

                anchors.fill: parent

                Rectangle {
                    id: filterBarBg

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    width: topFilterBar.width + 30
                    height: topFilterBar.height + 14
                    radius: height / 2
                    color: appLauncher.colors ? Qt.rgba(appLauncher.colors.surfaceContainer.r, appLauncher.colors.surfaceContainer.g, appLauncher.colors.surfaceContainer.b, 0.85) : Qt.rgba(0.1, 0.12, 0.18, 0.85)
                    z: 10
                }

                // Top filter bar (source filters, search input)
                Row {
                    id: topFilterBar

                    anchors.centerIn: filterBarBg
                    spacing: 16
                    z: 11

                    Row {
                        id: sourceFilterRow

                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: [{
                                "filter": "",
                                "icon": "󰄶",
                                "label": "All"
                            }, {
                                "filter": "desktop",
                                "icon": "󰀻",
                                "label": "Apps"
                            }, {
                                "filter": "game",
                                "icon": "󰊗",
                                "label": "Games"
                            }, {
                                "filter": "steam",
                                "icon": "󰓓",
                                "label": "Steam"
                            }, {
                                "filter": "clipboard",
                                "icon": "󰓓",
                                "label": "Clipboard"
                            }]

                            Rectangle {
                                property bool isSelected: appLauncher.sourceFilter === modelData.filter
                                property bool isHovered: sourceMouseArea.containsMouse

                                width: 32
                                height: 24
                                radius: 4
                                color: isSelected ? (appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7") : (isHovered ? (appLauncher.colors ? Qt.rgba(appLauncher.colors.surfaceVariant.r, appLauncher.colors.surfaceVariant.g, appLauncher.colors.surfaceVariant.b, 0.5) : Qt.rgba(1, 1, 1, 0.15)) : "transparent")
                                border.width: isSelected ? 0 : 1
                                border.color: isHovered ? (appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.pixelSize: 14
                                    font.family: appLauncher.fontIcons
                                    color: parent.isSelected ? (appLauncher.colors ? appLauncher.colors.primaryText : "#000") : (appLauncher.colors ? appLauncher.colors.tertiary : "#8bceff")
                                }

                                MouseArea {
                                    id: sourceMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (parent.isSelected)
                                            appLauncher.sourceFilter = "";
                                        else
                                            appLauncher.sourceFilter = modelData.filter;
                                    }
                                }

                                ToolTip {
                                    visible: sourceMouseArea.containsMouse
                                    text: modelData.label
                                    delay: 500
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }

                                }

                            }

                        }

                    }

                    Rectangle {
                        width: 1
                        height: 20
                        color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.3) : Qt.rgba(1, 1, 1, 0.2)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "󰍉"
                        font.family: appLauncher.fontIcons
                        font.pixelSize: 18
                        color: appLauncher.colors ? appLauncher.colors.tertiary : "#8bceff"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchInput

                        width: 200
                        font.family: appLauncher.fontBody
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        onTextChanged: appLauncher.searchText = text
                        onAccepted: {
                            if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < filteredModel.count) {
                                var app = filteredModel.get(sliceListView.currentIndex);
                                appLauncher.launchApp(app.exec, app.terminal, app.name);
                            }
                        }
                        Keys.onEscapePressed: GlobalStates.overviewOpen = false

                        Text {
                            anchors.fill: parent
                            text: ""
                            font: searchInput.font
                            color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primaryText.r, appLauncher.colors.primaryText.g, appLauncher.colors.primaryText.b, 0.4) : Qt.rgba(1, 1, 1, 0.4)
                            visible: !searchInput.text
                        }

                    }

                    Text {
                        text: ""
                        font.family: appLauncher.fontBody
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primaryText.r, appLauncher.colors.primaryText.g, appLauncher.colors.primaryText.b, 0.5) : Qt.rgba(1, 1, 1, 0.5)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                // Cache loading overlay with progress bar
                Rectangle {
                    anchors.fill: parent
                    color: appLauncher.colors ? Qt.rgba(appLauncher.colors.surfaceContainer.r, appLauncher.colors.surfaceContainer.g, appLauncher.colors.surfaceContainer.b, 0.95) : Qt.rgba(0.08, 0.1, 0.14, 0.95)
                    radius: 20
                    visible: appLauncher.cacheLoading
                    z: 50

                    Rectangle {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 12
                        width: 300
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.1)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            radius: 2
                            width: appLauncher.cacheTotal > 0 ? parent.width * (appLauncher.cacheProgress / appLauncher.cacheTotal) : 0
                            color: appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7"

                            Behavior on width {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -12
                        text: appLauncher.cacheTotal > 0 ? "LOADING APPS... " + appLauncher.cacheProgress + " / " + appLauncher.cacheTotal : "SCANNING..."
                        color: appLauncher.colors ? appLauncher.colors.tertiary : "#8bceff"
                        font.family: appLauncher.fontBody
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.letterSpacing: 0.5
                    }

                }

            }

        }

        // Horizontal parallelogram slice list view
        ListView {
            // Removed: MouseArea was blocking clicks on delegates
            // Temporarily disabled to test if mask is the problem

            id: sliceListView

            property int visibleCount: 12
            property bool keyboardNavActive: false
            property real lastMouseX: -1
            property real lastMouseY: -1

            anchors.top: cardContainer.top
            anchors.topMargin: appLauncher.topBarHeight + 15
            anchors.bottom: cardContainer.bottom
            anchors.bottomMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            width: appLauncher.expandedWidth + (visibleCount - 1) * (appLauncher.sliceWidth + appLauncher.sliceSpacing)
            orientation: ListView.Horizontal
            model: filteredModel
            clip: false
            spacing: appLauncher.sliceSpacing
            flickDeceleration: 1500
            maximumFlickVelocity: 3000
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: appLauncher.expandedWidth * 4
            visible: appLauncher.cardVisible
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 350
            preferredHighlightBegin: (width - appLauncher.expandedWidth) / 2
            preferredHighlightEnd: (width + appLauncher.expandedWidth) / 2
            highlightRangeMode: ListView.StrictlyEnforceRange
            focus: appLauncher.showing
            onVisibleChanged: {
                if (visible)
                    forceActiveFocus();

            }
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                    event.accepted = true;
                    return ;
                }
                if (event.text && event.text.length > 0 && !event.modifiers) {
                    var c = event.text.charCodeAt(0);
                    if (c >= 32 && c < 127) {
                        searchInput.text += event.text;
                        searchInput.forceActiveFocus();
                        event.accepted = true;
                        return ;
                    }
                }
                if (event.key === Qt.Key_Backspace) {
                    if (searchInput.text.length > 0)
                        searchInput.text = searchInput.text.slice(0, -1);

                    event.accepted = true;
                    return ;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < filteredModel.count) {
                        var app = filteredModel.get(sliceListView.currentIndex);
                        appLauncher.launchApp(app.exec, app.terminal, app.name);
                    }
                    event.accepted = true;
                    return ;
                }
                sliceListView.keyboardNavActive = true;
                if (event.key === Qt.Key_Left) {
                    if (currentIndex > 0)
                        currentIndex--;

                    event.accepted = true;
                    return ;
                }
                if (event.key === Qt.Key_Right) {
                    if (currentIndex < filteredModel.count - 1)
                        currentIndex++;

                    event.accepted = true;
                    return ;
                }
            }

            // ── Scroll-wheel navigation ──────────────────────────────
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    // Support both vertical and horizontal scroll
                    var delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? -event.angleDelta.x : event.angleDelta.y;
                    if (delta < 0) {
                        if (sliceListView.currentIndex < filteredModel.count - 1)
                            sliceListView.currentIndex++;

                    } else if (delta > 0) {
                        if (sliceListView.currentIndex > 0)
                            sliceListView.currentIndex--;

                    }
                    event.accepted = true;
                }
            }

            Connections {
                function onShowingChanged() {
                    if (appLauncher.showing)
                        sliceListView.forceActiveFocus();

                }

                target: appLauncher
            }

            highlight: Item {
            }

            header: Item {
                width: (sliceListView.width - appLauncher.expandedWidth) / 2
                height: 1
            }

            footer: Item {
                width: (sliceListView.width - appLauncher.expandedWidth) / 2
                height: 1
            }

            // Parallelogram slice delegate
            delegate: Item {
                id: delegateItem

                property bool isCurrent: ListView.isCurrentItem
                property bool isHovered: itemMouseArea.containsMouse
                property real viewX: x - sliceListView.contentX
                property real fadeZone: appLauncher.sliceWidth * 1.5
                property real edgeOpacity: {
                    if (fadeZone <= 0)
                        return 1;

                    var center = viewX + width * 0.5;
                    var leftFade = Math.min(1, Math.max(0, center / fadeZone));
                    var rightFade = Math.min(1, Math.max(0, (sliceListView.width - center) / fadeZone));
                    return Math.min(leftFade, rightFade);
                }

                width: isCurrent ? appLauncher.expandedWidth : appLauncher.sliceWidth
                height: sliceListView.height
                z: isCurrent ? 100 : (isHovered ? 90 : 50 - Math.min(Math.abs(index - sliceListView.currentIndex), 50))
                opacity: edgeOpacity
                // Parallelogram hit-testing mask (disabled for debugging - clicks not reaching delegates)
                containmentMask: null

                // Drop shadow canvas behind slice
                Canvas {
                    id: shadowCanvas

                    property real shadowOffsetX: delegateItem.isCurrent ? 4 : 2
                    property real shadowOffsetY: delegateItem.isCurrent ? 10 : 5
                    property real shadowAlpha: delegateItem.isCurrent ? 0.6 : 0.4

                    z: -1
                    anchors.fill: parent
                    anchors.margins: -10
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onShadowAlphaChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var ox = 10;
                        var oy = 10;
                        var w = delegateItem.width;
                        var h = delegateItem.height;
                        var sk = appLauncher.skewOffset;
                        var sx = shadowOffsetX;
                        var sy = shadowOffsetY;
                        var layers = [{
                            "dx": sx,
                            "dy": sy,
                            "alpha": shadowAlpha * 0.5
                        }, {
                            "dx": sx * 0.6,
                            "dy": sy * 0.6,
                            "alpha": shadowAlpha * 0.3
                        }, {
                            "dx": sx * 1.4,
                            "dy": sy * 1.4,
                            "alpha": shadowAlpha * 0.2
                        }];
                        for (var i = 0; i < layers.length; i++) {
                            var l = layers[i];
                            ctx.globalAlpha = l.alpha;
                            ctx.fillStyle = "#000000";
                            ctx.beginPath();
                            ctx.moveTo(ox + sk + l.dx, oy + l.dy);
                            ctx.lineTo(ox + w + l.dx, oy + l.dy);
                            ctx.lineTo(ox + w - sk + l.dx, oy + h + l.dy);
                            ctx.lineTo(ox + l.dx, oy + h + l.dy);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }

                // Image container (background, thumbnail, parallelogram mask)
                Item {
                    id: imageContainer

                    anchors.fill: parent
                    layer.enabled: true
                    layer.smooth: true
                    layer.samples: 4

                    Image {
                        id: bgImage

                        anchors.fill: parent
                        source: model.background ? "file://" + model.background : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        visible: status === Image.Ready
                        sourceSize.width: appLauncher.expandedWidth
                        sourceSize.height: appLauncher.sliceHeight
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !bgImage.visible && (!thumbImage.visible || thumbImage.status !== Image.Ready)

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: appLauncher.colors && appLauncher.colors.surfaceContainer ? appLauncher.colors.surfaceContainer : "#1a1c2e"
                            }

                            GradientStop {
                                position: 1
                                color: appLauncher.colors && appLauncher.colors.surface ? appLauncher.colors.surface : "#0e1018"
                            }

                        }

                    }

                    Image {
                        id: thumbImage

                        anchors.fill: parent
                        source: model.thumb ? "file://" + model.thumb : ""
                        fillMode: model.source === "steam" ? Image.PreserveAspectCrop : Image.Pad
                        horizontalAlignment: Image.AlignHCenter
                        verticalAlignment: Image.AlignVCenter
                        smooth: true
                        asynchronous: true
                        sourceSize.width: appLauncher.expandedWidth
                        sourceSize.height: appLauncher.sliceHeight
                        visible: model.thumb !== "" && !bgImage.visible
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, delegateItem.isCurrent ? 0 : (delegateItem.isHovered ? 0.15 : 0.4))

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                    }

                    // App icon — shown big and prominent when no thumbnail
                    Item {
                        anchors.centerIn: parent
                        width: delegateItem.isCurrent ? 192 : 72
                        height: width
                        visible: !thumbImage.visible || thumbImage.status !== Image.Ready

                        // Outer glow ring
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 16
                            height: parent.height + 16
                            radius: (parent.width + 16) / 2
                            color: "transparent"
                            border.width: delegateItem.isCurrent ? 2 : 0
                            border.color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.35) : Qt.rgba(1, 1, 1, 0.25)

                            Behavior on border.width {
                                NumberAnimation {
                                    duration: 200
                                }

                            }

                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            radius: parent.width * 0.22
                            color: Qt.rgba(0, 0, 0, delegateItem.isCurrent ? 0.5 : 0.7)
                            border.width: 1.5
                            border.color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, delegateItem.isCurrent ? 0.6 : 0.25) : Qt.rgba(1, 1, 1, 0.2)

                            Image {
                                anchors.fill: parent
                                anchors.margins: parent.width * 0.14
                                source: model.iconPath ? "file://" + model.iconPath : (model.icon ? "image://icon/" + model.icon : "")
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                                asynchronous: true
                            }

                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutBack
                                easing.overshoot: 0.8
                            }

                        }

                    }

                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskThresholdMin: 0.3
                        maskSpreadAtMin: 0.3

                        maskSource: ShaderEffectSource {

                            sourceItem: Item {
                                width: imageContainer.width
                                height: imageContainer.height
                                layer.enabled: true
                                layer.smooth: true
                                layer.samples: 8

                                Shape {
                                    anchors.fill: parent
                                    antialiasing: true
                                    preferredRendererType: Shape.CurveRenderer

                                    ShapePath {
                                        fillColor: "white"
                                        strokeColor: "transparent"
                                        startX: appLauncher.skewOffset
                                        startY: 0

                                        PathLine {
                                            x: delegateItem.width
                                            y: 0
                                        }

                                        PathLine {
                                            x: delegateItem.width - appLauncher.skewOffset
                                            y: delegateItem.height
                                        }

                                        PathLine {
                                            x: 0
                                            y: delegateItem.height
                                        }

                                        PathLine {
                                            x: appLauncher.skewOffset
                                            y: 0
                                        }

                                    }

                                }

                            }

                        }

                    }

                }

                // Parallelogram glow border
                Shape {
                    id: glowBorder

                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer
                    opacity: 1

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: delegateItem.isCurrent ? (appLauncher.colors ? appLauncher.colors.primary : "#8BC34A") : (delegateItem.isHovered ? Qt.rgba(appLauncher.colors ? appLauncher.colors.primary.r : 0.5, appLauncher.colors ? appLauncher.colors.primary.g : 0.76, appLauncher.colors ? appLauncher.colors.primary.b : 0.29, 0.4) : Qt.rgba(0, 0, 0, 0.6))
                        strokeWidth: delegateItem.isCurrent ? 3 : 1
                        startX: appLauncher.skewOffset
                        startY: 0

                        PathLine {
                            x: delegateItem.width
                            y: 0
                        }

                        PathLine {
                            x: delegateItem.width - appLauncher.skewOffset
                            y: delegateItem.height
                        }

                        PathLine {
                            x: 0
                            y: delegateItem.height
                        }

                        PathLine {
                            x: appLauncher.skewOffset
                            y: 0
                        }

                        Behavior on strokeColor {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                    }

                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    width: 22
                    height: 22
                    radius: 11
                    color: model.source === "steam" ? (appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7") : Qt.rgba(0, 0, 0, 0.7)
                    border.width: 1
                    border.color: model.source === "steam" ? "transparent" : (appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.6) : Qt.rgba(1, 1, 1, 0.4))
                    visible: model.source === "steam"
                    z: 10

                    Text {
                        anchors.centerIn: parent
                        text: "󰓓"
                        font.family: appLauncher.fontIcons
                        font.pixelSize: 12
                        color: model.source === "steam" ? (appLauncher.colors ? appLauncher.colors.primaryText : "#000") : (appLauncher.colors ? appLauncher.colors.primary : "#4fc3f7")
                    }

                }

                // App name label (visible when selected)
                Rectangle {
                    id: nameLabel

                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: nameText.width + 24
                    height: 32
                    radius: 6
                    color: Qt.rgba(0, 0, 0, 0.75)
                    border.width: 1
                    border.color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.5) : Qt.rgba(1, 1, 1, 0.2)
                    visible: delegateItem.isCurrent
                    opacity: delegateItem.isCurrent ? 1 : 0

                    Text {
                        id: nameText

                        anchors.centerIn: parent
                        text: (model.displayName || model.name).toUpperCase()
                        font.family: appLauncher.fontBody
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        color: "#ffffff"
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                        width: Math.min(implicitWidth, delegateItem.width - 60)
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }

                    }

                }

                // Category type badge (bottom-right)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: appLauncher.skewOffset + 8
                    width: typeBadgeText.width + 8
                    height: 16
                    radius: 4
                    color: Qt.rgba(0, 0, 0, 0.75)
                    border.width: 1
                    border.color: appLauncher.colors ? Qt.rgba(appLauncher.colors.primary.r, appLauncher.colors.primary.g, appLauncher.colors.primary.b, 0.4) : Qt.rgba(1, 1, 1, 0.2)
                    z: 10

                    Text {
                        id: typeBadgeText

                        anchors.centerIn: parent
                        text: model.source === "steam" ? "STEAM" : model.categories.indexOf("Game") !== -1 ? "GAME" : model.categories.indexOf("Development") !== -1 ? "DEV" : model.categories.indexOf("Graphics") !== -1 ? "GFX" : (model.categories.indexOf("AudioVideo") !== -1 || model.categories.indexOf("Audio") !== -1 || model.categories.indexOf("Video") !== -1) ? "MEDIA" : model.categories.indexOf("Network") !== -1 ? "NET" : model.categories.indexOf("Office") !== -1 ? "OFFICE" : model.categories.indexOf("System") !== -1 ? "SYS" : model.categories.indexOf("Settings") !== -1 ? "CFG" : model.categories.indexOf("Utility") !== -1 ? "UTIL" : "APP"
                        font.family: appLauncher.fontBody
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        color: appLauncher.colors ? appLauncher.colors.tertiary : "#8bceff"
                    }

                }

                // Mouse area: click once to select, click again (when current) to launch
                // Hover navigation removed — use scroll wheel or arrow keys instead.
                MouseArea {
                    id: itemMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        console.log("[AppLauncher] Delegate clicked! Current:", delegateItem.isCurrent, "Model:", model.name);
                        if (delegateItem.isCurrent) {
                            console.log("[AppLauncher] Launching:", model.name, "Exec:", model.exec);
                            appLauncher.launchApp(model.exec, model.terminal, model.name);
                        } else {
                            console.log("[AppLauncher] Selecting app at index:", index);
                            sliceListView.currentIndex = index;
                        }
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }

                }

            }

        }

    }

    // Secondary monitor overlays to capture keyboard input from any screen
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: secondaryLauncherPanel

            property var modelData
            property bool isMainMonitor: modelData.name === appLauncher.mainMonitor || (Quickshell.screens.length === 1)

            screen: modelData
            visible: appLauncher.showing && !isMainMonitor
            color: "transparent"
            WlrLayershell.namespace: "app-launcher-parallel-secondary"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (appLauncher.showing && !isMainMonitor) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.5)
                opacity: appLauncher.cardVisible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                    }

                }

            }

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.overviewOpen = false
            }

            FocusScope {
                anchors.fill: parent
                focus: appLauncher.showing && !isMainMonitor
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.overviewOpen = false;
                        event.accepted = true;
                        return ;
                    }
                    if (event.text && event.text.length > 0 && !event.modifiers) {
                        var c = event.text.charCodeAt(0);
                        if (c >= 32 && c < 127) {
                            appLauncher.searchText += event.text;
                            event.accepted = true;
                            return ;
                        }
                    }
                    if (event.key === Qt.Key_Backspace) {
                        if (appLauncher.searchText.length > 0)
                            appLauncher.searchText = appLauncher.searchText.slice(0, -1);

                        event.accepted = true;
                        return ;
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (sliceListView.currentIndex >= 0 && sliceListView.currentIndex < filteredModel.count) {
                            var app = filteredModel.get(sliceListView.currentIndex);
                            appLauncher.launchApp(app.exec, app.terminal, app.name);
                        }
                        event.accepted = true;
                        return ;
                    }
                    if (event.key === Qt.Key_Left) {
                        if (sliceListView.currentIndex > 0)
                            sliceListView.currentIndex--;

                        event.accepted = true;
                        return ;
                    }
                    if (event.key === Qt.Key_Right) {
                        if (sliceListView.currentIndex < filteredModel.count - 1)
                            sliceListView.currentIndex++;

                        event.accepted = true;
                        return ;
                    }
                }
            }

        }

    }

}
