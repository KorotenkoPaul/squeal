//
//  HeaderCollectionViewCell.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 PaulDevelopersGroupe. All rights reserved.
//

import Foundation
import UIKit

class HeaderCollectionViewCell: UICollectionViewCell {
    var rateLabel: UILabel = {
        let rateLabel = UILabel()
        return rateLabel
    }()
    var viewsLabel: UILabel = {
        let rateLabel = UILabel()
        return rateLabel
    }()
    var storyView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    var bufCollectionView: AutoScrolling?
    let storyLabel: UILabel = {
        let label = UILabel()
        label.text = "SOME STORY NAME LABEL BLA-BLA"
        label.font = UIFont(name: "Avenir-Black", size: 32)
        if UIScreen.main.bounds.height == 568 {
            label.font = UIFont(name: "Avenir-Black", size: 25)
        }
        label.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    let genreLabel: UILabel = {
        let label = UILabel()
        label.text = "Genre"
        label.font = UIFont(name: "Avenir-Medium", size: 13)
        if UIScreen.main.bounds.height == 568 {
            label.font = UIFont(name: "Avenir-Medium", size: 10)
        }
        label.textColor = UIColor(displayP3Red: 133/255, green: 128/255, blue: 150/255, alpha: 1)
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        label.textAlignment = .left
        return label
    }()
    let storyImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.translatesAutoresizingMaskIntoConstraints = false
        image.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
        image.clipsToBounds = true
        image.layer.cornerRadius = 10
        return image
    }()

    func isLoading() {
        self.storyLabel.alpha = 0
        self.genreLabel.alpha = 0
        self.storyImage.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
    }
    
    @objc func reloadLang () {
        var slidesForFrontend = [Story]()
        
        for i in 0 ..< slideUrl.count {
            var serverSlider = slideUrl[i]
            
            let commonMenu = horrorMenu + romanceMenu + thrillerMenu
            for i in commonMenu {
                if i.img.contains(serverSlider[0]) {
                    slidesForFrontend.append(i)
                }
            }
        }
        
        slidesArray = []
        slidesArray = [Slider(slides: slidesForFrontend )]

    }

    override init(frame: CGRect) {
        super.init(frame: .zero)
        self.backgroundColor = .clear//UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
        self.clipsToBounds = true
        self.addSubview(storyView)
        storyView.addSubview(storyImage)
        storyImage.addSubview(storyLabel)
        storyImage.addSubview(genreLabel)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadLang), name: .reloadLang, object: nil)
        storyView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        storyView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        storyView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        storyView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true

        //constraints
        storyImage.trailingAnchor.constraint(equalTo: storyView.trailingAnchor).isActive = true
        storyImage.topAnchor.constraint(equalTo: storyView.topAnchor).isActive = true
        storyImage.bottomAnchor.constraint(equalTo: storyView.bottomAnchor).isActive = true
        storyImage.leadingAnchor.constraint(equalTo: storyView.leadingAnchor, constant: 16).isActive = true

        storyLabel.topAnchor.constraint(equalTo: storyImage.topAnchor, constant: 18.2).isActive = true
        storyLabel.leadingAnchor.constraint(equalTo: storyImage.leadingAnchor, constant: 25.9).isActive = true
        storyLabel.widthAnchor.constraint(equalToConstant: 178.3).isActive = true

        genreLabel.topAnchor.constraint(equalTo: storyLabel.bottomAnchor, constant: 0).isActive = true
        genreLabel.leadingAnchor.constraint(equalTo: storyLabel.leadingAnchor, constant: 0).isActive = true
        genreLabel.widthAnchor.constraint(equalTo: storyLabel.widthAnchor, multiplier: 1).isActive = true
        genreLabel.heightAnchor.constraint(equalToConstant: 15).isActive = true
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
