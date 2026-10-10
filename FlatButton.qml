import QtQuick

pragma ComponentBehavior: Bound

// House-style button matching the panel's Send button: accent blue, radius 6,
// 24px tall, white 11px label.
//
// This lives in its own file rather than as an inline `component` because a
// child id inside an inline component is not resolvable from that component's
// own root in this Quickshell/Qt build -- width bindings silently became
// undefined and the buttons collapsed to zero width. As a file, normal QML
// scoping applies and implicitWidth measures the label correctly.
Rectangle {
    id: root

    property string text: ""
    property bool primary: true
    property int horizontalPadding: 20

    signal clicked()

    implicitHeight: 24
    implicitWidth: label.implicitWidth + horizontalPadding
    radius: 6

    color: primary
           ? (hoverArea.containsMouse ? "#2f61d8" : "#3a6df0")
           : (hoverArea.containsMouse ? "#333" : "#252525")
    border.width: primary ? 0 : 1
    border.color: "#3a3a3a"
    opacity: enabled ? 1 : 0.45

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? "#fff" : "#ccc"
        font.pixelSize: 11
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}