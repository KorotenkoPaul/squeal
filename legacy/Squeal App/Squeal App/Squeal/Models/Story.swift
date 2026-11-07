//
//  Story.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit
import FirebaseStorage

var searchOpen = false
var afterSuccess = 0
var success = 0
var dictOfDownloadImageByUrl: [String: UIImage]! = [:]

class Story: NSObject {

    //MARK:- Vars
    var name: String!
    var storyDescription: String?
    var author: String?
    var releaseDate: String?
    var status: String?
    var genre: String?
    var images: UIImage?
    var episodes: [String] = []
    var img: String!
    
    var date:Date {
        
        let df = DateFormatter()
        df.dateFormat = "MMMM dd, yyyy"
        if UserDefaults.standard.string(forKey: "Languages") == nil || UserDefaults.standard.string(forKey: "Languages") == "english" {
            df.locale = Locale.init(identifier: "en_US")
        } else {
            df.locale = Locale.init(identifier: "fr_FR")
        }
        return df.date(from: releaseDate ?? "January 01, 1970")!
    }

    //MARK:- Init

    init(name: String!, storyDescription: String?, author: String?, releaseDate: String?, status: String?, genre: String?, image: String?, episodes: [String]) {
        super.init()
        self.name = name
        self.storyDescription = storyDescription
        self.author = author
        self.releaseDate = releaseDate
        self.status = status
        self.genre = genre
        self.episodes = episodes
        self.img = image

        if image == "" || image == nil {
            self.images =  UIImage(named: "nill")

        } else {
            if dictOfDownloadImageByUrl != nil {
                if dictOfDownloadImageByUrl.keys.contains(self.img.lowercased()) {
                    self.images = dictOfDownloadImageByUrl[self.img.lowercased()]
                } else {
                    download(image: image)
                }
            }else{
                download(image: image)
            }
        }


    }

    //MARK:- Private

    private func download (image: String?) {
        let storage = Storage.storage()
        DispatchQueue.main.async(execute: { () -> Void in
            let ref = storage.reference().child(image!)
            let done = ref.getData(maxSize: 20048*20048, completion: {data, error in
                if error != nil {
                    self.images = #imageLiteral(resourceName: "nill")
                    print ("error photo \(self.name!)")
                } else {
                    let backimg = UIImage(data: data!)
                    self.images = #imageLiteral(resourceName: "nill")
//                    if !dictOfDownloadImage.values.contains(backimg!) {
//                        dictOfDownloadImage.updateValue(backimg!, forKey: self.name.lowercased())
//                        //self.images = dictOfDownloadImage[self.name.lowercased()]
//                    } else {
//                        //self.images = dictOfDownloadImage[self.name.lowercased()]
//                    }
                    if !dictOfDownloadImageByUrl.values.contains(backimg!) {
                        dictOfDownloadImageByUrl.updateValue(backimg!, forKey: self.img.lowercased())
                        dictOfDownloadImage.updateValue(backimg!, forKey: self.name.lowercased())
                        self.images = dictOfDownloadImageByUrl[self.img.lowercased()]
                    } else {
                        self.images = dictOfDownloadImageByUrl[self.img.lowercased()]
                    }
                }})

            done.observe(.success) { snapshot in
                afterSuccess += 1

                if success < 11 {
                    success = success + 1
                    print(success)

                }

                if afterSuccess >= 11{
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 , execute: {
                        if searchOpen == true && dictOfDownloadImageByUrl.keys.contains(self.img.lowercased()) {
                            print("will search reload")
                            //                            NotificationCenter.default.post(name: .SearchReload, object: nil)
                            print("reload \(self.name.lowercased())")
                            print(afterSuccess)
                        }else if self.genre == changeGenre && dictOfDownloadImageByUrl.keys.contains(self.img.lowercased()){
                            print("will search reload")
                            //                            NotificationCenter.default.post(name: .reload, object: nil)
                            print("reload")
                            print(afterSuccess)
                        }
                    })

                }
            }
        })

    }

}
