/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Lagoon splash screen, based on the MacTahoe splash by Vince Liuice.
 * The CachyOS logo sits exactly where it is on the wallpaper; while the session
 * loads, its three bubbles float up from the C one after another.
 */

import QtQuick 2.5
import QtQuick.Window 2.5

Image {
    id: root
    source: background(width, height)
    fillMode: Image.PreserveAspectCrop

    // Same background as the desktop: the wallpaper (without its logo) in the size Plasma
    // would pick for this screen, so the waves line up too (plasma-workspace,
    // wallpapers/image/plugin/finder/packagefinder.cpp). Sizes are filled in by build.sh.
    readonly property var backgroundSizes: @BACKGROUND_SIZES@
    function background(w, h) {
        const tw = w * Screen.devicePixelRatio, th = h * Screen.devicePixelRatio
        const desired = th > 0 ? tw / th : 0
        let best = "", bestDistance = Infinity
        for (const size of backgroundSizes) {
            const [cw, ch] = size.split("x").map(Number)
            let delta = cw - tw
            delta = delta >= 0 ? delta : -delta * 2 // penalize scaling up
            const distance = Math.abs(cw / ch - desired) * 25000 + delta
            if (distance < bestDistance) {
                best = size
                bestDistance = distance
            }
        }
        return "images/background-" + best + ".png"
    }

    property int stage

    onStageChanged: {
        if (stage == 1) {
            introAnimation.running = true
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        Item {
            id: logo
            // same size and place as the logo on the wallpaper
            width: Math.min(root.width, root.height) * 0.26
            height: width
            anchors.centerIn: parent

            Image {
                anchors.fill: parent
                source: "images/logo-c.svg"
                sourceSize.width: width
                sourceSize.height: height
            }

            // The logo's bubbles, from the C outwards: centre and radius as
            // fractions of the logo size (computed from the CachyOS logo SVG).
            Repeater {
                model: [
                    { x: 0.9000, y: 0.6004, r: 0.0725 },
                    { x: 0.7143, y: 0.4478, r: 0.0551 },
                    { x: 0.7886, y: 0.2353, r: 0.0283 }
                ]
                Rectangle {
                    id: bubble
                    required property var modelData
                    required property int index

                    width: logo.width * modelData.r * 2
                    height: width
                    radius: width / 2
                    x: logo.width * modelData.x - width / 2
                    y: logo.height * modelData.y - height / 2
                    color: "#94e2d5"
                    antialiasing: true

                    // at rest the logo matches the wallpaper exactly; each bubble
                    // in turn swells and rises a little, then settles back
                    property real lift: 0
                    transform: Translate { y: -bubble.lift }

                    // KSplash moves to stage 5 once the desktop is up and closes shortly
                    // after: the bubbles then finish their cycle and stay at rest, so the
                    // logo is already identical to the wallpaper when the desktop fades in.
                    SequentialAnimation {
                        running: root.stage < 5
                        alwaysRunToEnd: true
                        loops: Animation.Infinite
                        PauseAnimation { duration: bubble.index * 220 }
                        ParallelAnimation {
                            NumberAnimation { target: bubble; property: "scale"; from: 1; to: 1.35; duration: 320; easing.type: Easing.OutQuad }
                            NumberAnimation { target: bubble; property: "lift"; from: 0; to: logo.width * 0.025; duration: 320; easing.type: Easing.OutQuad }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: bubble; property: "scale"; from: 1.35; to: 1; duration: 480; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: bubble; property: "lift"; from: logo.width * 0.025; to: 0; duration: 480; easing.type: Easing.InOutQuad }
                        }
                        PauseAnimation { duration: (2 - bubble.index) * 220 + 500 }
                    }
                }
            }
        }
    }

    OpacityAnimator {
        id: introAnimation
        running: false
        target: content
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.InOutQuad
    }
}
