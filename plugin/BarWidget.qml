import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Ui

Item {
    id: root
    implicitWidth: 120
    implicitHeight: 24

    property string label: "OC Sessions"

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse ? "#3a3a3a" : "transparent"
        radius: 4
    }

    Text {
        anchors.centerIn: parent
        text: label
        color: Qt.rgba(1,1,1,0.9)
        font.pixelSize: 12
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            Quickshell.WindowManager.openPanel("io.github.aroehrscheid-lsrmnky.opencode-sessions")
        }
    }
}
