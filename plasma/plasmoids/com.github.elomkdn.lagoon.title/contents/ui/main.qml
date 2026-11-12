// Lagoon Title: the name of the active app, in bold, before the global menu. Its window's
// title is in the tooltip. With no active window (the desktop), it takes no room.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    property string appName: ""
    property string windowTitle: ""
    // an app without a name (no desktop file) shows its window's title instead
    readonly property string shown: appName !== "" ? appName : windowTitle

    preferredRepresentation: fullRepresentation
    Plasmoid.status: shown !== "" ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus

    toolTipMainText: appName !== "" && windowTitle !== appName ? windowTitle : ""
    toolTipSubText: ""

    // every window, on every desktop and screen: only the active one matters
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortDisabled
    }

    function refresh() {
        const index = tasks.activeTask;
        if (!index || index.row < 0) {  // no active window: the desktop has the focus
            appName = "";
            windowTitle = "";
            return;
        }
        appName = tasks.data(index, TaskManager.AbstractTasksModel.AppName) || "";
        windowTitle = tasks.data(index, Qt.DisplayRole) || "";
    }

    Connections {
        target: tasks
        function onActiveTaskChanged() { root.refresh(); }
        // a window renamed, or an app that sets its name late
        function onDataChanged() { root.refresh(); }
        function onCountChanged() { root.refresh(); }
    }

    Component.onCompleted: refresh()

    fullRepresentation: Item {
        readonly property real padding: Kirigami.Units.smallSpacing * 2
        readonly property real wanted: root.shown !== ""
            ? Math.min(label.implicitWidth, Kirigami.Units.gridUnit * 14) + padding * 2 : 0

        Layout.preferredWidth: wanted
        Layout.minimumWidth: wanted
        Layout.maximumWidth: wanted
        Layout.fillHeight: true

        PlasmaComponents.Label {
            id: label
            anchors.fill: parent
            anchors.leftMargin: parent.padding
            anchors.rightMargin: parent.padding
            visible: root.shown !== ""
            text: root.shown
            textFormat: Text.PlainText
            font.weight: Font.Bold
            elide: Text.ElideRight
            maximumLineCount: 1
            verticalAlignment: Text.AlignVCenter
        }
    }
}
