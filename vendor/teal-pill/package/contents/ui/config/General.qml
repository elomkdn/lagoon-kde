import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.private.mpris as Mpris

KCM.SimpleKCM {
    id: page

    property string cfg_players
    property alias cfg_showWhenNoMedia: showWhenNoMedia.checked
    property alias cfg_alwaysShowTitle: alwaysShowTitle.checked
    property alias cfg_titleWidth: titleWidth.value
    property alias cfg_tintFromCover: tintFromCover.checked
    property alias cfg_showCharger: showCharger.checked
    property alias cfg_showTransfers: showTransfers.checked
    property alias cfg_showMicrophone: showMicrophone.checked
    property alias cfg_showBluetooth: showBluetooth.checked
    property alias cfg_showPowerProfile: showPowerProfile.checked
    property alias cfg_showCamera: showCamera.checked
    property alias cfg_showScreenShare: showScreenShare.checked
    property alias cfg_showSnapshot: showSnapshot.checked

    // the players followed, by the names they give themselves; none: the one playing
    readonly property var chosen: cfg_players.split(",").map(x => x.trim()).filter(x => x)
    // the players open right now: [{ identity, iconName }]
    property var open: []
    readonly property var listed: {
        const names = open.map(p => p.identity);
        return open.concat(chosen.filter(n => !names.includes(n)).map(n => ({ identity: n, iconName: "", closed: true })));
    }

    function choose(name, on) {
        const names = chosen.filter(n => n !== name);
        if (on) {
            names.push(name);
        }
        cfg_players = names.join(",");
    }

    function listOpen() {
        const role = Qt.UserRole + 1;
        const list = [];
        for (let i = 1; i < mpris.rowCount(); i++) {
            const player = mpris.data(mpris.index(i, 0), role);
            if (player && !list.some(p => p.identity === player.identity)) {
                list.push({ identity: player.identity, iconName: player.desktopEntry || player.iconName || "view-media-track" });
            }
        }
        open = list;
    }

    Mpris.Mpris2Model {
        id: mpris
        onRowsInserted: page.listOpen()
        onRowsRemoved: page.listOpen()
    }

    Component.onCompleted: listOpen()

    Kirigami.FormLayout {
        ColumnLayout {
            Kirigami.FormData.label: i18n("Players:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            spacing: Kirigami.Units.smallSpacing

            QQC2.RadioButton {
                text: i18n("The one playing")
                checked: page.chosen.length === 0
                onToggled: if (checked) page.cfg_players = ""
            }
            QQC2.RadioButton {
                id: only
                text: i18n("Only these:")
                checked: page.chosen.length > 0
                enabled: page.listed.length > 0
                onToggled: if (checked && page.chosen.length === 0) page.cfg_players = page.listed[0].identity
            }
            Repeater {
                model: page.listed

                RowLayout {
                    required property var modelData
                    Layout.leftMargin: Kirigami.Units.gridUnit
                    enabled: only.checked

                    QQC2.CheckBox {
                        checked: page.chosen.includes(modelData.identity)
                        onToggled: page.choose(modelData.identity, checked)
                    }
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        source: modelData.iconName || "view-media-track"
                        opacity: modelData.closed ? 0.5 : 1
                    }
                    QQC2.Label {
                        text: modelData.closed ? i18n("%1 (not open)", modelData.identity) : modelData.identity
                        opacity: modelData.closed ? 0.6 : 1
                    }
                }
            }
            QQC2.Label {
                visible: page.listed.length === 0
                text: i18n("Open a player to choose it here.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        QQC2.CheckBox {
            id: showWhenNoMedia
            Kirigami.FormData.label: i18n("Panel:")
            text: i18n("Show when nothing plays")
        }
        QQC2.CheckBox {
            id: alwaysShowTitle
            text: i18n("Always show the title, not only on hover")
        }
        QQC2.SpinBox {
            id: titleWidth
            Kirigami.FormData.label: i18n("Title width:")
            from: 80
            to: 600
            stepSize: 10
            textFromValue: value => i18n("%1 px", value)
            valueFromText: text => parseInt(text)
        }

        QQC2.CheckBox {
            id: tintFromCover
            Kirigami.FormData.label: i18n("Colors:")
            text: i18n("Take the accent from the cover")
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Lyrics:")
            text: i18n("From lrclib.net, a free database: the title and artist of the song you open them for are sent to it.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showCharger
            Kirigami.FormData.label: i18n("In the island:")
            text: i18n("Charger plugged in or out")
        }
        QQC2.CheckBox {
            id: showTransfers
            text: i18n("Copies and downloads in progress")
        }
        QQC2.CheckBox {
            id: showMicrophone
            text: i18n("A dot while a microphone records")
        }
        QQC2.CheckBox {
            id: showCamera
            text: i18n("A dot while a camera is in use")
        }
        QQC2.CheckBox {
            id: showScreenShare
            text: i18n("A dot while the screen is shared or recorded")
        }
        QQC2.CheckBox {
            id: showBluetooth
            text: i18n("Headphones connecting, with their battery")
        }
        QQC2.CheckBox {
            id: showPowerProfile
            text: i18n("Power profile changing")
        }
        QQC2.CheckBox {
            id: showSnapshot
            text: i18n("A warning when started from a snapshot")
        }
    }
}
