import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import "code/catppuccin.js" as Catppuccin
import "activities"

PlasmoidItem {
    id: root

    readonly property bool playing: player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // the cover's color, as a Catppuccin accent
    readonly property color accent: sampler.accent
    readonly property color onAccent: Catppuccin.CRUST

    // MPRIS sends the position only when asked: it runs on here between two asks
    property real position: 0
    readonly property real length: player.songLength
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    // every player but the multiplexer: [{ index, identity, iconName }]
    property var players: []

    Plasmoid.status: player.ready || Plasmoid.configuration.showWhenNoMedia
        || activities.flashing || activities.busy
        ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    Plasmoid.icon: "view-media-track"

    toolTipMainText: player.ready ? player.title : i18n("Nothing playing")
    toolTipSubText: player.ready ? [player.artists, player.identity].filter(x => x).join(" · ") : ""
    toolTipTextFormat: Text.PlainText

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 14

    // charger, transfers, microphone: what the island shows besides music
    Activities {
        id: activities
    }

    Player {
        id: player
        sourceIdentities: {
            const names = Plasmoid.configuration.players.split(",").map(x => x.trim()).filter(x => x);
            return names.length ? names : null;
        }
    }

    // the cover, drawn at 12 x 12 px to read its colors (Kirigami's ImageColors crashed the
    // shell when covers changed quickly); invisible, but in the scene, where a canvas paints
    Canvas {
        id: sampler
        property string url: Plasmoid.configuration.tintFromCover ? player.artUrl : ""
        property string loadedUrl
        property color accent: Catppuccin.TEAL
        width: 12
        height: 12
        opacity: 0.01
        renderStrategy: Canvas.Immediate
        onUrlChanged: {
            if (loadedUrl) {
                unloadImage(loadedUrl);
            }
            accent = Catppuccin.TEAL;
            loadedUrl = url;
            if (url) {
                loadImage(url);
            }
        }
        onImageLoaded: requestPaint()
        onPaint: {
            if (!url || !isImageLoaded(url)) {
                return;
            }
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(url, 0, 0, width, height);
            accent = Catppuccin.accentFromPixels(ctx.getImageData(0, 0, width, height).data);
        }
    }

    Connections {
        target: player
        function onSongPositionChanged() { root.position = player.songPosition; }
        function onTitleChanged() { player.updatePosition(); }
    }

    Connections {
        target: player.mpris2Model
        function onRowsInserted() { root.listPlayers(); }
        function onRowsRemoved() { root.listPlayers(); }
        function onCurrentIndexChanged() { root.listPlayers(); }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.playing
        onTriggered: root.position = Math.min(root.position + interval * 1000, root.length || Infinity)
    }

    // catch up with seeks made in the player itself
    Timer {
        interval: root.expanded ? 2000 : 5000
        repeat: true
        running: root.playing
        triggeredOnStart: true
        onTriggered: player.updatePosition()
    }

    function seek(fraction) {
        if (player.canSeek && length > 0) {
            position = fraction * length;
            player.setPosition(position);
        }
    }

    // a player chosen by hand stays for a minute, even paused
    property double chosenUntil: 0

    function choosePlayer(index) {
        chosenUntil = Date.now() + 60000;
        player.mpris2Model.currentIndex = index;
    }

    function listPlayers() {
        const model = player.mpris2Model;
        const containerRole = Qt.UserRole + 1;
        const list = [];
        for (let i = 1; i < model.rowCount(); i++) {
            const container = model.data(model.index(i, 0), containerRole);
            if (container) {
                list.push({ index: i, identity: container.identity, iconName: container.desktopEntry || container.iconName || "view-media-track" });
            }
        }
        players = list;
        pickPlayer();
    }

    // Plasma's own choice (the multiplexer, row 0) can settle on a browser that stays
    // registered without a track: when following "the one playing", the widget picks
    // itself the player playing, else the current one if it has a track, else the first
    // with a track.
    function pickPlayer() {
        const model = player.mpris2Model;
        if (player.sourceIdentities || model.rowCount() < 2) {
            if (model.currentIndex < 0 && model.rowCount() > 0) {
                model.updatePlayerIndex(model);
            }
            return;
        }
        const containerRole = Qt.UserRole + 1;
        const hasTrack = p => !!(p && (p.track || p.artist || p.album));
        if (Date.now() < chosenUntil && player.ready) {
            return;
        }
        let playing = -1, withTrack = -1;
        for (let i = 1; i < model.rowCount(); i++) {
            const p = model.data(model.index(i, 0), containerRole);
            if (playing < 0 && p?.playbackStatus === Mpris.PlaybackStatus.Playing && hasTrack(p)) {
                playing = i;
            }
            if (withTrack < 0 && hasTrack(p)) {
                withTrack = i;
            }
        }
        const current = model.currentIndex >= 1 ? model.data(model.index(model.currentIndex, 0), containerRole) : null;
        if (playing >= 0 && current?.playbackStatus !== Mpris.PlaybackStatus.Playing) {
            model.currentIndex = playing;
        } else if (!hasTrack(current) && withTrack >= 0) {
            model.currentIndex = withTrack;
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.pickPlayer()
    }

    Component.onCompleted: listPlayers()

    compactRepresentation: IslandCompact {}
    fullRepresentation: IslandFull {}
}
