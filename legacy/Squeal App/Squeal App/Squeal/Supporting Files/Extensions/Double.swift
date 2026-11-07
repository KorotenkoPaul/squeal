//
//  Double.swift
//  Squeal
//
//  Created by p.ilin on 14.10.2018.
//  Copyright © 2018 PaulDevelopersGroupe. All rights reserved.
//

import Foundation

extension Double {
    
    func formatPoints() -> String{
        let thousandNum = self/1000
        let millionNum = self/1000000
        if self >= 1000 && self < 1000000{
            if(floor(thousandNum) == thousandNum){
                return ("\(Int(thousandNum))k").replacingOccurrences(of: ".0", with: "")
            }
            return("\(thousandNum.roundTo(places: 1))k").replacingOccurrences(of: ".0", with: "")
        }
        if self > 1000000{
            if(floor(millionNum) == millionNum){
                return("\(Int(thousandNum))k").replacingOccurrences(of: ".0", with: "")
            }
            return ("\(millionNum.roundTo(places: 1))M").replacingOccurrences(of: ".0", with: "")
        }
        else{
            if(floor(self) == self){
                return ("\(Int(self))")
            }
            return ("\(self)")
        }
    }

    func roundTo(places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
