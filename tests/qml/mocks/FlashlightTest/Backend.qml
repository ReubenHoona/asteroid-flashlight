// Test double for the flashlight QML tests (as asteroid-launcher tests/qml/mocks):
// the watch the mocks stand for: dconf, mce's display settings and display
// state, the keepalive. Every write a mock passes on is recorded in calls;
// reset() puts the defaults back.
pragma Singleton
import QtQuick

QtObject {
    // dconf
    property var conf: ({})
    signal confWritten(string key)
    function confHas(key) { return conf.hasOwnProperty(key) }
    function confGet(key) { return conf[key] }
    function confSet(key, v) {
        conf[key] = v
        record("dconf", key, [v])
        confWritten(key)
    }

    // mce's display settings (DisplaySettings) and display state (MceDisplay)
    property int brightness: 60
    property bool als: true
    property bool displayReady: true
    property int displayState: 2      // MceDisplay.DisplayOn

    // the keepalive (DisplayBlanking)
    property bool blankingPrevented: false

    // what was asked of the backends: { target, method, args }
    property var calls: []
    function record(target, method, args) {
        var l = calls.slice()
        l.push({ "target": target, "method": method, "args": args || [] })
        calls = l
    }
    function find(target, method) {
        for (var i = calls.length - 1; i >= 0; i--)
            if (calls[i].target === target && calls[i].method === method)
                return calls[i]
        return null
    }
    function count(target, method) {
        var n = 0
        for (var i = 0; i < calls.length; i++)
            if (calls[i].target === target && calls[i].method === method)
                n++
        return n
    }
    function clearCalls() { calls = [] }

    function reset() {
        conf = {}
        brightness = 60
        als = true
        displayReady = true
        displayState = 2
        blankingPrevented = false
        calls = []
    }
    Component.onCompleted: reset()
}
