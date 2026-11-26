import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    TaskManager.VirtualDesktopInfo { id: vdi }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: function(source) { disconnectSource(source) }
    }

    function switchTo(index) {
        exec.connectSource("qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Switch to Desktop " + (index + 1) + "'")
    }

    fullRepresentation: MouseArea {
        Layout.preferredWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumWidth: Layout.preferredWidth
        Layout.fillHeight: true
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) {
            var cur = vdi.desktopIds.indexOf(vdi.currentDesktop)
            var n = vdi.numberOfDesktops
            if (wheel.angleDelta.y < 0) root.switchTo((cur + 1) % n)
            else root.switchTo((cur - 1 + n) % n)
        }

        RowLayout {
            id: row
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            Repeater {
                model: vdi.desktopIds
                delegate: MouseArea {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool active: vdi.currentDesktop === modelData
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                    Layout.fillHeight: true
                    hoverEnabled: true
                    onClicked: root.switchTo(index)

                    TaskManager.TasksModel {
                        id: tasks
                        filterByVirtualDesktop: true
                        virtualDesktop: cell.modelData
                        filterByActivity: true
                        activity: activityInfo.currentActivity
                        groupMode: TaskManager.TasksModel.GroupDisabled
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.active ? "󱓻" : String(cell.index + 1)
                        font.family: "JetBrainsMonoNL Nerd Font"
                        font.pixelSize: Kirigami.Units.gridUnit * 0.75
                        color: Kirigami.Theme.textColor
                        opacity: cell.active || tasks.count > 0 ? 1.0 : (cell.containsMouse ? 0.8 : 0.45)
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }
            }
        }
    }

    TaskManager.ActivityInfo { id: activityInfo }
}
