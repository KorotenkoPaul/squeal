//
//  Slider.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit

class Slider: NSObject {

    var slides: [Story] = []
    
    init(slides: [Story]) {
        super.init()
        self.slides = slides
        Support.shared.numberOfSlides = slides.count
        Support.shared.currentPage = 50 * slides.count
        dotsAmount = numberOfSlides()
    }
    
    func numberOfSlides() -> Int {
        return slides.count
    }
    
    func slideAt(_ indexPath: IndexPath) -> Story {
        return slides[indexPath.item % self.numberOfSlides()]
    }
    
}
