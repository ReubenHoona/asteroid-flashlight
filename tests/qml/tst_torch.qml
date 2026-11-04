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
 * to a mode that comes on; the values a killed torch left behind.
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
            compare(find(t, "icon").name, "gm-flashlight-on")
            compare(String(find(t, "icon").color), "#bdbdbd")
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
            compare(String(find(t, "icon").color), "#cc0000")
            compare(Backend.brightness, 100)
            verify(Backend.blankingPrevented)
            tryCompare(t, "controlShown", false, 3000)
            shot("torch-03-red")

            tap()
            compare(t.screen, "off")
            compare(colorOf("light"), "#000000")
            compare(find(t, "icon").name, "gm-flashlight-off")
            compare(String(find(t, "icon").color), "#bdbdbd")
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
            Backend.displayState = 2
            wait(50)
            compare(t.screen, "off")
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
    }
}
