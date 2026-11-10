import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "components"
import "code/catppuccin.js" as Catppuccin

// The island's card: the cover, the song and the dancing bars; the progress between the
// times; previous, play/pause, next, the button that opens the player and the lyrics, which are
// only asked for once they are open. Below: the players to choose from, and who is using a
// microphone, a camera or the screen.
Item {
    id: card

    // the pill's cover comes to this place by itself: the card's own waits for it
    property bool coverHidden: false
    readonly property real margin: Kirigami.Units.largeSpacing
    readonly property real coverSize: Kirigami.Units.gridUnit * 3
    readonly property real coverRadius: Kirigami.Units.cornerRadius * 1.2
    readonly property real coverShadow: Kirigami.Units.smallSpacing * 2

    property bool showLyrics: false
    // the lyrics are asked for once they have appeared: nothing else happens meanwhile
    property bool lyricsWanted: false

    implicitHeight: column.implicitHeight + margin * 2

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

    ColumnLayout {
        id: column
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: card.margin
        spacing: Kirigami.Units.largeSpacing

        // the cover, the song, the bars
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Cover {
                Layout.preferredWidth: card.coverSize
                Layout.preferredHeight: card.coverSize
                opacity: card.coverHidden ? 0 : 1
                source: player.artUrl
                accent: root.accent
                radius: card.coverRadius
                shadowSize: card.coverShadow
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Marquee {
                    Layout.fillWidth: true
                    text: root.hasMedia ? player.title : i18n("Nothing playing")
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
                visible: root.hasMedia
                color: root.accent
                running: root.playing && (root.cardOpen || !root.surface)
                opacity: root.playing ? 1 : 0.45
            }
        }

        // the progress, between the times
        RowLayout {
            Layout.fillWidth: true
            visible: root.hasMedia && root.length > 0
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

        // the controls in the middle, whatever stands on each side of them
        RowLayout {
            Layout.fillWidth: true
            // the buttons' round hover areas stay out of the spacing around the icons
            Layout.topMargin: -Kirigami.Units.smallSpacing
            Layout.bottomMargin: -Kirigami.Units.smallSpacing * 2

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 0

                IconButton {
                    visible: root.hasMedia
                    symbolic: false
                    size: Kirigami.Units.iconSizes.smallMedium
                    source: player.mpris2Model.currentPlayer?.desktopEntry || player.mpris2Model.currentPlayer?.iconName || "view-media-track"
                    enabled: player.canRaise
                    tip: i18n("Open %1", player.identity)
                    onClicked: {
                        player.raise();
                        root.closeCard();
                    }
                }

                Item { Layout.fillWidth: true }
            }

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

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 0

                Item { Layout.fillWidth: true }

                IconButton {
                    visible: root.hasMedia
                    size: Kirigami.Units.iconSizes.smallMedium
                    source: "view-media-lyrics"
                    tip: card.showLyrics ? i18n("Hide the lyrics") : i18n("Show the lyrics")
                    accent: root.accent
                    checked: card.showLyrics
                    onClicked: card.showLyrics = !card.showLyrics
                }
            }
        }

        // several players open: each one is there to pick
        Flow {
            Layout.fillWidth: true
            visible: root.players.length > 1
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: root.players

                QQC2.AbstractButton {
                    id: chip
                    required property var modelData
                    readonly property bool current: modelData.identity === player.identity

                    width: chipRow.implicitWidth + Kirigami.Units.largeSpacing * 2
                    height: Kirigami.Units.gridUnit * 1.7
                    hoverEnabled: true
                    onClicked: root.choosePlayer(modelData.index)

                    background: Rectangle {
                        radius: height / 2
                        color: chip.current ? Qt.alpha(root.accent, 0.2) : Qt.alpha(Kirigami.Theme.textColor, chip.hovered ? 0.09 : 0.04)
                        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                    }

                    contentItem: Item {
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Kirigami.Units.iconSizes.small
                                height: width
                                source: chip.modelData.iconName
                            }
                            PlasmaComponents3.Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.identity
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }
                    }
                }
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
            // left open, they are only asked for again once the card is back
            active: card.lyricsWanted && (root.cardOpen || root.planar)
            artist: player.artists
            title: player.title
            seconds: root.length / 1000000
            position: root.position / 1000000
            accent: root.accent
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
        }

        // who is using a microphone, a camera, the screen
        Repeater {
            model: activities.inUse

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 2

                Sign {
                    source: modelData.icon
                    fallback: modelData.fallback ?? "unknown"
                    color: modelData.color
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: modelData.label
                    elide: Text.ElideRight
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.8
                }
            }
        }
    }
}
