//
//  PiecewiseLinearFunction.swift
//  Variometer
//
//  Created by Türkay Biliyor on 29/12/2017.
//  Copyright © 2017 Türkay Biliyor. All rights reserved.
//

import Foundation

struct xyPoint{
    let x: Double
    let y: Double
}

class PieceviseLinearFunction
{
    var pointArray : [xyPoint] = []
    
    func addNewPoint(newPoint : xyPoint) {
        
        if (pointArray.count == 0)
        {
            let xy = xyPoint(x: newPoint.x, y: newPoint.y)
            pointArray.append(xy)
            return
        }
        else if (newPoint.x > (pointArray[pointArray.count - 1].x))
        {
            let xy = xyPoint(x: newPoint.x, y: newPoint.y)
            pointArray.append(xy)
            return
        }
        else
        {
            for i in 0..<pointArray.count{
                if(pointArray[i].x > newPoint.x){
                    pointArray.insert(newPoint, at: i)
                    return
                }
            }
        }
    }
    
    func getValue(x : Double) -> Double{
        
        var point : xyPoint
        var lastPoint : xyPoint = pointArray[0]
        
        if(x <= lastPoint.x){
            return lastPoint.y
        }
        
        for i in 0..<pointArray.count{
            
            point = pointArray[i]
            if(x <= point.x){
                let ratio = (x - lastPoint.x) / (point.x - lastPoint.x)
                let value = lastPoint.y + ratio * (point.y - lastPoint.y)
                return value
            }
            lastPoint = point
        }
        return lastPoint.y
    }
    
    func getSize () -> Int{
        
        return pointArray.count
    }
}

