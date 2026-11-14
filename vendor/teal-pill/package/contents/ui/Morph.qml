import QtQuick
import org.kde.kirigami as Kirigami
import "components"
import "code/catppuccin.js" as Catppuccin
import "code/numbers.js" as Numbers

// The card coming out of the pill: a shape in the pill's crust that buds from its edge and opens
// just beyond it, leaving the pill in place to fold it back. A spring drives it, so it can turn
// around at any moment. The cover travels on its own, from the pill to the card and back.
Item {
    id: morph

    property bool open: false
    // where the pill and its cover are, in this item's coordinates
    property rect pill
    property rect pillCover
    // where the pill was when the card opened: the card stays put while the pill narrows
    property rect anchor
    property string edge: "top"

    readonly property bool pillHovered: pillZone.containsMouse

    signal dismissed()
    signal settled()

    // Plasma's "no animations" setting
    readonly property bool animated: Kirigami.Units.longDuration > 0

    property real progress: open ? 1 : 0
    Behavior on progress {
        enabled: morph.animated
        SpringAnimation { spring: 4; damping: 0.33; epsilon: 0.002 }
    }
    onProgressChanged: if (!open && progress <= 0.001) settled()

    readonly property real shown: Math.max(0, progress)
    function mix(from, to) { return from + (to - from) * Math.max(0, progress); }

    readonly property real screenGap: Kirigami.Units.smallSpacing * 2
    readonly property real pillGap: Kirigami.Units.smallSpacing * 2
    readonly property real cardWidth: Kirigami.Units.gridUnit * 19
    readonly property real cardRadius: Kirigami.Units.gridUnit
    // the lyrics opening: only the shape's height follows, no window is resized
    property real cardHeight: card.implicitHeight
    Behavior on cardHeight {
        enabled: morph.animated && morph.progress > 0.9
        SpringAnimation { spring: 5; damping: 0.5; epsilon: 0.25 }
    }

    readonly property real cardX: edge === "left" ? anchor.x + anchor.width + pillGap
        : edge === "right" ? anchor.x - pillGap - cardWidth
        : Numbers.clamp(anchor.x + (anchor.width - cardWidth) / 2, screenGap, width - cardWidth - screenGap)
    readonly property real cardY: edge === "top" ? anchor.y + anchor.height + pillGap
        : edge === "bottom" ? anchor.y - pillGap - cardHeight
        : Numbers.clamp(anchor.y + (anchor.height - cardHeight) / 2, screenGap, height - cardHeight - screenGap)

    // the side the card comes from: x and y, each -1, 0 or 1
    readonly property point towardPill: Qt.point(edge === "left" ? -1 : edge === "right" ? 1 : 0,
                                                 edge === "top" ? -1 : edge === "bottom" ? 1 : 0)

    // the shape at its start: a thin bud against the pill's edge, on the card's side
    readonly property real budThickness: Kirigami.Units.smallSpacing * 2
    readonly property rect bud: {
        const across = 0.7;
        if (edge === "left" || edge === "right") {
            return Qt.rect(edge === "left" ? pill.x + pill.width - 1 : pill.x + 1 - budThickness,
                           pill.y + pill.height * (1 - across) / 2, budThickness, pill.height * across);
        }
        return Qt.rect(pill.x + pill.width * (1 - across) / 2,
                       edge === "top" ? pill.y + pill.height - 1 : pill.y + 1 - budThickness,
                       pill.width * across, budThickness);
    }

    focus: true
    Keys.onEscapePressed: dismissed()

    // a click anywhere else closes the card
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: morph.dismissed()
    }

    // the pill, under this overlay: it still lights up, and a click there folds the card back
    MouseArea {
        id: pillZone
        x: morph.pill.x
        y: morph.pill.y
        width: morph.pill.width
        height: morph.pill.height
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPressed: morph.dismissed()
    }

    Kirigami.ShadowedRectangle {
        id: shape
        x: morph.mix(morph.bud.x, morph.cardX)
        y: morph.mix(morph.bud.y, morph.cardY)
        width: morph.mix(morph.bud.width, morph.cardWidth)
        height: morph.mix(morph.bud.height, morph.cardHeight)
        radius: Math.min(Math.min(width, height) / 2, morph.cardRadius)
        color: Catppuccin.CRUST
        opacity: Math.min(1, morph.shown / 0.12)
        border.width: 1
        border.color: Qt.alpha(Catppuccin.TEXT, 0.08)
        shadow.size: Kirigami.Units.gridUnit * 1.5
        shadow.yOffset: Kirigami.Units.smallSpacing
        shadow.color: Qt.rgba(0, 0, 0, 0.5)

        // clicks on the card stay on the card
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            anchors.fill: parent
            clip: true

            // the content arrives from the pill's side and settles as the shape opens
            Card {
                id: card
                readonly property real away: Kirigami.Units.gridUnit * (1 - Math.min(1, morph.shown))
                x: morph.cardX - shape.x + morph.towardPill.x * away
                y: morph.cardY - shape.y + morph.towardPill.y * away
                width: morph.cardWidth
                height: implicitHeight
                coverHidden: root.hasMedia
                opacity: Math.max(0, (morph.shown - 0.4) / 0.6)
            }
        }
    }

    Cover {
        visible: root.hasMedia
        x: morph.mix(morph.pillCover.x, morph.cardX + card.margin)
        y: morph.mix(morph.pillCover.y, morph.cardY + card.margin)
        width: morph.mix(morph.pillCover.width, card.coverSize)
        height: morph.mix(morph.pillCover.height, card.coverSize)
        radius: morph.mix(morph.pillCover.width / 2, card.coverRadius)
        shadowSize: morph.mix(0, card.coverShadow)
        // whole by the time the pill's own cover is hidden
        opacity: Math.min(1, morph.shown / 0.02)
        source: player.artUrl
        accent: root.accent
    }
}
