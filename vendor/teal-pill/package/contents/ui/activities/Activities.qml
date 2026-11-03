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
// Each can be turned off. Volume and brightness are left to Plasma's own pop-ups.
//
// These come from Plasma's own modules, some of them private: a new Plasma may move them.
QtObject {
    id: activities

    // a passing event: { kind, icon, level (0..1, or -1), text }; null when none
    property var flash: null
    readonly property bool flashing: flash !== null

    readonly property int jobs: Plasmoid.configuration.showTransfers ? jobsModel.activeJobsCount : 0
    readonly property real jobsProgress: jobsModel.jobsPercentage / 100
    readonly property bool microphone: Plasmoid.configuration.showMicrophone && recordingStreams > 0
    property int recordingStreams: 0
    readonly property bool camera: Plasmoid.configuration.showCamera && sensorsNow.camera
    readonly property bool screen: Plasmoid.configuration.showScreenShare && sensorsNow.screen
    readonly property bool snapshot: Plasmoid.configuration.showSnapshot && startedFromSnapshot
    readonly property bool busy: jobs > 0 || dots.length > 0

    // the lasting ones, each a colored dot in Mocha
    readonly property var dots: {
        const list = [];
        if (microphone) {
            list.push({ color: Catppuccin.MOCHA.peach, icon: "audio-input-microphone" });
        }
        if (camera) {
            list.push({ color: Catppuccin.MOCHA.green, icon: "camera-web-symbolic" });
        }
        if (screen) {
            list.push({ color: Catppuccin.MOCHA.mauve, icon: "video-display-symbolic" });
        }
        if (snapshot) {
            list.push({ color: Catppuccin.MOCHA.yellow, icon: "drive-harddisk-symbolic" });
        }
        return list;
    }

    function show(kind, icon, level, text, duration = 1800) {
        flash = { kind: kind, icon: icon, level: level, text: text };
        flashTimer.interval = duration;
        flashTimer.restart();
    }

    property Timer flashTimer: Timer {
        onTriggered: activities.flash = null
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
                activities.show(pluggedIn ? "charging" : "battery",
                                pluggedIn ? "battery-full-charging" : "battery-full", percent / 100, percent + " %");
            }
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
            if (battery >= 0) {
                activities.show("bluetooth", icon, battery / 100, battery + " %");
            } else {
                activities.show("bluetooth", icon, -1, name);
            }
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
            switch (profile) {
            case "performance": activities.show("profile", "battery-profile-performance-symbolic", -1, i18n("Performance")); break;
            case "balanced": activities.show("profile", "speedometer-symbolic", -1, i18n("Balanced")); break;
            case "power-saver": activities.show("profile", "battery-profile-powersave-symbolic", -1, i18n("Power save")); break;
            }
        }
    }

    // --- a camera or the screen in use --------------------------------------------------------

    property var sensorsNow: ({ camera: false, screen: false })

    property Plasma5Support.DataSource sensors: Plasma5Support.DataSource {
        engine: "executable"
        interval: 3000
        connectedSources: Plasmoid.configuration.showCamera || Plasmoid.configuration.showScreenShare ? [Sensors.SENSORS_COMMAND] : []
        onNewData: (source, data) => activities.sensorsNow = Sensors.read(data.stdout)
    }

    // --- started from a snapshot, which a reboot would leave --------------------------------------

    property bool startedFromSnapshot: false

    function warnOfSnapshot() {
        if (snapshot && settled) {
            show("snapshot", "drive-harddisk-symbolic", -1, i18n("Started from a snapshot"), 6000);
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
        model: Plasmoid.configuration.showMicrophone ? activities.recordingModel : null
        delegate: QtObject {
            required property var model
            // not a level meter, like the one of Plasma's own volume popup
            readonly property bool recording: {
                const props = model.PulseObject?.properties ?? {};
                const binary = props["application.process.binary"] ?? "";
                return !(props["media.name"] ?? "").includes("Peak detect")
                    && !["plasmashell", "pavucontrol", "pavucontrol-qt", "kded6", "kmix"].includes(binary);
            }
            Component.onCompleted: if (recording) activities.recordingStreams++
            Component.onDestruction: if (recording) activities.recordingStreams--
        }
    }

    property Volume.SourceOutputModel recordingModel: Volume.SourceOutputModel {}
}
