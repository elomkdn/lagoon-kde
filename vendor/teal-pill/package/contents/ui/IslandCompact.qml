import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "components"
import "code/catppuccin.js" as Catppuccin

// In the panel, an island: a pill in Mocha's darkest color (crust). It holds the music (the
// cover and the dancing bars, the title on hover or always); the charger, headphones or a power
// profile take it for a moment; colored dots tell a microphone, a camera, a shared screen or a
// snapshot; transfers get a bubble of their own beside it, with their progress around.
// Click: the card; middle click: play/pause; wheel: volume.
MouseArea {
    id: island

    // whatever the panel's colors: the text stays readable on the crust
    Kirigami.Theme.inherit: false
    Kirigami.Theme.textColor: Catppuccin.TEXT

    readonly property bool hasMedia: player.ready
    readonly property bool flashing: activities.flashing
    // nearly the panel's height, whatever it is: a thin bar must not make a tiny pill
    readonly property real pillHeight: Math.max(Kirigami.Units.iconSizes.small + 6, height - 4)
    readonly property real coverSize: pillHeight - 6
    readonly property bool open: hasMedia && !flashing && (containsMouse || root.expanded || Plasmoid.configuration.alwaysShowTitle)
    readonly property real titleRoom: open ? Math.min(title.implicitWidth, Plasmoid.configuration.titleWidth) : 0
    readonly property bool showPill: hasMedia || flashing || activities.dots.length > 0 || Plasmoid.configuration.showWhenNoMedia

    Layout.preferredWidth: row.width + Kirigami.Units.smallSpacing * 2
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton

    onClicked: mouse => {
        switch (mouse.button) {
        case Qt.MiddleButton: player.playPause(); break;
        case Qt.BackButton: player.previous(); break;
        case Qt.ForwardButton: player.next(); break;
        default: root.expanded = !root.expanded;
        }
    }
    onWheel: wheel => player.changeVolume(wheel.angleDelta.y / 120 * 0.05, true)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            id: pill
            visible: island.showPill
            height: island.pillHeight
            width: (island.flashing ? flash.implicitWidth : music.implicitWidth) + 16
            radius: height / 2
            color: Catppuccin.CRUST
            clip: true

            Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            // the music, or the microphone alone
            RowLayout {
                id: music
                anchors.left: parent.left
                anchors.leftMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: Kirigami.Units.smallSpacing * 2
                opacity: island.flashing ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

                Cover {
                    Layout.preferredWidth: island.coverSize
                    Layout.preferredHeight: island.coverSize
                    visible: island.hasMedia
                    source: player.artUrl
                    accent: root.accent
                    radius: height / 2
                }

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    Layout.leftMargin: 4
                    visible: !island.hasMedia
                    source: activities.dots[0]?.icon ?? "view-media-track"
                }

                Marquee {
                    id: title
                    Layout.preferredWidth: island.titleRoom
                    visible: island.titleRoom > 1
                    opacity: island.open ? 1 : 0
                    text: [player.title, player.artists].filter(x => x).join(" · ")
                    scrolling: island.containsMouse
                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                }

                PlayingBars {
                    Layout.preferredWidth: Math.round(island.coverSize * 0.85)
                    Layout.preferredHeight: Math.round(island.coverSize * 0.7)
                    Layout.rightMargin: activities.dots.length > 0 ? 0 : 2
                    visible: island.hasMedia
                    color: root.accent
                    running: root.playing
                    opacity: root.playing ? 1 : 0.45
                }

                // a microphone, a camera, a shared screen, a snapshot
                Repeater {
                    model: activities.dots

                    Rectangle {
                        required property var modelData
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        Layout.rightMargin: 2
                        radius: 3.5
                        color: modelData.color
                    }
                }
            }

            // a passing event: its icon, its level, its value
            RowLayout {
                id: flash
                readonly property var event: activities.flash
                readonly property color tint: event?.kind === "charging" ? Catppuccin.MOCHA.green : Kirigami.Theme.highlightColor
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: Kirigami.Units.smallSpacing * 2
                opacity: island.flashing ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: flash.event?.icon ?? ""
                    isMask: true
                    color: flash.event?.kind === "charging" ? flash.tint : Kirigami.Theme.textColor
                    Kirigami.Theme.inherit: false
                    Kirigami.Theme.textColor: flash.event?.kind === "charging" ? flash.tint : island.Kirigami.Theme.textColor
                }

                Rectangle {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                    Layout.preferredHeight: 5
                    visible: (flash.event?.level ?? -1) >= 0
                    radius: 2.5
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.15)

                    Rectangle {
                        width: parent.width * Math.max(0, flash.event?.level ?? 0)
                        height: parent.height
                        radius: parent.radius
                        color: flash.tint
                        Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                    }
                }

                PlasmaComponents3.Label {
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 2
                    text: flash.event?.text ?? ""
                    font.features: { "tnum": 1 }
                    horizontalAlignment: Text.AlignRight
                    color: flash.event?.kind === "charging" ? flash.tint : Kirigami.Theme.textColor
                }
            }
        }

        // transfers: a bubble of their own, their progress around it
        Rectangle {
            visible: activities.jobs > 0
            width: island.pillHeight
            height: island.pillHeight
            radius: height / 2
            color: Catppuccin.CRUST

            Shape {
                anchors.fill: parent
                anchors.margins: 3
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                    strokeWidth: 2.5
                    PathAngleArc {
                        centerX: (island.pillHeight - 6) / 2
                        centerY: centerX
                        radiusX: centerX - 1.5
                        radiusY: radiusX
                        startAngle: -90
                        sweepAngle: 360
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Kirigami.Theme.highlightColor
                    strokeWidth: 2.5
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: (island.pillHeight - 6) / 2
                        centerY: centerX
                        radiusX: centerX - 1.5
                        radiusY: radiusX
                        startAngle: -90
                        sweepAngle: 360 * Math.max(0.03, activities.jobsProgress)
                    }
                }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.45)
                height: width
                source: "download"
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }
    }
}
