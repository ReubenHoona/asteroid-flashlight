// Test double for the flashlight QML tests: Nemo.Mce's MceDisplay on Backend.displayState
import QtQuick
import FlashlightTest

QtObject {
    enum State { DisplayOff, DisplayDim, DisplayOn }
    readonly property bool valid: true
    readonly property int state: Backend.displayState
}
