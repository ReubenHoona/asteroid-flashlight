// Test double for the flashlight QML tests: Nemo.KeepAlive's DisplayBlanking
// (mce's blanking pause) on Backend.blankingPrevented
import QtQuick
import FlashlightTest

QtObject {
    property bool preventBlanking: false
    onPreventBlankingChanged: {
        Backend.blankingPrevented = preventBlanking
        Backend.record("mce", "blanking_pause", [preventBlanking])
    }
    Component.onCompleted: Backend.blankingPrevented = preventBlanking
    // gone with its object, as the real one's destructor lets the display blank
    Component.onDestruction: Backend.blankingPrevented = false
}
