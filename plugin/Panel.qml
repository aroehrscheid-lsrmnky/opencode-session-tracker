import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Ui

Rectangle {
    id: root
    width: 960
    height: 640
    color: "#1e1e1e"
    radius: 12

    property string cachePath: "/home/remotemonkey/.cache/opencode-sessions/sessions.json"
    property string libraryPath: "/home/remotemonkey/.config/omarchy/plugins/io.github.yourname.opencode-sessions/prompts.json"
    property var sessions: []
    property int activeSessionIndex: 0
    property var library: []
    property int viewMode: 0
    property string searchText: ""
    property string dayFilter: "All"
    property string tagFilter: ""

    FileView {
        id: cacheView
        path: root.cachePath
        onFileChanged: {
            try { var d = JSON.parse(text); sessions = d.sessions || [] } catch(e) {}
        }
    }

    FileView {
        id: libView
        path: root.libraryPath
        onFileChanged: {
            try { library = JSON.parse(text).library || [] } catch(e) { library = [] }
        }
    }

    Process {
        id: saveProc
        command: ["python3", "/home/remotemonkey/documents/opencode-session-tracker/save_prompt.py", editor.text]
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_F && event.modifiers & Qt.ControlModifier) { searchField.forceActiveFocus(); event.accepted = true }
        if (event.key === Qt.Key_W && event.modifiers & Qt.ControlModifier) { editor.text = ""; event.accepted = true }
        if (event.key === Qt.Key_S && event.modifiers & Qt.ControlModifier) { saveProc.start(); event.accepted = true }
        if (event.key === Qt.Key_Escape) { Quickshell.WindowManager.closePanel("io.github.yourname.opencode-sessions") }
    }

    Column {
        anchors.fill: parent
        spacing: 8
        padding: 12

        Text {
            text: "OpenCode Session Tracker"
            color: "white"
            font.pixelSize: 18
            font.bold: true
        }

        Row {
            spacing: 8
            Repeater {
                model: ["Sessions","Library","Stats"]
                delegate: Rectangle {
                    width: 100; height: 28; radius: 6
                    color: viewMode===index ? "#3a3a3a" : "#252525"
                    Text { anchors.centerIn: parent; text: modelData; color: "white"; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: viewMode = index }
                }
            }
            TextField {
                id: searchField
                width: 200; height: 28
                placeholderText: "Search..."
                onTextChanged: root.searchText = text
                background: Rectangle { color: "#252525"; radius: 6 }
                color: "white"
            }
        }

        Row {
            spacing: 6
            Repeater {
                model: ["All","Today","Yesterday","7d","30d"]
                delegate: Rectangle {
                    height: 24; radius: 12; padding: { left: 8; right: 8 }
                    color: dayFilter===modelData ? "#3a3a3a" : "#252525"
                    Text { anchors.centerIn: parent; text: modelData; color: "white"; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; onClicked: dayFilter = modelData }
                }
            }
        }

        Loader {
            active: viewMode===0
            anchors.fill: parent
            sourceComponent: sessionsView
        }
        Loader {
            active: viewMode===1
            anchors.fill: parent
            sourceComponent: libraryView
        }
        Loader {
            active: viewMode===2
            anchors.fill: parent
            sourceComponent: statsView
        }
    }

    function matchesDay(ts) {
        if (dayFilter==="All") return true
        var d = new Date(ts)
        var now = new Date()
        if (dayFilter==="Today") return d.toDateString()===now.toDateString()
        if (dayFilter==="Yesterday") { var y=new Date(now); y.setDate(now.getDate()-1); return d.toDateString()===y.toDateString() }
        if (dayFilter==="7d") return now - d < 7*24*3600*1000
        if (dayFilter==="30d") return now - d < 30*24*3600*1000
        return true
    }

    Component {
        id: sessionsView
        Column {
            spacing: 8
            Row {
                spacing: 6
                Repeater {
                    model: root.sessions
                    delegate: Rectangle {
                        width: 180; height: 28; radius: 6
                        color: index === root.activeSessionIndex ? "#3a3a3a" : "#252525"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.title.slice(0,24)
                            color: "white"; font.pixelSize: 12; elide: Text.ElideRight
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.activeSessionIndex = index }
                    }
                }
            }
            Row {
                spacing: 12
                anchors.fill: parent
                Rectangle {
                    width: parent.width * 0.55
                    color: "#252525"; radius: 8
                    Column {
                        anchors.fill: parent; padding: 8
                        Text { text: "Recent Prompts"; color: "#ccc"; font.pixelSize: 14 }
                        ScrollView {
                            anchors.fill: parent; anchors.topMargin: 4
                            Column {
                                spacing: 6
                                Repeater {
                                    model: root.sessions[activeSessionIndex] ? root.sessions[activeSessionIndex].recent_prompts.filter(p => {
                                        var m = p.prompt.toLowerCase().includes(root.searchText.toLowerCase())
                                        return m && matchesDay(p.time_created)
                                    }) : []
                                    delegate: Column {
                                        width: parent.width; spacing: 2
                                        Text { text: new Date(modelData.time_created).toLocaleDateString(); color: "#888"; font.pixelSize: 10 }
                                        Rectangle {
                                            width: parent.width; color: "#1e1e1e"; radius: 4; padding: 6
                                            Text { text: modelData.prompt; wrapMode: Text.WordWrap; color: "#ddd"; font.pixelSize: 12 }
                                            MouseArea { anchors.fill: parent; onClicked: editor.text = modelData.prompt }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width * 0.45
                    color: "#252525"; radius: 8
                    Column {
                        anchors.fill: parent; padding: 8; spacing: 6
                        Text { text: "Prepare Prompt"; color: "#ccc"; font.pixelSize: 14 }
                        TextArea {
                            id: editor
                            anchors.fill: parent; anchors.bottomMargin: 40
                            placeholderText: "Type prompt here..."
                            color: "white"; wrapMode: TextArea.Wrap
                            background: Rectangle { color: "#1e1e1e"; radius: 6 }
                        }
                        Row {
                            spacing: 8
                            Button { text: "Copy"; onClicked: editor.copy() }
                            Button { text: "Save to Library"; onClicked: saveProc.start() }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: libraryView
        Column {
            spacing: 8
            Text { text: "Prompt Library"; color: "#ccc"; font.pixelSize: 14 }
            // Tag chips
            Row {
                spacing: 6
                Repeater {
                    model: {
                        var tags = []
                        for (var i=0;i<library.length;i++) {
                            for (var j=0;j<library[i].tags.length;j++) {
                                var t = library[i].tags[j]
                                if (tags.indexOf(t)===-1) tags.push(t)
                            }
                        }
                        return tags
                    }
                    delegate: Rectangle {
                        height: 24; radius: 12; padding: { left: 8; right: 8 }
                        color: tagFilter===modelData ? "#3a3a3a" : "#252525"
                        Text { anchors.centerIn: parent; text: "#"+modelData; color: "white"; font.pixelSize: 11 }
                        MouseArea { anchors.fill: parent; onClicked: tagFilter = tagFilter===modelData ? "" : modelData }
                    }
                }
            }
            ScrollView {
                anchors.fill: parent
                Column {
                    spacing: 6
                    Repeater {
                        model: root.library.filter(p => {
                            var txt = p.text.toLowerCase().includes(root.searchText.toLowerCase())
                            var tag = !tagFilter || p.tags.indexOf(tagFilter)!==-1
                            return txt && tag
                        })
                        delegate: Rectangle {
                            width: parent.width; color: "#252525"; radius: 6; padding: 8
                            Column {
                                spacing: 4
                                Text { text: modelData.text.slice(0,200); color: "white"; wrapMode: Text.WordWrap; font.pixelSize: 12 }
                                Row {
                                    spacing: 4
                                    Repeater {
                                        model: modelData.tags
                                        delegate: Text { text: "#"+modelData; color: "#8ab4f8"; font.pixelSize: 10 }
                                    }
                                }
                                Text { text: new Date(modelData.created_at).toLocaleString(); color: "#888"; font.pixelSize: 10 }
                            }
                            MouseArea { anchors.fill: parent; onClicked: editorLib.text = modelData.text }
                        }
                    }
                }
            }
            TextArea {
                id: editorLib
                width: parent.width; height: 120
                placeholderText: "Quick edit / copy from library..."
                color: "white"
                background: Rectangle { color: "#1e1e1e"; radius: 6 }
            }
        }
    }

    Component {
        id: statsView
        Column {
            spacing: 8
            Text { text: "Stats"; color: "#ccc"; font.pixelSize: 14 }
            Text { text: "Sessions: " + sessions.length; color: "white"; font.pixelSize: 13 }
            Text { text: "Library items: " + library.length; color: "white"; font.pixelSize: 13 }
            Text { text: "Total prompts in last 30d: " + sessions.reduce((a,s)=>a + s.recent_prompts.filter(p=> (Date.now()-p.time_created)<30*24*3600*1000).length,0); color: "white"; font.pixelSize: 13 }
        }
    }
}
