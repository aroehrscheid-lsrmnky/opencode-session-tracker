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
        command: ["python3", "/home/remotemonkey/documents/opencode-session-tracker/save_prompt.py", editor.text, searchText]
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
            Rectangle {
                width: 100; height: 28; radius: 6
                color: viewMode===0 ? "#3a3a3a" : "#252525"
                Text { anchors.centerIn: parent; text: "Sessions"; color: "white"; font.pixelSize: 12 }
                MouseArea { anchors.fill: parent; onClicked: viewMode=0 }
            }
            Rectangle {
                width: 100; height: 28; radius: 6
                color: viewMode===1 ? "#3a3a3a" : "#252525"
                Text { anchors.centerIn: parent; text: "Library"; color: "white"; font.pixelSize: 12 }
                MouseArea { anchors.fill: parent; onClicked: viewMode=1 }
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
                anchors.topMargin: 8
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
                                    model: root.sessions[activeSessionIndex] ? root.sessions[activeSessionIndex].recent_prompts.filter(p => p.prompt.toLowerCase().includes(root.searchText.toLowerCase())) : []
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
                            Button { text: "Copy"; onClicked: console.log("Copy:", editor.text) }
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
            ScrollView {
                anchors.fill: parent
                Column {
                    spacing: 6
                    Repeater {
                        model: root.library.filter(p => p.text.toLowerCase().includes(root.searchText.toLowerCase()))
                        delegate: Rectangle {
                            width: parent.width; color: "#252525"; radius: 6; padding: 8
                            Column {
                                spacing: 4
                                Text { text: modelData.text.slice(0,200); color: "white"; wrapMode: Text.WordWrap; font.pixelSize: 12 }
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
}
