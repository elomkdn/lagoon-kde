import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A small symbolic icon in one color: what is in use is told by its shape as well as its color.
Kirigami.Icon {
    id: sign

    Layout.preferredWidth: Kirigami.Units.iconSizes.small
    Layout.preferredHeight: Kirigami.Units.iconSizes.small
    isMask: true
    // the theme's icons take their color from the color scheme
    Kirigami.Theme.inherit: false
    Kirigami.Theme.textColor: sign.color
}
