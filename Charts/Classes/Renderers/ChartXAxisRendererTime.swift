//
//  ChartXAxisRendererTime.swift
//  Charts
//
//  Created by Ryan Macleod on 2016-03-20.
//  Copyright © 2016 Cumul8. All rights reserved.
//  Licensed under Apache License 2.0
//

import Foundation
import CoreGraphics

#if !os(OSX)
    import UIKit
#endif


public class ChartXAxisRendererTime: ChartXAxisRenderer
{
    /// the minimum value on the x-axis
    public var chartMinX: Int = 0
    
    /// the maximum value on the x-axis
    public var chartMaxX: Int = 0
    
    /// Calculates the minimum and maximum x-value the chart can currently display (with the given zoom level).
    public override func calcXBounds(chart chart: BarLineChartViewBase, xAxisModulus: Int)
    {
        let low = chart.lowestVisibleXValue
        let high = chart.highestVisibleXValue
        
        minX = Int(ceil(low))
        maxX = Int(ceil(high))
        chartMaxX = Int(ceil(chart.chartXMax))
        chartMinX = Int(ceil(chart.chartXMin))
        
        // When are xbounds change we need to recompute our axis
        computeAxis(xValAverageLength: (chart._data?.xValAverageLength)!, xValues: xAxis!.values)
    }
    
    public override func computeAxis(xValAverageLength xValAverageLength: Double, xValues: [String?])
    {
        guard let xAxis = xAxis else { return }
        
        var a = ""
        
        let max = Int(round(xValAverageLength + Double(xAxis.spaceBetweenLabels)))

        for (var i = 0; i < max; i++)
        {
            a += "h"
        }

        let widthText = a as NSString
        
        let labelSize = widthText.sizeWithAttributes([NSFontAttributeName: xAxis.labelFont])
        
        let labelWidth = labelSize.width
        let labelHeight = labelSize.height
        
        let labelRotatedSize = ChartUtils.sizeOfRotatedRectangle(labelSize, degrees: xAxis.labelRotationAngle)
        
        xAxis.labelWidth = labelWidth
        xAxis.labelHeight = labelHeight
        xAxis.labelRotatedWidth = labelRotatedSize.width
        xAxis.labelRotatedHeight = labelRotatedSize.height
        
        xAxis.values = xValues
        
        computeAxisValues(min: self.minX, max: self.maxX)
    }
    
    /// Sets up the y-axis labels. Computes the desired number of labels between
    /// the two given extremes. Unlike the papareXLabels() method, this method
    /// needs to be called upon every refresh of the view.
    public func computeAxisValues(min min: Int, max: Int)
    {
        guard let xAxis = xAxis else { return }
        
        let xMin = Double(min)
        let xMax = Double(max)
        
        let labelCount = floor(viewPortHandler.contentWidth / xAxis.labelRotatedWidth)
        let range = abs(xMax - xMin)
        
        if (labelCount == 0 || range <= 0)
        {
            xAxis.values = [String?]()
            return
        }
        
        let rawInterval = range / Double(labelCount)
        var interval = ChartUtils.roundToNextSignificant(number: Double(rawInterval))
        let intervalMagnitude = pow(10.0, round(log10(interval)))
        let intervalSigDigit = (interval / intervalMagnitude)
        if (intervalSigDigit > 5)
        {
            // Use one order of magnitude higher, to avoid intervals like 0.9 or 90
            interval = floor(10.0 * intervalMagnitude)
        }
        
        let first = ceil(Double(xMin) / interval) * interval
        let last = ChartUtils.nextUp(floor(Double(xMax) / interval) * interval)
        
        var f: Double,
        i: Int,
        n = 0
        for (f = first; f <= last; f += interval) {
            ++n
        }
        
        if (xAxis.values.count < n) {
            // Ensure stops contains at least numStops elements.
            xAxis.values = [String?](count: n, repeatedValue: "0.0")
        } else if (xAxis.values.count > n) {
            xAxis.values.removeRange(n..<xAxis.values.count)
        }
        
        for (f = first, i = 0; i < n; f += interval, ++i) {
            // Fix for IEEE negative zero case (Where value == -0.0, and 0.0 == -0.0)
            if (f == 0.0) { f = 0.0 }
            
            xAxis.values[i] = String(f)
        }
    }

    private var _axisLineSegmentsBuffer = [CGPoint](count: 2, repeatedValue: CGPoint())
    
    public override func renderAxisLine(context context: CGContext)
    {
        guard let xAxis = xAxis else { return }
        
        if (!xAxis.isEnabled || !xAxis.isDrawAxisLineEnabled)
        {
            return
        }
        
        CGContextSaveGState(context)
        
        CGContextSetStrokeColorWithColor(context, xAxis.axisLineColor.CGColor)
        CGContextSetLineWidth(context, xAxis.axisLineWidth)
        if (xAxis.axisLineDashLengths != nil)
        {
            CGContextSetLineDash(context, xAxis.axisLineDashPhase, xAxis.axisLineDashLengths, xAxis.axisLineDashLengths.count)
        }
        else
        {
            CGContextSetLineDash(context, 0.0, nil, 0)
        }
        
        if (xAxis.labelPosition == .Top
            || xAxis.labelPosition == .TopInside
            || xAxis.labelPosition == .BothSided)
        {
            _axisLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
            _axisLineSegmentsBuffer[0].y = viewPortHandler.contentTop
            _axisLineSegmentsBuffer[1].x = viewPortHandler.contentRight
            _axisLineSegmentsBuffer[1].y = viewPortHandler.contentTop
            CGContextStrokeLineSegments(context, _axisLineSegmentsBuffer, 2)
        }
        
        if (xAxis.labelPosition == .Bottom
            || xAxis.labelPosition == .BottomInside
            || xAxis.labelPosition == .BothSided)
        {
            _axisLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
            _axisLineSegmentsBuffer[0].y = viewPortHandler.contentBottom
            _axisLineSegmentsBuffer[1].x = viewPortHandler.contentRight
            _axisLineSegmentsBuffer[1].y = viewPortHandler.contentBottom
            CGContextStrokeLineSegments(context, _axisLineSegmentsBuffer, 2)
        }
        
        CGContextRestoreGState(context)
    }
    
