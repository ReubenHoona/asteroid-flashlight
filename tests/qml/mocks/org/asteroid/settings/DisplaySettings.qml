// Test double for the flashlight QML tests (as asteroid-launcher tests/qml/mocks):
// qml-asteroid's DisplaySettings (mce display settings), with ready
import QtQuick
import FlashlightTest

QtObject {
    id: ds
    readonly property bool ready: Backend.displayReady
    property int brightness: Backend.brightness
    readonly property int maximumBrightness: 100
    property bool ambientLightSensorEnabled: Backend.als
    onBrightnessChanged: if (brightness !== Backend.brightness) {
        Backend.brightness = brightness
        Backend.record("mce", "display_brightness", [brightness])
    }
    onAmbientLightSensorEnabledChanged: if (ambientLightSensorEnabled !== Backend.als) {
        Backend.als = ambientLightSensorEnabled
        Backend.record("mce", "als_enabled", [ambientLightSensorEnabled])
    }
    property Connections _sync: Connections {
        target: Backend
        function onBrightnessChanged() { if (ds.brightness !== Backend.brightness) ds.brightness = Backend.brightness }
        function onAlsChanged() { if (ds.ambientLightSensorEnabled !== Backend.als) ds.ambientLightSensorEnabled = Backend.als }
    }
}
