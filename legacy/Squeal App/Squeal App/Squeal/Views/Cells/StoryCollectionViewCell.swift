//
//  StoryCollectionViewCell.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit

class StoryCollectionViewCell: UICollectionViewCell {
    // slider outlets
    var sliderStatusLabel:UILabel? // Ненужный элемент в новом дизайне
    var sliderGenreLabel: UILabel?

    let storyView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    // story outlets
    var storyImage: UIImageView = {
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.contentMode = .scaleAspectFill
        return image
    }()
    
    var storyGradient: UIImageView = {
        let gradient = UIImageView()
        gradient.translatesAutoresizingMaskIntoConstraints = false
        gradient.contentMode = .scaleAspectFill
        gradient.image = UIImage(named: "gradient")
        return gradient
    }()
    
    var storyLabel: UILabel = {
        let label = UILabel()
        label.frame = .zero
        label.text = "NAME"
        label.font = UIFont(name: "SFProDisplay-Regular", size: 20)
        if UIScreen.main.bounds.height == 568 {
            label.font = UIFont(name: "SFProDisplay-Regular", size: 17)
        }
        label.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
        label.backgroundColor = .clear
        label.textAlignment = NSTextAlignment.center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()



    var rateImage: UIImageView = {
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.image = UIImage(named: "small rating")
        image.tintColor = UIColor(displayP3Red: 207/255, green: 66/255, blue: 97/255, alpha: 1)
        image.contentMode = .scaleAspectFill
        return image
    }()
    var rateLabel: UILabel = {
        let label = UILabel()
        label.text = "8,4"
        label.font = UIFont(name: "ArialMT", size: 12)
        label.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var viewsImage: UIImageView = {
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.image = UIImage(named: "eye")
        image.contentMode = .scaleAspectFit
        return image
    }()
    var viewsLabel: UILabel = {
        let label = UILabel()
        label.text = "129,3k"
        label.font = UIFont(name: "ArialMT", size: 12)
        label.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()


    func isLoading(_ flag: Bool) {
        if flag {
            self.storyView.alpha = 0
        } else {
            self.storyView.alpha = 1
        }
    }

    var bufCollectionView: AutoScrolling?
    
    @objc func visibleGradient () {
        if storyImage.image != nil && storyImage.image != #imageLiteral(resourceName: "nill") {
             storyGradient.isHidden = false
        }
    }
    
    func fillWith(_ story: Story) {
        sliderStatusLabel?.text = story.status?.uppercased()
        storyLabel.text = story.name.uppercased()
        sliderGenreLabel?.text = story.genre?.uppercased()
        storyImage.image = story.images
    }

    override init(frame: CGRect) {
        super.init(frame: .zero)
        self.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
        self.layer.cornerRadius = 10
        self.clipsToBounds = true
        self.addSubview(storyImage)
        storyImage.addSubview(storyGradient)
        storyImage.addSubview(storyView)
        storyView.addSubview(storyLabel)
        storyView.addSubview(rateImage)
        storyView.addSubview(rateLabel)
        storyView.addSubview(viewsImage)
        storyView.addSubview(viewsLabel)

        storyGradient.isHidden = true
        //frame
        NotificationCenter.default.addObserver(self, selector: #selector(visibleGradient), name: .reloadLang, object: nil)
        //Констреинты - позже засунуть в функцию (для наглядности)
        storyImage.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        storyImage.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        storyImage.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        storyImage.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        
        storyGradient.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        storyGradient.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        storyGradient.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        storyGradient.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true

        storyView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        storyView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        storyView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        storyView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true

        viewsImage.widthAnchor.constraint(equalToConstant: 16).isActive = true
        viewsImage.heightAnchor.constraint(equalToConstant: 16).isActive = true
        viewsImage.leadingAnchor.constraint(equalTo: storyImage.centerXAnchor, constant: 0).isActive = true
        viewsImage.bottomAnchor.constraint(equalTo: storyImage.bottomAnchor, constant: -17.5).isActive = true


        //viewsLabel.widthAnchor.constraint(equalToConstant: 37).isActive = true
        viewsLabel.heightAnchor.constraint(equalToConstant: 14).isActive = true
        viewsLabel.leadingAnchor.constraint(equalTo: viewsImage.trailingAnchor, constant: 5).isActive = true
        viewsLabel.bottomAnchor.constraint(equalTo: storyImage.bottomAnchor, constant: -18.5).isActive = true

        
        storyLabel.centerXAnchor.constraint(equalTo: storyImage.centerXAnchor).isActive = true
        storyLabel.widthAnchor.constraint(equalTo: storyImage.widthAnchor, constant: -30).isActive = true
        storyLabel.bottomAnchor.constraint(equalTo: storyImage.bottomAnchor, constant: -46.5).isActive = true
        //storyLabel.topAnchor.constraint(lessThanOrEqualTo: storyImage.topAnchor).isActive = true // Нужен ограничивающий констреинт

        //rateLabel.widthAnchor.constraint(equalToConstant: 19).isActive = true
        rateLabel.heightAnchor.constraint(equalToConstant: 14).isActive = true
        rateLabel.trailingAnchor.constraint(equalTo: viewsImage.leadingAnchor, constant: -10).isActive = true
        rateLabel.bottomAnchor.constraint(equalTo: storyImage.bottomAnchor, constant: -18.5).isActive = true

        rateImage.widthAnchor.constraint(equalToConstant: 13).isActive = true
        rateImage.heightAnchor.constraint(equalToConstant: 13).isActive = true
        rateImage.trailingAnchor.constraint(equalTo: rateLabel.leadingAnchor, constant: -5).isActive = true
        rateImage.bottomAnchor.constraint(equalTo: storyImage.bottomAnchor, constant: -19.5).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
