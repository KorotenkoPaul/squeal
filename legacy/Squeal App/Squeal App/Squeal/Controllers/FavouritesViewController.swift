//
//  FavouritesViewController.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit

var dictOfFavourite: [String: [String : [Any]]] = [:]

struct genreStruct {
    var genre: String!
}

class FavouritesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var tableView: UITableView! = nil
    var arrayOfGenres = [genreStruct]()
    var horrorDict: [[String: [Any]]] = []
    var romanceDict: [[String: [Any]]] = []
    var thrillerDict: [[String: [Any]]] = []
    
    func configurateTableView() {
        tableView = UITableView(frame: CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: view.bounds.height)), style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self

        tableView.frame = view.bounds
        tableView.register(FavouritesTableViewCell.self, forCellReuseIdentifier: "favouritesCell")
        tableView.rowHeight = 105
        tableView.separatorStyle = .none
        tableView.sectionFooterHeight = 0.01
        tableView.sectionHeaderHeight = 36
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        view.addSubview(tableView)
        tableView.backgroundColor = .clear
        tableView.tableHeaderView = {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 0.01))
            view.backgroundColor = .clear
            return view
        }()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if language == "english" {
            arrayOfGenres = [genreStruct.init(genre: "HORROR"), genreStruct.init(genre: "ROMANCE"), genreStruct.init(genre: "THRILLER")]
        } else if language == "french" {
            arrayOfGenres = [genreStruct.init(genre: "HORREUR"), genreStruct.init(genre: "ROMANCE"), genreStruct.init(genre: "THRILLER")]
        }
        view.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)

        

        configurateTableView()
        commutate()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTableView(sender:)), name: .reloadFavourites , object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        view.viewWithTag(666)?.removeFromSuperview()
        let placeholder = emptyView()
        placeholder.center = CGPoint(x: view.center.x + 11.5, y: view.center.y - 20)
        if !horrorDict.isEmpty || !romanceDict.isEmpty || !thrillerDict.isEmpty {
            placeholder.isHidden = true
        }
        view.addSubview(placeholder)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
        }
        if storyIsOpen {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "showTheTabBar"), object: nil, userInfo: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func reloadTableView(sender: Notification) {
        if language == "english" {
            arrayOfGenres = [genreStruct.init(genre: "HORROR"), genreStruct.init(genre: "ROMANCE"), genreStruct.init(genre: "THRILLER")]
        } else if language == "french" {
            arrayOfGenres = [genreStruct.init(genre: "HORREUR"), genreStruct.init(genre: "ROMANCE"), genreStruct.init(genre: "THRILLER")]
        }
        commutate()
        tableView.reloadData()
    }
    
    func commutate () {
        horrorDict = []
        romanceDict = []
        thrillerDict = []
        for i in dictOfFavourite.keys {
            if dictOfFavourite[i]!["genre"]![0] as! String == "horror" {
                horrorDict.append(dictOfFavourite[i]!)
            }else if dictOfFavourite[i]!["genre"]![0] as! String == "romance" {
                romanceDict.append(dictOfFavourite[i]!)
            }else if dictOfFavourite[i]!["genre"]![0] as! String == "thriller" {
                thrillerDict.append(dictOfFavourite[i]!)
            }
        }
        if !horrorDict.isEmpty || !romanceDict.isEmpty || !thrillerDict.isEmpty {
            tableView.isHidden = false
            view.viewWithTag(666)?.isHidden = true
        } else if horrorDict.isEmpty && romanceDict.isEmpty && thrillerDict.isEmpty {
            tableView.isHidden = true
            view.viewWithTag(666)?.isHidden = false
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return arrayOfGenres.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return horrorDict.count
        }else if section == 1 {
            return romanceDict.count
        }else{
            return thrillerDict.count
        }
        
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "favouritesCell") as! FavouritesTableViewCell
        cell.delegateForRemove = self
        // dataSource
        var dict = romanceDict
        if indexPath.section == 0 {
            dict = horrorDict
        }else if indexPath.section == 1 {
            dict = romanceDict
        }else{
            dict = thrillerDict
        }
        
        guard dict[indexPath.item]["name"]![0] as? String != nil else {
        
            return cell
        }

        guard dict[indexPath.item]["description"]![0] as? String != nil else {
         
            return cell
        }
        let globalName = dict[indexPath.item]["name"]![0] as! String
        cell.cellLabel.text = (dict[indexPath.item]["name"]![0] as? String)?.capitalizingFirstLetter()
        cell.cellAbout.text = dict[indexPath.item]["description"]![0] as? String
        if dict[indexPath.item]["image"]![0] as? UIImage != nil {
            cell.cellImage.image = dict[indexPath.item]["image"]![0] as? UIImage
        }

        let ganres = [horrorMenu, romanceMenu, thrillerMenu]

        for i in ganres {
            for j in i {
                dictOfProgress.updateValue(UserDefaults.standard.integer(forKey: "\(j.name.lowercased())"), forKey: j.name )
            }
        }
        for key in dictOfProgress.keys { //Переводим в нижний регистр все ключи в словаре
            if key != key.lowercased() {
                dictOfProgress[key.lowercased()] = dictOfProgress.removeValue(forKey: key)
            }
        }
        if dictOfProgress != [:]  {
            if  dictOfProgress.keys.contains(globalName.lowercased()) {
                let storyName = dict[indexPath.item]["name"]![0] as? String

                let progress = dictOfProgress[(storyName?.lowercased())!]
              
                if language == "english" {
                    cell.completedLabel.text = "Completed \(String(progress!))%"
                } else if language == "french" {
                    cell.completedLabel.text = "Terminé \(String(progress!))%"
                }
            } else {
                if language == "english" {
                    cell.completedLabel.text = "Completed 0%"
                } else if language == "french" {
                    cell.completedLabel.text = "Terminé 0%"
                }
            }
        }
        
        return cell
    }
    
    // MARK: sectionHeader
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            if horrorDict.isEmpty {
           
                return 0.001
            } else {
                return 36
            }
        } else if section == 1 {
            if romanceDict.isEmpty {
          
                return 0.001
            }else{
                return 36
            }
        }else{
            if thrillerDict.isEmpty {
            
                return 0.001
            }else{
                return 36
            }
        }
        
    }


    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 34))
        let label = UILabel(frame: CGRect(x: 30, y: 15, width: 119, height: 13))
        label.font = UIFont(name: "Helvetica-Bold", size: 12)
        label.textAlignment = .left
        label.backgroundColor = .clear
        view.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
        label.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 0.5)
        view.addSubview(label)

        label.text = arrayOfGenres[section].genre
        if section == 0 {
            if horrorDict.isEmpty {
                view.alpha = 0
            }
        } else if section == 1 {
            if romanceDict.isEmpty {
                view.alpha = 0
            }
        }else{
            if thrillerDict.isEmpty {
                view.alpha = 0
            }
        }
        return view
        
    }
    
    func maskCell(cell: UITableViewCell, fromTopWithMargin margin: CGFloat) {
        cell.layer.mask = visibilityMaskForCell(cell: cell, withLocation: margin/cell.frame.size.height)
        cell.layer.masksToBounds = true
    }
    
    func visibilityMaskForCell(cell: UITableViewCell, withLocation location: CGFloat) -> CAGradientLayer {
        let mask = CAGradientLayer()
        mask.frame = cell.bounds
        mask.colors = [UIColor.clear.cgColor, UIColor.white.cgColor]
        mask.locations = [NSNumber(value: Float(location)), NSNumber(value: Float(location))]
        return mask
    }
    
    private func emptyView() -> UIView {
        
        let view = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 300, height: 219 + 64 + 40)))
        
        let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: (view.frame.width-300)/2, y: 0), size: CGSize(width: 300, height: 219)))
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "add to favourites")
        view.addSubview(imageView)
        
        let offlineLabel = UILabel(frame: CGRect(origin: CGPoint(x: 4, y: 219 + 32), size: CGSize(width: 300, height: 20)))
        offlineLabel.numberOfLines = 0
        if UserDefaults.standard.string(forKey: "Languages") == nil || UserDefaults.standard.string(forKey: "Languages") == "english" {
            offlineLabel.text = "No favorite stories yet"
        } else {
            offlineLabel.text = "Aucune histoires préférées"
        }
        
        offlineLabel.textColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 1)
        offlineLabel.font = UIFont(name: "LucidaGrande-Bold", size: 17)
        
        offlineLabel.backgroundColor = .clear
        offlineLabel.textAlignment = .left
        offlineLabel.sizeToFit()
        offlineLabel.center = CGPoint.init(x: imageView.center.x, y: offlineLabel.center.y)
        view.addSubview(offlineLabel)
        
        let tapLabel = UILabel(frame: CGRect(origin: CGPoint(x: 0, y: 64 + 219), size: CGSize(width: 300, height: 40)))
        tapLabel.numberOfLines = 0
        
        var descTitle:String = ""
        if UserDefaults.standard.string(forKey: "Languages") == nil || UserDefaults.standard.string(forKey: "Languages") == "english" {
            descTitle = "1. Click and hold on any story\n2. Like it to save one"
        } else {
            descTitle = "1. Cliquez et appuyer sur une histoire\n2. Aimez pour la sauvegarder"
        }
        let attributedString = NSMutableAttributedString(string: descTitle)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.maximumLineHeight = 14
        paragraphStyle.minimumLineHeight = 14
        attributedString.addAttribute(NSAttributedStringKey.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, attributedString.length))
        
        tapLabel.attributedText = attributedString
        tapLabel.textColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.65)
        tapLabel.font = UIFont(name: "LucidaGrande", size: 14)
        tapLabel.backgroundColor = .clear
        tapLabel.sizeToFit()
        tapLabel.center = CGPoint.init(x: imageView.center.x, y: tapLabel.center.y)
        view.addSubview(tapLabel)
        
        view.tag = 666
        return view
        
    }
}


