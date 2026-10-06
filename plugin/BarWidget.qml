import QtQuick
import qs.Ui

BarWidget {
    id: root
    moduleName: "io.github.aroehrscheid-lsrmnky.opencode-sessions"

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "OC"
        horizontalMargin: 7.5
        onPressed: {
            if (!root.bar) return
            root.bar.run("omarchy-shell shell toggle io.github.aroehrscheid-lsrmnky.opencode-sessions '{}'")
        }
    }
}
