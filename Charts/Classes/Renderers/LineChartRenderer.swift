//
//  LineChartRenderer.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 4/3/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics

#if !os(OSX)
    import UIKit
#endif


public class LineChartRenderer: LineRadarChartRenderer
{
    public weak var dataProvider: LineChartDataProvider?
    
    public init(dataProvider: LineChartDataProvider?, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    public override func drawData(context context: CGContext)
    {
        guard let lineData = dataProvider?.lineData else { return }
        
        for (var i = 0; i < lineData.dataSetCount; i++)
        {
            guard let set = lineData.getDataSetByIndex(i) else { continue }
            
            if set.isVisible
            {
                if !(set is ILineChartDataSet)
                {
                    fatalError("Datasets for LineChartRenderer must conform to ILineChartDataSet")
                }
                
                drawDataSet(context: context, dataSet: set as! ILineChartDataSet)
            }
        }
    }
    
    public func drawDataSet(context context: CGContext, dataSet: ILineChartDataSet)
    {
        let entryCount = dataSet.entryCount
        
        if (entryCount < 1)
        {
            return
        }
        
        CGContextSaveGState(context)
        
        CGContextSetLineWidth(context, dataSet.lineWidth)
        if (dataSet.lineDashLengths != nil)
        {
            CGContextSetLineDash(context, dataSet.lineDashPhase, dataSet.lineDashLengths!, dataSet.lineDashLengths!.count)
        }
        else
        {
            CGContextSetLineDash(context, 0.0, nil, 0)
        }
        
        // if drawing cubic lines is enabled
        if (dataSet.isDrawCubicEnabled)
        {
            drawCubic(context: context, dataSet: dataSet)
        }
        else
        { // draw normal (straight) lines
            drawLinear(context: context, dataSet: dataSet)
        }
        
        CGContextRestoreGState(context)
    }
    
    public func drawCubic(context context: CGContext, dataSet: ILineChartDataSet)
    {
        guard let
            trans = dataProvider?.getTransformer(dataSet.axisDependency),
            animator = animator
            else { return }
        
        let entryCount = dataSet.entryCount
        
        guard let
            entryFrom = dataSet.entryForXIndex(self.minX < 0 ? self.minX : 0, rounding: .Down),
            entryTo = dataSet.entryForXIndex(self.maxX, rounding: .Up)
            else { return }
        
        let diff = (entryFrom == entryTo) ? 1 : 0
        var minx = max(dataSet.entryIndex(entry: entryFrom) - diff - 1, 0)
        var maxx = min(max(minx + 2, dataSet.entryIndex(entry: entryTo) + 1), entryCount)
        
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        let intensity = dataSet.cubicIntensity
        
        // the path for the cubic-spline
        let cubicPath = CGPathCreateMutable()
        
        var valueToPixelMatrix = trans.valueToPixelMatrix
        
        let size = Int(ceil(CGFloat(maxx - minx) * phaseX + CGFloat(minx)))
        
        if (size - minx >= 2)
        {
            var prevDx: CGFloat = 0.0
            var prevDy: CGFloat = 0.0
            var curDx: CGFloat = 0.0
            var curDy: CGFloat = 0.0
            
            // TODO: Ryan, cheaty mccheaterson
            minx = 0
            maxx = dataSet.entryCount - 1
            
            var prevPrev: ChartDataEntry! = dataSet.entryForIndex(minx)
            var prev: ChartDataEntry! = prevPrev
            var cur: ChartDataEntry! = prev
            var next: ChartDataEntry! = dataSet.entryForIndex(minx + 1)
            
            if cur == nil || next == nil { return }
            
            // We need to use values to support numeric scaling, defaults to xIndex
            var curXVal = self.determineXVal(cur)
            if (curXVal.isNaN) { return }
            
            var nextXVal = self.determineXVal(next)
            if (nextXVal.isNaN) { return }
            
            var prevXVal = self.determineXVal(prev)
            if (prevXVal.isNaN) { return }
            
            var prevPrevXVal = self.determineXVal(prevPrev)
            if (prevPrevXVal.isNaN) { return }
            
            // let the spline start
            CGPathMoveToPoint(cubicPath, &valueToPixelMatrix, CGFloat(curXVal), CGFloat(cur.value) * phaseY)
            
            prevDx = CGFloat(curXVal - prevXVal) * intensity
            prevDy = CGFloat(cur.value - prev.value) * intensity
            
            curDx = CGFloat(nextXVal - curXVal) * intensity
            curDy = CGFloat(next.value - cur.value) * intensity
            
            // the first cubic
            CGPathAddCurveToPoint(cubicPath, &valueToPixelMatrix,
                CGFloat(prevXVal) + prevDx, (CGFloat(prev.value) + prevDy) * phaseY,
                CGFloat(curXVal) - curDx, (CGFloat(cur.value) - curDy) * phaseY,
                CGFloat(curXVal), CGFloat(cur.value) * phaseY)
            
            for (var j = minx + 1, count = min(size, entryCount - 1); j < count; j++)
            {
                prevPrev = prev
                prev = cur
                cur = next
                next = dataSet.entryForIndex(j + 1)
                
                if next == nil { break }
                
                curXVal = self.determineXVal(cur)
                if (curXVal.isNaN) { continue }
                
                nextXVal = self.determineXVal(next)
                if (nextXVal.isNaN) { continue }
                
                prevXVal = self.determineXVal(prev)
                if (prevXVal.isNaN) { continue }
                
                prevPrevXVal = self.determineXVal(prevPrev)
                if (prevPrevXVal.isNaN) { continue }

                
                prevDx = CGFloat(curXVal - prevPrevXVal) * intensity
                prevDy = CGFloat(cur.value - prevPrev.value) * intensity
                curDx = CGFloat(nextXVal - prevXVal) * intensity
                curDy = CGFloat(next.value - prev.value) * intensity
                
                CGPathAddCurveToPoint(cubicPath, &valueToPixelMatrix, CGFloat(prevXVal) + prevDx, (CGFloat(prev.value) + prevDy) * phaseY,
                    CGFloat(curXVal) - curDx,
                    (CGFloat(cur.value) - curDy) * phaseY, CGFloat(curXVal), CGFloat(cur.value) * phaseY)
            }
            
            if (size > entryCount - 1)
            {
                prevPrev = dataSet.entryForIndex(entryCount - (entryCount >= 3 ? 3 : 2))
                prev = dataSet.entryForIndex(entryCount - 2)
                cur = dataSet.entryForIndex(entryCount - 1)
                next = cur
                
                if prevPrev == nil || prev == nil || cur == nil { return }
                
                curXVal = self.determineXVal(cur)
                if (curXVal.isNaN) { return }
                
                nextXVal = self.determineXVal(next)
                if (nextXVal.isNaN) { return }
                
                prevXVal = self.determineXVal(prev)
                if (prevXVal.isNaN) { return }
                
                prevPrevXVal = self.determineXVal(prevPrev)
                if (prevPrevXVal.isNaN) { return }
                
                prevDx = CGFloat(curXVal - prevPrevXVal) * intensity
                prevDy = CGFloat(cur.value - prevPrev.value) * intensity
                curDx = CGFloat(nextXVal - prevXVal) * intensity
                curDy = CGFloat(next.value - prev.value) * intensity
                
                // the last cubic
                CGPathAddCurveToPoint(cubicPath, &valueToPixelMatrix, CGFloat(prevXVal) + prevDx, (CGFloat(prev.value) + prevDy) * phaseY,
                    CGFloat(curXVal) - curDx,
                    (CGFloat(cur.value) - curDy) * phaseY, CGFloat(curXVal), CGFloat(cur.value) * phaseY)
            }
        }
        
        CGContextSaveGState(context)
        
        if (dataSet.isDrawFilledEnabled)
        {
            // Copy this path because we make changes to it
            let fillPath = CGPathCreateMutableCopy(cubicPath)
            
            drawCubicFill(context: context, dataSet: dataSet, spline: fillPath!, matrix: valueToPixelMatrix, from: minx, to: size)
        }
        
        CGContextBeginPath(context)
        CGContextAddPath(context, cubicPath)
        CGContextSetStrokeColorWithColor(context, drawingColor.CGColor)
        CGContextStrokePath(context)
        
        CGContextRestoreGState(context)
    }
    
    public func drawCubicFill(context context: CGContext, dataSet: ILineChartDataSet, spline: CGMutablePath, matrix: CGAffineTransform, from: Int, to: Int)
    {
        guard let dataProvider = dataProvider else { return }
        
        if to - from <= 1
        {
            return
        }
        
        let fillMin = dataSet.fillFormatter?.getFillLinePosition(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0
        
        // Take the from/to xIndex from the entries themselves,
        // so missing entries won't screw up the filling.
        // What we need to draw is line from points of the xIndexes - not arbitrary entry indexes!
        guard let xTo = dataSet.entryForIndex(0) else { return }
        guard let xFrom = dataSet.entryForIndex(dataSet.entryCount - 1) else { return }
        
        let xToVal = self.determineXVal(xTo)
        if (xToVal.isNaN) { return }
        
        let xFromVal = self.determineXVal(xFrom)
        if (xFromVal.isNaN) { return }

        var pt1 = CGPoint(x: xFromVal, y: fillMin)
        var pt2 = CGPoint(x: xToVal, y: fillMin)
        pt1 = CGPointApplyAffineTransform(pt1, matrix)
        pt2 = CGPointApplyAffineTransform(pt2, matrix)
        
        CGPathAddLineToPoint(spline, nil, pt1.x, pt1.y)
        CGPathAddLineToPoint(spline, nil, pt2.x, pt2.y)
        CGPathCloseSubpath(spline)
        
        if dataSet.fill != nil
        {
            drawFilledPath(context: context, path: spline, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
        }
        else
        {
            drawFilledPath(context: context, path: spline, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
        }
    }
    
    private var _lineSegments = [CGPoint](count: 2, repeatedValue: CGPoint())
    
    public func drawLinear(context context: CGContext, dataSet: ILineChartDataSet)
    {
        guard let
            trans = dataProvider?.getTransformer(dataSet.axisDependency),
            animator = animator
            else { return }
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        let entryCount = dataSet.entryCount
        let isDrawSteppedEnabled = dataSet.isDrawSteppedEnabled
        let pointsPerEntryPair = isDrawSteppedEnabled ? 4 : 2
        
        let phaseY = animator.phaseY

        guard let
            entryFrom = dataSet.entryForXIndex(self.minX < 0 ? self.minX : 0, rounding: .Down),
            entryTo = dataSet.entryForXIndex(self.maxX, rounding: .Up)
            else { return }
        
        let diff = (entryFrom == entryTo) ? 1 : 0
        let minx = max(dataSet.entryIndex(entry: entryFrom) - diff, 0)
        let maxx = min(max(minx + 2, dataSet.entryIndex(entry: entryTo) + 1), entryCount)
        
        CGContextSaveGState(context)
        
        CGContextSetLineCap(context, dataSet.lineCapType)

        // more than 1 color
        if (dataSet.colors.count > 1)
        {
            if (_lineSegments.count != pointsPerEntryPair)
            {
                _lineSegments = [CGPoint](count: pointsPerEntryPair, repeatedValue: CGPoint())
            }
            
            for (var j = 0, count = dataSet.entryCount; j < count; j++)
            {
                // Last point, we have already drawn a line to this point
                if (count > 1 && j == count - 1) { break }
                
                guard let e = dataSet.entryForIndex(j) else { continue }
                
                let xVal = self.determineXVal(e)
                if (xVal.isNaN) { continue }
                
                _lineSegments[0].x = xVal
                _lineSegments[0].y = CGFloat(e.value) * phaseY
                
                if (j + 1 < count)
                {
                    guard let eEnd = dataSet.entryForIndex(j + 1) else { break }
                    
                    let xValEnd = self.determineXVal(eEnd)
                    if (xVal.isNaN) { continue }

                    if isDrawSteppedEnabled
                    {
                        _lineSegments[1] = CGPoint(x: xValEnd, y: _lineSegments[0].y)
                        _lineSegments[2] = _lineSegments[1]
                        _lineSegments[3] = CGPoint(x: xValEnd, y: CGFloat(eEnd.value) * phaseY)
                    }
                    else
                    {
                        _lineSegments[1] = CGPoint(x: xValEnd, y: CGFloat(eEnd.value) * phaseY)
                    }
                }
                else
                {
                    _lineSegments[1] = _lineSegments[0]
                }

                for i in 0..<_lineSegments.count
                {
                    _lineSegments[i] = CGPointApplyAffineTransform(_lineSegments[i], valueToPixelMatrix)
                }
                
                if (!viewPortHandler.isInBoundsRight(_lineSegments[0].x))
                {
                    break
                }
                
                // make sure the lines don't do shitty things outside bounds
                if (!viewPortHandler.isInBoundsRight(_lineSegments[0].x)) { break }
                if (!viewPortHandler.isInBoundsLeft(_lineSegments[1].x)
                    || (!viewPortHandler.isInBoundsTop(_lineSegments[0].y) && !viewPortHandler.isInBoundsBottom(_lineSegments[1].y))
                    || (!viewPortHandler.isInBoundsTop(_lineSegments[0].y) && !viewPortHandler.isInBoundsBottom(_lineSegments[1].y)))
                {
                    continue
                }
                
                // get the color that is set for this line-segment
                CGContextSetStrokeColorWithColor(context, dataSet.colorAt(j).CGColor)
                CGContextStrokeLineSegments(context, _lineSegments, pointsPerEntryPair)
            }
        }
        else
        { // only one color per dataset
            
            var e1: ChartDataEntry!
            var e2: ChartDataEntry!
            
            if (_lineSegments.count != max((entryCount - 1) * pointsPerEntryPair, pointsPerEntryPair))
            {
                _lineSegments = [CGPoint](count: max((entryCount - 1) * pointsPerEntryPair, pointsPerEntryPair), repeatedValue: CGPoint())
            }
            
            e1 = dataSet.entryForIndex(minx)
            
            if e1 != nil
            {
                _lineSegments = [CGPoint]()

                for (var x = 1, j = 0, count = dataSet.entryCount; x < count; x++)
                {
                    e1 = dataSet.entryForIndex(x == 0 ? 0 : (x - 1))
                    e2 = dataSet.entryForIndex(x)
                    
                    if e1 == nil || e2 == nil { continue }

                    let xVal1 = self.determineXVal(e1)
                    if (xVal1.isNaN) { continue }
                    let position1 = CGPointApplyAffineTransform(CGPoint(x: CGFloat(xVal1), y: CGFloat(e1.value) * phaseY), valueToPixelMatrix)
                    
                    let xVal2 = self.determineXVal(e2)
                    if (xVal2.isNaN) { continue }
                    let position2 = CGPointApplyAffineTransform(CGPoint(x: CGFloat(xVal2), y: CGFloat(e2.value) * phaseY), valueToPixelMatrix)
                    
                    if (!viewPortHandler.isInBoundsRight(position1.x)) { break }
                    if (!viewPortHandler.isInBoundsLeft(position2.x)
                        || (!viewPortHandler.isInBoundsTop(position1.y) && !viewPortHandler.isInBoundsBottom(position2.y))
                        || (!viewPortHandler.isInBoundsTop(position2.y) && !viewPortHandler.isInBoundsBottom(position1.y)))
                    {
                        continue
                    }
                    
                    _lineSegments.append(position1)
                
                    if isDrawSteppedEnabled
                    {
                        let position3 = CGPointApplyAffineTransform(
                            CGPoint(
                                x: CGFloat(xVal2),
                                y: CGFloat(e1.value) * phaseY
                            ), valueToPixelMatrix)
                        _lineSegments.append(position3)
                        
                        let position4 = CGPointApplyAffineTransform(
                            CGPoint(
                                x: CGFloat(xVal2 ),
                                y: CGFloat(e1.value) * phaseY
                            ), valueToPixelMatrix)
                        _lineSegments.append(position4)
                    }
                
                    _lineSegments.append(position2)
                }
            
                CGContextSetStrokeColorWithColor(context, dataSet.colorAt(0).CGColor)
                CGContextStrokeLineSegments(context, _lineSegments, _lineSegments.count)
            }
        }
        
        CGContextRestoreGState(context)
        
        // if drawing filled is enabled
        if (dataSet.isDrawFilledEnabled && entryCount > 0)
        {
            drawLinearFill(context: context, dataSet: dataSet, minx: minx, maxx: maxx, trans: trans)
        }
    }
    
    public func drawLinearFill(context context: CGContext, dataSet: ILineChartDataSet, minx: Int, maxx: Int, trans: ChartTransformer)
    {
        guard let dataProvider = dataProvider else { return }
        
        let filled = generateFilledPath(
            dataSet: dataSet,
            fillMin: dataSet.fillFormatter?.getFillLinePosition(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0,
            from: minx,
            to: maxx,
            matrix: trans.valueToPixelMatrix)
        
        if dataSet.fill != nil
        {
            drawFilledPath(context: context, path: filled, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
        }
        else
        {
            drawFilledPath(context: context, path: filled, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
        }
    }
    
    /// Generates the path that is used for filled drawing.
    private func generateFilledPath(dataSet dataSet: ILineChartDataSet, fillMin: CGFloat, from: Int, to: Int, var matrix: CGAffineTransform) -> CGPath
    {
        let phaseY = animator?.phaseY ?? 1.0
        let isDrawSteppedEnabled = dataSet.isDrawSteppedEnabled
        
        var e: ChartDataEntry!
        
        let filled = CGPathCreateMutable()
        
        e = dataSet.entryForIndex(0)
        if e != nil
        {
            let xVal = self.determineXVal(e)
            if (xVal.isNaN) { return filled }

            CGPathMoveToPoint(filled, &matrix, xVal, fillMin)
            CGPathAddLineToPoint(filled, &matrix, xVal, CGFloat(e.value) * phaseY)
        }

        for (var x = 1, count = dataSet.entryCount; x < count; x++)
        {
            guard let e = dataSet.entryForIndex(x) else { continue }
            
            let xVal = self.determineXVal(e)
            if (xVal.isNaN) { continue }

            if isDrawSteppedEnabled
            {
                guard let ePrev = dataSet.entryForIndex(x-1) else { continue }
                CGPathAddLineToPoint(filled, &matrix, CGFloat(xVal), CGFloat(ePrev.value) * phaseY)
            }
            
            CGPathAddLineToPoint(filled, &matrix, xVal, CGFloat(e.value) * phaseY)
        }
        
        // close up
        e = dataSet.entryForIndex(dataSet.entryCount - 1)
        if e != nil
        {
            let xVal = self.determineXVal(e)
            if (xVal.isNaN) { return filled }
            
            CGPathAddLineToPoint(filled, &matrix, xVal, fillMin)
        }
        CGPathCloseSubpath(filled)
        
        return filled
    }
    
    public override func drawValues(context context: CGContext)
    {
        guard let
            dataProvider = dataProvider,
            lineData = dataProvider.lineData,
            animator = animator
            else { return }
        
        if (CGFloat(lineData.yValCount) < CGFloat(dataProvider.maxVisibleValueCount) * viewPortHandler.scaleX)
        {
            var dataSets = lineData.dataSets

            let phaseY = animator.phaseY
            
            var pt = CGPoint()
            
            for (var i = 0; i < dataSets.count; i++)
            {
                guard let dataSet = dataSets[i] as? ILineChartDataSet else { continue }
                
                if !dataSet.isDrawValuesEnabled || dataSet.entryCount == 0
                {
                    continue
                }
                
                let valueFont = dataSet.valueFont
                
                guard let formatter = dataSet.valueFormatter else { continue }
                
                let trans = dataProvider.getTransformer(dataSet.axisDependency)
                let valueToPixelMatrix = trans.valueToPixelMatrix
                
                // make sure the values do not interfear with the circles
                var valOffset = Int(dataSet.circleRadius * 1.75)
                
                if (!dataSet.isDrawCirclesEnabled)
                {
                    valOffset = valOffset / 2
                }
                
                for (var j = 0, count = dataSet.entryCount; j < count; j++)
                {
                    guard let e = dataSet.entryForIndex(j) else { break }
                    
                    let xVal = self.determineXVal(e)
                    if (xVal.isNaN) { continue }
                    
                    pt.x = xVal
                    pt.y = CGFloat(e.value) * phaseY
                    pt = CGPointApplyAffineTransform(pt, valueToPixelMatrix)
                    
                    if (!viewPortHandler.isInBoundsRight(pt.x)) { break }
                    if (!viewPortHandler.isInBoundsLeft(pt.x) || !viewPortHandler.isInBoundsY(pt.y)) { continue }
                    
                    ChartUtils.drawText(context: context,
                        text: formatter.stringFromNumber(e.value)!,
                        point: CGPoint(
                            x: pt.x,
                            y: pt.y - CGFloat(valOffset) - valueFont.lineHeight),
                        align: .Center,
                        attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: dataSet.valueTextColorAt(j)])
                }
            }
        }
    }
    
    public override func drawExtras(context context: CGContext)
    {
        drawCircles(context: context)
    }
    
    private func drawCircles(context context: CGContext)
    {
        guard let
            dataProvider = dataProvider,
            lineData = dataProvider.lineData,
            animator = animator
            else { return }

        let phaseY = animator.phaseY
        
        let dataSets = lineData.dataSets
        
        var pt = CGPoint()
        var rect = CGRect()
        
        CGContextSaveGState(context)
        // Circles
        for (var i = 0, count = dataSets.count; i < count; i++)
        {
            guard let dataSet = lineData.getDataSetByIndex(i) as? ILineChartDataSet else { continue }
            
            if !dataSet.isVisible || !dataSet.isDrawCirclesEnabled || dataSet.entryCount == 0 { continue }
            
            let trans = dataProvider.getTransformer(dataSet.axisDependency)
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            let circleRadius = dataSet.circleRadius
            let circleDiameter = circleRadius * 2.0
            let circleHoleDiameter = circleRadius
            let circleHoleRadius = circleHoleDiameter / 2.0
            let isDrawCircleHoleEnabled = dataSet.isDrawCircleHoleEnabled
            
            // TODO - Ryan, this could be a bottleneck for high counts but we can no longer use minX and maxX as an indicator of visible slice
            for (var j = 0, count = dataSet.entryCount; j < count; j++)
            {
                guard let e = dataSet.entryForIndex(j) else { break }
                
                let xVal = self.determineXVal(e)
                if (xVal.isNaN) { continue }
                
                pt.x = xVal
                pt.y = CGFloat(e.value) * phaseY
                pt = CGPointApplyAffineTransform(pt, valueToPixelMatrix)
                
                // If we are outside the right bounds we can stop rendering cricles
                if (!viewPortHandler.isInBoundsRight(pt.x)) { break }
                
                // make sure the circles don't do shitty things outside bounds - Best comment yet, RM
                // If we are outside the left bounds we should continue to the next circle and not render the current index
                if (!viewPortHandler.isInBoundsLeft(pt.x) || !viewPortHandler.isInBoundsY(pt.y)) { continue }
                
                CGContextSetFillColorWithColor(context, dataSet.getCircleColor(j)!.CGColor)
                
                rect.origin.x = pt.x - circleRadius
                rect.origin.y = pt.y - circleRadius
                rect.size.width = circleDiameter
                rect.size.height = circleDiameter
                CGContextFillEllipseInRect(context, rect)
                
                if (isDrawCircleHoleEnabled)
                {
                    CGContextSetFillColorWithColor(context, dataSet.circleHoleColor.CGColor)
                    
                    rect.origin.x = pt.x - circleHoleRadius
                    rect.origin.y = pt.y - circleHoleRadius
                    rect.size.width = circleHoleDiameter
                    rect.size.height = circleHoleDiameter
                    CGContextFillEllipseInRect(context, rect)
                }
            }
        }
        
        CGContextRestoreGState(context)
    }
    
    private func determineXVal (entry: ChartDataEntry) -> CGFloat {
        guard let dataProvider = dataProvider else { return CGFloat.NaN }
        guard let valueType = dataProvider.lineData?.valueType else { return CGFloat.NaN }
        
        switch valueType {
        case .Default:
            return CGFloat(entry.xIndex)
        
        case .Numeric:
            guard let xVal = (dataProvider.lineData?.xValsNumeric[entry.xIndex]) else { return CGFloat.NaN }
            
            return CGFloat(xVal)
            
        case .Temporal:
            guard let xVal = (dataProvider.lineData?.xValsNumeric[entry.xIndex]) else { return CGFloat.NaN }

            return CGFloat(xVal)
        }
    }
    
    
    private var _highlightPointBuffer = CGPoint()
    
    public override func drawHighlighted(context context: CGContext, indices: [ChartHighlight])
    {
        guard let
            lineData = dataProvider?.lineData,
            chartXMax = dataProvider?.chartXMax,
            animator = animator
            else { return }
        
        CGContextSaveGState(context)
        
        for (var i = 0; i < indices.count; i++)
        {
            guard let set = lineData.getDataSetByIndex(indices[i].dataSetIndex) as? ILineChartDataSet else { continue }
            
            if !set.isHighlightEnabled
            {
                continue
            }
            
            CGContextSetStrokeColorWithColor(context, set.highlightColor.CGColor)
            CGContextSetLineWidth(context, set.highlightLineWidth)
            if (set.highlightLineDashLengths != nil)
            {
                CGContextSetLineDash(context, set.highlightLineDashPhase, set.highlightLineDashLengths!, set.highlightLineDashLengths!.count)
            }
            else
            {
                CGContextSetLineDash(context, 0.0, nil, 0)
            }
            
            let xIndex = indices[i].xIndex; // get the x-position
            
            if (CGFloat(xIndex) > CGFloat(chartXMax) * animator.phaseX)
            {
                continue
            }
            
            let yValue = set.yValForXIndex(xIndex)
            if (yValue.isNaN)
            {
                continue
            }
            
            let y = CGFloat(yValue) * animator.phaseY; // get the y-position
            
            _highlightPointBuffer.x = CGFloat(xIndex)
            _highlightPointBuffer.y = y
            
            let trans = dataProvider?.getTransformer(set.axisDependency)
            
            trans?.pointValueToPixel(&_highlightPointBuffer)
            
            // draw the lines
            drawHighlightLines(context: context, point: _highlightPointBuffer, set: set)
        }
        
        CGContextRestoreGState(context)
    }
}