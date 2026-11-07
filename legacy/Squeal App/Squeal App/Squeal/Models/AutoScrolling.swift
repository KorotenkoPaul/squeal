//
//  AutoScrolling.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit

enum AutoScrollingCollectionViewScrollDirection: String {
    case left = "left"
    case right = "right"
}

class AutoScrolling: UICollectionView {
    
    private var timer = Timer()
    
    // The time interval between each scroll in collection view. 3 seconds is the default interval
    var scrollInterval: Int = 3
    
    deinit { stopScrolling() }
    
    override func awakeFromNib() {
        super.awakeFromNib()
//        self.isPagingEnabled = true
    }
    
    @objc func reloadLang () {
        
        self.reloadData()
        self.scrollToItem(at: IndexPath(item: 100, section: 0), at: .left, animated: false)
        self.startScrolling()
        
        
        print("has reloaded")
    }

    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadLang), name: .reloadLang, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    fileprivate func setTimer() {
        if timer.isValid {
            timer.invalidate()
        }
        self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(scrollInterval), target: self, selector: #selector(self.autoScrollImageSlider), userInfo: nil, repeats: true)
        RunLoop.main.add(self.timer, forMode: .commonModes)
    }
    
    // Starts scrolling the collection view if there is at least one item in the datasource
    
    var count: Int = 0
    
    func startScrolling() {
        count += 1
        if count == 2 {
           // self.setContentOffset(CGPoint(x: (self.frame.width - 45) * CGFloat(Support.shared.currentPage!), y: 0), animated: false)
        }
        if !timer.isValid {
            if self.numberOfItems(inSection: 0) != 0 {
                stopScrolling()
                setTimer()
            }
        }
    }
    
    func stopScrolling() {
        if timer.isValid { self.timer.invalidate() }
    }
    
    @objc fileprivate func autoScrollImageSlider() {
        DispatchQueue.main.async {
            let firstIndex = 0
            let lastIndex = self.numberOfItems(inSection: 0) - 1
            let visibleCellsIndexes = self.indexPathsForVisibleItems.filter({ (ip) -> Bool in
                if let cell = self.cellForItem(at: ip) {
                    return cell.frame.origin.x >= self.contentOffset.x
                } else {
                    return false
                }
                
            }).sorted()
            
            if !visibleCellsIndexes.isEmpty {
                let nextIndex = visibleCellsIndexes[0].row + 1
                let nextIndexPath: IndexPath = IndexPath.init(item: nextIndex, section: 0)
                let firstIndexPath: IndexPath = IndexPath.init(item: firstIndex, section: 0)
                
                if nextIndex > lastIndex {
                    self.scrollToItem(at: firstIndexPath, at: .left, animated: true)
                } else {
                    self.scrollToItem(at: nextIndexPath, at: .left, animated: true)
                }
            }
        }
    }
    
    func scrollToPreviousOrNextCell(direction: AutoScrollingCollectionViewScrollDirection) {
        DispatchQueue.main.async {
            let firstIndex = 0
            let lastIndex = self.numberOfItems(inSection: 0) - 1
            let visibleCellsIndexes = self.indexPathsForVisibleItems.filter({ (ip) -> Bool in
                if let cell = self.cellForItem(at: ip) {
                    return cell.frame.origin.x >= self.contentOffset.x
                } else {
                    return false
                }
                
            }).sorted()
            
            if !visibleCellsIndexes.isEmpty {
                let nextIndex = visibleCellsIndexes[0].row + 1
                let previousIndex = visibleCellsIndexes[0].row - 1
                let nextIndexPath: IndexPath = IndexPath.init(item: nextIndex, section: 0)
                let previousIndexPath: IndexPath = IndexPath.init(item: previousIndex, section: 0)
                
                if direction == .left {
                    if previousIndex < firstIndex {
                        // Do your own thing
                    } else {
                        self.scrollToItem(at: previousIndexPath, at: .left, animated: true)
                    }
                } else if direction == .right {
                    if nextIndex > lastIndex {
                        // Do your own thing
                    } else {
                        self.scrollToItem(at: nextIndexPath, at: .left, animated: true)
                    }
                }
            }
        }
    }
}
