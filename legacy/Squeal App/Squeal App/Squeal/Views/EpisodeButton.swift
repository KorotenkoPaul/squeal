//
//  EpisodeButton.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 PaulDevelopersGroupe. All rights reserved.
//

import UIKit

class EpisodeButton: UIButton {
    var isActive = false{
        didSet{
            if isActive {
                self.backgroundColor = .clear
                self.setTitleColor(UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1), for: .normal) 
            } else {
                self.backgroundColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
                self.setTitleColor(.black, for: .normal)
            }
        }
    }
    init(){
        super.init(frame: .zero)
        self.frame.size = CGSize(width: 38, height: 38)
        self.layer.cornerRadius = 19
        self.backgroundColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
        self.layer.borderWidth = 2
        self.layer.borderColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1).cgColor
        self.setTitleColor(.black, for: .normal)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
