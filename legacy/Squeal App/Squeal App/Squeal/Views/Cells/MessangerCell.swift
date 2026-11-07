//
//  MessangerCell.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit

class MessengerCell: UICollectionViewCell {
    
    var row = 0
    var messenger: MessengerViewController!
    let mainView: UIView! = UIView()
    let leftMessage: UIView! = UIView()
    let leftName: UILabel! = UILabel()
    let rightName: UILabel! = UILabel()
    let leftLabel: UILabel! = {
        let label = UILabel()
        label.text = "custom"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    let leftImage: UIImageView = UIImageView()
    let leftActivity: UIActivityIndicatorView! = UIActivityIndicatorView()
    let rightMessage: UIView! = UIView()
    let rightLabel: UILabel! = {
        let label = UILabel()
        label.text = "custom"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    let rightImage: UIImageView = UIImageView()
    let rightActivity: UIActivityIndicatorView! = UIActivityIndicatorView()
    
    

    override init(frame: CGRect) {
        super.init(frame: frame)
        //messenger = Messenger()
        
        self.addSubview(leftMessage)
        self.addSubview(rightMessage)
        
        leftName.text = "Paige"
        rightName.text = "Ash"
        
        leftName.textColor = UIColor(red:0.34, green:0.33, blue:0.39, alpha:1.0)
        rightName.textColor = UIColor(red:0.43, green:0.31, blue:0.68, alpha:1.0)
        
        if UIScreen.main.bounds.height == 568 {
            leftName.font = UIFont(name: "Helvetica-Bold", size: 11)
            rightName.font = UIFont(name: "Helvetica-Bold", size: 11)
            
            leftLabel.font = UIFont(name: "Helvetica", size: 15)
            rightLabel.font = UIFont(name: "Helvetica", size: 15)
        } else {
            leftName.font = UIFont(name: "Helvetica-Bold", size: 13)
            rightName.font = UIFont(name: "Helvetica-Bold", size: 13)
            
            leftLabel.font = UIFont(name: "Helvetica", size: 17)
            rightLabel.font = UIFont(name: "Helvetica", size: 17)
        }
        //addSubview(rightImage)
        leftMessage.addSubview(leftLabel)
        leftMessage.addSubview(leftImage)
        leftMessage.addSubview(leftActivity)
        rightMessage.addSubview(rightLabel)
        rightMessage.addSubview(rightImage)
        rightMessage.addSubview(rightActivity)
        
        self.addSubview(leftName)
        self.addSubview(rightName)
       
        leftLabel.textColor = UIColor.white
        rightLabel.textColor = UIColor.white
        
        leftMessage.backgroundColor = UIColor(red: 0.34, green: 0.33, blue: 0.39, alpha: 1.0)
        rightMessage.backgroundColor = UIColor(red: 0.43, green: 0.31, blue: 0.68, alpha: 1.0)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


}

