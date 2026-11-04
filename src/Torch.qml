/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * The Flashlight as stock Wear OS's on the Pixel Watch 2 (ClockworkFlashlight,
 * com.google.android.clockwork.flashlight; STOCK-FLASHLIGHT.md): the screen is
 * the light. It comes on white; a tap turns it red, the next tap off (a black
 * screen with the grey "off" icon), the next white again (ControllerImpl
 * .toggle). While it is white or red the screen stays on at the torch's
 * brightness (BrightnessController.setFullBrightness: window brightness 1.0
 * and FLAG_KEEP_SCREEN_ON); the user's brightness and adaptive brightness are
 * back when it goes off, and it goes off by itself after 2 minutes
 * (TimeoutController) or when the display is turned off or the app leaves the
 * front (onPause -> turnOff). The light fades to black at the edge (bg_white,
 * bg_red: a radial gradient from 87.48 % of the radius) with the Material
 * flashlight icon, 32 of 192 dp, in grey 400 (#bdbdbd) on white and in #cc0000
 * on red; off is black with the grey "flashlight off" icon (UiImpl).
 *
 * Beyond stock, as asked: the brightness of the light is adjustable while it
 * is on, by the crown (10 % per detent, 10 to 100 %, a haptic tick, a bump at
 * the ends) or by the + and - buttons of the control that shows then, laid
 * out as stock's own brightness control (SysUI WearFullscreenSlider: + at the
 * top, - at the bottom, the value between). The level is remembered.
 *
 * Brightness goes through mce (DisplaySettings: display_brightness and
 * als_enabled), as Settings and the quick panel do. While a mode holds the
 * brightness (Bedtime, whose cap of 20/255 stock applies to the window
 * brightness too, DisplayPowerController; Extra dim) the torch leaves it
 * alone and the control is disabled, as stock disables its brightness tile in
 * bedtime. A mode coming on while the torch holds the brightness takes over
 * the user's values to restore (the modes engine's saved/ keys); a mode going
 * off while the torch is on gives the torch its brightness back.
 */

import QtQuick
import QtQuick.Window
import org.asteroid.controls
import org.asteroid.utils
import org.asteroid.settings
import Nemo.Configuration
import Nemo.KeepAlive
import Nemo.Mce

