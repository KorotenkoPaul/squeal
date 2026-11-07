//
//  LoadingDataSource.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 PaulDevelopersGroupe. All rights reserved.
//

import Foundation
import UIKit

class LoadingDataSource: NSObject {
    
}

extension LoadingDataSource: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 8
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "storyCell", for: indexPath) as! StoryCollectionViewCell
        cell.isLoading(true)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionElementKindSectionHeader:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                             withReuseIdentifier: "loadingHeaderView",
                                                                             for: indexPath) as! LoadingHeaderView
            headerView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: (UIScreen.main.bounds.width - 61) * 0.653 + 104)
            return headerView
        default:
            assert(false, "Unexpected element kind")
            // То, что ниже написали для архивации
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                             withReuseIdentifier: "loadingHeaderView",
                                                                             for: indexPath) as! LoadingHeaderView
            return headerView
        }
    }
}


class LoadingHeaderView: UICollectionReusableView, UICollectionViewDataSource {

    let label: UILabel = {
        let label = UILabel()
        label.frame = CGRect(x: 32, y: 20, width: 123, height: 16)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.font = UIFont(name:"Helvetica-Bold", size: 12.0)
        label.textColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.5)
        label.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
        return label
    }()

    var headerCollectionView: UICollectionView!
    var genreSwitcher: GenreSwitcher!


    func configurateGenreSwitcher() {
        genreSwitcher = GenreSwitcher(frame: CGRect(origin: CGPoint(x: 0, y: 50 + (self.bounds.width - 61) * 0.653 ), size: CGSize(width: self.bounds.width, height: self.bounds.height - (50 + (self.bounds.width - 61) * 0.653))), fourGenresButtons: [GenreButton(genreName:  ""), GenreButton(genreName:  ""), GenreButton(genreName:  ""), GenreButton(genreName:  "")])
        self.addSubview(genreSwitcher)
        genreSwitcher.isLoading(true)
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


        headerCollectionView = UICollectionView(frame: CGRect(x: 0, y: 50, width: self.bounds.width, height: optimalCellSize.height), collectionViewLayout: layout)
        headerCollectionView.autoresizingMask = [.flexibleWidth]
        headerCollectionView.register(HeaderCollectionViewCell.self, forCellWithReuseIdentifier: "LoadingHeaderCell")
        headerCollectionView.showsHorizontalScrollIndicator = false
        headerCollectionView.contentOffset = CGPoint(x: optimalCellSize.width * 5000, y: 0)
        print("slidesArray.count: \(slidesArray.count)")

        headerCollectionView.dataSource = self

        headerCollectionView.backgroundColor = .clear
        self.addSubview(headerCollectionView)
    }


    override init(frame: CGRect) {
        super.init(frame: frame)
        configurateHeaderCollectionView()
        self.addSubview(label)
        configurateGenreSwitcher()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: collectionView methods
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 10000
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let swipeCell = collectionView.dequeueReusableCell(withReuseIdentifier: "LoadingHeaderCell", for: indexPath) as? HeaderCollectionViewCell else {
            fatalError()
        }
        swipeCell.isLoading()
        return swipeCell
    }
}
