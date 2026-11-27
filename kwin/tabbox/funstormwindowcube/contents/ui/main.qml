/*
    Window Cube: a KWin window switcher (Alt+Tab) that shows the windows as faces of a 3D cube.
    Geometry and camera follow KDE's Cube effect (Vlad Zahorodnii, GPL-2.0-only OR GPL-3.0-only);
    the switcher plumbing follows KDE's Cover Switch (Ismael Asensio, GPL-2.0-or-later).
*/

import QtQuick
import QtQuick.Window
import QtQuick3D
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
    id: tabBox
    currentIndex: cubeView ? cubeView.currentIndex : -1

    Window {
        id: window

        x: tabBox.screenGeometry.x
        y: tabBox.screenGeometry.y
        width: tabBox.screenGeometry.width
        height: tabBox.screenGeometry.height
        flags: Qt.ToolTip | Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        visibility: Window.FullScreen
        // Workaround QTBUG-35244. Do not directly assign here to avoid warning
        visible: true
        color: "transparent"

        KWin.DesktopBackground {
            activity: KWin.Workspace.currentActivity
            desktop: KWin.Workspace.currentVirtualDesktop
            outputName: window.screen.name
        }
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.8
        }

        // One face: just the window at its own size (never scaled up) and its title, no background
        component FaceView: Item {
            id: fv
            property var entry: null
            property real maxW: 800
            property real maxH: 600
            readonly property real titleH: 64

            width: Math.max(thumb.width, 320)
            height: thumb.height + titleH

            KWin.WindowThumbnail {
                id: thumb
                visible: fv.entry !== null
                wId: fv.entry ? fv.entry.wid : ""
                readonly property real fit: (implicitWidth > 0 && implicitHeight > 0)
                    ? Math.min(1, fv.maxW / implicitWidth, fv.maxH / implicitHeight) : 1
                width: Math.round(implicitWidth * fit)
                height: Math.round(implicitHeight * fit)
                x: Math.round((fv.width - width) / 2)
                y: 0
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: 12
                Kirigami.Icon {
                    source: fv.entry ? fv.entry.ico : ""
                    width: 40
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: fv.entry ? fv.entry.cap : ""
                    color: "white"
                    font.pixelSize: 28
                    font.bold: true
                    textFormat: Text.PlainText
                    elide: Text.ElideMiddle
                    width: Math.min(implicitWidth, 900)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item {
            id: cubeView
            anchors.fill: parent
            focus: true

            property int currentIndex: 0
            property int shownIndex: 0
            property var entries: []
            readonly property int count: entries.length
            // one face per window (1 = a single card, 2 = a two-sided card, 3+ = a prism)
            readonly property int faceCount: count
            readonly property real angleTick: faceCount > 0 ? 360 / faceCount : 360
            readonly property size faceSize: Qt.size(width * 0.8, height * 0.8)
            readonly property real faceDistance: count < 3 ? 60 : 0.5 * faceSize.width / Math.tan(angleTick * Math.PI / 360) + 100
            readonly property real tanHalfFov: Math.tan(0.5 * camera.fieldOfView * Math.PI / 180)
            property real azimuth: 0
            property bool opened: false
            property real radius: (opened ? faceDistance * 1.75 : faceDistance) + 0.5 * faceSize.height / tanHalfFov * (opened && count < 3 ? 1.9 : 1)
            property real tilt: opened ? (count < 3 ? 8 : 20) : 0
            readonly property int duration: 220

            Behavior on azimuth {
                enabled: window.visible
                NumberAnimation { duration: cubeView.duration; easing.type: Easing.OutCubic }
            }
            Behavior on radius { NumberAnimation { duration: cubeView.duration; easing.type: Easing.OutCubic } }
            Behavior on tilt { NumberAnimation { duration: cubeView.duration; easing.type: Easing.OutCubic } }

            function goTo(i) {
                if (count === 0) return;
                let step = (((i - shownIndex) % count) + count) % count;
                if (step > count / 2) step -= count;
                azimuth += step * angleTick;
                shownIndex = i;
            }
            onCurrentIndexChanged: goTo(currentIndex)

            function step(d) {
                if (count > 0) currentIndex = (currentIndex + d + count) % count;
            }
            Keys.onLeftPressed: step(-1)
            Keys.onUpPressed: step(-1)
            Keys.onRightPressed: step(1)
            Keys.onDownPressed: step(1)

            // window list (id, title, icon) read from the TabBox model
            Instantiator {
                id: inst
                model: tabBox.model
                delegate: QtObject {
                    readonly property var wid: windowId
                    readonly property string cap: caption
                    readonly property var ico: icon
                }
                onObjectAdded: Qt.callLater(cubeView.rebuild)
                onObjectRemoved: Qt.callLater(cubeView.rebuild)
            }
            function rebuild() {
                const a = [];
                for (let i = 0; i < inst.count; ++i) a.push(inst.objectAt(i));
                entries = a;
            }

            View3D {
                id: view
                anchors.fill: parent
                renderMode: View3D.Offscreen
                environment: SceneEnvironment { backgroundMode: SceneEnvironment.Transparent }

                Node {
                    eulerRotation.y: cubeView.azimuth
                    Node {
                        eulerRotation.x: -cubeView.tilt
                        PerspectiveCamera {
                            id: camera
                            z: cubeView.radius
                            clipNear: 10
                            clipFar: 100000
                        }
                    }
                }

                Repeater3D {
                    model: cubeView.count
                    delegate: Model {
                        id: face
                        required property int index
                        readonly property int windowIndex: index
                        pickable: true
                        source: "#Rectangle"
                        scale: Qt.vector3d(faceItem.width / 100, faceItem.height / 100, 1)
                        eulerRotation.y: cubeView.angleTick * index
                        position: {
                            const t = Qt.matrix4x4();
                            t.rotate(cubeView.angleTick * index, Qt.vector3d(0, 1, 0));
                            return t.times(Qt.vector3d(0, 0, cubeView.faceDistance));
                        }
                        materials: [
                            DefaultMaterial {
                                cullMode: Material.NoCulling
                                lighting: DefaultMaterial.NoLighting
                                diffuseMap: Texture {
                                    sourceItem: FaceView {
                                        id: faceItem
                                        maxW: cubeView.faceSize.width
                                        maxH: cubeView.faceSize.height
                                        entry: cubeView.entries[face.windowIndex] ?? null
                                    }
                                }
                            }
                        ]
                    }
                }
            }

            MouseArea {
                anchors.fill: view
                onClicked: mouse => {
                    const hit = view.pick(mouse.x, mouse.y);
                    if (hit.objectHit) tabBox.model.activate(hit.objectHit.windowIndex);
                }
            }
        }
    }

    onCurrentIndexChanged: {
        if (currentIndex >= 0 && currentIndex !== cubeView.currentIndex) {
            cubeView.currentIndex = currentIndex;
        }
    }

    onVisibleChanged: {
        window.visible = visible;
        if (visible) {
            Qt.callLater(() => cubeView.opened = true);
        } else {
            // reset while hidden so the next Alt+Tab starts clean
            cubeView.opened = false;
            cubeView.currentIndex = 0;
            cubeView.shownIndex = 0;
            cubeView.azimuth = 0;
        }
    }
}
