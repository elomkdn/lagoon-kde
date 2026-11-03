import QtQuick
import org.kde.kirigami as Kirigami

// The cover, rounded, with a soft shadow; a music note on a tinted square without one.
Item {
    id: cover

    property string source
    property real radius: Kirigami.Units.cornerRadius
    property color accent
    property real shadowSize: 0

    readonly property bool loaded: image.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: cover.radius
        visible: !cover.loaded
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(cover.accent, 0.30) }
            GradientStop { position: 1; color: Qt.alpha(cover.accent, 0.12) }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.42)
            height: width
            source: "view-media-track"
            isMask: true
            color: cover.accent
        }
    }

    Kirigami.ShadowedImage {
        id: image
        anchors.fill: parent
        visible: cover.loaded
        source: cover.source
        radius: cover.radius
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // one size whatever the item's: a change of size would restart a download
        sourceSize.width: 512
        sourceSize.height: 512
        mipmap: true
        shadow.size: cover.shadowSize
        shadow.yOffset: cover.shadowSize / 4
        shadow.color: Qt.rgba(0, 0, 0, 0.45)
    }
}
