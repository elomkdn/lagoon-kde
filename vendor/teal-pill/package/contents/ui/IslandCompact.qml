import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "components"
import "code/catppuccin.js" as Catppuccin
import "code/numbers.js" as Numbers

// In the panel, an island: a pill in Mocha's darkest color (crust). It holds the music (the
// cover and the dancing bars, the title on hover or always); the charger, headphones or a power
// profile take it for a moment; small colored signs tell a microphone, a camera, a shared screen
// or a snapshot; transfers get a bubble of their own beside it, with their progress around.
// Click: the card; middle click: play/pause; wheel: volume.
MouseArea {
    id: island

    // whatever the panel's colors: the text stays readable on the crust
    Kirigami.Theme.inherit: false
    Kirigami.Theme.textColor: Catppuccin.TEXT

    readonly property bool hasMedia: root.hasMedia
    readonly property bool flashing: activities.flashing
    // nearly the panel's height, whatever it is: a thin bar must not make a tiny pill
    readonly property real pillHeight: Math.max(Kirigami.Units.iconSizes.small + 6, height - 4)
    readonly property real coverSize: pillHeight - 6
    readonly property bool open: hasMedia && !flashing && (containsMouse || Plasmoid.configuration.alwaysShowTitle)
    readonly property real titleRoom: open ? Math.min(title.implicitWidth, Kirigami.Units.gridUnit * 12) : 0
    readonly property bool hasSigns: activities.inUse.length > 0 || activities.snapshot
    readonly property bool showPill: hasMedia || flashing || hasSigns || root.cardOpen || Plasmoid.configuration.showWhenNoMedia

    Component.onCompleted: {
        root.pillItem = pill;
        root.pillCoverItem = pillCover;
    }

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
        default: root.toggleCard();
        }
    }
    onWheel: wheel => player.changeVolume(wheel.angleDelta.y / 120 * 0.05, true)

    // Plasma's "no animations" setting
    readonly property bool animated: Kirigami.Units.longDuration > 0

    // the applet stays in the panel while the bubble goes back in (main.qml)
    Binding {
        target: root
        property: "bubbleHeld"
        value: bubble.held
    }

    Item {
        id: row
        anchors.centerIn: parent
        height: island.pillHeight
        // the transfers' bubble buds from the pill's end and pinches off; without the pill, it
        // grows in place
        readonly property bool budding: island.showPill
        readonly property real size: island.pillHeight
        readonly property real gap: Kirigami.Units.smallSpacing
        // where the pill ends, and the bubble buds from
        readonly property real end: budding ? pill.width : 0
        width: end + bubble.grown * (budding ? size + gap : size)

        Rectangle {
            id: pill
            visible: island.showPill
            height: island.pillHeight
            // never narrower than it is tall: a lone icon or sign gets a round pill, its room to
            // spare on the left, and the bubble can hide under the pill's end
            readonly property real wanted: (island.flashing ? flash.implicitWidth : music.implicitWidth) + 16
            readonly property real spare: Math.max(0, height - wanted)
            width: wanted + spare
            radius: height / 2
            color: Catppuccin.CRUST
            clip: true
            // it gives way as the card leaves, and takes the card back with a small bump
            scale: 1 - 0.05 * root.cardProgress

            // a spring keeps its speed when the mouse comes back halfway
            Behavior on width {
                enabled: island.animated
                SpringAnimation { spring: 5; damping: 0.45; epsilon: 0.25 }
            }

            // the music, or the microphone alone
            RowLayout {
                id: music
                anchors.left: parent.left
                anchors.leftMargin: 3 + pill.spare
                anchors.verticalCenter: parent.verticalCenter
                spacing: Kirigami.Units.smallSpacing * 2
                opacity: island.flashing ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

                // the cover; while it is away in the card, a chevron that folds the card back
                Item {
                    id: pillCover
                    Layout.preferredWidth: island.coverSize
                    Layout.preferredHeight: island.coverSize
                    visible: island.hasMedia

                    Cover {
                        anchors.fill: parent
                        visible: root.cardProgress <= 0.02
                        source: player.artUrl
                        accent: root.accent
                        radius: height / 2
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.alpha(Kirigami.Theme.textColor, root.pillHovered ? 0.16 : 0.07)
                        opacity: chevron.opacity
                        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                    }

                    Kirigami.Icon {
                        id: chevron
                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.7)
                        height: width
                        scale: 0.6 + 0.4 * opacity
                        opacity: Numbers.clamp((root.cardProgress - 0.45) / 0.55)
                        // not every icon theme has the first name of each pair
                        readonly property var names: {
                            switch (Plasmoid.location) {
                            case PlasmaCore.Types.BottomEdge: return ["arrow-down", "go-down-symbolic"];
                            case PlasmaCore.Types.LeftEdge: return ["arrow-left", "go-previous-symbolic"];
                            case PlasmaCore.Types.RightEdge: return ["arrow-right", "go-next-symbolic"];
                            default: return ["arrow-up", "go-up-symbolic"];
                            }
                        }
                        source: names[0]
                        fallback: names[1]
                        isMask: true
                        color: Kirigami.Theme.textColor
                    }
                }

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    Layout.leftMargin: 4
                    visible: !island.hasMedia && !island.hasSigns
                    source: "view-media-track"
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
                    Layout.rightMargin: island.hasSigns ? 0 : 2
                    visible: island.hasMedia
                    color: root.accent
                    running: root.playing
                    opacity: root.playing ? 1 : 0.45
                }

                // a microphone, a camera, a shared screen
                Repeater {
                    model: activities.inUse

                    Sign {
                        required property var modelData
                        Layout.rightMargin: 2
                        source: modelData.icon
                        color: modelData.color
                    }
                }

                // the system's own state, apart from who is using what
                Sign {
                    visible: activities.snapshot
                    Layout.rightMargin: 2
                    source: Qt.resolvedUrl("../icons/snapshot.svg")
                    color: Catppuccin.MOCHA.yellow
                }
            }

            // a passing event: its icon, its level, its value
            RowLayout {
                id: flash
                // the event on show: it stays while the pill fades it out, and the next one in
                // line takes its place through a quick fade
                property var event: null
                readonly property var coming: activities.flash
                property real swap: 1
                onComingChanged: {
                    if (coming === null) {
                        return;
                    }
                    if (event === null || !island.animated || opacity === 0) {
                        swapping.stop();
                        event = coming;
                        swap = 1;
                    } else {
                        swapping.restart();
                    }
                }
                SequentialAnimation {
                    id: swapping
                    NumberAnimation { target: flash; property: "swap"; to: 0; duration: Kirigami.Units.shortDuration }
                    ScriptAction { script: flash.event = flash.coming ?? flash.event }
                    NumberAnimation { target: flash; property: "swap"; to: 1; duration: Kirigami.Units.shortDuration }
                }
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
                    opacity: flash.swap
                    isMask: true
                    color: flash.event?.kind === "charging" ? flash.tint : Kirigami.Theme.textColor
                    Kirigami.Theme.inherit: false
                    Kirigami.Theme.textColor: flash.event?.kind === "charging" ? flash.tint : island.Kirigami.Theme.textColor
                }

                Rectangle {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                    Layout.preferredHeight: 5
                    visible: (flash.event?.level ?? -1) >= 0
                    opacity: flash.swap
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
                    opacity: flash.swap
                    font.features: { "tnum": 1 }
                    horizontalAlignment: Text.AlignRight
                    color: flash.event?.kind === "charging" ? flash.tint : Kirigami.Theme.textColor
                }
            }
        }

        // the neck between the pill and the bubble while it comes out or goes back in: it thins as
        // they part, and breaks just before the bubble settles
        Shape {
            id: neck
            z: -1
            // drawn from the centre of the pill's end cap: when the pill's width changes, only
            // the shape moves, its path stays as it is
            x: row.end - r
            width: row.size * 2 + row.gap
            height: row.height
            preferredRendererType: Shape.CurveRenderer

            readonly property real r: row.size / 2
            // from half the bubble under the pill to the break, just short of its place: 0 to 1
            readonly property real apart: bubble.offset
            readonly property real strain: Numbers.clamp((apart + r) / (row.gap * 0.85 + r))
            // where the neck leaves each circle, above and below the middle line: near the top
            // while they are one, lower as they part
            readonly property real angle: (80 - 35 * strain) * Math.PI / 180
            readonly property real far: r * Math.sin(angle)
            readonly property real x1: r * Math.cos(angle)
            readonly property real x2: apart + 2 * r - r * Math.cos(angle)
            readonly property real middle: (x1 + x2) / 2
            readonly property real reach: (x2 - x1) / 2
            // as thick as the pill at first, then it thins
            readonly property real waist: r * Math.pow(1 - strain, 1.3)
            // each end leaves its circle along the circle
            readonly property real slope: reach * 0.5 / Math.tan(angle)

            // it breaks before it is a thread
            visible: row.budding && bubble.visible && apart > -r && reach > 0 && waist > r * 0.12

            ShapePath {
                fillColor: Catppuccin.CRUST
                strokeColor: "transparent"
                strokeWidth: 0
                startX: neck.x1
                startY: neck.r - neck.far
                PathCubic {
                    x: neck.middle; y: neck.r - neck.waist
                    control1X: neck.x1 + neck.reach * 0.5; control1Y: neck.r - neck.far + neck.slope
                    control2X: neck.middle - neck.reach * 0.5; control2Y: neck.r - neck.waist
                }
                PathCubic {
                    x: neck.x2; y: neck.r - neck.far
                    control1X: neck.middle + neck.reach * 0.5; control1Y: neck.r - neck.waist
                    control2X: neck.x2 - neck.reach * 0.5; control2Y: neck.r - neck.far + neck.slope
                }
                PathLine { x: neck.x2; y: neck.r + neck.far }
                PathCubic {
                    x: neck.middle; y: neck.r + neck.waist
                    control1X: neck.x2 - neck.reach * 0.5; control1Y: neck.r + neck.far - neck.slope
                    control2X: neck.middle + neck.reach * 0.5; control2Y: neck.r + neck.waist
                }
                PathCubic {
                    x: neck.x1; y: neck.r + neck.far
                    control1X: neck.middle - neck.reach * 0.5; control1Y: neck.r + neck.waist
                    control2X: neck.x1 + neck.reach * 0.5; control2Y: neck.r + neck.far - neck.slope
                }
                PathLine { x: neck.x1; y: neck.r - neck.far }
            }
        }

        // transfers: a bubble of their own, their progress around it. It sits under the pill, so
        // that it comes out from behind the pill's end, and goes back the same way.
        Rectangle {
            id: bubble
            z: -1
            readonly property bool wanted: activities.jobs > 0
            // 0: in the pill, 1: out beside it; the spring goes a little past both
            property real out: wanted ? 1 : 0
            Behavior on out {
                enabled: island.animated
                SpringAnimation { spring: 3.5; damping: 0.38; epsilon: 0.002 }
            }
            readonly property real grown: Numbers.clamp(out)
            // from the moment a transfer starts until the bubble is back in: the spring's
            // rebound past 0 afterwards is not shown
            property bool held: false
            Component.onCompleted: held = wanted
            onWantedChanged: held = wanted || out > 0.005
            onOutChanged: if (!wanted && out <= 0.005) held = false
            // where it stands from the pill's end: under the pill's cap at 0, beside it at 1
            readonly property real offset: (row.size + row.gap) * out - row.size
            visible: held && out > 0.005
            // without the pill, it grows from the middle of its own room
            x: row.budding ? row.end + offset : (grown - 1) * row.size / 2
            width: row.size
            height: row.size
            radius: height / 2
            scale: row.budding ? 1 : grown
            color: Catppuccin.CRUST

            Item {
                anchors.fill: parent
                // what it holds shows once it is mostly out
                opacity: row.budding ? Numbers.clamp((bubble.out - 0.6) / 0.4) : bubble.grown

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
                    source: Qt.resolvedUrl("../icons/download.svg")
                    isMask: true
                    color: Kirigami.Theme.textColor
                }
            }
        }
    }
}