    /// draws the x-labels on the specified y-position
    public override func drawLabels(context context: CGContext, pos: CGFloat, anchor: CGPoint)
    {
        guard let xAxis = xAxis else { return }
        
        let paraStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        paraStyle.alignment = .Center
        
        let labelAttrs = [NSFontAttributeName: xAxis.labelFont,
            NSForegroundColorAttributeName: xAxis.labelTextColor,
            NSParagraphStyleAttributeName: paraStyle]
        let labelRotationAngleRadians = xAxis.labelRotationAngle * ChartUtils.Math.FDEG2RAD
        
        let valueToPixelMatrix = transformer.valueToPixelMatrix
        
        var position = CGPoint(x: 0.0, y: 0.0)
        
        var labelMaxSize = CGSize()
        
        if (xAxis.isWordWrapEnabled)
        {
            labelMaxSize.width = xAxis.wordWrapWidthPercent * valueToPixelMatrix.a
        }
        
        for (var i = 0; i < xAxis.values.count; i++)
        {
            let label = xAxis.values[i]!
            let labelValue = Double(label)!
            
            position.x = CGFloat(labelValue)
            position.y = 0.0
            position = CGPointApplyAffineTransform(position, valueToPixelMatrix)
            
            if (viewPortHandler.isInBoundsX(position.x))
            {
                let labelns = label

                if (xAxis.isAvoidFirstLastClippingEnabled)
                {
                    // avoid clipping of the last
                    if (i == xAxis.values.count - 1 && xAxis.values.count > 1)
                    {
                        let width = labelns.boundingRectWithSize(labelMaxSize, options: .UsesLineFragmentOrigin, attributes: labelAttrs, context: nil).size.width
                        
                        if (width > viewPortHandler.offsetRight * 2.0
                            && position.x + width > viewPortHandler.chartWidth)
                        {
                            position.x -= width / 2.0
                        }
                    }
                    else if (i == 0)
                    { // avoid clipping of the first
                        let width = labelns.boundingRectWithSize(labelMaxSize, options: .UsesLineFragmentOrigin, attributes: labelAttrs, context: nil).size.width
                        position.x += width / 2.0
                    }
                }
   
                drawLabel(context: context, label: labelns, xIndex: i, x: position.x, y: pos, attributes: labelAttrs, constrainedToSize: labelMaxSize, anchor: anchor, angleRadians: labelRotationAngleRadians)
            }
        }
    }
    
    private var _gridLineSegmentsBuffer = [CGPoint](count: 2, repeatedValue: CGPoint())
    
    public override func renderGridLines(context context: CGContext)
    {
        guard let xAxis = xAxis else { return }
        
        if (!xAxis.isDrawGridLinesEnabled || !xAxis.isEnabled)
        {
            return
        }
        
        CGContextSaveGState(context)
        
        CGContextSetShouldAntialias(context, xAxis.gridAntialiasEnabled)
        CGContextSetStrokeColorWithColor(context, xAxis.gridColor.CGColor)
        CGContextSetLineWidth(context, xAxis.gridLineWidth)
        CGContextSetLineCap(context, xAxis.gridLineCap)
        
        if (xAxis.gridLineDashLengths != nil)
        {
            CGContextSetLineDash(context, xAxis.gridLineDashPhase, xAxis.gridLineDashLengths, xAxis.gridLineDashLengths.count)
        }
        else
        {
            CGContextSetLineDash(context, 0.0, nil, 0)
        }
        
        let valueToPixelMatrix = transformer.valueToPixelMatrix
        
        var position = CGPoint(x: 0.0, y: 0.0)
        
        for (var i = 0; i < xAxis.values.count; i++)
        {
            position.x = CGFloat(Double(xAxis.values[i]!)!)
            position.y = 0.0
            position = CGPointApplyAffineTransform(position, valueToPixelMatrix)
            
            if (position.x >= viewPortHandler.offsetLeft
                && position.x <= viewPortHandler.chartWidth)
            {
                _gridLineSegmentsBuffer[0].x = position.x
                _gridLineSegmentsBuffer[0].y = viewPortHandler.contentTop
                _gridLineSegmentsBuffer[1].x = position.x
                _gridLineSegmentsBuffer[1].y = viewPortHandler.contentBottom
                CGContextStrokeLineSegments(context, _gridLineSegmentsBuffer, 2)
            }
        }
        
        CGContextRestoreGState(context)
    }
}