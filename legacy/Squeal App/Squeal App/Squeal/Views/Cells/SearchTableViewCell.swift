//
//  SearchTableViewCell.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 PaulDevelopersGroupe. All rights reserved.
//

import UIKit

class SearchTableViewCell: UITableViewCell {
    var isLoading = false {
        didSet{
            if isLoading {
                storyLabel.frame = CGRect(x: 100, y: 19, width: 185, height: 15)
                storyLabel.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
                storyLabel.layer.cornerRadius = 7.5
                storyLabel.clipsToBounds = true
                storyLabel.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 0)

                genreLabel.frame = CGRect(x: 100, y: 48, width: 119, height: 14)
                genreLabel.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
                genreLabel.layer.cornerRadius = 7
                genreLabel.clipsToBounds = true
                genreLabel.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 0)
            } else {

            }
        }
    }

    let storyLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 100, y: 17, width: 220, height: 20))
        label.font = UIFont(name: "SFProDisplay-Regular", size: 18)
        label.text = "NAME OF STORY"
        label.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
        label.textAlignment = .left
        label.backgroundColor = .clear
        return label
    }()

    let genreLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 100, y: 45, width: 119, height: 13))
        label.font = UIFont(name: "SFProDisplay-Medium", size: 13)
        label.text = "THRILLER"
        label.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 0.5)
        label.textAlignment = .left
        label.backgroundColor = .clear
        return label
    }()

    let storyImage: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 18, y: 5, width: 70, height: 70))
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 5
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
        return imageView
    }()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?){
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.addSubview(storyImage)
        self.addSubview(storyLabel)
        self.addSubview(genreLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        self.backgroundColor = selected ? UIColor(displayP3Red: 31/255, green: 21/255, blue: 53/255, alpha: 1) : .clear
    }

}
