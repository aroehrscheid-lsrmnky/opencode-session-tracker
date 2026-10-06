import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Ui

Item {
    id: root
    implicitWidth: 120
    implicitHeight: 24

    property string label: "OC Sessions"

    Text {
        anchors.centerIn: parent
        text: label
        color: Qt.rgba(1,1,1,0.9)
        font.pixelSize: 12
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            // Open panel
            Quickshell.WindowManager.openPanel("io.github.yourname.opencode-sessions")
        }
    }
}
