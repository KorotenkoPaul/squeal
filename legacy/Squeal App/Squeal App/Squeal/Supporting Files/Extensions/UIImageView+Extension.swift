//
//  UIImageView+Extension.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit

extension UIImageView {
    public func imageFromUrl(urlString: String) {
        if let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                if error == nil {
                    guard let data = data else { return }
                    self.image = UIImage(data: data)
                }
            }
            
        }
        
    }
    
}
