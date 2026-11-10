import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import org.kde.ksvg as KSvg
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "code/catppuccin.js" as Catppuccin

// The card in Plasma's own popup, where the overlay is not available: away from a panel, or
// in a session without layer-shell. Its content unfolds from the top when it opens.
Item {
    id: full

    // a card fitted to its content: Plasma would otherwise keep a size the popup had before
    Layout.preferredWidth: Kirigami.Units.gridUnit * 19
    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.maximumWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: card.implicitHeight
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumHeight: Layout.preferredHeight

    // Mocha's darkest color, up to the popup's frame, leaving its line: it takes the frame's
    // shape from the theme's own picture, whatever its corners
    Item {
        id: backdrop
        readonly property var popup: full.Window.window
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

    // the content unfolds from the top center
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
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; from: 0.94; to: 1; duration: Kirigami.Units.longDuration; easing.type: Easing.OutBack }
        NumberAnimation { target: shift; property: "y"; from: -Kirigami.Units.gridUnit; to: 0; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
    }

    Card {
        id: card
        anchors.fill: parent
        transformOrigin: Item.Top
        transform: Translate { id: shift }
    }
}
