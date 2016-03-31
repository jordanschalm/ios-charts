//
//  LineChartView.swift
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

/// Chart that draws lines, surfaces, circles, ...
public class LineChartView: BarLineChartViewBase, LineChartDataProvider {
    /// flag that enables or disables the highlighting arrow
    private var _renderNumericXAxis = false
    private var _renderTimeXAxis = true
   
    internal override func initialize() {
        super.initialize()
        
        renderer = LineChartRenderer(dataProvider: self, animator: _animator, viewPortHandler: _viewPortHandler)
    }
    
    internal override func calcMinMax() {
        super.calcMinMax()
        
        if (self._data?.valueType == .Temporal) {
            self.calcMinMaxTime()
        }
    }

    private func calcMinMaxTime() {
        guard let data = _data else { return }
        
        if (_deltaX == 0.0 && data.yValCount > 0) {
            _deltaX = 1.0
        }
        
        // Danger these should get defaults after the loop or things might explode
        var maxValue = Double.NaN
        var minValue = Double.NaN
        for (var i = 0, len = data.xVals.count; i < len; i++) {
            guard let value = data.xVals[i] else { continue }
            
            // TODO - Ryan, this should use a property defined dateFormat
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let date = dateFormatter.dateFromString(value)
            guard let timeValue = date?.timeIntervalSince1970 else { continue }

            if (maxValue.isNaN || timeValue > maxValue) { maxValue = timeValue }
            if (minValue.isNaN || timeValue < minValue) { minValue = timeValue }
        }
        
        _chartXMax = maxValue
        _chartXMin = minValue
        _deltaX = CGFloat(abs(_chartXMax - _chartXMin))
    }
    
    public override func notifyDataSetChanged()
    {
        // We need to use the proper axis renderer based on the type of data we are using
        if let data = _data
        {
            switch data.valueType {
            case .Default:
                _xAxisRenderer = ChartXAxisRenderer(viewPortHandler: _viewPortHandler, xAxis: _xAxis, transformer: _leftAxisTransformer)
                break
                
            case .Numeric:
                _xAxisRenderer = ChartXAxisRendererNumeric(viewPortHandler: _viewPortHandler, xAxis: _xAxis, transformer: _leftAxisTransformer)
                break
                
            case .Temporal:
                _xAxisRenderer = ChartXAxisRendererNumeric(viewPortHandler: _viewPortHandler, xAxis: _xAxis, transformer: _leftAxisTransformer)
                break
            }
        }

        super.notifyDataSetChanged()
    }
    
    // MARK: - LineChartDataProvider
    
    public var lineData: LineChartData? { return _data as? LineChartData }
}