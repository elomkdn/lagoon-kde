import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../code/catppuccin.js" as Catppuccin
import "../code/lyrics.js" as LyricsSource

// Synced lyrics: the line being sung, bright and centered, follows the music.
Item {
    id: lyrics

    property string artist
    property string title
    property real seconds
    property real position          // seconds
    property color accent
    property bool active: false     // fetched only when shown

    property var lines: []
    property bool synced: false
    property string state_: "idle"  // idle, loading, ready, none, error

    readonly property int current: {
        if (!synced) {
            return -1;
        }
        let index = -1;
        for (let i = 0; i < lines.length && lines[i].time <= position + 0.25; i++) {
            index = i;
        }
        return index;
    }

    // lrclib is often busy for a moment: asked again a little later each time
    property int retries: 0

    function load() {
        if (!active || !title) {
            return;
        }
        const track = title;
        state_ = "loading";
        lines = [];
        LyricsSource.fetch(artist, title, seconds, result => {
            if (track !== title) {
                return;
            }
            if (result.error && retries < 3) {
                retries++;
                retry.interval = retries * 4000;
                retry.restart();
                return;
            }
            if (result.synced) {
                lines = result.synced; synced = true; state_ = "ready";
            } else if (result.plain) {
                lines = result.plain; synced = false; state_ = "ready";
            } else {
                state_ = result.none ? "none" : "error";
            }
        });
    }

    Timer {
        id: retry
        onTriggered: lyrics.load()
    }

    onTitleChanged: {
        retries = 0;
        retry.stop();
        state_ = "idle";
        load();
    }
    onActiveChanged: {
        if (active && state_ !== "ready") {
            retries = 0;
            load();
        } else if (!active) {
            retry.stop();
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        visible: lyrics.state_ === "ready"
        model: lyrics.lines
        clip: true
        spacing: Kirigami.Units.smallSpacing * 2
        currentIndex: lyrics.current
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Kirigami.Units.longDuration
        preferredHighlightBegin: height * 0.38
        preferredHighlightEnd: height * 0.38
        highlightRangeMode: lyrics.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        interactive: !lyrics.synced
        header: Item { height: lyrics.synced ? 0 : Kirigami.Units.largeSpacing }

        delegate: PlasmaComponents3.Label {
            required property var modelData
            required property int index
            width: ListView.view.width
            text: modelData.text || "♪"
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
            font.weight: index === lyrics.current ? Font.Bold : Font.Normal
            color: index === lyrics.current ? lyrics.accent : Kirigami.Theme.textColor
            opacity: !lyrics.synced || index === lyrics.current ? 1 : 0.45
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
        }

    }

    // fade at the top and the bottom
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: Kirigami.Units.gridUnit * 2
        visible: list.visible
        gradient: Gradient {
            GradientStop { position: 0; color: Catppuccin.CRUST }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Kirigami.Units.gridUnit * 2
        visible: list.visible
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Catppuccin.CRUST }
        }
    }

    // made when needed: they are slow to make, which must not stop the card's opening
    Loader {
        anchors.centerIn: parent
        active: lyrics.state_ === "loading"
        sourceComponent: PlasmaComponents3.BusyIndicator { running: true }
    }

    Loader {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        active: lyrics.state_ === "none" || lyrics.state_ === "error"
        sourceComponent: Kirigami.PlaceholderMessage {
            icon.name: lyrics.state_ === "none" ? "view-media-lyrics" : "network-disconnect"
            text: lyrics.state_ === "none" ? i18n("No lyrics for this song") : i18n("Lyrics unavailable")
            explanation: lyrics.state_ === "error" ? i18n("lrclib.net is not answering. Close and open the lyrics to try again.") : ""
        }
    }
}
