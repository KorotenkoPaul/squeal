//
//  SquealProducts.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import Foundation

public struct SquealProducts {
    
    public static let SquealTrial = "com.pauldevelopers.ios.subscription.week"
    public static let SquealMonth = "com.pauldevelopers.ios.subscription.month"
    public static let SquealSixMonth = "com.pauldevelopers.ios.subscription.six.month"
    
    static let productIdentifiers: Set<String> = [SquealProducts.SquealTrial,
                                                                     SquealProducts.SquealMonth,
                                                                     SquealProducts.SquealSixMonth]
}

