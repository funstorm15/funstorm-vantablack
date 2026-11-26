/*
    SPDX-FileCopyrightText: 2022 Vlad Zahorodnii <vlad.zahorodnii@kde.org>
    Modified for FunStorm Vantablack: jump to desktop N, Alt+Tab with release-to-enter, retargeting.

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents

KWinComponents.SceneEffect {
    id: effect

    property bool activated: false
    readonly property int animationDuration: 200
    property var pendingDesktop: null
    property bool altHold: false   // Alt+Tab mode: wait for Alt release before entering
    signal jumpRequested()

    // stored as a property to keep the component alive and cleanup afterwards
    property var mainDelegate: KWinComponents.Workspace.desktops.length < 3 ? Qt.createComponent("PlaceholderView.qml") : Qt.createComponent("ScreenView.qml")
    delegate: mainDelegate
    Instantiator {
        model: effect.configuration.BorderActivate
        KWinComponents.ScreenEdgeHandler {
            mode: KWinComponents.ScreenEdgeHandler.Pointer
            edge: modelData
            onActivated: toggle();
        }
    }

    Instantiator {
        model: effect.configuration.TouchBorderActivate
        KWinComponents.ScreenEdgeHandler {
            mode: KWinComponents.ScreenEdgeHandler.Touch
            edge: modelData
            onActivated: toggle();
        }
    }

    KWinComponents.ShortcutHandler {
        name: "Cube Switch Toggle"
        text: "Toggle Cube (Cube Switch)"
        sequence: "Meta+C"
        onActivated: toggle();
    }

    Instantiator {
        model: 9
        KWinComponents.ShortcutHandler {
            name: "Cube Switch to Desktop " + (index + 1)
            text: "Cube Switch to Desktop " + (index + 1)
            sequence: index < 5 ? "Meta+" + (index + 1) : ""
            onActivated: { effect.altHold = false; effect.jumpTo(index); }
        }
    }

    KWinComponents.ShortcutHandler {
        name: "Cube Switch Next Desktop"
        text: "Cube Switch to Next Desktop"
        sequence: "Alt+Tab"
        onActivated: {
            const desktops = KWinComponents.Workspace.desktops;
            const from = effect.pendingDesktop || KWinComponents.Workspace.currentDesktop;
            effect.altHold = true;
            effect.jumpTo((desktops.indexOf(from) + 1) % desktops.length);
        }
    }

    function jumpTo(i) {
        const desktops = KWinComponents.Workspace.desktops;
        if (i >= desktops.length) return;
        const d = desktops[i];
        const busy = activated || deactivateTimer.running;
        if (d === KWinComponents.Workspace.currentDesktop && !busy) return;
        // a new press interrupts whatever the cube is doing and retargets immediately
        deactivateTimer.stop();
        pendingDesktop = d;
        visible = true;
        activated = true;
        jumpRequested();
    }

    Timer {
        id: deactivateTimer
        interval: effect.animationDuration
        onTriggered: effect.visible = false
    }

    function toggle() {
        if (activated) {
            deactivate();
        } else {
            activate();
        }
    }

    function activate() {
        if (activated || deactivateTimer.running) {
            return;
        }
        visible = true;
        activated = true;
    }

    function deactivate() {
        if (!activated) {
            return;
        }
        activated = false;
        altHold = false;
        pendingDesktop = null;
        deactivateTimer.start();
    }
}
