/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * The torch covers the whole screen, as stock's FlashlightActivity (a plain
 * Activity with flashlight_layout): nothing of the shell shows.
 */

import QtQuick
import org.asteroid.controls

Application {
    id: app

    centerColor: "#000000"
    outerColor: "#000000"
    leftIndicVisible: false
    topIndicVisible: false
    rightIndicVisible: false
    bottomIndicVisible: false
    // no time text over the light (D60-47): CP3A's FlashlightActivity is a
    // plain Activity showing flashlight_layout (FlashlightActivity.java:43),
    // the light and its glyph only (flashlight_layout.xml:2-17), so the
    // time-text setting does not reach it
    showTime: false

    Torch {
        anchors.fill: parent
    }
}
