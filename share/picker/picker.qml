// Port of Omarchy's image picker (shell/plugins/image-picker/ImagePicker.qml)
// to plain QtQuick, with the Vantablack colours.
// Usage: qml6 picker.qml -- <dir> <current-image-or-none>
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Shapes
import Qt.labs.folderlistmodel

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Wallpaper Picker"

    readonly property var args: Qt.application.arguments
    readonly property string folder: args[args.length - 2]
    readonly property string currentImage: args[args.length - 1]

    // Vantablack (Omarchy theme) colours
    property color scrim: Qt.rgba(0, 0, 0, 0.5)
    property color selectedBorder: "#8d8d8d"
    property color unselectedBorder: Qt.rgba(1, 1, 1, 0.28)

    // Omarchy sizes
    property int expandedWidth: 768
    property int expandedHeight: 475
    property int sliceWidth: 108
    property int sliceHeight: 432
    property int sliceSpacing: -30
    property int skewOffset: 28

    property int selectedIndex: 0
    property bool initialised: false

    function pick(path) { console.log("PICK " + path); Qt.quit() }
    function cancel() { Qt.quit() }
    function selectAdjacent(d) {
        const n = files.count; if (n === 0) return
        selectedIndex = (selectedIndex + d + n) % n
    }
    function applySelected() { if (files.count > 0) pick(files.get(selectedIndex, "filePath")) }

    FolderListModel {
        id: files
        folder: "file://" + root.folder
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready && !root.initialised) {
            for (let i = 0; i < count; i++)
                if (get(i, "filePath") === root.currentImage) { root.selectedIndex = i; break }
            root.initialised = true
        }
    }

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.cancel() }

    Item {
        id: card
        visible: root.initialised && files.count > 0
        width: Math.min(parent.width - 80, root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing) + 40)
        height: root.expandedHeight + 60
        anchors.centerIn: parent
        MouseArea { anchors.fill: parent; onClicked: {} }

        Item {
            id: carousel
            anchors.top: parent.top
            anchors.topMargin: 30
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.expandedWidth + 13 * (root.sliceWidth + root.sliceSpacing)
            focus: true

            readonly property real itemStep: root.sliceWidth + root.sliceSpacing
            readonly property real previewX: (width - root.expandedWidth) / 2

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.applySelected(); event.accepted = true }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab
                         || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) { root.selectAdjacent(-1); event.accepted = true }
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { root.selectAdjacent(1); event.accepted = true }
            }
            Component.onCompleted: forceActiveFocus()

            Repeater {
                model: files
                delegate: Item {
                    id: item
                    required property int index
                    required property string filePath

                    // shortest signed distance around the ring (wrap-around carousel)
                    readonly property int relativeIndex: {
                        const n = files.count
                        let r = index - root.selectedIndex
                        if (r > n / 2) r -= n
                        if (r < -n / 2) r += n
                        return r
                    }
                    readonly property bool selected: index === root.selectedIndex
                    readonly property bool nearby: Math.abs(relativeIndex) <= 16
                    property bool sourceActivated: nearby
                    onNearbyChanged: if (nearby) sourceActivated = true

                    visible: nearby
                    x: selected ? carousel.previewX
                       : (relativeIndex < 0 ? carousel.previewX + relativeIndex * carousel.itemStep
                                            : carousel.previewX + root.expandedWidth + root.sliceSpacing + (relativeIndex - 1) * carousel.itemStep)
                    width: selected ? root.expandedWidth : root.sliceWidth
                    height: selected ? root.expandedHeight : root.sliceHeight
                    y: selected ? 0 : (root.expandedHeight - root.sliceHeight) / 2
                    z: selected ? 100 : 50 - Math.min(Math.abs(relativeIndex), 40)

                    readonly property real skAbs: Math.abs(root.skewOffset)
                    readonly property real topLeft: root.skewOffset >= 0 ? skAbs : 0
                    readonly property real topRight: root.skewOffset >= 0 ? width : width - skAbs
                    readonly property real bottomRight: root.skewOffset >= 0 ? width - skAbs : width
                    readonly property real bottomLeft: root.skewOffset >= 0 ? 0 : skAbs

                    Item {
                        id: maskShape
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Shape {
                            anchors.fill: parent
                            antialiasing: true
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "white"; strokeColor: "transparent"
                                startX: item.topLeft; startY: 0
                                PathLine { x: item.topRight; y: 0 }
                                PathLine { x: item.bottomRight; y: item.height }
                                PathLine { x: item.bottomLeft; y: item.height }
                                PathLine { x: item.topLeft; y: 0 }
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: maskShape
                            maskThresholdMin: 0.3
                            maskSpreadAtMin: 0.3
                        }
                        Image {
                            anchors.fill: parent
                            source: item.sourceActivated ? "file://" + item.filePath : ""
                            sourceSize.width: 960
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, item.selected ? 0 : 0.42)
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: item.selected ? root.selectedBorder : root.unselectedBorder
                            strokeWidth: item.selected ? 3 : 1
                            startX: item.topLeft; startY: 0
                            PathLine { x: item.topRight; y: 0 }
                            PathLine { x: item.bottomRight; y: item.height }
                            PathLine { x: item.bottomLeft; y: item.height }
                            PathLine { x: item.topLeft; y: 0 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: item.selected ? root.applySelected() : (root.selectedIndex = item.index)
                    }
                }
            }
        }
    }
}
