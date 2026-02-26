pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool open: false
    property var notes: []
    property var items: []

    // Selection state — only one thing selected at a time
    property string selectedNoteId: ""
    property string selectedItemId: ""
    function selectNote(id) { selectedNoteId = id; selectedItemId = "" }
    function selectItem(id) { selectedItemId = id; selectedNoteId = "" }
    function clearSelection() { selectedNoteId = ""; selectedItemId = "" }

    property var colors: ["#FFE566","#FF9EC4","#67E8F9","#FFB347","#C4B5FD","#86EFAC","#FCA5A5","#A5F3FC"]
    property string authorName: "Fauzan"
    readonly property string serverUrl: "http://localhost:19877"
    property string toolbarMode: "none"
    property var emojiList: ["⭐","🔥","💡","✅","❗","🎯","💬","🚀","❤️","🎉","📌","⚡","🌈","🎨","🏆","😊","🥳","👀","💎","🌟"]

    // ── Data ──
    function loadAll() { _loadNotes(); _loadItems() }
    function _loadNotes() {
        const xhr = new XMLHttpRequest(); xhr.open("GET", root.serverUrl + "/notes")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200)
                try { root.notes = JSON.parse(xhr.responseText) } catch(e) { root.notes = [] }
        }; xhr.send()
    }
    function _loadItems() {
        const xhr = new XMLHttpRequest(); xhr.open("GET", root.serverUrl + "/items")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200)
                try { root.items = JSON.parse(xhr.responseText) } catch(e) { root.items = [] }
        }; xhr.send()
    }
    function saveNotes() {
        const xhr = new XMLHttpRequest(); xhr.open("POST", root.serverUrl + "/notes")
        xhr.setRequestHeader("Content-Type", "application/json"); xhr.send(JSON.stringify(root.notes))
    }
    function saveItems() {
        const xhr = new XMLHttpRequest(); xhr.open("POST", root.serverUrl + "/items")
        xhr.setRequestHeader("Content-Type", "application/json"); xhr.send(JSON.stringify(root.items))
    }

    // ── Note functions ──
    function addNote() {
        const used = root.notes.map(function(n) { return n.color })
        let color = root.colors[root.notes.length % root.colors.length]
        for (let i = 0; i < root.colors.length; i++) { if (used.indexOf(root.colors[i]) === -1) { color = root.colors[i]; break } }
        const nx = 300 + Math.random() * 700; const ny = 160 + Math.random() * 460
        const arr = root.notes.slice()
        arr.push({ id: Date.now().toString(36), title: "", body: "", color: color, x: nx, y: ny, w: 200, r: 0, sticker: "", created: Date.now() })
        root.notes = arr; saveNotes()
    }
    function deleteNote(id) { root.notes = root.notes.filter(function(n) { return n.id !== id }); saveNotes() }
    function setNoteColor(id, c) { root.notes = root.notes.map(function(n) { return n.id !== id ? n : Object.assign({}, n, {color: c}) }); saveNotes() }
    function setNoteSticker(id, s) { root.notes = root.notes.map(function(n) { return n.id !== id ? n : Object.assign({}, n, {sticker: s}) }); saveNotes() }
    function resizeNote(id, w) { root.notes = root.notes.map(function(n) { return n.id !== id ? n : Object.assign({}, n, {w: w}) }); saveNotes() }
    function rotateNote(id, r) { root.notes = root.notes.map(function(n) { return n.id !== id ? n : Object.assign({}, n, {r: r}) }); saveNotes() }
    function moveNote(id, nx, ny) { root.notes = root.notes.map(function(n) { return n.id !== id ? n : Object.assign({}, n, {x: nx, y: ny}) }); saveNotes() }

    // ── Item functions ──
    function addEmojiItem(emoji) {
        const nx = 300 + Math.random() * 700; const ny = 160 + Math.random() * 460
        const arr = root.items.slice()
        arr.push({ id: Date.now().toString(36), type: "emoji", content: emoji, x: nx, y: ny, w: 100, h: 100, r: 0 })
        root.items = arr; saveItems()
    }
    function addImageItem(path) {
        const nx = 300 + Math.random() * 500; const ny = 160 + Math.random() * 380
        const arr = root.items.slice()
        arr.push({ id: Date.now().toString(36), type: "image", content: path, x: nx, y: ny, w: 240, h: 180, r: 0 })
        root.items = arr; saveItems()
    }
    function deleteItem(id) { root.items = root.items.filter(function(it) { return it.id !== id }); saveItems() }
    function moveItem(id, nx, ny) { root.items = root.items.map(function(it) { return it.id !== id ? it : Object.assign({}, it, {x: nx, y: ny}) }); saveItems() }
    function resizeItem(id, w, h) { root.items = root.items.map(function(it) { return it.id !== id ? it : Object.assign({}, it, {w: w, h: h}) }); saveItems() }
    function rotateItem(id, r) { root.items = root.items.map(function(it) { return it.id !== id ? it : Object.assign({}, it, {r: r}) }); saveItems() }

    // ── Panel ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.open
            color: "transparent"
            WlrLayershell.namespace: "quickshell:stickyNotes"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            HyprlandFocusGrab { windows: [win]; active: root.open; onCleared: root.open = false }
            Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut
                onActivated: { if (root.selectedNoteId !== "" || root.selectedItemId !== "") root.clearSelection(); else root.open = false }
            }

            // Dim — tap to deselect
            Rectangle {
                anchors.fill: parent; color: "#000"
                opacity: root.open ? 0.12 : 0
                Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                MouseArea { anchors.fill: parent; onClicked: root.clearSelection() }
            }

            // ── Notes ──
            Item {
                anchors.fill: parent

                Repeater {
                    model: root.notes
                    delegate: NoteCard {
                        required property var modelData
                        required property int index
                        x: (modelData.x ?? 300) - noteWidth / 2
                        y: (modelData.y ?? 250) - (height - (isSelected ? 52 : 0)) / 2
                        noteId: modelData.id; noteTitle: modelData.title; noteBody: modelData.body
                        noteColor: modelData.color; noteWidth: modelData.w ?? 200
                        noteRotation: modelData.r ?? 0; noteSticker: modelData.sticker ?? ""
                        authorName: root.authorName; availableColors: root.colors
                        panelOpen: root.open; animDelay: index * 65
                        isSelected: root.selectedNoteId === modelData.id

                        onSelectRequested: (id) => root.selectNote(id)
                        onTitleEdited: (id, val) => { for (let i = 0; i < root.notes.length; i++) { if (root.notes[i].id === id) { root.notes[i].title = val; break } } }
                        onBodyEdited: (id, val) => { for (let i = 0; i < root.notes.length; i++) { if (root.notes[i].id === id) { root.notes[i].body = val; break } } root.saveNotes() }
                        onColorChanged: (id, c) => root.setNoteColor(id, c)
                        onStickerChanged: (id, s) => root.setNoteSticker(id, s)
                        onResized: (id, w) => root.resizeNote(id, w)
                        onRotated: (id, r) => root.rotateNote(id, r)
                        onDeleteRequested: (id) => root.deleteNote(id)
                        onMoved: (id, nx, ny) => root.moveNote(id, nx, ny)
                    }
                }
            }

            // ── Canvas Items (stickers / images) ──
            Item {
                anchors.fill: parent
                Repeater {
                    model: root.items
                    delegate: CanvasItem {
                        required property var modelData
                        required property int index
                        x: (modelData.x ?? 400) - itemW / 2
                        y: (modelData.y ?? 300) - itemH / 2
                        itemId: modelData.id; itemType: modelData.type; content: modelData.content
                        itemW: modelData.w ?? 100; itemH: modelData.h ?? 100; itemRotation: modelData.r ?? 0
                        panelOpen: root.open; animDelay: index * 50 + 200
                        isSelected: root.selectedItemId === modelData.id

                        onSelectRequested: (id) => root.selectItem(id)
                        onMoved: (id, nx, ny) => root.moveItem(id, nx, ny)
                        onResized: (id, w, h) => root.resizeItem(id, w, h)
                        onRotated: (id, r) => root.rotateItem(id, r)
                        onDeleteRequested: (id) => root.deleteItem(id)
                    }
                }
            }

            // ── Toolbar (right side) ──
            Column {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 22; anchors.rightMargin: 28
                spacing: 10
                opacity: root.open ? 1 : 0; scale: root.open ? 1.0 : 0.3; transformOrigin: Item.TopRight
                Behavior on opacity { NumberAnimation { duration: 350 } }
                Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                Repeater {
                    model: [
                        { icon: "📝", tip: "Add Note",     color: "#f59e0b", action: "note"  },
                        { icon: "😊", tip: "Emoji Sticker", color: "#6366f1", action: "emoji" },
                        { icon: "🖼️", tip: "Add Image",    color: "#22c55e", action: "image" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 48; height: 48; radius: 24
                        color: tbH.containsMouse
                            ? modelData.color
                            : root.toolbarMode === modelData.action && modelData.action !== "image" && modelData.action !== "note"
                                ? modelData.color
                                : "#f8f8f8"
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Text { anchors.centerIn: parent; text: parent.modelData.icon; font.pixelSize: 22 }
                        MouseArea {
                            id: tbH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parent.modelData.action === "note") { root.addNote() }
                                else if (parent.modelData.action === "image") { root.open = false; Qt.callLater(function() { imagePicker.open() }) }
                                else { root.toolbarMode = root.toolbarMode === parent.modelData.action ? "none" : parent.modelData.action }
                            }
                        }
                        Rectangle {
                            anchors.right: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 8
                            width: tipTxt.implicitWidth + 16; height: 28; radius: 8; color: "#1a1a2e"; visible: tbH.containsMouse
                            Text { id: tipTxt; anchors.centerIn: parent; text: parent.parent.modelData.tip; font.pixelSize: 12; color: "#fff" }
                        }
                    }
                }
            }

            // ── Emoji picker panel ──
            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: 22 + 58 * 2; anchors.rightMargin: 86
                width: 248; height: emojiGrid.implicitHeight + 24; radius: 16
                color: "#1a1a2e"; border.color: Qt.rgba(1,1,1,0.12); border.width: 1; z: 50
                visible: root.toolbarMode === "emoji"
                scale: visible ? 1.0 : 0.7; opacity: visible ? 1 : 0; transformOrigin: Item.TopRight
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Grid { id: emojiGrid; anchors.centerIn: parent; columns: 5; spacing: 8
                    Repeater { model: root.emojiList
                        delegate: Rectangle { required property var modelData; required property int index
                            width: 38; height: 38; radius: 10
                            color: eH.containsMouse ? Qt.rgba(1,1,1,0.14) : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 22 }
                            MouseArea { id: eH; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.addEmojiItem(parent.modelData); root.toolbarMode = "none" } } } } }
            }

            // ── Hint ──
            Text {
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 16
                text: (root.selectedNoteId !== "" || root.selectedItemId !== "") 
                    ? "Tap canvas to deselect  ·  Esc to deselect"
                    : "Esc · close   ·   " + root.notes.length + " notes   ·   " + root.items.length + " items"
                font.pixelSize: 11; color: "white"
                opacity: root.open ? 0.35 : 0
                Behavior on opacity { NumberAnimation { duration: 400 } }
                Behavior on text { /* no animation needed */ }
            }
        }
    }

    // ── Image file picker (outside PanelWindow so it isn't blocked) ──
    FileDialog {
        id: imagePicker
        title: "Pick an image"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.gif *.webp *.svg *.bmp)"]
        onAccepted: { root.addImageItem(selectedFile.toString().replace("file://", "")); root.open = true }
        onRejected: root.open = true
    }

    GlobalShortcut {
        name: "stickyNotesToggle"
        description: "Toggle sticky notes"
        onPressed: { root.open = !root.open; if (root.open) root.loadAll() }
    }
}
