import QtQuick
import Quickshell
import Quickshell.Io
import "WindowRegistry.js" as LayoutMath 

Item {
    id: root
    visible: false

    // Callers should set both dimensions. Leaving currentHeight at its default
    // makes getScale() treat the screen as 1080p and under-scale every popup on
    // taller displays, which then disagree with the window size Main.qml
    // reserved for them.
    property real currentWidth: 1920.0
    property real currentHeight: 1080.0
    property real uiScale: GlobalSettingsWatcher.uiScale
    property real dpiScale: GlobalSettingsWatcher.dpiScale

    property real rawBaseScale: {
        // Guard against a zero/unmapped surface during the first frame.
        let w = currentWidth > 0 ? currentWidth : 1920.0;
        let h = currentHeight > 0 ? currentHeight : 1080.0;
        return LayoutMath.getScale(w, h, uiScale, dpiScale);
    }

    // Add behavior to prevent teleporting UI
    property real baseScale: rawBaseScale
    Behavior on baseScale { NumberAnimation { duration: 150 } }
    
    function s(val) { 
        return LayoutMath.s(val, baseScale); 
    }
}
