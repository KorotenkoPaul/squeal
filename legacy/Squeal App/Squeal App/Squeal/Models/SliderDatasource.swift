//
//  SliderDatasource.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit

class SliderDatasource: NSObject, UICollectionViewDataSource {

    var slider: Slider
    
    init(slider: Slider) {
        self.slider = slider
        super.init()
        print("slider DataSource init, slider count is: \(self.slider.numberOfSlides())")
    }

    func numberOfSlides() -> Int {
        return slider.numberOfSlides()
    }
    
    // MARK: collectionView methods
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 10000
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let swipeCell = collectionView.dequeueReusableCell(withReuseIdentifier: "headerCell", for: indexPath) as? HeaderCollectionViewCell else {
            fatalError()
        }
        var container = slidesArray[0].slides
        let slide = slidesArray[0].slideAt([0, indexPath.item % slider.numberOfSlides()])
        swipeCell.storyImage.image = slide.images
        swipeCell.storyLabel.text = slide.name.lowercased().capitalizingFirstLetter()
        var genreForLang: String? = ""
        if language == "english" {
            genreForLang = slide.genre
        }else{
            if slide.genre?.lowercased() == "horror" {
                genreForLang = "horreur"
            }else  {
                genreForLang = slide.genre
            }
        }
        swipeCell.genreLabel.text = genreForLang?.uppercased()

        if !dictOfViews.isEmpty {
            if dictOfViews.keys.contains(container[indexPath.item % (container.count)].name.lowercased()) {
                let storyName = container[indexPath.item % (container.count)].name.lowercased()
                let storyViews = dictOfViews[storyName]!["views"]!["num"]!
                if let storyRating = dictOfViews[storyName]!["rating"]?["num"] {
                    let numberFormatter = NumberFormatter()
                    numberFormatter.maximumFractionDigits = 1
                    let number = NSNumber(value: storyRating)
                    let ratingString = numberFormatter.string(from: number)
                    swipeCell.rateLabel.text = ratingString
                } else {
                    swipeCell.rateLabel.text = "8.9"
                }

                swipeCell.viewsLabel.text = storyViews.formatPoints()//String(Int(storyViews))

            }else{
                swipeCell.viewsLabel.text = String(113)
            }
        }
        return swipeCell
    }
    
}
