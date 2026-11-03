import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// A round, flat button with a symbolic icon; "checked" puts it in the accent, with a dot.
QQC2.AbstractButton {
    id: button

    property alias source: icon.source
    property int size: Kirigami.Units.iconSizes.smallMedium
    property color accent: Kirigami.Theme.highlightColor
    property string tip
    // symbolic icons take the text color; an app's icon keeps its own colors
    property bool symbolic: true

    implicitWidth: size + Kirigami.Units.largeSpacing * 2
    implicitHeight: implicitWidth
    hoverEnabled: true
    opacity: enabled ? 1 : 0.35

    QQC2.ToolTip.text: tip
    QQC2.ToolTip.visible: hovered && tip
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

    background: Rectangle {
        radius: width / 2
        color: Qt.alpha(Kirigami.Theme.textColor, button.pressed ? 0.16 : button.hovered ? 0.09 : 0)
        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    }

    contentItem: Item {
        Kirigami.Icon {
            id: icon
            anchors.centerIn: parent
            width: button.size
            height: button.size
            isMask: button.symbolic
            color: button.symbolic ? (button.checked ? button.accent : Kirigami.Theme.textColor) : "transparent"
            // the theme's icons take their color from the color scheme
            Kirigami.Theme.inherit: false
            Kirigami.Theme.textColor: button.checked ? button.accent : button.Kirigami.Theme.textColor
            scale: button.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }

        Rectangle {
            visible: button.checked
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: icon.bottom
            anchors.topMargin: 2
            width: 4
            height: 4
            radius: 2
            color: button.accent
        }
    }
}
