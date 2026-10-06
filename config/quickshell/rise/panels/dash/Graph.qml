import QtQuick

// Area graph of `values`, newest on the right; maxValue 0 = auto-scale.
Canvas {
    property var values: []
    property real maxValue: 100
    property int slots: 60
    property color lineColor: "white"
    property real fillAlpha: 0.22
    property real lineWidth: 2
    onValuesChanged: requestPaint()
    onMaxValueChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var v = values || [], n = v.length
        if (n < 2) return
        var max = maxValue > 0 ? maxValue : Math.max.apply(null, v.concat([1]))
        var step = width / (slots - 1)
        var x0 = width - (n - 1) * step
        function y(val) { return height - 2 - (height - 6) * Math.max(0, Math.min(1, val / max)) }
        ctx.beginPath()
        ctx.moveTo(x0, height)
        for (var i = 0; i < n; i++) ctx.lineTo(x0 + i * step, y(v[i]))
        ctx.lineTo(x0 + (n - 1) * step, height)
        ctx.closePath()
        var g = ctx.createLinearGradient(0, 0, 0, height)
        g.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, fillAlpha))
        g.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0))
        ctx.fillStyle = g
        ctx.fill()
        ctx.beginPath()
        for (var j = 0; j < n; j++) {
            if (j === 0) ctx.moveTo(x0, y(v[0])); else ctx.lineTo(x0 + j * step, y(v[j]))
        }
        ctx.strokeStyle = lineColor
        ctx.lineWidth = lineWidth
        ctx.lineJoin = "round"
        ctx.stroke()
    }
}
