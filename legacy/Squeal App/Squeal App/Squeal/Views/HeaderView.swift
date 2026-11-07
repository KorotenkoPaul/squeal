//
//  HeaderView.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 PaulDevelopersGroupe. All rights reserved.
//

import Foundation
import UIKit

class HeaderView: UICollectionReusableView {
    var isEnglishLanguage = true {
        didSet {
            if isEnglishLanguage {
                genreSwitcher.genre1.setTitle("FEATURED", for: .normal)
                genreSwitcher.genre2.setTitle("HORROR", for: .normal)
                genreSwitcher.genre3.setTitle("ROMANCE", for: .normal)
                genreSwitcher.genre4.setTitle("THRILLER", for: .normal)
                label.text = "BEST OF THE WEEK"
                label.sizeToFit()
                self.setNeedsLayout()
            } else {
                genreSwitcher.genre1.setTitle("POPULAIRES", for: .normal)
                genreSwitcher.genre2.setTitle("HORREUR", for: .normal)
                genreSwitcher.genre3.setTitle("ROMANCE", for: .normal)
                genreSwitcher.genre4.setTitle("THRILLER", for: .normal)
                label.text = "MEILLEUR DE LA SEMAINE"
                label.sizeToFit()
                self.setNeedsLayout()
            }
        }
    }
    let dataSource = SliderDatasource(slider: slidesArray[0])
    var delegateNdatasouce: SliderCollectionViewDelegateNDataSource!

    let label: UILabel = {
        let label = UILabel()
        label.frame = CGRect(x: 32, y: 20, width: 123, height: 16)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = false
        label.text = "BEST OF THE WEEK"
        label.font = UIFont(name:"Helvetica-Bold", size: 12.0)
        if UIScreen.main.bounds.height == 568 {
            label.font = UIFont(name:"Helvetica-Bold", size: 11.0)
        }
        label.textColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.5)
        //label.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)// Включим при загрузке
        return label
    }()

    var headerCollectionView: AutoScrolling!//AutoScrolling!
    var genreSwitcher: GenreSwitcher!


    func configurateGenreSwitcher() {
        genreSwitcher = GenreSwitcher(frame: CGRect(origin: CGPoint(x: 0, y: 50 + (self.bounds.width - 61) * 0.653 ), size: CGSize(width: self.bounds.width, height: self.bounds.height - (50 + (self.bounds.width - 61) * 0.653))), fourGenresButtons: [GenreButton(genreName:  "FEATURED"), GenreButton(genreName:  "HORROR"), GenreButton(genreName:  "ROMANCE"), GenreButton(genreName:  "THRILLER")])
        self.addSubview(genreSwitcher)
    }

    func configurateHeaderCollectionView() {
        let optimalCellSize = CGSize(width: self.bounds.width - 45, height: (self.bounds.width - 61) * 0.653)
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: optimalCellSize.width,
                                 height: optimalCellSize.height)
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0


        headerCollectionView = AutoScrolling(frame: CGRect(x: 0, y: 50, width: self.bounds.width, height: optimalCellSize.height), collectionViewLayout: layout)
        headerCollectionView.autoresizingMask = [.flexibleWidth]
        headerCollectionView.register(HeaderCollectionViewCell.self, forCellWithReuseIdentifier: "headerCell")
        headerCollectionView.showsHorizontalScrollIndicator = false

        delegateNdatasouce = SliderCollectionViewDelegateNDataSource(collectionView: headerCollectionView, collectionViewFlowLayout: layout, datasource: dataSource)
        headerCollectionView.delegate = delegateNdatasouce

//        headerCollectionView.dataSource = dataSource
//        headerCollectionView.delegate = self
        headerCollectionView.backgroundColor = .clear
        self.addSubview(headerCollectionView)
    }

    @objc
    func chooseEnglishLanguageInHeaderView(sender: Notification) {
        genreSwitcher.genre1.setTitle("FEATURED", for: .normal)
        genreSwitcher.genre2.setTitle("HORROR", for: .normal)
        genreSwitcher.genre3.setTitle("ROMANCE", for: .normal)
        genreSwitcher.genre4.setTitle("THRILLER", for: .normal)
        label.text = "BEST OF THE WEEK"
        label.sizeToFit()
        self.setNeedsLayout()
    }
    @objc
    func chooseFrenchLanguageInHeaderView(sender: Notification) {
        genreSwitcher.genre1.setTitle("POPULAIRES", for: .normal)
        genreSwitcher.genre2.setTitle("HORREUR", for: .normal)
        genreSwitcher.genre3.setTitle("ROMANCE", for: .normal)
        genreSwitcher.genre4.setTitle("THRILLER", for: .normal)
        label.text = "MEILLEUR DE LA SEMAINE"
        label.sizeToFit()
        self.setNeedsLayout()
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        configurateHeaderCollectionView()
        self.addSubview(label)
        configurateGenreSwitcher()
        NotificationCenter.default.addObserver(self, selector: #selector(chooseEnglishLanguageInHeaderView(sender:)), name: NSNotification.Name.init("chooseEnglishLanguageInHeaderView"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(chooseFrenchLanguageInHeaderView(sender:)), name: NSNotification.Name.init("chooseFrenchLanguageInHeaderView"), object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//extension HeaderView: UICollectionViewDelegate, UIScrollViewDelegate {
//
//    // MARK:- Параметры скроллинга в слайдере
//    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
//           let cellWidth = (self.frame.width - 61 + 16)
//           let item = Int(scrollView.contentOffset.x / cellWidth)
//           let equatebleContentOffset: CGFloat = scrollView.contentOffset.x - (cellWidth * CGFloat(item))
//
//           guard let cv = scrollView as? UICollectionView else { return }
//           if equatebleContentOffset < 0.5 * cellWidth {
//               cv.scrollToItem(at: IndexPath(item: item + 1, section: 0), at: UICollectionViewScrollPosition.left, animated: true)
//               print("<0,4")
//           } else {
//               cv.scrollToItem(at: IndexPath(item: item, section: 0), at: UICollectionViewScrollPosition.left, animated: true)
//               print(">0,5")
//           }
//    }
//
//    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
//        let cellWidth = (self.frame.width - 45)
//        let item = Int(scrollView.contentOffset.x / cellWidth)
//        let equatebleContentOffset: CGFloat = scrollView.contentOffset.x - (cellWidth * CGFloat(item))
//
//        guard let cv = scrollView as? UICollectionView else { return }
//        if equatebleContentOffset < 0.5 * cellWidth {
//            cv.scrollToItem(at: IndexPath(item: item + 1, section: 0), at: UICollectionViewScrollPosition.left, animated: true)
//            print("<0,5")
//        } else {
//            cv.scrollToItem(at: IndexPath(item: item, section: 0), at: UICollectionViewScrollPosition.left, animated: true)
//            print(">0,5")
//        }
//    }
//}
