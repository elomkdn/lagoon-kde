import QtQuick

// Four centered bars that dance while music plays: each one picks its next
// height and its own tempo at random, so the motion never loops; the middle ones reach higher.
// When the music stops, they settle into small equal dots.
Row {
    id: bars

    property color color
    property bool running: false

    // how high each bar may reach, from left to right
    readonly property var reach: [0.65, 1.0, 0.85, 0.55]
    readonly property real rest: 0.2

    spacing: Math.max(1, Math.round(width / 9))

    Repeater {
        model: bars.reach.length

        Rectangle {
            id: bar
            required property int index
            property real level: bars.rest
            width: (bars.width - bars.spacing * (bars.reach.length - 1)) / bars.reach.length
            height: Math.max(width, bars.height * level)
            anchors.verticalCenter: parent?.verticalCenter
            radius: width / 2
            color: bars.color

            Behavior on level { NumberAnimation { id: glide; duration: 300; easing.type: Easing.InOutSine } }

            Timer {
                running: bars.running
                repeat: true
                triggeredOnStart: true
                interval: 200
                onTriggered: {
                    interval = 130 + Math.random() * 230;
                    glide.duration = interval;
                    bar.level = bars.rest + Math.random() * (bars.reach[bar.index] - bars.rest);
                }
                onRunningChanged: if (!running) {
                    glide.duration = 300;
                    bar.level = bars.rest;
                }
            }
        }
    }
}
