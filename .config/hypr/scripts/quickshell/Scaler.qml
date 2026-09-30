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
    property real currentWidth: (Screen.width && Screen.width > 0) ? Screen.width : 1920.0
    property real currentHeight: (Screen.height && Screen.height > 0) ? Screen.height : 1080.0
    property real uiScale: GlobalSettingsWatcher.uiScale
    property real dpiScale: GlobalSettingsWatcher.dpiScale

    property real rawBaseScale: {
        // Guard against zero, NaN, or unmapped surface during the first frame.
        let scrW = (Screen.width && Screen.width > 0) ? Screen.width : 1920.0;
        let scrH = (Screen.height && Screen.height > 0) ? Screen.height : 1080.0;
        let w = (currentWidth && !isNaN(currentWidth) && currentWidth > 0) ? currentWidth : scrW;
        let h = (currentHeight && !isNaN(currentHeight) && currentHeight > 0) ? currentHeight : scrH;
        // Safety guard: if caller passed a sub-window/popup dimension instead of monitor resolution,
        // use screen dimensions so inner contents never suffer quadratic double-scaling.
        if (h < scrH * 0.7) h = scrH;
        if (w < scrW * 0.7) w = scrW;
        return LayoutMath.getScale(w, h, uiScale, dpiScale);
    }

    // Add behavior to prevent teleporting UI
    property real baseScale: rawBaseScale
    Behavior on baseScale { NumberAnimation { duration: 150 } }
    
    function s(val) { 
        return LayoutMath.s(val, baseScale); 
    }
}
