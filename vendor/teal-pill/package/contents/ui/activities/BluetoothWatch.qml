import QtQuick
import org.kde.bluezqt as BluezQt

// Headphones that just connected, with their battery when they tell it. Apart, and loaded by a
// Loader: without Bluez-Qt, only this is missing from the island.
Instantiator {
    id: watch

    // battery: 0 to 100, or -1 when they do not tell it
    signal headphones(string name, string icon, int battery)

    model: BluezQt.DevicesModel {}

    delegate: QtObject {
        required property var model

        readonly property bool connected: model.Connected
        // Headset, Headphones and AudioVideo in Device::Type
        readonly property bool audio: [4, 5, 6].includes(model.Type)
        readonly property url icon: Qt.resolvedUrl("../../icons/" + (model.Type === 4 ? "headset" : "headphones") + ".svg")

        onConnectedChanged: {
            if (connected && audio) {
                settle.restart();
            } else {
                settle.stop();
            }
        }

        // the battery comes a moment after the connection
        property Timer settle: Timer {
            interval: 1500
            onTriggered: watch.headphones(model.Name, icon, model.Device?.battery?.percentage ?? -1)
        }
    }
}
