import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import org.kde.ksvg as KSvg
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import "components"
import "code/catppuccin.js" as Catppuccin

// The island's card: the cover, the song and the dancing bars; the progress between the
// times; previous, play/pause, next, and the button that opens the player. Its content unfolds
// from the top when it opens. The lyrics open below, and are only asked for then.
Item {
    id: card

    property bool showLyrics: false
    // the lyrics are asked for once they have appeared: nothing else happens meanwhile
    property bool lyricsWanted: false

    onShowLyricsChanged: {
        lyricsWanted = false;
        if (showLyrics) {
            riseIn.restart();
            afterOpening.restart();
        }
    }

    NumberAnimation {
        id: riseIn
        target: rise
        property: "y"
        from: Kirigami.Units.gridUnit
        to: 0
        duration: Kirigami.Units.longDuration
        easing.type: Easing.OutCubic
    }

    Timer {
        id: afterOpening
        interval: Kirigami.Units.longDuration + 50
        onTriggered: card.lyricsWanted = true
    }

    // whatever the theme's colors: the text stays readable on the crust
    Kirigami.Theme.inherit: false
    Kirigami.Theme.textColor: Catppuccin.TEXT

    // a card fitted to its content: Plasma would otherwise keep a size the popup had before
    Layout.preferredWidth: Kirigami.Units.gridUnit * 19
    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.maximumWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumHeight: Layout.preferredHeight

    // Mocha's darkest color, up to the popup's frame, leaving its line: it takes the frame's
    // shape from the theme's own picture, whatever its corners
    Item {
        id: backdrop
        readonly property var popup: card.Window.window
        z: -1
        anchors.fill: parent
        anchors.topMargin: 1 - (popup?.topPadding ?? 0)
        anchors.leftMargin: 1 - (popup?.leftPadding ?? 0)
        anchors.rightMargin: 1 - (popup?.rightPadding ?? 0)
        anchors.bottomMargin: 1 - (popup?.bottomPadding ?? 0)

        Rectangle {
            id: crust
            anchors.fill: parent
            color: Catppuccin.CRUST
            layer.enabled: true
            visible: false
        }

        KSvg.FrameSvgItem {
            id: frameShape
            anchors.fill: parent
            imagePath: "dialogs/background"
            layer.enabled: true
            visible: false
            // a popup touching its panel has no border on that side
            enabledBorders: {
                if (backdrop.popup?.margin !== 0) {
                    return KSvg.FrameSvg.AllBorders;
                }
                switch (Plasmoid.location) {
                case PlasmaCore.Types.TopEdge: return KSvg.FrameSvg.AllBorders & ~KSvg.FrameSvg.TopBorder;
                case PlasmaCore.Types.BottomEdge: return KSvg.FrameSvg.AllBorders & ~KSvg.FrameSvg.BottomBorder;
                case PlasmaCore.Types.LeftEdge: return KSvg.FrameSvg.AllBorders & ~KSvg.FrameSvg.LeftBorder;
                case PlasmaCore.Types.RightEdge: return KSvg.FrameSvg.AllBorders & ~KSvg.FrameSvg.RightBorder;
                default: return KSvg.FrameSvg.AllBorders;
                }
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: crust
            maskEnabled: true
            maskSource: frameShape
        }
    }

    // the content unfolds from the top center, like the island opening
    Connections {
        target: root
        function onExpandedChanged() {
            if (root.expanded) {
                unfold.restart();
            }
        }
    }

    ParallelAnimation {
        id: unfold
        NumberAnimation { target: column; property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: column; property: "scale"; from: 0.94; to: 1; duration: Kirigami.Units.longDuration; easing.type: Easing.OutBack }
        NumberAnimation { target: shift; property: "y"; from: -Kirigami.Units.gridUnit; to: 0; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: column
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing
        transformOrigin: Item.Top
        transform: Translate { id: shift }

        // the cover, the song, the bars
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Cover {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                source: player.artUrl
                accent: root.accent
                radius: Kirigami.Units.cornerRadius * 1.2
                shadowSize: Kirigami.Units.smallSpacing * 2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Marquee {
                    Layout.fillWidth: true
                    text: player.ready ? player.title : i18n("Nothing playing")
                    font.weight: Font.DemiBold
                    scrolling: titleHover.hovered
                    HoverHandler { id: titleHover }
                }
                Marquee {
                    Layout.fillWidth: true
                    visible: player.artists
                    text: player.artists
                    opacity: 0.65
                    scrolling: artistHover.hovered
                    HoverHandler { id: artistHover }
                }
            }

            PlayingBars {
                Layout.preferredWidth: Kirigami.Units.gridUnit
                Layout.preferredHeight: Kirigami.Units.gridUnit
                Layout.alignment: Qt.AlignVCenter
                visible: player.ready
                color: root.accent
                running: root.playing
                opacity: root.playing ? 1 : 0.45
            }
        }

        // the progress, between the times
        RowLayout {
            Layout.fillWidth: true
            visible: player.ready && root.length > 0
            spacing: Kirigami.Units.smallSpacing * 2

            PlasmaComponents3.Label {
                text: Catppuccin.duration(seek.shown * root.length)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.features: { "tnum": 1 }
                opacity: 0.6
            }
            SeekBar {
                id: seek
                Layout.fillWidth: true
                value: root.progress
                accent: root.accent
                interactive: player.canSeek
                onMoved: value => root.seek(value)
            }
            PlasmaComponents3.Label {
                text: "-" + Catppuccin.duration(root.length - seek.shown * root.length)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.features: { "tnum": 1 }
                opacity: 0.6
            }
        }

        // the controls; the button that opens the player on the left, the lyrics on the right
        RowLayout {
            Layout.fillWidth: true
            // the buttons' round hover areas stay out of the spacing around the icons
            Layout.topMargin: -Kirigami.Units.smallSpacing
            Layout.bottomMargin: -Kirigami.Units.smallSpacing * 2

            IconButton {
                visible: player.ready
                symbolic: false
                size: Kirigami.Units.iconSizes.smallMedium
                source: player.mpris2Model.currentPlayer?.desktopEntry || player.mpris2Model.currentPlayer?.iconName || "view-media-track"
                enabled: player.canRaise
                tip: root.players.length > 1 ? i18n("Open %1 (right click: next player)", player.identity) : i18n("Open %1", player.identity)
                onClicked: {
                    player.raise();
                    root.expanded = false;
                }

                // several players: the next one
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    enabled: root.players.length > 1
                    onTapped: {
                        const at = root.players.findIndex(p => p.identity === player.identity);
                        root.choosePlayer(root.players[(at + 1) % root.players.length].index);
                    }
                }
            }

            Item { Layout.fillWidth: true }

            IconButton {
                source: "media-skip-backward"
                tip: i18n("Previous")
                size: Kirigami.Units.iconSizes.medium
                enabled: player.canGoPrevious
                onClicked: player.previous()
            }
            IconButton {
                source: root.playing ? "media-playback-pause" : "media-playback-start"
                size: Kirigami.Units.iconSizes.medium * 1.25
                enabled: root.playing ? player.canPause : player.canPlay
                onClicked: player.playPause()
            }
            IconButton {
                source: "media-skip-forward"
                tip: i18n("Next")
                size: Kirigami.Units.iconSizes.medium
                enabled: player.canGoNext
                onClicked: player.next()
            }

            Item { Layout.fillWidth: true }

            IconButton {
                visible: player.ready
                size: Kirigami.Units.iconSizes.smallMedium
                source: "view-media-lyrics"
                tip: card.showLyrics ? i18n("Hide the lyrics") : i18n("Show the lyrics")
                accent: root.accent
                checked: card.showLyrics
                onClicked: card.showLyrics = !card.showLyrics
            }
        }

        // the popup takes its new height at once: resizing its window at every frame is what
        // stutters. Only the lyrics move, which is smooth: they fade in as they rise.
        Lyrics {
            id: lyricsView
            Layout.fillWidth: true
            Layout.preferredHeight: card.showLyrics ? Kirigami.Units.gridUnit * 12 : 0
            visible: card.showLyrics
            opacity: card.showLyrics ? 1 : 0
            transform: Translate { id: rise }
            active: card.lyricsWanted
            artist: player.artists
            title: player.title
            seconds: root.length / 1000000
            position: root.position / 1000000
            accent: root.accent
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
        }
    }
}