Item {
    id: torch

    // stock's ScreenState: WHITE, RED, OFF; the app starts white
    property string screen: "white"
    readonly property bool lit: screen !== "off"
    // the torch's brightness in percent, 10 to 100 in tens, remembered
    readonly property int level: levelConf.value
    // stock TimeoutController.TURN_OFF_TIMEOUT_MS: 2 minutes
    property int timeoutMs: 120000
    // the modes engine has written its own saved values by then
    property int handoverMs: 1000
    // a mode holds the brightness (modescore.h: Bedtime at most 8 %, Extra dim under 10 %)
    readonly property bool held: bedtimeConf.value === true || extraDimConf.value === true
    readonly property alias controlShown: control.shown

    ConfigurationValue { id: levelConf; key: "/org/asteroidos/flashlight/brightness"; defaultValue: 100 }
    // the user's brightness and adaptive brightness while the torch holds
    // them (-1: not held); in dconf so that a torch killed while on leaves
    // them for the next run to put back
    ConfigurationValue { id: savedBrightness; key: "/org/asteroidos/flashlight/saved-brightness"; defaultValue: -1 }
    ConfigurationValue { id: savedAls; key: "/org/asteroidos/flashlight/saved-auto-brightness"; defaultValue: -1 }
    ConfigurationValue { id: bedtimeConf; key: "/org/asteroidos/modes/bedtime"; defaultValue: false }
    ConfigurationValue { id: extraDimConf; key: "/org/asteroidos/modes/extra-dim"; defaultValue: false }
    // the modes engine's "user's value to restore" (asteroid-launcher modes.cpp)
    ConfigurationValue { id: modesSavedBrightness; key: "/org/asteroidos/modes/saved/brightness"; defaultValue: -1 }
    ConfigurationValue { id: modesSavedAls; key: "/org/asteroidos/modes/saved/auto-brightness"; defaultValue: false }
    // the crown as RotaryInput reads it (qml-asteroid rotaryinput.h)
    ConfigurationValue { id: detentConf; key: "/org/asteroidos/ux/rotary-counts-per-detent"; defaultValue: 24 }
    ConfigurationValue { id: invertConf; key: "/org/asteroidos/ux/rotary-invert"; defaultValue: false }

    DisplaySettings {
        id: display
        // mce's values arrive after the start: hold once they have
        onReadyChanged: if (ready && torch.lit) torch.hold()
    }

    // FLAG_KEEP_SCREEN_ON while the light is on
    DisplayBlanking { preventBlanking: torch.lit }

    // the display going off, the app leaving the front (the right swipe
    // puts it behind the home screen): stock's onPause turns the light off
    MceDisplay {
        onStateChanged: if (state === MceDisplay.DisplayOff) torch.turnOff()
    }
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: {
        if (windowActive)
            inactive.stop()
        else
            inactive.start()
    }
    Timer {
        id: inactive
        interval: 300
        onTriggered: if (!torch.windowActive) torch.turnOff()
    }

    Timer {
        id: offTimer
        interval: torch.timeoutMs
        onTriggered: torch.turnOff()
    }

    function turnWhite() { screen = "white"; hold(); offTimer.restart() }
    function turnRed() { screen = "red"; hold(); offTimer.restart() }
    function turnOff() { screen = "off"; release(); offTimer.stop() }
    function toggle() {
        if (screen === "white")
            turnRed()
        else if (screen === "red")
            turnOff()
        else
            turnWhite()
    }

    // the user's brightness and adaptive brightness kept, the torch's level
    // set. Integers ("| 0"): the modes engine passes a saved brightness on
    // to mce, which takes an int32
    function hold() {
        if (held || !display.ready)
            return
        if (savedBrightness.value < 0) {
            savedBrightness.value = display.brightness | 0
            savedAls.value = display.ambientLightSensorEnabled ? 1 : 0
        }
        if (display.ambientLightSensorEnabled)
            display.ambientLightSensorEnabled = false
        if (display.brightness !== level)
            display.brightness = level
    }
    // the user's values back (also those a killed torch left behind)
    function release() {
        if (savedBrightness.value < 0)
            return
        display.brightness = savedBrightness.value | 0
        if (savedAls.value >= 0)
            display.ambientLightSensorEnabled = savedAls.value === 1
        savedBrightness.value = -1
        savedAls.value = -1
    }

    onHeldChanged: {
        rehold.stop()
        handover.stop()
        if (held) {
            if (lit && savedBrightness.value >= 0)
                handover.start()
        } else if (lit) {
            rehold.start()
        }
    }
    // a mode came on while the torch held the brightness: the engine saved
    // the torch's values as the user's; the user's own go there instead and
    // the torch has nothing to restore any more
    Timer {
        id: handover
        interval: torch.handoverMs
        onTriggered: {
            if (!torch.held || savedBrightness.value < 0)
                return
            modesSavedBrightness.value = savedBrightness.value | 0
            modesSavedAls.value = savedAls.value === 1
            savedBrightness.value = -1
            savedAls.value = -1
        }
    }
    // a mode went off while the torch is on: the engine has restored the
    // user's values by now, hold them again
    Timer {
        id: rehold
        interval: torch.handoverMs
        onTriggered: if (torch.lit) torch.hold()
    }

    // the level: a step of 10 %, the light follows at once
    function step(n) {
        if (!lit)
            return
        if (held) {
            control.show()
            return
        }
        var v = Math.max(10, Math.min(100, level + 10 * n)) | 0
        if (v === level) {
            Haptics.limit()
        } else {
            levelConf.value = v
            display.brightness = v
            Haptics.tick()
        }
        control.show()
    }

    // the crown: one step per detent, as RotaryInput's snapping views
    WheelHandler {
        id: crown
        target: null
        property real pending: 0
        onWheel: (event) => {
            var d = event.angleDelta.y
            if (d === 0)
                return
            if (invertConf.value === true)
                d = -d
            var unit = 120 * Math.max(1, detentConf.value)
            pending += d
            while (pending >= unit) {
                pending -= unit
                torch.step(1)
            }
            while (pending <= -unit) {
                pending += unit
                torch.step(-1)
            }
        }
    }

    // the light: stock bg_white / bg_red / bg_black
    Rectangle {
        id: light
        objectName: "light"
        anchors.fill: parent
        color: torch.screen === "white" ? "#ffffff" : torch.screen === "red" ? "#ff0000" : "#000000"
    }

    // the fade to black at the edge: round, a radial gradient from 87.48 %
    // of the radius (bg_white round); square, 24 of 192 dp at each edge with
    // round corners (bg_white)
    Canvas {
        id: vignette
        anchors.fill: parent
        visible: torch.lit
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var clear = "rgba(0,0,0,0)", dark = "rgba(0,0,0,1)"
            if (DeviceSpecs.hasRoundScreen) {
                var r = Math.min(width, height) / 2
                var g = ctx.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, r)
                g.addColorStop(0, clear)
                g.addColorStop(0.8748, clear)
                g.addColorStop(1, dark)
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            } else {
                var e = Math.min(width, height) * 24 / 192
                var edges = [[0, e, 0, 0, 0, e, e, height - 2 * e], [width, width - e, width - e, 0, width - e, e, e, height - 2 * e],
                             [0, 0, 0, e, e, 0, width - 2 * e, e], [0, height, 0, height - e, e, height - e, width - 2 * e, e]]
                for (var i = 0; i < edges.length; i++) {
                    var s = edges[i]
                    var lg = ctx.createLinearGradient(s[0], s[1], s[2], s[3])
                    lg.addColorStop(0, dark)
                    lg.addColorStop(1, clear)
                    ctx.fillStyle = lg
                    ctx.fillRect(s[4], s[5], s[6], s[7])
                }
                var corners = [[e, e, 0, 0], [width - e, e, width - e, 0], [e, height - e, 0, height - e], [width - e, height - e, width - e, height - e]]
                for (var c = 0; c < corners.length; c++) {
                    var k = corners[c]
                    var rg = ctx.createRadialGradient(k[0], k[1], 0, k[0], k[1], e)
                    rg.addColorStop(0, clear)
                    rg.addColorStop(1, dark)
                    ctx.fillStyle = rg
                    ctx.fillRect(k[2], k[3], e, e)
                }
            }
        }
    }

    // a tap anywhere toggles (UiImpl: the container's click listener)
    MouseArea {
        anchors.fill: parent
        onClicked: torch.toggle()
    }

    // the Material flashlight icon, 32 of 192 dp, centered (flashlight_layout);
    // the level takes its place while the control shows (stock's slider has
    // the value in the centre)
    Icon {
        id: icon
        objectName: "icon"
        anchors.centerIn: parent
        width: Dims.l(100 / 6)
        height: width
        name: torch.lit ? "gm-flashlight-on" : "gm-flashlight-off"
        color: torch.screen === "red" ? "#cc0000" : "#bdbdbd"
        opacity: control.shown ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    LevelControl {
        id: control
        anchors.fill: parent
        level: torch.level
        enabled: torch.lit && !torch.held
        onIncrement: torch.step(1)
        onDecrement: torch.step(-1)
    }

    // the control shows for a moment when the light comes on, so that it is
    // found; the crown or a tap on it brings it back (screen itself: the
    // lit binding may not have followed yet when this runs)
    onScreenChanged: if (screen !== "off") control.show()
    Component.onCompleted: {
        hold()
        offTimer.start()
        control.show()
    }
    // the app closing (the swipe, the crown button, the launcher 5 s after
    // the display went off): the user's brightness back
    Component.onDestruction: release()
}
