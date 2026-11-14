import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.notificationmanager as NotificationManager
import "../code/catppuccin.js" as Catppuccin
import "../code/sensors.js" as Sensors

// What else the island shows, besides music: a passing
// event (the charger, headphones, the power profile) takes the pill for a moment, and lasting
// ones (transfers, a microphone, a camera, a shared screen, a snapshot) sit beside the music.
// The microphone, the camera and the screen are always told, and by whom; the others can be
// turned off. Volume and brightness are left to Plasma's own pop-ups.
//
// These come from Plasma's own modules, some of them private: a new Plasma may move them.
QtObject {
    id: activities

    // a passing event: { kind, icon, level (0..1, or -1), text }; null when none
    property var flash: null
    readonly property bool flashing: flash !== null

    readonly property int jobs: Plasmoid.configuration.showTransfers ? jobsModel.activeJobsCount : 0
    readonly property real jobsProgress: jobsModel.jobsPercentage / 100
    // the apps recording from a microphone, one entry per stream
    property var recordingApps: []
    readonly property bool snapshot: Plasmoid.configuration.showSnapshot && startedFromSnapshot
    readonly property bool busy: jobs > 0 || inUse.length > 0 || snapshot

    function names(apps) {
        return Array.from(new Set(apps.filter(x => x))).join(", ");
    }

    // Teal Pill's own icons (contents/icons): one drawing for every theme, solid like the
    // system's tray icons, so the signs and the passing events look alike
    function icon(name) {
        return Qt.resolvedUrl("../../icons/" + name + ".svg");
    }

    // what is being used: its sign in Mocha, and a sentence that says who
    readonly property var inUse: {
        const list = [];
        if (recordingApps.length > 0) {
            const who = names(recordingApps);
            list.push({
                color: Catppuccin.MOCHA.peach,
                icon: activities.icon("microphone"),
                label: who ? i18n("%1 is using the microphone", who) : i18n("The microphone is in use"),
            });
        }
        if (sensorsNow.camera) {
            const who = names(sensorsNow.cameraBy);
            list.push({
                color: Catppuccin.MOCHA.green,
                icon: activities.icon("camera"),
                label: who ? i18n("%1 is using the camera", who) : i18n("The camera is in use"),
            });
        }
        if (sensorsNow.screen) {
            const who = names(sensorsNow.screenBy);
            list.push({
                color: Catppuccin.MOCHA.mauve,
                icon: activities.icon("screen"),
                label: who ? i18n("%1 is sharing the screen", who) : i18n("The screen is being shared"),
            });
        }
        return list;
    }

    // News from a source (the charger, headphones, the power profile, the snapshot): what() makes
    // the event as things stand when its turn comes, or null when it no longer applies (the
    // setting was turned off meanwhile). One piece of news per source: a newer one replaces it,
    // on show or waiting.
    property var waiting: []
    // the news on show: its source, and when it started and ends (ms)
    property var current: null
    // once another source waits, the event on show gives way after this long
    readonly property int glance: 1200

    function show(source, what, duration = 1800) {
        const news = { source: source, what: what, duration: duration };
        if (current === null || current.source === source) {
            begin(news);
            return;
        }
        const turn = waiting.findIndex(x => x.source === source);
        waiting = turn < 0 ? waiting.concat([news]) : waiting.map((x, i) => i === turn ? news : x);
        giveWay();
    }

    function begin(news) {
        const event = news.what();
        if (!event) {
            next();
            return;
        }
        const now = Date.now();
        current = { source: news.source, since: now, ends: now + news.duration };
        flash = event;
        flashTimer.interval = news.duration;
        flashTimer.restart();
        if (waiting.length > 0) {
            giveWay();
        }
    }

    function giveWay() {
        const ends = Math.min(current.ends, current.since + glance);
        if (ends < current.ends) {
            current.ends = ends;
            flashTimer.interval = Math.max(1, ends - Date.now());
            flashTimer.restart();
        }
    }

    function next() {
        if (waiting.length > 0) {
            const news = waiting[0];
            waiting = waiting.slice(1);
            begin(news);
        } else {
            current = null;
            flash = null;
        }
    }

    property Timer flashTimer: Timer {
        onTriggered: activities.next()
    }

    // nothing shows while the session starts: headphones reconnect, services come up. And each
    // source's first value, however late it comes, is where it stands, not a change.
    property bool settled: false
    property Timer settleTimer: Timer {
        interval: 10000
        running: true
        onTriggered: {
            activities.settled = true;
            activities.warnOfSnapshot();
        }
    }

    // --- charger ------------------------------------------------------------------------------

    property Plasma5Support.DataSource power: Plasma5Support.DataSource {
        engine: "powermanagement"
        connectedSources: Plasmoid.configuration.showCharger ? ["AC Adapter", "Battery"] : []
        readonly property var pluggedIn: data["AC Adapter"]?.["Plugged in"]
        property bool pluggedInKnown: false
        readonly property int percent: data["Battery"]?.["Percent"] ?? 0
        readonly property bool hasBattery: data["Battery"]?.["Has Battery"] ?? percent > 0
        onPluggedInChanged: {
            if (pluggedIn === undefined) {
                return;
            }
            const first = !pluggedInKnown;
            pluggedInKnown = true;
            if (!first && activities.settled && hasBattery) {
                activities.show("battery", () => activities.power.event());
            }
        }
        // plugged in or not, and the percentage, as they are now
        function event() {
            if (pluggedIn === undefined) {
                return null;
            }
            return {
                kind: pluggedIn ? "charging" : "battery",
                icon: activities.icon(pluggedIn ? "battery-charging" : "battery"),
                level: percent / 100,
                text: percent + " %",
            };
        }
    }

    // --- headphones connecting -----------------------------------------------------------------

    property Loader bluetooth: Loader {
        active: Plasmoid.configuration.showBluetooth
        source: "BluetoothWatch.qml"
    }
    property Connections bluetoothEvents: Connections {
        target: activities.bluetooth.item
        function onHeadphones(name, icon, battery) {
            if (!activities.settled) {
                return;
            }
            activities.show("bluetooth", () => !activities.bluetooth.item ? null : {
                kind: "bluetooth",
                icon: icon,
                level: battery >= 0 ? battery / 100 : -1,
                text: battery >= 0 ? battery + " %" : name,
            });
        }
    }

    // --- the power profile --------------------------------------------------------------------

    property Loader powerProfile: Loader {
        active: Plasmoid.configuration.showPowerProfile
        source: "PowerProfileWatch.qml"
    }
    property string knownProfile: ""
    property Connections powerProfileEvents: Connections {
        target: activities.powerProfile.item
        function onChanged(profile) {
            if (!profile || profile === activities.knownProfile) {
                return;
            }
            const first = !activities.knownProfile;
            activities.knownProfile = profile;
            if (first || !activities.settled) {
                return;
            }
            const shown = {
                "performance": ["performance", i18n("Performance")],
                "balanced": ["balanced", i18n("Balanced")],
                "power-saver": ["powersave", i18n("Power save")],
            }[profile];
            if (shown) {
                activities.show("profile", () => !activities.powerProfile.item ? null : {
                    kind: "profile",
                    icon: activities.icon(shown[0]),
                    level: -1,
                    text: shown[1],
                });
            }
        }
    }

    // --- a camera or the screen in use --------------------------------------------------------

    property var sensorsNow: ({ camera: false, screen: false, cameraBy: [], screenBy: [] })

    property Plasma5Support.DataSource sensors: Plasma5Support.DataSource {
        engine: "executable"
        interval: 3000
        connectedSources: [Sensors.SENSORS_COMMAND]
        onNewData: (source, data) => activities.sensorsNow = Sensors.read(data.stdout)
    }

    // --- started from a snapshot, which a reboot would leave --------------------------------------

    property bool startedFromSnapshot: false

    function warnOfSnapshot() {
        if (snapshot && settled) {
            show("snapshot", () => !activities.snapshot ? null : {
                kind: "snapshot",
                icon: activities.icon("snapshot"),
                level: -1,
                text: i18n("Started from a snapshot"),
            }, 6000);
        }
    }

    property Plasma5Support.DataSource rootMount: Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: ["findmnt -no FSROOT /"]
        onNewData: (source, data) => {
            activities.rootMount.disconnectSource(source);
            activities.startedFromSnapshot = data.stdout.includes(".snapshots");
            activities.warnOfSnapshot();
        }
    }

    // --- transfers: copies, downloads, KDE Connect…, as Plasma's notifications follow them ----

    property NotificationManager.Notifications jobsModel: NotificationManager.Notifications {
        showNotifications: false
        showJobs: true
        showExpired: false
    }

    // --- the microphone, while an app records -------------------------------------------------

    property Instantiator recording: Instantiator {
        model: activities.recordingModel
        delegate: QtObject {
            required property var model
            readonly property var props: model.PulseObject?.properties ?? {}
            readonly property string binary: props["application.process.binary"] ?? ""
            readonly property string app: props["application.name"] ?? binary
            // not a level meter, like the one of Plasma's own volume popup
            readonly property bool recording: !(props["media.name"] ?? "").includes("Peak detect")
                && !["plasmashell", "pavucontrol", "pavucontrol-qt", "kded6", "kmix"].includes(binary)
            // the name it was counted under, whatever its properties become
            property string counted
            property bool isCounted: false
            Component.onCompleted: {
                if (recording) {
                    counted = app;
                    isCounted = true;
                    activities.recordingApps = activities.recordingApps.concat([counted]);
                }
            }
            Component.onDestruction: {
                if (isCounted) {
                    const apps = activities.recordingApps.slice();
                    apps.splice(apps.indexOf(counted), 1);
                    activities.recordingApps = apps;
                }
            }
        }
    }

    property Volume.SourceOutputModel recordingModel: Volume.SourceOutputModel {}
}
