import QtQuick
import QtQuick.Shapes
import Caelestia.Config

// Animated streak flame. Scales to any size (default 18x18); drawn on a 64x64 design grid.
// Flame shapes and motion come from the supplied Lottie: the outer and inner flame morph in
// 16 linear steps over a 2 s loop while the whole flame bobs with an ease-in-out.
// The last keyframe equals the first, so the loop has no seam.
Item {
    id: root
    implicitWidth: 18
    implicitHeight: 18
    width: implicitWidth
    height: implicitHeight

    // Set to false for a still flame (bind it to your reduced-motion setting).
    property bool animated: true
    property bool autoplay: false        // static by default, true on hover
    property int duration: 2000          // one full loop, ms
    readonly property real restProgress: 0.088 // straight-up frame where tip aligns with base (33.5)
    property real progress: restProgress // position in the loop

    // Colors: follows Caelestia theming (matches streak text & pill background)
    property color outerColor: Colours.palette.m3onTertiaryContainer
    property color innerColor: Colours.palette.m3tertiaryContainer

    // Scale of inner flame core (0.75 = 25% smaller inner core, giving thicker flame body)
    property real innerScale: 0.75
    readonly property real innerCenterX: 33.5
    readonly property real innerCenterY: 33.0

    readonly property real k: (width > 0 ? width : (implicitWidth > 0 ? implicitWidth : 48)) / 64 // design units -> pixels
    readonly property real bobDistance: 8.18

    // Keyframes: [startX, startY, then 6 x (c1x, c1y, c2x, c2y, x, y)], in 64x64 design units.
    readonly property var outerTimes: [0.00000, 0.06250, 0.12500, 0.18750, 0.25000, 0.31250, 0.37500, 0.43750, 0.50000, 0.56250, 0.62500, 0.68750, 0.75000, 0.81250, 0.87500, 0.93750, 1.00000]
    readonly property var outerFrames: [
            [33.45, 52.82, 25.47, 52.82, 9.82, 46.67, 9.82, 31.95, 9.82, 27.2, 10.89, 19.33, 15.65, 12.83, 20.41, 6.33, 27.16, 2.45, 31.76, 3.63, 36.36, 4.8, 31.87, 11.1, 38.36, 17.74, 42.5, 21.98, 48.48, 25.51, 51.24, 30.88, 56.61, 46.53, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 11.05, 47.91, 13.81, 31.49, 15.04, 24.74, 17.64, 18.25, 19.79, 14.98, 21.94, 11.7, 22.55, 5.87, 26.24, 3.58, 30.08, 1.18, 36.35, 6.68, 42.84, 13.32, 46.98, 17.57, 50.17, 23.06, 52.01, 30.27, 56.08, 46.21, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 11.36, 48.22, 14.12, 31.8, 15.34, 25.05, 21.79, 19.33, 25.78, 15.29, 29.76, 11.24, 32.37, 3.08, 35.13, 3.02, 37.9, 2.97, 40.65, 2.54, 47.13, 9.18, 48.94, 11.86, 52.47, 16.92, 54, 30.42, 55.98, 47.82, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 9.21, 46.99, 11.97, 30.57, 13.2, 23.82, 17.95, 17.33, 21.94, 13.29, 25.93, 9.25, 37.9, 2.56, 41.88, 3.6, 45.87, 4.65, 41.34, 10.96, 44.99, 17.01, 48.63, 23.06, 50.63, 26.58, 51.55, 30.27, 54.92, 47.45, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 9.82, 46.67, 9.82, 31.95, 9.82, 27.2, 10.89, 19.33, 15.65, 12.83, 20.41, 6.33, 27.16, 2.45, 31.76, 3.63, 36.36, 4.8, 31.87, 11.1, 38.36, 17.74, 42.5, 21.98, 48.48, 25.51, 51.24, 30.88, 56.61, 46.53, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 11.05, 47.91, 13.81, 31.49, 15.04, 24.74, 17.64, 18.25, 19.79, 14.98, 21.94, 11.7, 22.55, 5.87, 26.24, 3.58, 30.08, 1.18, 36.35, 6.68, 42.84, 13.32, 46.98, 17.57, 50.17, 23.06, 52.01, 30.27, 56.08, 46.21, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 11.36, 48.22, 14.12, 31.8, 15.34, 25.05, 21.79, 19.33, 25.78, 15.29, 29.76, 11.24, 32.37, 3.08, 35.13, 3.02, 37.9, 2.97, 40.65, 2.54, 47.13, 9.18, 48.94, 11.86, 52.47, 16.92, 54, 30.42, 55.98, 47.82, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 9.21, 46.99, 11.97, 30.57, 13.2, 23.82, 17.95, 17.33, 21.94, 13.29, 25.93, 9.25, 37.9, 2.56, 41.88, 3.6, 45.87, 4.65, 41.34, 10.96, 44.99, 17.01, 48.63, 23.06, 50.63, 26.58, 51.55, 30.27, 54.92, 47.45, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 9.82, 46.67, 9.82, 31.95, 9.82, 27.2, 10.89, 19.33, 15.65, 12.83, 20.41, 6.33, 27.16, 2.45, 31.76, 3.63, 36.36, 4.8, 31.87, 11.1, 38.36, 17.74, 42.5, 21.98, 48.48, 25.51, 51.24, 30.88, 56.61, 46.53, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 11.05, 47.91, 13.81, 31.49, 15.04, 24.74, 17.64, 18.25, 19.79, 14.98, 21.94, 11.7, 22.55, 5.87, 26.24, 3.58, 30.08, 1.18, 36.35, 6.68, 42.84, 13.32, 46.98, 17.57, 50.17, 23.06, 52.01, 30.27, 56.08, 46.21, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 11.36, 48.22, 14.12, 31.8, 15.34, 25.05, 21.79, 19.33, 25.78, 15.29, 29.76, 11.24, 32.37, 3.08, 35.13, 3.02, 37.9, 2.97, 40.65, 2.54, 47.13, 9.18, 48.94, 11.86, 52.47, 16.92, 54, 30.42, 55.98, 47.82, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 9.21, 46.99, 11.97, 30.57, 13.2, 23.82, 17.95, 17.33, 21.94, 13.29, 25.93, 9.25, 37.9, 2.56, 41.88, 3.6, 45.87, 4.65, 41.34, 10.96, 44.99, 17.01, 48.63, 23.06, 50.63, 26.58, 51.55, 30.27, 54.92, 47.45, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 9.82, 46.67, 9.82, 31.95, 9.82, 27.2, 10.89, 19.33, 15.65, 12.83, 20.41, 6.33, 27.16, 2.45, 31.76, 3.63, 36.36, 4.8, 31.87, 11.1, 38.36, 17.74, 42.5, 21.98, 48.48, 25.51, 51.24, 30.88, 56.61, 46.53, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 11.05, 47.91, 13.81, 31.49, 15.04, 24.74, 17.64, 18.25, 19.79, 14.98, 21.94, 11.7, 22.55, 5.87, 26.24, 3.58, 30.08, 1.18, 36.35, 6.68, 42.84, 13.32, 46.98, 17.57, 50.17, 23.06, 52.01, 30.27, 56.08, 46.21, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 11.36, 48.22, 14.12, 31.8, 15.34, 25.05, 21.79, 19.33, 25.78, 15.29, 29.76, 11.24, 32.37, 3.08, 35.13, 3.02, 37.9, 2.97, 40.65, 2.54, 47.13, 9.18, 48.94, 11.86, 52.47, 16.92, 54, 30.42, 55.98, 47.82, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 9.21, 46.99, 11.97, 30.57, 13.2, 23.82, 17.95, 17.33, 21.94, 13.29, 25.93, 9.25, 37.9, 2.56, 41.88, 3.6, 45.87, 4.65, 41.34, 10.96, 44.99, 17.01, 48.63, 23.06, 50.63, 26.58, 51.55, 30.27, 54.92, 47.45, 41.42, 52.82, 33.45, 52.82],
            [33.45, 52.82, 25.47, 52.82, 9.82, 46.67, 9.82, 31.95, 9.82, 27.2, 10.89, 19.33, 15.65, 12.83, 20.41, 6.33, 27.16, 2.45, 31.76, 3.63, 36.36, 4.8, 31.87, 11.1, 38.36, 17.74, 42.5, 21.98, 48.48, 25.51, 51.24, 30.88, 56.61, 46.53, 41.42, 52.82, 33.45, 52.82]
        ]
    readonly property var innerTimes: [0.00000, 0.04583, 0.10833, 0.17083, 0.23333, 0.29583, 0.35833, 0.42083, 0.48333, 0.54583, 0.60833, 0.67083, 0.73333, 0.79583, 0.85833, 0.92083, 0.98333, 1.00000]
    readonly property var innerFrames: [
            [47.83, 36.31, 47.83, 30.05, 44.9, 28.85, 40.33, 25.31, 35.86, 21.83, 34.32, 19.07, 31.33, 19.08, 28.75, 19.1, 23.72, 21.88, 21.57, 26.06, 19.32, 30.36, 19.1, 31.98, 19.1, 36.33, 19.1, 43.05, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.83, 43.03, 47.83, 36.31],
            [47.99, 36.31, 47.99, 30.05, 44.65, 27.39, 39.46, 24.16, 34.64, 21.16, 28.42, 18.88, 26.43, 18.93, 24.14, 18.99, 22.94, 20.67, 21.33, 25.45, 19.94, 29.57, 19.61, 32.52, 19.61, 36.39, 19.61, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.99, 43.03, 47.99, 36.31],
            [47.82, 36.04, 48.73, 29.7, 48.41, 27.83, 46.38, 24.63, 44.49, 21.63, 38.26, 18.86, 34.91, 18.86, 31.78, 18.86, 30.93, 21.55, 28.62, 24.58, 26.3, 27.61, 20.22, 28.48, 20.04, 36.39, 19.9, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 46.86, 42.7, 47.82, 36.04],
            [47.82, 36.19, 48.05, 33.05, 48.02, 30.12, 47.76, 27.38, 47.42, 23.85, 44.93, 18.88, 41.57, 18.88, 38.44, 18.88, 35, 21.67, 31.23, 24.29, 28.09, 26.47, 19.78, 28.48, 19.61, 36.39, 19.46, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.32, 42.89, 47.82, 36.19],
            [47.78, 36.31, 47.78, 30.05, 44.99, 29.38, 40.65, 25.73, 36.3, 22.08, 36.47, 19.14, 33.11, 19.14, 30.42, 19.14, 24, 22.32, 21.66, 26.28, 19.09, 30.64, 18.91, 31.78, 18.91, 36.31, 18.91, 43.03, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.78, 43.03, 47.78, 36.31],
            [47.99, 36.31, 47.99, 30.05, 44.65, 27.39, 39.46, 24.16, 34.64, 21.16, 28.42, 18.88, 26.43, 18.93, 24.14, 18.99, 22.94, 20.67, 21.33, 25.45, 19.94, 29.57, 19.61, 32.52, 19.61, 36.39, 19.61, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.99, 43.03, 47.99, 36.31],
            [47.82, 36.04, 48.73, 29.7, 48.41, 27.83, 46.38, 24.63, 44.49, 21.63, 38.26, 18.86, 34.91, 18.86, 31.78, 18.86, 30.93, 21.55, 28.62, 24.58, 26.3, 27.61, 20.22, 28.48, 20.04, 36.39, 19.9, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 46.86, 42.7, 47.82, 36.04],
            [47.82, 36.19, 48.05, 33.05, 48.02, 30.12, 47.76, 27.38, 47.42, 23.85, 44.93, 18.88, 41.57, 18.88, 38.44, 18.88, 35, 21.67, 31.23, 24.29, 28.09, 26.47, 19.78, 28.48, 19.61, 36.39, 19.46, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.32, 42.89, 47.82, 36.19],
            [47.78, 36.31, 47.78, 30.05, 44.99, 29.38, 40.65, 25.73, 36.3, 22.08, 36.47, 19.14, 33.11, 19.14, 30.42, 19.14, 24, 22.32, 21.66, 26.28, 19.09, 30.64, 18.91, 31.78, 18.91, 36.31, 18.91, 43.03, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.78, 43.03, 47.78, 36.31],
            [47.99, 36.31, 47.99, 30.05, 44.65, 27.39, 39.46, 24.16, 34.64, 21.16, 28.42, 18.88, 26.43, 18.93, 24.14, 18.99, 22.94, 20.67, 21.33, 25.45, 19.94, 29.57, 19.61, 32.52, 19.61, 36.39, 19.61, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.99, 43.03, 47.99, 36.31],
            [47.82, 36.04, 48.73, 29.7, 48.41, 27.83, 46.38, 24.63, 44.49, 21.63, 38.26, 18.86, 34.91, 18.86, 31.78, 18.86, 30.93, 21.55, 28.62, 24.58, 26.3, 27.61, 20.22, 28.48, 20.04, 36.39, 19.9, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 46.86, 42.7, 47.82, 36.04],
            [47.82, 36.19, 48.05, 33.05, 48.02, 30.12, 47.76, 27.38, 47.42, 23.85, 44.93, 18.88, 41.57, 18.88, 38.44, 18.88, 35, 21.67, 31.23, 24.29, 28.09, 26.47, 19.78, 28.48, 19.61, 36.39, 19.46, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.32, 42.89, 47.82, 36.19],
            [47.78, 36.31, 47.78, 30.05, 44.99, 29.38, 40.65, 25.73, 36.3, 22.08, 36.47, 19.14, 33.11, 19.14, 30.42, 19.14, 24, 22.32, 21.66, 26.28, 19.09, 30.64, 18.91, 31.78, 18.91, 36.31, 18.91, 43.03, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.78, 43.03, 47.78, 36.31],
            [47.99, 36.31, 47.99, 30.05, 44.65, 27.39, 39.46, 24.16, 34.64, 21.16, 28.42, 18.88, 26.43, 18.93, 24.14, 18.99, 22.94, 20.67, 21.33, 25.45, 19.94, 29.57, 19.61, 32.52, 19.61, 36.39, 19.61, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.99, 43.03, 47.99, 36.31],
            [47.82, 36.04, 48.73, 29.7, 48.41, 27.83, 46.38, 24.63, 44.49, 21.63, 38.26, 18.86, 34.91, 18.86, 31.78, 18.86, 30.93, 21.55, 28.62, 24.58, 26.3, 27.61, 20.22, 28.48, 20.04, 36.39, 19.9, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 46.86, 42.7, 47.82, 36.04],
            [47.82, 36.19, 48.05, 33.05, 48.02, 30.12, 47.76, 27.38, 47.42, 23.85, 44.93, 18.88, 41.57, 18.88, 38.44, 18.88, 35, 21.67, 31.23, 24.29, 28.09, 26.47, 19.78, 28.48, 19.61, 36.39, 19.46, 43.11, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.32, 42.89, 47.82, 36.19],
            [47.78, 36.31, 47.78, 30.05, 44.99, 29.38, 40.65, 25.73, 36.3, 22.08, 36.47, 19.14, 33.11, 19.14, 30.42, 19.14, 24, 22.32, 21.66, 26.28, 19.09, 30.64, 18.91, 31.78, 18.91, 36.31, 18.91, 43.03, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.78, 43.03, 47.78, 36.31],
            [47.83, 36.31, 47.83, 30.05, 44.9, 28.85, 40.33, 25.31, 35.86, 21.83, 34.32, 19.07, 31.33, 19.08, 28.75, 19.1, 23.72, 21.88, 21.57, 26.06, 19.32, 30.36, 19.1, 31.98, 19.1, 36.33, 19.1, 43.05, 25.37, 46.74, 33.34, 46.74, 41.31, 46.74, 47.83, 43.03, 47.83, 36.31]
        ]

    // Linear interpolation between neighbouring keyframes with 0..1 cycle wrap.
    function frameAt(times, frames, p) {
        var pNorm = p % 1.0;
        if (pNorm < 0) pNorm += 1.0;
        var i = 0
        while (i < times.length - 2 && pNorm >= times[i + 1])
            i++
        var u = (pNorm - times[i]) / (times[i + 1] - times[i])
        var a = frames[i], b = frames[i + 1], out = new Array(a.length)
        for (var n = 0; n < a.length; n++)
            out[n] = a[n] + (b[n] - a[n]) * u
        return out
    }

    // cubic-bezier(.5, 0, .5, 1) easing: solve x(s) = u, return y(s).
    function easeInOut(u) {
        var s = u
        for (var n = 0; n < 8; n++) {
            var x = 1.5 * s * (1 - s) + s * s * s - u
            var dx = 1.5 - 3 * s + 3 * s * s
            if (Math.abs(dx) < 1e-6) break
            s -= x / dx
        }
        s = Math.max(0, Math.min(1, s))
        return 3 * s * s - 2 * s * s * s
    }

    // Both layers are driven by the single `progress` value, so they can never drift apart.
    readonly property var outer: animated ? frameAt(outerTimes, outerFrames, progress) : outerFrames[0]
    readonly property var innerRaw: animated ? frameAt(innerTimes, innerFrames, progress) : innerFrames[0]
    readonly property var inner: {
        var raw = innerRaw;
        var arr = new Array(raw.length);
        var cx = innerCenterX, cy = innerCenterY, s = innerScale;
        for (var i = 0; i < raw.length; i += 2) {
            arr[i] = cx + (raw[i] - cx) * s;
            arr[i + 1] = cy + (raw[i + 1] - cy) * s;
        }
        return arr;
    }
    // Bobbing motion:
    // At rest (progress = restProgress), sits at (bobDistance / 2) = 4.09, matching SVG's .sf-rest translate(0 4.09).
    // When playing, oscillates smoothly between 0 and bobDistance.
    readonly property real bob: animated
        ? (bobDistance / 2) * (1 - Math.sin(2 * Math.PI * (progress - restProgress)))
        : bobDistance / 2

    property bool isLooping: false

    NumberAnimation {
        id: loopAnim
        target: root
        property: "progress"
        from: root.restProgress
        to: root.restProgress + 1.0
        duration: root.duration
        loops: Animation.Infinite
        running: root.animated && root.isLooping && root.visible
    }

    onAutoplayChanged: {
        if (autoplay) {
            root.isLooping = true;
        } else {
            root.isLooping = false;
            root.progress = root.restProgress;
        }
    }

    Shape {
        id: shape
        width: root.width
        height: root.height
        y: root.bob * root.k

        ShapePath {
            id: outerPath
            strokeColor: "transparent"
            fillColor: root.outerColor
            startX: root.outer[0] * root.k
            startY: root.outer[1] * root.k
            PathCubic {
                control1X: root.outer[2] * root.k;   control1Y: root.outer[3] * root.k
                control2X: root.outer[4] * root.k; control2Y: root.outer[5] * root.k
                x: root.outer[6] * root.k;         y: root.outer[7] * root.k
            }
            PathCubic {
                control1X: root.outer[8] * root.k;   control1Y: root.outer[9] * root.k
                control2X: root.outer[10] * root.k; control2Y: root.outer[11] * root.k
                x: root.outer[12] * root.k;         y: root.outer[13] * root.k
            }
            PathCubic {
                control1X: root.outer[14] * root.k;   control1Y: root.outer[15] * root.k
                control2X: root.outer[16] * root.k; control2Y: root.outer[17] * root.k
                x: root.outer[18] * root.k;         y: root.outer[19] * root.k
            }
            PathCubic {
                control1X: root.outer[20] * root.k;   control1Y: root.outer[21] * root.k
                control2X: root.outer[22] * root.k; control2Y: root.outer[23] * root.k
                x: root.outer[24] * root.k;         y: root.outer[25] * root.k
            }
            PathCubic {
                control1X: root.outer[26] * root.k;   control1Y: root.outer[27] * root.k
                control2X: root.outer[28] * root.k; control2Y: root.outer[29] * root.k
                x: root.outer[30] * root.k;         y: root.outer[31] * root.k
            }
            PathCubic {
                control1X: root.outer[32] * root.k;   control1Y: root.outer[33] * root.k
                control2X: root.outer[34] * root.k; control2Y: root.outer[35] * root.k
                x: root.outer[36] * root.k;         y: root.outer[37] * root.k
            }
        }

        ShapePath {
            id: innerPath
            strokeColor: "transparent"
            fillColor: root.innerColor
            startX: root.inner[0] * root.k
            startY: root.inner[1] * root.k
            PathCubic {
                control1X: root.inner[2] * root.k;   control1Y: root.inner[3] * root.k
                control2X: root.inner[4] * root.k; control2Y: root.inner[5] * root.k
                x: root.inner[6] * root.k;         y: root.inner[7] * root.k
            }
            PathCubic {
                control1X: root.inner[8] * root.k;   control1Y: root.inner[9] * root.k
                control2X: root.inner[10] * root.k; control2Y: root.inner[11] * root.k
                x: root.inner[12] * root.k;         y: root.inner[13] * root.k
            }
            PathCubic {
                control1X: root.inner[14] * root.k;   control1Y: root.inner[15] * root.k
                control2X: root.inner[16] * root.k; control2Y: root.inner[17] * root.k
                x: root.inner[18] * root.k;         y: root.inner[19] * root.k
            }
            PathCubic {
                control1X: root.inner[20] * root.k;   control1Y: root.inner[21] * root.k
                control2X: root.inner[22] * root.k; control2Y: root.inner[23] * root.k
                x: root.inner[24] * root.k;         y: root.inner[25] * root.k
            }
            PathCubic {
                control1X: root.inner[26] * root.k;   control1Y: root.inner[27] * root.k
                control2X: root.inner[28] * root.k; control2Y: root.inner[29] * root.k
                x: root.inner[30] * root.k;         y: root.inner[31] * root.k
            }
            PathCubic {
                control1X: root.inner[32] * root.k;   control1Y: root.inner[33] * root.k
                control2X: root.inner[34] * root.k; control2Y: root.inner[35] * root.k
                x: root.inner[36] * root.k;         y: root.inner[37] * root.k
            }
        }
    }
}
