import QtQuick
import Quickshell.Wayland
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Ui

Item {
    id: root
    property var shell
    property var manifest
    property bool opened: false

    function open(payloadJson) { root.opened = true }
    function close() {
        if (!root.opened) return
        root.opened = false
        if (shell && manifest && typeof shell.hide === 'function') shell.hide(manifest.id)
    }

    PanelWindow {
        id: panelWin
        visible: root.opened
        WlrLayershell.namespace: "opencode-sessions-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }

        Rectangle {
            id: card
            width: 960
            height: 640
            radius: 12
            color: "#1e1e1e"
            anchors.centerIn: parent

            property string home: Quickshell.env("HOME")
            property string pluginDir: home + "/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions"
            property string cachePath: home + "/.cache/opencode-sessions/sessions.json"
            property string libraryPath: pluginDir + "/prompts.json"
            property var sessions: []
            property int activeSessionIndex: 0
            property var library: []
            property int viewMode: 0
            property string searchText: ""
            property string dayFilter: "All"
            property string tagFilter: ""
            property string draftText: ""
            property string libDraft: ""
            property string statusMsg: ""

            onSessionsChanged: {
                if (activeSessionIndex >= sessions.length)
                    activeSessionIndex = Math.max(0, sessions.length - 1)
            }

            function setStatus(msg) {
                statusMsg = msg
                statusTimer.restart()
            }

            function savePrompt() {
                if (draftText.trim() === "") {
                    setStatus("Nothing to save")
                    return
                }
                saveProc.running = true
            }

            function matchesDay(ts) {
                if (dayFilter === "All") return true
                var d = new Date(ts)
                var now = new Date()
                if (dayFilter === "Today") return d.toDateString() === now.toDateString()
                if (dayFilter === "Yesterday") {
                    var y = new Date(now)
                    y.setDate(now.getDate() - 1)
                    return d.toDateString() === y.toDateString()
                }
                if (dayFilter === "7d") return now - d < 7 * 24 * 3600 * 1000
                if (dayFilter === "30d") return now - d < 30 * 24 * 3600 * 1000
                return true
            }

            function filteredPrompts() {
                var s = sessions[activeSessionIndex]
                if (!s) return []
                var q = searchText.toLowerCase()
                return s.recent_prompts.filter(p => {
                    return String(p.prompt).toLowerCase().includes(q) && matchesDay(p.time_created)
                })
            }

            function libraryTags() {
                var tags = []
                for (var i = 0; i < library.length; i++) {
                    var itemTags = library[i].tags || []
                    for (var j = 0; j < itemTags.length; j++) {
                        if (tags.indexOf(itemTags[j]) === -1) tags.push(itemTags[j])
                    }
                }
                return tags
            }

            function filteredLibrary() {
                var q = searchText.toLowerCase()
                return library.filter(p => {
                    var txt = String(p.text || "").toLowerCase().includes(q)
                    var tag = !tagFilter || (p.tags || []).indexOf(tagFilter) !== -1
                    return txt && tag
                })
            }

            Timer {
                id: statusTimer
                interval: 4000
                onTriggered: card.statusMsg = ""
            }

            FileView {
                id: cacheView
                path: card.cachePath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        var d = JSON.parse(String(text() || ""))
                        card.sessions = d.sessions || []
                    } catch (e) {}
                }
            }

            FileView {
                id: libView
                path: card.libraryPath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        var d = JSON.parse(String(text() || ""))
                        card.library = d.library || []
                    } catch (e) {
                        card.library = []
                    }
                }
            }

            Process {
                id: saveProc
                command: ["python3", card.pluginDir + "/scripts/save_prompt.py", card.draftText]
                onExited: (exitCode, exitStatus) => {
                    if (exitCode === 0) {
                        card.setStatus("Saved to library")
                        libView.reload()
                    } else {
                        card.setStatus("Save failed (exit " + exitCode + ")")
                    }
                }
            }

            Process {
                id: exportJsonProc
                command: ["python3", card.pluginDir + "/scripts/export_library.py"]
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus("Exported: " + String(line).trim())
                    }
                }
            }

            Process {
                id: exportMdProc
                command: ["python3", card.pluginDir + "/scripts/export_library_md.py"]
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus("Exported: " + String(line).trim())
                    }
                }
            }

            Process {
                id: importDialog
                command: ["python3", "-c", "import tkinter.filedialog as fd; print(fd.askopenfilename(), flush=True)"]
                stdout: SplitParser {
                    onRead: function(line) {
                        var p = String(line).trim()
                        if (p === "") return
                        importFile.command = ["python3", card.pluginDir + "/scripts/import_library.py", p]
                        importFile.running = true
                    }
                }
            }

            Process {
                id: importFile
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus(String(line).trim())
                    }
                }
                onExited: libView.reload()
            }

            Shortcut { sequence: "Escape"; onActivated: root.close() }
            Shortcut { sequence: "Ctrl+F"; onActivated: searchField.forceActiveFocus() }
            Shortcut { sequence: "Ctrl+W"; onActivated: card.draftText = "" }
            Shortcut { sequence: "Ctrl+S"; onActivated: card.savePrompt() }
            Shortcut { sequence: "Ctrl+1"; onActivated: card.viewMode = 0 }
            Shortcut { sequence: "Ctrl+2"; onActivated: card.viewMode = 1 }
            Shortcut { sequence: "Ctrl+3"; onActivated: card.viewMode = 2 }

            Column {
                id: headerCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "OpenCode Session Tracker"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                Row {
                    spacing: 8

                    Repeater {
                        model: ["Sessions", "Library", "Stats"]
                        delegate: Rectangle {
                            width: 100
                            height: 28
                            radius: 6
                            color: card.viewMode === index ? "#3a6df0" : "#252525"
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: "white"
                                font.pixelSize: 12
                            }
                            MouseArea { anchors.fill: parent; onClicked: card.viewMode = index }
                        }
                    }

                    Item { width: 16; height: 1 }

                    TextField {
                        id: searchField
                        width: 240
                        height: 28
                        placeholderText: "Search... (Ctrl+F)"
                        onTextChanged: card.searchText = text
                        background: Rectangle { color: "#252525"; radius: 6 }
                        color: "white"
                    }
                }

                Row {
                    spacing: 6
                    visible: card.viewMode === 0

                    Repeater {
                        model: ["All", "Today", "Yesterday", "7d", "30d"]
                        delegate: Rectangle {
                            height: 24
                            radius: 12
                            width: dayLabel.implicitWidth + 16
                            color: card.dayFilter === modelData ? "#3a6df0" : "#252525"
                            Text {
                                id: dayLabel
                                anchors.centerIn: parent
                                text: modelData
                                color: "white"
                                font.pixelSize: 11
                            }
                            MouseArea { anchors.fill: parent; onClicked: card.dayFilter = modelData }
                        }
                    }
                }
            }

            Item {
                id: contentArea
                anchors.top: headerCol.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 28

                Loader {
                    anchors.fill: parent
                    active: card.viewMode === 0
                    sourceComponent: sessionsView
                }
                Loader {
                    anchors.fill: parent
                    active: card.viewMode === 1
                    sourceComponent: libraryView
                }
                Loader {
                    anchors.fill: parent
                    active: card.viewMode === 2
                    sourceComponent: statsView
                }
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.statusMsg
                visible: card.statusMsg !== ""
                color: "#8ab4f8"
                font.pixelSize: 12
            }

            Component {
                id: sessionsView

                Item {
                    anchors.fill: parent

                    Flow {
                        id: sessionChips
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 6

                        Repeater {
                            model: card.sessions
                            delegate: Rectangle {
                                width: chipLabel.implicitWidth + 20
                                height: 26
                                radius: 6
                                color: index === card.activeSessionIndex ? "#3a6df0" : "#252525"
                                Text {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: modelData.title.slice(0, 28)
                                    color: "white"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                                MouseArea { anchors.fill: parent; onClicked: card.activeSessionIndex = index }
                            }
                        }
                    }

                    Item {
                        id: panes
                        anchors.top: sessionChips.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom

                        Rectangle {
                            id: promptsPane
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: (parent.width - 12) * 0.55
                            color: "#252525"
                            radius: 8

                            Text {
                                id: promptsHeader
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 10
                                text: "Recent Prompts"
                                color: "#ccc"
                                font.pixelSize: 14
                            }

                            ScrollView {
                                id: promptScroll
                                anchors.top: promptsHeader.bottom
                                anchors.topMargin: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 10
                                clip: true

                                Column {
                                    id: promptList
                                    width: promptScroll.availableWidth
                                    spacing: 6

                                    Repeater {
                                        id: promptRepeater
                                        model: card.filteredPrompts()
                                        delegate: Column {
                                            width: promptList.width
                                            spacing: 4

                                            Text {
                                                text: new Date(modelData.time_created).toLocaleString()
                                                color: "#888"
                                                font.pixelSize: 10
                                            }

                                            Rectangle {
                                                width: parent.width
                                                height: promptText.implicitHeight + 12
                                                color: "#1e1e1e"
                                                radius: 4

                                                Text {
                                                    id: promptText
                                                    x: 6
                                                    y: 6
                                                    width: parent.width - 12
                                                    text: modelData.prompt
                                                    wrapMode: Text.WordWrap
                                                    color: "#ddd"
                                                    font.pixelSize: 12
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        card.draftText = modelData.prompt
                                                        card.setStatus("Prompt loaded into editor")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: promptRepeater.count === 0
                                text: card.sessions.length === 0
                                    ? "No sessions yet — waiting for the exporter cache"
                                    : "No prompts match the current filters"
                                color: "#666"
                                font.pixelSize: 13
                            }
                        }

                        Rectangle {
                            id: editorPane
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: (parent.width - 12) * 0.45
                            color: "#252525"
                            radius: 8

                            Text {
                                id: editorHeader
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 10
                                text: "Prepare Prompt"
                                color: "#ccc"
                                font.pixelSize: 14
                            }

                            TextArea {
                                id: editor
                                anchors.top: editorHeader.bottom
                                anchors.topMargin: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.bottom: buttonRow.top
                                anchors.bottomMargin: 8
                                text: card.draftText
                                onTextChanged: {
                                    if (text !== card.draftText) card.draftText = text
                                }
                                placeholderText: "Type a prompt, or click one on the left"
                                placeholderTextColor: "#888"
                                color: "white"
                                wrapMode: TextArea.Wrap
                                selectByMouse: true
                                background: Rectangle { color: "#1e1e1e"; radius: 6 }
                            }

                            // Fallback placeholder (native one sometimes doesn't render)
                            Text {
                                anchors.top: editor.top
                                anchors.topMargin: 8
                                anchors.left: editor.left
                                anchors.leftMargin: 10
                                visible: editor.text === ""
                                text: "Type a prompt, or click one on the left"
                                color: "#888"
                                font.pixelSize: 12
                                z: editor.z + 1
                            }

                            Row {
                                id: buttonRow
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 10
                                spacing: 8

                                Button {
                                    text: "Copy"
                                    bordered: true
                                    onClicked: {
                                        Quickshell.clipboardText = card.draftText
                                        card.setStatus("Copied to clipboard")
                                    }
                                }
                                Button {
                                    text: "Save to Library"
                                    bordered: true
                                    onClicked: card.savePrompt()
                                }
                                Button {
                                    text: "Clear"
                                    bordered: true
                                    onClicked: card.draftText = ""
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: libraryView

                Item {
                    anchors.fill: parent

                    Row {
                        id: libToolbar
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 8

                        Text {
                            text: "Prompt Library"
                            color: "#ccc"
                            font.pixelSize: 14
                            height: 28
                            verticalAlignment: Text.AlignVCenter
                        }

                        Button { text: "Export JSON"; bordered: true; onClicked: exportJsonProc.running = true }
                        Button { text: "Export MD"; bordered: true; onClicked: exportMdProc.running = true }
                        Button { text: "Import"; bordered: true; onClicked: importDialog.running = true }
                    }

                    Flow {
                        id: tagFlow
                        anchors.top: libToolbar.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 6

                        Repeater {
                            model: card.libraryTags()
                            delegate: Rectangle {
                                height: 24
                                radius: 12
                                width: tagLabel.implicitWidth + 16
                                color: card.tagFilter === modelData ? "#3a6df0" : "#252525"
                                Text {
                                    id: tagLabel
                                    anchors.centerIn: parent
                                    text: "#" + modelData
                                    color: "white"
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: card.tagFilter = card.tagFilter === modelData ? "" : modelData
                                }
                            }
                        }
                    }

                    TextArea {
                        id: editorLib
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        height: 110
                        text: card.libDraft
                        onTextChanged: {
                            if (text !== card.libDraft) card.libDraft = text
                        }
                        placeholderText: "Click a library item to load it here"
                        placeholderTextColor: "#888"
                        color: "white"
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        background: Rectangle { color: "#1e1e1e"; radius: 6 }
                    }

                    // Fallback placeholder (native one sometimes doesn't render)
                    Text {
                        anchors.top: editorLib.top
                        anchors.topMargin: 8
                        anchors.left: editorLib.left
                        anchors.leftMargin: 10
                        visible: editorLib.text === ""
                        text: "Click a library item to load it here"
                        color: "#888"
                        font.pixelSize: 12
                        z: editorLib.z + 1
                    }

                    ScrollView {
                        id: libScroll
                        anchors.top: tagFlow.bottom
                        anchors.topMargin: 8
                        anchors.bottom: editorLib.top
                        anchors.bottomMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        clip: true

                        Column {
                            id: libList
                            width: libScroll.availableWidth
                            spacing: 6

                            Repeater {
                                id: libRepeater
                                model: card.filteredLibrary()
                                delegate: Rectangle {
                                    width: libList.width
                                    height: libItemCol.implicitHeight + 16
                                    color: "#252525"
                                    radius: 6

                                    Column {
                                        id: libItemCol
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: modelData.text.length > 300 ? modelData.text.slice(0, 300) + "…" : modelData.text
                                            wrapMode: Text.WordWrap
                                            color: "#ddd"
                                            font.pixelSize: 12
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: 4

                                            Repeater {
                                                model: modelData.tags || []
                                                delegate: Text {
                                                    text: "#" + modelData
                                                    color: "#8ab4f8"
                                                    font.pixelSize: 10
                                                }
                                            }
                                        }

                                        Text {
                                            text: new Date(modelData.created_at).toLocaleString()
                                            color: "#888"
                                            font.pixelSize: 10
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: card.libDraft = modelData.text
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: libRepeater.count === 0
                        text: card.library.length === 0
                            ? "Library is empty — save prompts from the Sessions tab"
                            : "No library items match the current filters"
                        color: "#666"
                        font.pixelSize: 13
                    }
                }
            }

            Component {
                id: statsView

                Item {
                    anchors.fill: parent

                    Column {
                        x: 4
                        y: 4
                        spacing: 8

                        Text { text: "Stats"; color: "#ccc"; font.pixelSize: 14 }
                        Text { text: "Sessions: " + card.sessions.length; color: "white"; font.pixelSize: 13 }
                        Text { text: "Library items: " + card.library.length; color: "white"; font.pixelSize: 13 }
                        Text {
                            text: "Prompts (last 30d): " + card.sessions.reduce((a, s) =>
                                a + s.recent_prompts.filter(p => (Date.now() - p.time_created) < 30 * 24 * 3600 * 1000).length, 0)
                            color: "white"
                            font.pixelSize: 13
                        }
                        Text {
                            text: "Active session: " + (card.sessions[card.activeSessionIndex] ? card.sessions[card.activeSessionIndex].title : "—")
                            color: "white"
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
