//
//  ScatterChartView.swift
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

/// The ScatterChart. Draws dots, triangles, squares and custom shapes into the chartview.
public class ScatterChartView: BarLineChartViewBase, ScatterChartDataProvider
{
    public override func initialize()
    {
        super.initialize()
        
        renderer = ScatterChartRenderer(dataProvider: self, animator: _animator, viewPortHandler: _viewPortHandler)
        
        _chartXMin = -0.5
    }

    public override func calcMinMax()
    {
        super.calcMinMax()

        if (self._valueType == .Numeric) {
            self.calculateNumbericMinMax()
        } else {
            self.calculateIndexMinMax()
        }
    }
    
    private func calculateIndexMinMax () {
        guard let data = _data else { return }
        
        if (_deltaX == 0.0 && data.yValCount > 0)
        {
            _deltaX = 1.0
        }
        
        _chartXMax += 0.5
        _deltaX = CGFloat(abs(_chartXMax - _chartXMin))
    }
    
    private func calculateNumbericMinMax () {
        guard let data = _data else { return }

        if (_deltaX == 0.0 && data.yValCount > 0)
        {
            _deltaX = 1.0
        }
        
        var maxValue = _chartXMax
        var minValue = _chartXMin
        for (var i = 0, len = data.xVals.count; i < len; i++) {
            guard let value = Double(data.xVals[i]!) else {
                continue
            }
            
            if (value > maxValue) { maxValue = value }
            if (value < minValue) { minValue = value }
        }
        
        // Add 1 percent padding so we aren't clipping our values
        let padding = (maxValue - minValue) * 0.01
        
        _chartXMax = maxValue + padding
        _chartXMin = minValue - padding
        _deltaX = CGFloat(abs(_chartXMax - _chartXMin))
    }
    
    /// calculates the modulus for x-labels and grid
    internal override func calcModulus()
    {
        super.calcModulus();
        
        // Change modulus function for numeric rendering
        if (_valueType == .Numeric) {
            self.calculateNumericModulus()
        }
    }
    
    private func calculateNumericModulus () {
        if (_xAxis === nil || !_xAxis.isEnabled) { return }
        
        if (!_xAxis.isAxisModulusCustom)
        {
            let requiredWidth = (CGFloat(_data?.xValCount ?? 0) * _xAxis.labelRotatedWidth)
            let availableWidth = _viewPortHandler.contentWidth * _viewPortHandler.touchMatrix.a
            
            
            let chartXMin = self.chartXMin
            let chartXMax = self.chartXMax
            
            // We can no longer use the count to make a reasonable assumption about how many grids we need
            let minX = _xAxisRenderer.minX
            let maxX = _xAxisRenderer.maxX
            
            let deltaX = Double(maxX - minX)
            
            let deltaChartX = Double(chartXMax - chartXMin)
            
            
            let percentageView = (deltaChartX / deltaX)
            
            // TODO: it would be nice to have the user specify the count and default to 10 if none specified or some invalid number.
            _xAxis.axisLabelModulus = Int(deltaX / 10)
            
            // _xAxis.axisLabelModulus = Int(ceil((requiredWidth / availableWidth)))
            
        }
        
        if (_xAxis.axisLabelModulus < 1)
        {
            _xAxis.axisLabelModulus = 1
        }

    }
    
    public var valueType: ValueType {
        set {
            _valueType = newValue
            
            switch _valueType {
            case .Numeric:
                _xAxisRenderer = ChartXAxisRendererNumeric(viewPortHandler: _viewPortHandler, xAxis: _xAxis, transformer: _leftAxisTransformer)
                renderer!.valueType = .Numeric
                break
                
            case .Default:
                _xAxisRenderer = ChartXAxisRenderer(viewPortHandler: _viewPortHandler, xAxis: _xAxis, transformer: _leftAxisTransformer)
                renderer!.valueType = .Default
                break
                
            default:
                _xAxisRenderer = ChartXAxisRenderer(viewPortHandler: _viewPortHandler, xAxis: _xAxis, transformer: _leftAxisTransformer)
                renderer!.valueType = .Default
                break
            }
        }
        get {
            return _valueType
        }
    }
    
    
    // MARK: - ScatterChartDataProbider
    
    public var scatterData: ScatterChartData? { return _data as? ScatterChartData }
}