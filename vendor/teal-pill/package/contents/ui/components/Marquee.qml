import QtQuick
import org.kde.plasma.components as PlasmaComponents3

// A one-line text, cut with an ellipsis when too long; on hover, it scrolls by.
Item {
    id: marquee

    property alias text: label.text
    property alias font: label.font
    property alias color: label.color
    property bool scrolling: false

    readonly property bool overflows: label.implicitWidth > width + 1
    readonly property int gap: 32

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: true

    PlasmaComponents3.Label {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: running ? implicitWidth : marquee.width
        elide: running ? Text.ElideNone : Text.ElideRight
        textFormat: Text.PlainText
        maximumLineCount: 1
        readonly property bool running: marquee.scrolling && marquee.overflows
    }

    // the text again, after the gap: the loop looks endless
    PlasmaComponents3.Label {
        visible: label.running
        anchors.verticalCenter: parent.verticalCenter
        x: label.x + label.implicitWidth + marquee.gap
        text: label.text
        font: label.font
        color: label.color
        textFormat: Text.PlainText
    }

    NumberAnimation {
        target: label
        property: "x"
        from: 0
        to: -(label.implicitWidth + marquee.gap)
        duration: (label.implicitWidth + marquee.gap) * 28
        loops: Animation.Infinite
        running: label.running
        onRunningChanged: if (!running) label.x = 0
    }
}
