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
    property var sessions: []
    property int activeSessionIndex: 0

    // Load cache
    FileView {
        path: root.cachePath
        onFileChanged: {
            try {
                sessions = JSON.parse(text)
                sessions = sessions.sessions || []
            } catch(e) {}
        }
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

        // Tab bar
        Row {
            id: tabBar
            spacing: 6
            Repeater {
                model: root.sessions
                delegate: Rectangle {
                    width: 180
                    height: 28
                    radius: 6
                    color: index === root.activeSessionIndex ? "#3a3a3a" : "#252525"
                    Text {
                        anchors.centerIn: parent
                        text: modelData.title.slice(0,24)
                        color: "white"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.activeSessionIndex = index
                    }
                }
            }
        }

        Row {
            spacing: 12
            anchors.fill: parent
            anchors.topMargin: 8

            // Recent prompts list
            Rectangle {
                width: parent.width * 0.55
                color: "#252525"
                radius: 8
                Column {
                    anchors.fill: parent
                    padding: 8
                    Text { text: "Recent Prompts"; color: "#ccc"; font.pixelSize: 14 }
                    ScrollView {
                        anchors.fill: parent
                        anchors.topMargin: 4
                        Column {
                            spacing: 6
                            Repeater {
                                model: root.sessions[activeSessionIndex] ? root.sessions[activeSessionIndex].recent_prompts : []
                                delegate: Rectangle {
                                    width: parent.width
                                    color: "#1e1e1e"
                                    radius: 4
                                    padding: 6
                                    Text {
                                        text: modelData.prompt
                                        wrapMode: Text.WordWrap
                                        color: "#ddd"
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Prompt editor
            Rectangle {
                width: parent.width * 0.45
                color: "#252525"
                radius: 8
                Column {
                    anchors.fill: parent
                    padding: 8
                    spacing: 6
                    Text { text: "Prepare Prompt"; color: "#ccc"; font.pixelSize: 14 }
                    TextArea {
                        id: editor
                        anchors.fill: parent
                        placeholderText: "Type prompt here..."
                        color: "white"
                        wrapMode: TextArea.Wrap
                        background: Rectangle { color: "#1e1e1e"; radius: 6 }
                    }
                }
            }
        }
    }
}
