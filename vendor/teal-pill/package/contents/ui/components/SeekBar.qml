import QtQuick
import org.kde.kirigami as Kirigami

// A thin bar in the accent; its round knob, in the text color like the theme's sliders,
// shows on hover. Dragging previews the value, releasing sets it.
Item {
    id: bar

    property real value: 0
    property color accent: Kirigami.Theme.highlightColor
    property bool interactive: true
    signal moved(real value)

    readonly property bool active: interactive && (mouse.containsMouse || mouse.pressed)
    readonly property real shown: mouse.pressed ? mouse.preview : value

    implicitHeight: 16

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: bar.active ? 6 : 4
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.14)
        Behavior on height { NumberAnimation { duration: Kirigami.Units.shortDuration } }

        Rectangle {
            width: Math.max(track.height, track.width * bar.shown)
            height: parent.height
            radius: parent.radius
            color: bar.accent
            visible: bar.shown > 0
        }
    }

    Rectangle {
        x: track.width * bar.shown - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: Kirigami.Theme.textColor
        scale: bar.active ? 1 : 0
        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutBack } }
    }

    MouseArea {
        id: mouse
        property real preview: 0
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        enabled: bar.interactive
        hoverEnabled: true
        cursorShape: bar.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        function at(x) { return Math.max(0, Math.min(1, x / width)); }
        onPressed: event => preview = at(event.x)
        onPositionChanged: event => { if (pressed) preview = at(event.x); }
        onReleased: event => bar.moved(at(event.x))
    }
}
