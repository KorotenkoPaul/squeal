//
//  MessengerFlowLayout.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit

class MessengerFlowLayout: UICollectionViewFlowLayout {

    fileprivate var cache = [UICollectionViewLayoutAttributes]()
    
    
    var contentHeight = 0
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: (collectionView?.frame.width)!, height: CGFloat(contentHeight))
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override func prepare() {
        // 1
        guard let collectionView = collectionView else { return }
        cache = []
        var yOffset = 0
        
        for item in 0 ..< collectionView.numberOfItems(inSection: 0) {
            
            let indexPath = IndexPath(item: item, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            
            var height: CGFloat! = (globalTen * 10)
            if !globalHeight.isEmpty {
                height = globalHeight[item].height + globalTen * 2
            }
            
            attributes.frame.origin = CGPoint(x: 0, y: (yOffset))
            attributes.frame.size.width = collectionView.frame.width
            attributes.frame.size.height = height
            
            if item > 0 {
                
                if globalScheme[item] == globalScheme[item - 1] {
                    attributes.frame.origin.y += 3
                } else {
                    attributes.frame.origin.y += 20
                }
 
            }
            
            cache.append(attributes)
            
            yOffset = yOffset + Int(height) + 1
            
            if item > 0 {
                
                if globalScheme[item] == globalScheme[item - 1] {
                    yOffset += 3
                } else { yOffset += 20 }
                
            }
            
            contentHeight = 0
            contentHeight = max(contentHeight, yOffset)
            
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache[indexPath.item]
    }
    
    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {

        var visibleLayoutAttributes = [UICollectionViewLayoutAttributes]()


        for attributes in cache {
            if attributes.frame.intersects(rect) {
                visibleLayoutAttributes.append(attributes)
            }
        }
        return visibleLayoutAttributes
    }
    
}
