// Port of Omarchy's background plugin transition (shell/plugins/background/Background.qml):
// the new image is revealed from the centre by a slanted band, 420 ms InOutCubic.
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    readonly property string configured: root.configuration.Image || ""
    property string displayed: ""
    property string incoming: ""
    property real revealProgress: 1
    readonly property size physicalSize: Qt.size(Math.round(width * Screen.devicePixelRatio), Math.round(height * Screen.devicePixelRatio))

    function toUrl(p) { return !p ? "" : (p.indexOf("file://") === 0 ? p : "file://" + p) }

    onConfiguredChanged: {
        if (!configured || configured === displayed || configured === incoming) return
        if (!displayed) { displayed = configured; return }
        reveal.stop()
        incoming = configured
        revealProgress = 0
        if (incomingFrame.status === Image.Ready) reveal.restart()
    }
    Component.onCompleted: displayed = configured

    NumberAnimation {
        id: reveal
        target: root; property: "revealProgress"
        from: 0; to: 1; duration: 420
        easing.type: Easing.InOutCubic
        onFinished: { root.displayed = root.incoming; root.revealProgress = 1 }
    }

    Rectangle { anchors.fill: parent; color: "black" }

    Image {
        id: base
        anchors.fill: parent
        source: root.toUrl(root.displayed)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        onStatusChanged: if (status === Image.Ready && root.revealProgress >= 1) root.incoming = ""
    }

    Item {
        id: incomingLayer
        anchors.fill: parent
        visible: root.incoming !== "" && incomingFrame.status === Image.Ready
        layer.enabled: root.incoming !== "" && root.revealProgress < 1
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: revealMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.02
        }
        Image {
            id: incomingFrame
            anchors.fill: parent
            source: root.toUrl(root.incoming)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            mipmap: true
            cache: false
            smooth: true
            onStatusChanged: if (status === Image.Ready && root.incoming && root.revealProgress === 0) reveal.restart()
        }
    }

    Item {
        id: revealMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        readonly property real slant: -0.18
        readonly property real centerTop: width / 2 - slant * height / 2
        readonly property real centerBottom: width / 2 + slant * height / 2
        readonly property real reach: width / 2 + Math.abs(slant) * height / 2 + 4
        readonly property real spread: reach * root.revealProgress
        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "white"; strokeColor: "transparent"
                startX: revealMask.centerTop - revealMask.spread; startY: 0
                PathLine { x: revealMask.centerTop + revealMask.spread; y: 0 }
                PathLine { x: revealMask.centerBottom + revealMask.spread; y: revealMask.height }
                PathLine { x: revealMask.centerBottom - revealMask.spread; y: revealMask.height }
                PathLine { x: revealMask.centerTop - revealMask.spread; y: 0 }
            }
        }
    }
}
