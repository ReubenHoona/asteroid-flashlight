// Test double for the flashlight QML tests (as asteroid-settings tests/mocks)
// org.asteroid.utils WallClock for the Application's TimeText (test_17):
// a fixed 10:10
import QtQuick
QtObject {
    enum UpdateFrequency { Day, Minute, Second }
    property bool enabled: true
    property int updateFrequency: 1
    readonly property var time: new Date(2026, 10, 23, 10, 10, 0)
}
