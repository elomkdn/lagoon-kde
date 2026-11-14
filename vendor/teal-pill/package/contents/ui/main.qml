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

    // a player left stopped keeps its last track on the bus: after a moment it no longer counts.
    // The moment is for the players that stop briefly between two songs.
    readonly property bool stopped: player.ready && player.playbackStatus === Mpris.PlaybackStatus.Stopped
    property bool resting: false
    readonly property bool hasMedia: player.ready && !resting

    onStoppedChanged: {
        if (stopped) {
            restTimer.restart();
        } else {
            restTimer.stop();
            resting = false;
        }
    }

    Timer {
        id: restTimer
        interval: 2000
        onTriggered: root.resting = root.stopped
    }

    // the pill and its cover, where the card comes from
    property Item pillItem: null
    property Item pillCoverItem: null

    // in a panel on Wayland, the card springs out of the pill; elsewhere, Plasma's popup holds it
    readonly property var surface: surfaceLoader.status === Loader.Ready ? surfaceLoader.item : null
    readonly property bool cardOpen: surface ? surface.open : expanded
    // 0: the card is in the pill, 1: it is out; the spring goes a little past both
    readonly property real cardProgress: surface ? surface.progress : 0
    readonly property bool pillHovered: surface ? surface.pillHovered : false

    function toggleCard() {
        if (surface) {
            surface.open = !surface.open;
        } else {
            expanded = !expanded;
        }
    }

    function closeCard() {
        if (surface) {
            surface.open = false;
        } else {
            expanded = false;
        }
    }

    // the widget's keyboard shortcut opens the same card as a click
    activationTogglesExpanded: surface === null

    Connections {
        target: Plasmoid
        function onActivated() {
            if (root.surface) {
                root.toggleCard();
            }
        }
    }

    Loader {
        id: surfaceLoader
        active: !root.planar && Qt.platform.pluginName.includes("wayland")
        source: "Surface.qml"
    }

    readonly property bool planar: Plasmoid.formFactor !== PlasmaCore.Types.Horizontal && Plasmoid.formFactor !== PlasmaCore.Types.Vertical

    // the transfers' bubble, from its start until it is back in (IslandCompact.qml): when it
    // was alone, its way back is still seen
    property bool bubbleHeld: false

    Plasmoid.status: hasMedia || Plasmoid.configuration.showWhenNoMedia
        || activities.flashing || activities.busy || bubbleHeld || cardOpen
        ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    Plasmoid.icon: "view-media-track"

    // on hover the pill already shows the title: the tooltip only says who is using what, and
    // without any text Plasma shows none
    toolTipMainText: activities.inUse[0]?.label ?? ""
    toolTipSubText: activities.inUse.slice(1).map(x => x.label).join("\n")
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
        // from one song's color to the next, without a stop by teal in between
        Behavior on accent { ColorAnimation { duration: Kirigami.Units.longDuration * 2 } }
        onUrlChanged: {
            if (loadedUrl) {
                unloadImage(loadedUrl);
            }
            if (url) {
                coverLate.restart();
            } else {
                coverLate.stop();
                accent = Catppuccin.TEAL;
            }
            loadedUrl = url;
            if (url) {
                loadImage(url);
            }
        }
        // a cover that never comes must not leave the last song's color; a late one still counts
        Timer {
            id: coverLate
            interval: 3000
            onTriggered: {
                if (!sampler.isImageLoaded(sampler.url)) {
                    sampler.accent = Catppuccin.TEAL;
                }
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
        interval: root.cardOpen ? 2000 : 5000
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

    // a player worth showing holds a track and is not stopped: browsers stay registered without
    // one, and some players keep their last one once stopped
    function isLive(p) {
        return !!(p && (p.track || p.artist || p.album) && p.playbackStatus !== Mpris.PlaybackStatus.Stopped);
    }

    function listPlayers() {
        const model = player.mpris2Model;
        const containerRole = Qt.UserRole + 1;
        const list = [];
        for (let i = 1; i < model.rowCount(); i++) {
            const container = model.data(model.index(i, 0), containerRole);
            if (isLive(container) && (!player.sourceIdentities || player.sourceIdentities.includes(container.identity))) {
                list.push({ index: i, identity: container.identity, iconName: container.desktopEntry || container.iconName || "view-media-track" });
            }
        }
        // the same list stays the same object: what shows it is not rebuilt
        if (JSON.stringify(list) !== JSON.stringify(players)) {
            players = list;
        }
        pickPlayer();
    }

    // Plasma's own choice (the multiplexer, row 0) can settle on a player that is not doing
    // anything: when following "the one playing", the widget picks itself the player playing,
    // else the current one if it is live, else the first live one.
    function pickPlayer() {
        const model = player.mpris2Model;
        if (player.sourceIdentities || model.rowCount() < 2) {
            if (model.currentIndex < 0 && model.rowCount() > 0) {
                model.updatePlayerIndex(model);
            }
            return;
        }
        const containerRole = Qt.UserRole + 1;
        if (Date.now() < chosenUntil && player.ready) {
            return;
        }
        let playing = -1, live = -1;
        for (let i = 1; i < model.rowCount(); i++) {
            const p = model.data(model.index(i, 0), containerRole);
            if (playing < 0 && p?.playbackStatus === Mpris.PlaybackStatus.Playing && isLive(p)) {
                playing = i;
            }
            if (live < 0 && isLive(p)) {
                live = i;
            }
        }
        const current = model.currentIndex >= 1 ? model.data(model.index(model.currentIndex, 0), containerRole) : null;
        if (playing >= 0 && current?.playbackStatus !== Mpris.PlaybackStatus.Playing) {
            model.currentIndex = playing;
        } else if (!isLive(current) && live >= 0) {
            model.currentIndex = live;
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.listPlayers()
    }

    Component.onCompleted: {
        listPlayers();
        if (stopped) {
            restTimer.restart();
        }
    }

    compactRepresentation: IslandCompact {}
    fullRepresentation: IslandFull {}
}
