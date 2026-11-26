/*
    Zoom desktop switch for KWin.
    Based on KWin's Fade Desktop effect:
    SPDX-FileCopyrightText: 2009 Lucas Murray, 2012 Martin Gräßlin, 2018 Vlad Zahorodnii
    SPDX-License-Identifier: GPL-2.0-or-later
*/
"use strict";
// Zoom desktop switch: going "forward" the old desktop sinks back and the new one
// arrives from in front; going "back" it is mirrored. Based on KWin's Fade Desktop effect.
var zoomDesktop = {
    duration: 320,
    animateWindow: function (w, incoming, forward) {
        if (w.zoomAnim) { cancel(w.zoomAnim); delete w.zoomAnim; }
        var near = 1.12, far = 0.86;
        var scaleFrom, scaleTo;
        if (incoming) { scaleFrom = forward ? near : far; scaleTo = 1.0; }
        else          { scaleFrom = 1.0; scaleTo = forward ? far : near; }
        w.zoomAnim = animate({
            window: w,
            duration: zoomDesktop.duration,
            curve: QEasingCurve.OutCubic,
            fullScreen: true,
            keepAlive: false,
            animations: [
                { type: Effect.Opacity, from: incoming ? 0.0 : 1.0, to: incoming ? 1.0 : 0.0 },
                { type: Effect.Scale, from: scaleFrom, to: scaleTo }
            ]
        });
    },
    slotDesktopChanged: function (oldDesktop, newDesktop, movingWindow, screen) {
        if (effects.hasActiveFullScreenEffect && !effect.isActiveFullScreenEffect) return;
        var forward = true;
        if (oldDesktop && newDesktop && oldDesktop.x11DesktopNumber !== undefined) {
            forward = newDesktop.x11DesktopNumber > oldDesktop.x11DesktopNumber;
        }
        var order = effects.stackingOrder;
        for (var i = 0; i < order.length; ++i) {
            var w = order[i];
            if (w == movingWindow || w.screen !== screen || w.minimized) continue;
            if (!w.isOnActivity(effects.currentActivity)) continue;
            var onOld = w.isOnDesktop(oldDesktop), onNew = w.isOnDesktop(newDesktop);
            if (onOld == onNew) continue;
            zoomDesktop.animateWindow(w, onNew, forward);
        }
    },
    init: function () {
        zoomDesktop.duration = animationTime(320);
        effects.desktopChanged.connect(zoomDesktop.slotDesktopChanged);
    }
};
zoomDesktop.init();