extension FavouritesViewController: FavouritesTableViewCellDelegate {

    func viewDidTapped(cell: FavouritesTableViewCell) {
        
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            status.backgroundColor = UIColor.clear
        }
        
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        var dict = romanceDict
        if indexPath.section == 0 {
            dict = horrorDict
        }else if indexPath.section == 1 {
            dict = romanceDict
        }else{
            dict = thrillerDict
        }

        globalForLeft = dict[indexPath.item]["forLeft"]! as! [String]
        globalForRight = dict[indexPath.item]["forRight"]! as! [String]
        globalScheme = dict[indexPath.item]["scheme"]! as! [String]
        globalMiddle = dict[indexPath.item]["middle"]! as! [String]
        globalStoryName = (dict[indexPath.item]["name"]![0] as! String).uppercased()
        globalUserName = (dict[indexPath.item]["name"]![0] as! String).lowercased()


        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
            cell.cellView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { (true) in
            globalStoryName = (cell.cellLabel.text?.capitalizingFirstLetter())!
            if Int(String(globalStoryName.last!)) != nil {
                episodeNumber = Int(String(globalStoryName.last!))!
            } else {
                episodeNumber = 1
            }
            self.performSegue(withIdentifier: "openMessengerFromFavourites", sender: self)

            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                cell.cellView.transform = .identity
            }, completion: nil)
        }
    }

    func removeCell(cell: FavouritesTableViewCell) {

//        if let indexPath = tableView.indexPath(for: cell) {
//            tableView.beginUpdates()
//            tableView.deleteRows(at: [indexPath], with: .fade)
//            tableView.endUpdates()
//        }

            let indexPath = self.tableView.indexPath(for: cell)
            if indexPath != nil {
                let cell = self.tableView.cellForRow(at: indexPath!)
                let favouriteCell = cell as! FavouritesTableViewCell

                if indexPath?.section == 0 {
                    self.horrorDict.remove(at: (indexPath?.item)!)
                    self.tableView.beginUpdates()
                    self.tableView.performBatchUpdates({
                        self.tableView.deleteRows(at: [indexPath!], with: .fade)
                    }, completion: { (true) in
                        self.tableView.reloadData()
                        let queue = DispatchQueue.main
                        queue.async{
                            dictOfFavourite.removeValue(forKey: favouriteCell.cellLabel.text!.lowercased())
                            let encodedData = NSKeyedArchiver.archivedData(withRootObject: dictOfFavourite)
                            UserDefaults.standard.set(encodedData, forKey: "Favourite")
                        }
                    })
                    self.tableView.endUpdates()

                }else if indexPath?.section == 1 {
                    self.romanceDict.remove(at: (indexPath?.item)!)
                    self.tableView.beginUpdates()
                    self.tableView.performBatchUpdates({
                        self.tableView.deleteRows(at: [indexPath!], with: .fade )

                    }, completion: { (true) in
                        self.tableView.reloadData()
                        let queue = DispatchQueue.main
                        queue.async{
                            dictOfFavourite.removeValue(forKey: favouriteCell.cellLabel.text!.lowercased())
                            let encodedData = NSKeyedArchiver.archivedData(withRootObject: dictOfFavourite)
                            UserDefaults.standard.set(encodedData, forKey: "Favourite")
                        }
                    })
                    self.tableView.endUpdates()
                }else{
                    self.thrillerDict.remove(at: (indexPath?.item)!)

                    self.tableView.beginUpdates()
                    self.tableView.performBatchUpdates({
                        self.tableView.deleteRows(at: [indexPath!], with: .fade)
                    }, completion: { (true) in
                        self.tableView.reloadData()
                        let queue = DispatchQueue.main
                        queue.async{
                            dictOfFavourite.removeValue(forKey: favouriteCell.cellLabel.text!.lowercased())
                            let encodedData = NSKeyedArchiver.archivedData(withRootObject: dictOfFavourite)
                            UserDefaults.standard.set(encodedData, forKey: "Favourite")
                        }
                    })
                    self.tableView.endUpdates()
                }
            }
        if !horrorDict.isEmpty || !romanceDict.isEmpty || !thrillerDict.isEmpty {
            tableView.isHidden = false
            view.viewWithTag(666)?.isHidden = true
        } else if horrorDict.isEmpty && romanceDict.isEmpty && thrillerDict.isEmpty{
            tableView.isHidden = true
            view.viewWithTag(666)?.isHidden = false
        }
    }
}
