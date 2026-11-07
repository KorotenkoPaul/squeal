//
//  FavouritesTableViewCell.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit


protocol FavouritesTableViewCellDelegate: class {
    func removeCell(cell: FavouritesTableViewCell)
    func viewDidTapped(cell: FavouritesTableViewCell)
}

class FavouritesTableViewCell: UITableViewCell {
    var delegateForRemove: FavouritesTableViewCellDelegate?

    var scrollButton: UIButton = {
        let button = UIButton()
        button.frame = CGRect(x: UIScreen.main.bounds.width - 19, y: 5, width: 0, height: 95)
        button.backgroundColor = UIColor(displayP3Red: 110/255, green: 80/255, blue: 174/255, alpha: 1)
        button.layer.cornerRadius = 10
        button.alpha = 0
        if language == "english" {
            button.setTitle("Remove", for: .normal)
        } else if language == "french" {
            button.setTitle("Supprimer", for: .normal)
        }
        return button
    }()

    var scrollView: UIScrollView = {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 105))
        scrollView.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
        scrollView.contentSize = CGSize(width: UIScreen.main.bounds.width + 121 , height: 105)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isPagingEnabled = true
        return scrollView
    }()
    var gradientLayer: CAGradientLayer!

    // MARK: cell
    var cellView: UIView = {
        let view = UIView(frame: CGRect(origin: CGPoint(x: 19, y: 5), size: CGSize(width: UIScreen.main.bounds.width - 38, height: 95)))
        view.backgroundColor = UIColor(displayP3Red: 12/255, green: 0, blue: 44/255, alpha: 1)
        view.clipsToBounds = true
        view.layer.cornerRadius = 10
        return view
    }()
    var cellImage: UIImageView = {
        let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: UIScreen.main.bounds.width - 19 - 209, y: 0), size: CGSize(width: 209, height: 95)))
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    var cellLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 25, y: 25, width: UIScreen.main.bounds.width - 2 * (25 + 19), height: 24))
        label.font = UIFont(name: "Avenir-Medium", size: 21)
        if UIScreen.main.bounds.height == 568 {
            label.font = UIFont(name: "Avenir-Medium", size: 18)
        }
        label.textAlignment = .left
        label.textColor = .white
        return label
    }()
    var cellAbout: UILabel = {
        let label = UILabel(frame: CGRect(x: 25 + 19, y: 30, width: UIScreen.main.bounds.width - 2 * (25 + 19), height: 22))
        label.textAlignment = .left
        return label
    }()

    var completedLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 25, y: 54, width: UIScreen.main.bounds.width - 2 * (25 + 19), height: 22))
        label.font = UIFont(name: "Avenir-Medium", size: 10)
        label.textColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.5)
        label.textAlignment = .left
        return label
    }()

    @objc func pressRemoveCell(sender: UIButton) {
        delegateForRemove?.removeCell(cell: self)
    }

    @objc func cellViewDidTapped(sender: UITapGestureRecognizer){
        delegateForRemove?.viewDidTapped(cell: self)
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let gesture = UITapGestureRecognizer(target: self, action: #selector(cellViewDidTapped(sender:)))
        cellView.addGestureRecognizer(gesture)
        scrollButton.addTarget(self, action: #selector(pressRemoveCell(sender:)), for: .touchUpInside)
        scrollView.delegate = self
        self.contentView.addSubview(scrollView)
        scrollView.addSubview(cellView)
        scrollView.addSubview(scrollButton)
        cellView.addSubview(cellImage)
        cellView.addSubview(cellLabel)
        cellView.addSubview(completedLabel)
        self.backgroundColor = UIColor(displayP3Red: 38/255, green: 34/255, blue: 65/255, alpha: 1)



        gradientLayer = CAGradientLayer()
        gradientLayer.frame = cellImage.bounds
        gradientLayer.colors = [UIColor(displayP3Red: 12/255, green: 0, blue: 44/255, alpha: 1).cgColor,    UIColor(displayP3Red: 16/255, green: 3/255, blue: 49/255, alpha: 0.96).cgColor,
                                UIColor(displayP3Red: 23/255, green: 9/255, blue: 58/255, alpha: 0.91).cgColor,
                                UIColor(displayP3Red: 31/255, green: 15/255, blue: 69/255, alpha: 0.84).cgColor,
                                UIColor(displayP3Red: 40/255, green: 23/255, blue: 81/255, alpha: 0.76).cgColor,
                                UIColor(displayP3Red: 110/255, green: 80/255, blue: 174/255, alpha: 0).cgColor,
            ]

        gradientLayer.locations = [0.0, 0.09, 0.2, 0.32, 0.43]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0)
        cellImage.layer.addSublayer(gradientLayer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
    }
}

extension FavouritesTableViewCell: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {

        if scrollView.contentOffset.x > 7 {
        scrollButton.frame.size.width = scrollView.contentOffset.x - 7
        scrollButton.frame.origin.x = UIScreen.main.bounds.width - 19 + 7
        scrollButton.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: (scrollView.contentOffset.x - 7)/6.7)
        if scrollView.contentOffset.x > 121 {
            scrollButton.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: 17.015 + (scrollView.contentOffset.x - 121) / 10)
        }else{
            scrollButton.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: (scrollView.contentOffset.x - 7)/6.7)
        }
        if scrollView.contentOffset.x > 27 {
            scrollButton.alpha = (scrollView.contentOffset.x - 27) / 100
        }else{
            scrollButton.alpha = 0
        }
        } else {
        scrollButton.frame.size.width = 0
        scrollButton.frame.origin.x = UIScreen.main.bounds.width - 19 + scrollView.contentOffset.x
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.x == 0 {
            UIView.animate(withDuration: 0.3, animations: {
                self.cellView.frame.origin.x = 19
            })
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.cellView.frame.origin.x = 19
            })
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.x == 0 {
            UIView.animate(withDuration: 0.3, animations: {
                self.cellView.frame.origin.x = 19
            })
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.cellView.frame.origin.x = 19
            })
        }
    }
}
