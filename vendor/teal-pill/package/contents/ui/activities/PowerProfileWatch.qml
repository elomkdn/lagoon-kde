import QtQuick
import org.kde.plasma.private.batterymonitor as BatteryMonitor

// The power profile, which CachyOS's game-performance holds on performance during a game.
// Apart, and loaded by a Loader: this is a private module of Plasma, a new one may move it.
QtObject {
    id: watch

    signal changed(string profile)

    property BatteryMonitor.PowerProfilesControl control: BatteryMonitor.PowerProfilesControl {
        onActiveProfileChanged: watch.changed(activeProfile)
    }
}
