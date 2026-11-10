import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// Where the card lives: a transparent overlay on the pill's screen, shown only while the card
// is open, so that it can come out of the pill without any window being resized.
Window {
    id: surface

    property bool open: false
    readonly property real progress: morph.progress
    readonly property bool pillHovered: morph.pillHovered

    // the morph waits for the overlay's first frame, or it would start unseen
    property bool waitingForFrame: false
    property bool wasActive: false

    readonly property Item pill: root.pillItem
    readonly property Item cover: root.pillCoverItem

    color: "transparent"
    // while the card folds back, clicks go through to the pill and the desktop
    flags: open ? Qt.FramelessWindowHint : Qt.FramelessWindowHint | Qt.WindowTransparentForInput

    LayerShell.Window.scope: "teal-pill"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

    // the pill and its cover on the overlay, leaving out the pill's own scale
    function measure() {
        const at = pill.parent.mapToGlobal(pill.x, pill.y);
        const x = at.x - pill.Screen.virtualX, y = at.y - pill.Screen.virtualY;
        const inPill = cover.mapToItem(pill, 0, 0);
        morph.pill = Qt.rect(x, y, pill.width, pill.height);
        morph.pillCover = Qt.rect(x + inPill.x, y + inPill.y, cover.width, cover.height);
    }

    // the pill narrows once the mouse is on the overlay
    Connections {
        target: surface.pill
        function onWidthChanged() {
            if (surface.visible) {
                surface.measure();
            }
        }
    }

    function edgeName() {
        switch (Plasmoid.location) {
        case PlasmaCore.Types.BottomEdge: return "bottom";
        case PlasmaCore.Types.LeftEdge: return "left";
        case PlasmaCore.Types.RightEdge: return "right";
        default: return "top";
        }
    }

    onOpenChanged: {
        if (open) {
            const home = Array.from(Qt.application.screens).find(s => s.name === pill.Screen.name);
            if (home && !visible) {
                screen = home;
            }
            morph.edge = edgeName();
            measure();
            if (morph.progress <= 0.001) {
                morph.anchor = morph.pill;
            }
            wasActive = active;
            if (visible) {
                // opened again while it was folding back: it is already on screen
                morph.open = true;
            } else {
                waitingForFrame = true;
                visible = true;
            }
        } else if (waitingForFrame) {
            // closed again before anything was drawn: no morph will come to hide it
            waitingForFrame = false;
            visible = false;
        } else {
            waitingForFrame = false;
            morph.open = false;
        }
    }

    onFrameSwapped: {
        if (waitingForFrame) {
            waitingForFrame = false;
            morph.open = true;
        }
    }

    // going to another window closes the card
    onActiveChanged: {
        if (active) {
            wasActive = true;
        } else if (wasActive && open) {
            open = false;
        }
    }

    Morph {
        id: morph
        anchors.fill: parent
        onDismissed: surface.open = false
        onSettled: surface.visible = false
    }
}
