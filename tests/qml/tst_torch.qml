/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * The torch (src/Torch.qml) as the stock Wear OS Flashlight behaves
 * (STOCK-FLASHLIGHT.md), on the mocks of tests/qml/mocks: white, red, off by
 * a tap; the brightness held at the torch's level with adaptive brightness
 * off and the user's values back when off; the screen kept on; off after
 * the timeout, when the display goes off; the level by the crown and the
 * + / - buttons, remembered; a mode holding the brightness; the hand-over
 * to a mode that comes on; the values a killed torch left behind; the app
 * window (src/main.qml) with no time text over the light (D60-47).
 * Screenshots (384x384, round) go to the runner's shots directory as
 * torch-*.png. Run by torch/tools/run-torch-qml.sh (qemu-aarch64,
 * offscreen, software Qt Quick).
 */

import QtQuick
import QtTest
import FlashlightTest
import Flashlight

Item {
    id: root
    width: 384
    height: 384

    Rectangle { anchors.fill: parent; color: "black" }
    Item {
        id: screen
        anchors.fill: parent
        clip: true
        Loader {
            id: loader
            anchors.fill: parent
            active: false
            sourceComponent: Component { Torch { handoverMs: 150 } }
        }
        // the app window as the launcher opens it (src/main.qml: the
        // Application around the Torch), for test_17
        Loader {
            id: appLoader
            anchors.fill: parent
            active: false
            source: Qt.resolvedUrl("../../src/main.qml")
        }
        Canvas {
            anchors.fill: parent
            z: 100
            onPaint: {
                var ctx = getContext("2d")
                ctx.fillStyle = "#000000"
                ctx.beginPath()
                ctx.rect(0, 0, width, height)
                ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI, true)
                ctx.fill()
            }
        }
    }

    TestCase {
        name: "Torch"
        when: windowShown

        readonly property string shots: "/tmp/torch-shots"
        readonly property string levelKey: "/org/asteroidos/flashlight/brightness"
        readonly property string savedKey: "/org/asteroidos/flashlight/saved-brightness"
        readonly property string savedAlsKey: "/org/asteroidos/flashlight/saved-auto-brightness"
        readonly property int detent: 120 * 24

        function torch() { return loader.item }
        function appWindow() { return appLoader.item }
        function find(item, name) {
            if (!item)
                return null
            if (item.objectName === name)
                return item
            var kids = item.children || []
            for (var i = 0; i < kids.length; i++) {
                var r = find(kids[i], name)
                if (r)
                    return r
            }
            return null
        }
        // a torch closing restores the user's values (test_09): the watch's
        // state for the next one is set with the last one gone
        function stop() {
            loader.active = false
            wait(50)
        }
        function start() {
            loader.active = false
            loader.active = true
            tryCompare(loader, "status", Loader.Ready)
            wait(100)
        }
        function init() {
            stop()
            Backend.reset()
            start()
        }
        function cleanup() {
            appLoader.active = false
        }
        function nothingSaved() {
            var v = Backend.confGet(savedKey)
            return v === undefined || v < 0
        }
        function tap() {
            mouseClick(root, 192, 192)
            wait(100)
        }
        function tapAt(item) {
            var p = item.mapToItem(root, item.width / 2, item.height / 2)
            mouseClick(root, p.x, p.y)
            wait(100)
        }
        function turn(detents) {
            mouseWheel(root, 192, 192, 0, detents * detent)
            wait(50)
        }
        function shot(name) {
            wait(200)
            var img = grabImage(screen)
            img.save(shots + "/" + name + ".png")
        }
        function colorOf(name) { return String(find(torch(), name).color) }

        function test_01_white_red_off_white() {
            var t = torch()
            compare(t.screen, "white")
            compare(colorOf("light"), "#ffffff")
            // apps-misc-01: filled Material Symbols glyph, 24 dp, black on white
            compare(find(t, "icon").name, "flashlight-on-fill")
            compare(find(t, "icon").width, 48)
            compare(find(t, "icon").height, 48)
            compare(String(find(t, "icon").color), "#000000")
            // the user's 60 % and adaptive brightness kept, the level set, adaptive off
            compare(Backend.brightness, 100)
            compare(Backend.als, false)
            compare(Backend.confGet(savedKey), 60)
            compare(Backend.confGet(savedAlsKey), 1)
            verify(Backend.blankingPrevented)
            verify(t.controlShown)
            shot("torch-01-white-control")
            tryCompare(t, "controlShown", false, 3000)
            shot("torch-02-white")

            tap()
            compare(t.screen, "red")
            compare(colorOf("light"), "#ff0000")
            compare(String(find(t, "icon").color), "#000000")
            compare(Backend.brightness, 100)
            verify(Backend.blankingPrevented)
            tryCompare(t, "controlShown", false, 3000)
            shot("torch-03-red")

            tap()
            compare(t.screen, "off")
            compare(colorOf("light"), "#000000")
            compare(find(t, "icon").name, "flashlight-off-fill")
            compare(find(t, "icon").width, 48)
            // on-surface-variant, night (#cecdd4)
            compare(String(find(t, "icon").color), "#cecdd4")
            // the user's values back, nothing held
            compare(Backend.brightness, 60)
            compare(Backend.als, true)
            compare(Backend.confGet(savedKey), -1)
            compare(Backend.confGet(savedAlsKey), -1)
            verify(!Backend.blankingPrevented)
            verify(!t.controlShown)
            shot("torch-04-off")

            tap()
            compare(t.screen, "white")
            compare(Backend.brightness, 100)
            compare(Backend.als, false)
            verify(Backend.blankingPrevented)
        }

        function test_02_crown_sets_the_level() {
            var t = torch()
            tryCompare(t, "controlShown", false, 3000)
            turn(-1)
            compare(t.level, 90)
            compare(Backend.brightness, 90)
            verify(t.controlShown)
            compare(find(t, "levelLabel").text, "90%")
            shot("torch-05-crown-90")
            turn(-3)
            compare(t.level, 60)
            compare(Backend.brightness, 60)
            turn(2)
            compare(t.level, 80)
            // the ends
            turn(5)
            compare(t.level, 100)
            turn(-20)
            compare(t.level, 10)
            compare(Backend.brightness, 10)
            // half a detent is not a step
            mouseWheel(root, 192, 192, 0, detent / 2)
            wait(50)
            compare(t.level, 10)
            // remembered
            compare(Backend.confGet(levelKey), 10)
            // ...and the next torch starts at it
            tap(); tap()
            compare(Backend.brightness, 60)
            stop()
            start()
            compare(torch().level, 10)
            compare(Backend.brightness, 10)
        }

        function test_03_plus_minus_buttons() {
            var t = torch()
            verify(t.controlShown)
            tapAt(find(t, "minus"))
            compare(t.level, 90)
            compare(Backend.brightness, 90)
            compare(t.screen, "white")   // the button, not the toggle
            tapAt(find(t, "minus"))
            compare(t.level, 80)
            tapAt(find(t, "plus"))
            compare(t.level, 90)
            tapAt(find(t, "plus"))
            tapAt(find(t, "plus"))
            compare(t.level, 100)
            shot("torch-06-buttons")
            // hidden, the buttons' places toggle the light as anywhere else
            tryCompare(t, "controlShown", false, 3000)
            var p = find(t, "plus").mapToItem(root, find(t, "plus").width / 2, find(t, "plus").height / 2)
            mouseClick(root, p.x, p.y)
            wait(100)
            compare(t.screen, "red")
            compare(t.level, 100)
        }

        function test_04_timeout() {
            var t = torch()
            t.timeoutMs = 400
            // the timer took the new interval: off by itself
            tryCompare(t, "screen", "off", 3000)
            compare(Backend.brightness, 60)
            compare(Backend.als, true)
            verify(!Backend.blankingPrevented)
            // a tap starts it again, red restarts the timeout
            tap()
            compare(t.screen, "white")
            wait(250)
            tap()
            compare(t.screen, "red")
            wait(250)
            compare(t.screen, "red")
            tryCompare(t, "screen", "off", 3000)
        }

        function test_05_display_off_turns_it_off() {
            var t = torch()
            Backend.displayState = 0
            wait(50)
            compare(t.screen, "off")
            compare(Backend.brightness, 60)
            compare(Backend.als, true)
            // apps-misc-03: the display coming on again is stock's onResume:
            // the light is white again, the brightness held, the timer running
            Backend.displayState = 2
            wait(50)
            compare(t.screen, "white")
            compare(Backend.brightness, 100)
            compare(Backend.als, false)
            verify(Backend.blankingPrevented)
        }

        function test_06_a_mode_holding_the_brightness() {
            stop()
            Backend.confSet("/org/asteroidos/modes/bedtime", true)
            Backend.brightness = 8
            Backend.als = false
            Backend.clearCalls()
            start()
            var t = torch()
            compare(t.screen, "white")
            verify(t.held)
            // left alone
            compare(Backend.brightness, 8)
            compare(Backend.count("mce", "display_brightness"), 0)
            verify(nothingSaved())
            verify(Backend.blankingPrevented)
            // the control is greyed out and the crown does nothing
            turn(-1)
            compare(t.level, 100)
            compare(Backend.brightness, 8)
            verify(t.controlShown)
            verify(!find(t, "plus").parent.enabled)
            shot("torch-07-bedtime-held")
            tap(); tap()
            compare(t.screen, "off")
            compare(Backend.brightness, 8)
            // the mode ends while the torch is on: the engine's restore has
            // happened, the torch holds the brightness again
            tap()
            compare(t.screen, "white")
            Backend.confSet("/org/asteroidos/modes/bedtime", false)
            Backend.brightness = 60
            Backend.als = true
            tryCompare(Backend, "brightness", 100, 2000)
            compare(Backend.als, false)
            compare(Backend.confGet(savedKey), 60)
            compare(Backend.confGet(savedAlsKey), 1)
        }

        function test_07_a_mode_coming_on_takes_over() {
            var t = torch()
            compare(Backend.brightness, 100)
            // Extra dim comes on: the engine saved the torch's values and
            // holds the brightness under 10 %
            Backend.confSet("/org/asteroidos/modes/saved/brightness", 100)
            Backend.confSet("/org/asteroidos/modes/saved/auto-brightness", false)
            Backend.confSet("/org/asteroidos/modes/extra-dim", true)
            Backend.brightness = 5
            // after the hand-over the engine restores the user's values, the torch nothing
            tryCompare(Backend.conf, "/org/asteroidos/modes/saved/brightness", 60, 2000)
            compare(Backend.confGet("/org/asteroidos/modes/saved/auto-brightness"), true)
            compare(Backend.confGet(savedKey), -1)
            compare(Backend.confGet(savedAlsKey), -1)
            tap(); tap()
            compare(t.screen, "off")
            compare(Backend.brightness, 5)
        }

        function test_08_what_a_killed_torch_left() {
            // the last torch was killed while on: its saved values are the ones to put back
            stop()
            Backend.confSet(savedKey, 40)
            Backend.confSet(savedAlsKey, 1)
            Backend.brightness = 100
            Backend.als = false
            start()
            var t = torch()
            compare(Backend.brightness, 100)
            compare(Backend.confGet(savedKey), 40)
            tap(); tap()
            compare(Backend.brightness, 40)
            compare(Backend.als, true)
            compare(Backend.confGet(savedKey), -1)
        }

        function test_09_closing_while_on_restores() {
            compare(Backend.brightness, 100)
            loader.active = false
            wait(50)
            compare(Backend.brightness, 60)
            compare(Backend.als, true)
            compare(Backend.confGet(savedKey), -1)
            verify(!Backend.blankingPrevented)
            start()
        }

        function test_10_mce_not_ready_yet() {
            stop()
            Backend.displayReady = false
            start()
            var t = torch()
            compare(t.screen, "white")
            // nothing until mce's values are in
            compare(Backend.brightness, 60)
            verify(nothingSaved())
            Backend.displayReady = true
            wait(50)
            compare(Backend.brightness, 100)
            compare(Backend.confGet(savedKey), 60)
        }

        // apps-misc-03: onResume -> turnWhite after a pause, whatever the state was
        function test_11_resume_is_white() {
            var t = torch()
            tap()
            compare(t.screen, "red")
            // the display off and on: red does not come back, white does
            Backend.displayState = 0
            wait(50)
            compare(t.screen, "off")
            Backend.displayState = 1       // off to dim: the activity resumes
            wait(50)
            compare(t.screen, "white")
            Backend.displayState = 2       // dim to on: no second resume
            tap()
            compare(t.screen, "red")
            wait(50)
            compare(t.screen, "red")
            // the black off screen of a tap, then the display off and on
            tap()
            compare(t.screen, "off")
            Backend.displayState = 0
            wait(50)
            Backend.displayState = 2
            wait(50)
            compare(t.screen, "white")
            compare(Backend.brightness, 100)
        }

        function test_12_window_back_in_front_is_white() {
            var t = torch()
            // the app goes behind the home screen: off after the debounce
            t.windowActive = false
            tryCompare(t, "screen", "off", 2000)
            compare(Backend.brightness, 60)
            verify(!Backend.blankingPrevented)
            // and comes back to the front: white, timer and hold again
            t.windowActive = true
            compare(t.screen, "white")
            compare(Backend.brightness, 100)
            compare(Backend.als, false)
            verify(Backend.blankingPrevented)
            // the timer runs again from the resume
            t.timeoutMs = 400
            tryCompare(t, "screen", "off", 3000)
            // a flicker shorter than the debounce is no pause: red stays red
            t.timeoutMs = 120000
            tap()
            compare(t.screen, "white")
            tap()
            compare(t.screen, "red")
            t.windowActive = false
            wait(100)
            t.windowActive = true
            wait(400)
            compare(t.screen, "red")
        }

        function test_13_resume_waits_for_the_front_and_the_display() {
            var t = torch()
            Backend.displayState = 0
            wait(50)
            t.windowActive = false
            wait(50)
            // the display comes on, the app is still behind: nothing to show
            Backend.displayState = 2
            wait(50)
            compare(t.screen, "off")
            verify(!Backend.blankingPrevented)
            t.windowActive = true
            compare(t.screen, "white")
            verify(Backend.blankingPrevented)
            // the window in front while the display is off: not white yet
            Backend.displayState = 0
            wait(50)
            compare(t.screen, "off")
            t.windowActive = false
            wait(400)
            t.windowActive = true
            compare(t.screen, "off")
            Backend.displayState = 2
            wait(50)
            compare(t.screen, "white")
        }

        // the ink of a rendered image: the box of the pixels isInk accepts
        // within [x0,x1] x [y0,y1]
        function inkBox(img, x0, y0, x1, y1, isInk) {
            var b = { "l": 1e9, "t": 1e9, "r": -1, "b": -1 }
            for (var y = y0; y <= y1; y++)
                for (var x = x0; x <= x1; x++)
                    if (isInk(img.pixel(x, y))) {
                        b.l = Math.min(b.l, x); b.r = Math.max(b.r, x)
                        b.t = Math.min(b.t, y); b.b = Math.max(b.b, y)
                    }
            return b
        }
        function dark(c) { return c.r < 0.35 && c.g < 0.35 && c.b < 0.35 && c.a > 0.5 }
        function light(c) { return c.r > 0.5 && c.g > 0.5 && c.b > 0.5 && c.a > 0.5 }
        function near(c, hex, tol) {
            var e = Qt.color(hex)
            return Math.abs(c.r - e.r) <= tol && Math.abs(c.g - e.g) <= tol && Math.abs(c.b - e.b) <= tol
        }

        // apps-misc-01: the glyph on screen is the 24 dp (48 px) Material Symbols
        // flashlight, centred. Its ink in the 960 viewport is x 240..720 and
        // y 80..880: 12..36 and 4..44 px of 48
        function test_14_glyph_on_screen() {
            var t = torch()
            tryCompare(t, "controlShown", false, 3000)
            wait(300)
            var img = grabImage(screen)
            // the white light: black ink (the vignette is far from the middle)
            var b = inkBox(img, 140, 140, 244, 244, dark)
            verify(Math.abs(b.l - (168 + 12)) <= 1, "left " + b.l)
            verify(Math.abs(b.r - (168 + 36)) <= 1, "right " + b.r)
            verify(Math.abs(b.t - (168 + 4)) <= 1, "top " + b.t)
            verify(Math.abs(b.b - (168 + 44)) <= 1, "bottom " + b.b)
            // a pixel of the body is black, the light round the glyph is white
            verify(near(img.pixel(188, 202), "#000000", 0.1), "body " + img.pixel(188, 202))
            verify(near(img.pixel(150, 192), "#ffffff", 0.05), "light " + img.pixel(150, 192))
            shot("torch-06-white-black-glyph")
            // red: the same black glyph on red
            tap()
            tryCompare(t, "controlShown", false, 3000)
            wait(300)
            img = grabImage(screen)
            compare(colorOf("light"), "#ff0000")
            verify(near(img.pixel(188, 202), "#000000", 0.1), "red body " + img.pixel(188, 202))
            verify(near(img.pixel(150, 192), "#ff0000", 0.05), "red light " + img.pixel(150, 192))
            shot("torch-06-red-black-glyph")
            // off: the slashed glyph in #cecdd4 on black
            tap()
            wait(300)
            img = grabImage(screen)
            var o = inkBox(img, 140, 140, 244, 244, light)
            // ink x 73..831 -> 3.65..41.6 px, y 129..887 -> 6.45..44.4 px of 48
            verify(Math.abs(o.l - (168 + 3.65)) <= 2.5, "off left " + o.l)
            verify(Math.abs(o.r - (168 + 41.6)) <= 2.5, "off right " + o.r)
            verify(Math.abs(o.t - (168 + 6.45)) <= 2.5, "off top " + o.t)
            verify(Math.abs(o.b - (168 + 44.4)) <= 2.5, "off bottom " + o.b)
            var found = false
            for (var y = 170; y < 215 && !found; y++)
                for (var x = 170; x < 215 && !found; x++)
                    if (near(img.pixel(x, y), "#cecdd4", 0.03))
                        found = true
            verify(found, "no #cecdd4 pixel in the off glyph")
            shot("torch-04b-off-glyph")
        }

        // apps-misc-02, D60-26: the launcher icon drawn at 3 px per dp: the torch
        // box and its colours. The icon is the visible centre 72 dp of the 108 dp
        // adaptive canvas (what the launcher's circular mask shows; the launcher
        // fills its disc with it, X-Eos-Own-Icon), so stock's alpha box 117,84 to
        // 206,239 of 324 px is 63,30 to 152,185 of 216 px: 30 x 52 dp, 0.72 of the disc
        Component {
            id: iconCase
            Image {
                objectName: "im"
                width: 216
                height: 216
                sourceSize: Qt.size(216, 216)
                source: Qt.resolvedUrl("../../icons/asteroid-flashlight.svg")
            }
        }
        function test_15_launcher_icon() {
            var im = createTemporaryObject(iconCase, root)
            tryCompare(im, "status", Image.Ready)
            wait(200)
            var gi = grabImage(im)
            gi.save(shots + "/launcher-icon-3x.png")
            // ink: neither the white disc nor the transparent corners
            function ink(c) { return c.a > 0.5 && (c.r < 0.93 || c.g < 0.93 || c.b < 0.97) }
            // (the torch lies well inside the disc, whose antialiased edge is no ink)
            // (a box inside the disc, around the torch: x 36-72, y 26-82 dp)
            var b = inkBox(gi, 54, 24, 162, 192, ink)
            compare(b.l, 63)
            compare(b.r, 152)
            verify(Math.abs(b.t - 30) <= 1, "top " + b.t)
            verify(Math.abs(b.b - 185) <= 1, "bottom " + b.b)
            // the torch is 30 x 52 dp, 0.72 of the 72 dp disc
            compare(Math.round((b.r - b.l + 1) / 3), 30)
            compare(Math.round((b.b - b.t + 1) / 3), 52)
            fuzzyCompare((b.b - b.t + 1) / 216, 0.72, 0.01)
            // centred across
            verify(Math.abs((b.l + b.r) / 2 - 107.5) <= 1)
            // the white disc fills the picture, its corners empty
            verify(near(gi.pixel(6, 108), "#ffffff", 0.01), "disc")
            verify(!near(gi.pixel(2, 2), "#ffffff", 0.2), "outside the circle is not white: " + gi.pixel(2, 2))
            // the colours: body, switch, highlight, the head lightening downwards
            verify(near(gi.pixel(108, 161), "#336ef3", 0.02), "body " + gi.pixel(108, 161))
            verify(near(gi.pixel(108, 120), "#2c3796", 0.02), "switch " + gi.pixel(108, 120))
            verify(near(gi.pixel(108, 39), "#def0f9", 0.02), "highlight " + gi.pixel(108, 39))
            var h1 = gi.pixel(108, 46), h2 = gi.pixel(108, 74)
            verify(h1.b > 0.95 && h1.g > 0.68 && h1.r > 0.40 && h1.r < 0.75, "head top " + h1)
            verify(h2.r > h1.r, "the head lightens downwards")
            verify(h2.r <= Qt.color("#add7fe").r + 0.03, "head bottom " + h2)
        }

        // apps-misc-02: the launcher entry, and the install rules
        function readFile(rel) {
            var x = new XMLHttpRequest()
            x.open("GET", Qt.resolvedUrl(rel), false)
            x.send()
            return x.responseText
        }
        function test_16_desktop_entry_and_install() {
            var d = readFile("../../asteroid-flashlight.desktop.template")
            verify(d.indexOf("Icon=asteroid-flashlight\n") >= 0)
            verify(d.indexOf("X-Asteroid-Center-Color=#FFFFFF\n") >= 0)
            verify(d.indexOf("X-Asteroid-Outer-Color=#FFFFFF\n") >= 0)
            // D60-26: the launcher draws the icon as it is (CP3A: a white
            // background layer, a multi-tone blue torch), no tinted glyph
            verify(d.indexOf("X-Eos-Own-Icon=true\n") >= 0)
            verify(d.indexOf("X-Eos-Glyph-Color") < 0)
            verify(d.indexOf("FCF7EB") < 0 && d.indexOf("3C3A33") < 0, "the TWD9 colours are gone")
            var c = readFile("../../CMakeLists.txt")
            verify(c.indexOf("icons/flashlight-on-fill.svg") >= 0)
            verify(c.indexOf("icons/flashlight-off-fill.svg") >= 0)
            verify(c.indexOf("icons/asteroid-flashlight.svg") >= 0)
            verify(c.indexOf("icons/asteroid") >= 0)
            // the glyph files: Fill 1 in the 960 viewport (stock gm_flashlight_*_24)
            var on = readFile("../../icons/flashlight-on-fill.svg")
            verify(on.indexOf('viewBox="0 0 960 960"') >= 0)
            verify(on.indexOf("M240,200L240,160Q240,127") >= 0)
            var off = readFile("../../icons/flashlight-off-fill.svg")
            verify(off.indexOf("M320,800L320,432L84,196") >= 0)
        }

        // D60-47: no time text over the light. CP3A's FlashlightActivity is a
        // plain Activity, setContentView(flashlight_layout)
        // (FlashlightActivity.java:12, :43), and flashlight_layout.xml:2-17 is
        // the light (FrameLayout) and its glyph (ImageView) only: no TimeText.
        // The app window keeps the time off with the time-text setting on,
        // and the top of the light, where the time and its band would be, is
        // white.
        function findType(item, type) {
            if (!item)
                return null
            if (String(item).indexOf(type) === 0)
                return item
            var kids = item.children || []
            for (var i = 0; i < kids.length; i++) {
                var r = findType(kids[i], type)
                if (r)
                    return r
            }
            return null
        }
        // pixels not white in the band's place: its middle 33 px, from its
        // top (or the vignette's first clear row at x 192, y 24 + 2) to
        // its bottom
        function notWhiteUnderTime(img, tt) {
            var n = 0
            var y0 = Math.ceil(Math.max(tt.edgeMargin, 26))
            var y1 = Math.floor(tt.edgeMargin + tt.lineHeight) - 1
            for (var y = y0; y <= y1; y++)
                for (var x = 176; x <= 208; x++)
                    if (!near(img.pixel(x, y), "#ffffff", 0.02))
                        n++
            return n
        }
        function test_17_app_has_no_time_text() {
            stop()
            Backend.reset()
            Backend.confSet("/org/asteroidos/ux/time-text", true)
            appLoader.active = true
            tryCompare(appLoader, "status", Loader.Ready)
            var app = appWindow()
            var t = findType(app, "Torch")
            verify(t !== null, "the window holds the Torch")
            compare(t.screen, "white")
            tryCompare(t, "controlShown", false, 3000)
            var tt = findType(app, "TimeText")
            verify(tt !== null, "the Application has its TimeText")
            verify(tt.lineHeight > 0)
            compare(app.showTime, false)
            compare(tt.visible, false)
            wait(300)
            var img = grabImage(screen)
            compare(notWhiteUnderTime(img, tt), 0)
            verify(near(img.pixel(192, 30), "#ffffff", 0.02), "top of the light " + img.pixel(192, 30))
            shot("torch-17-app-no-time-text")
            // the check sees a time text: forced on, its band and digits
            // darken that place
            app.showTime = true
            wait(300)
            img = grabImage(screen)
            var n = notWhiteUnderTime(img, tt)
            verify(n > 100, "a shown time text darkens the top: " + n)
            shot("torch-17-app-time-text-forced")
        }
    }
}
