/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * The brightness control of the torch, laid out as stock Wear OS's own
 * brightness control (ClockworkSysUiGoogle WearFullscreenSlider,
 * wear_fullscreen_slider.xml: a standard 52 dp circular + button whose top
 * is at 4 % of the height, a - button whose bottom is at 96 %, the value
 * between them in white, the buttons in the WearCircularButtonSecondary
 * style; wear_circular_button_diameter_standard 52 dp, icon 26 dp). Over the
 * light the buttons and the value sit on translucent black so that they
 * read on white and on red. Shown for 1.5 s after each use; greyed out while
 * a mode holds the brightness, as stock's brightness tile in bedtime.
 */

import QtQuick
import org.asteroid.controls

Item {
    id: control

    property int level: 100
    property bool shown: false
    signal increment()
    signal decrement()

    function show() {
        shown = true
        hideTimer.restart()
    }
    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: control.shown = false
    }

    opacity: shown ? (enabled ? 1 : 0.38) : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    readonly property real buttonSize: Dims.l(100 * 52 / 192)
    readonly property real glyphSize: Dims.l(100 * 26 / 192)

    Rectangle {
        id: plus
        objectName: "plus"
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.04
        width: control.buttonSize
        height: width
        radius: width / 2
        color: "#000000"
        opacity: plusArea.pressed ? 0.75 : 0.55
        Icon {
            anchors.centerIn: parent
            width: control.glyphSize
            height: width
            name: "ios-add"
            color: "#ffffff"
        }
        MouseArea {
            id: plusArea
            anchors.fill: parent
            enabled: control.enabled && control.shown
            onClicked: control.increment()
        }
    }

    Rectangle {
        id: minus
        objectName: "minus"
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.96 - height
        width: control.buttonSize
        height: width
        radius: width / 2
        color: "#000000"
        opacity: minusArea.pressed ? 0.75 : 0.55
        Icon {
            anchors.centerIn: parent
            width: control.glyphSize
            height: width
            name: "ios-remove"
            color: "#ffffff"
        }
        MouseArea {
            id: minusArea
            anchors.fill: parent
            enabled: control.enabled && control.shown
            onClicked: control.decrement()
        }
    }

    // the value, in the centre (wear_fullscreen_slider_text)
    Rectangle {
        anchors.centerIn: parent
        width: levelLabel.implicitWidth + Dims.l(10)
        height: levelLabel.implicitHeight + Dims.l(4)
        radius: height / 2
        color: "#000000"
        opacity: 0.55
    }
    Label {
        id: levelLabel
        objectName: "levelLabel"
        anchors.centerIn: parent
        text: control.level + "%"
        color: "#ffffff"
        font.pixelSize: Dims.l(9)
    }
}
