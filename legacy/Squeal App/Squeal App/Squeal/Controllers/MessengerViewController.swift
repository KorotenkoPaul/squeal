//
//  messenger.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit
import FirebaseDatabase
import StoreKit

var globalForLeft: [String] = []
var globalForRight: [String] = []
var globalScheme: [String] = []
var globalMiddle: [String] = []
var globalStoryName: String = ""
var globalUserIcon: String! = String()
var globalUserName: String! = ""
var globalHeight: [CGSize] = []
var globalImagesHeightR: [CGSize] = []
var globalImagesHeightL: [CGSize] = []
var globalTen: CGFloat = 0

var globalString: String! = String()
var dictOfStoryPhotos = [String() : UIImage()]
//--------------------
var progress: Int! = 0
var limitOfTaps: Int! = Int()
var contentOffset: CGFloat = 0



class MessengerViewController: UIViewController {
    
    //MARK:- Outlets
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var navigationView: UIView!
    @IBOutlet weak var messengerCollectionView: UICollectionView!
    @IBOutlet weak var ratingView: UIView!
    @IBOutlet weak var bottomOfRate: NSLayoutConstraint!
    @IBOutlet weak var userName: UILabel!
    @IBOutlet weak var episodeNum: UILabel!
    
    //@IBOutlet weak var iconHeight: NSLayoutConstraint!
    @IBOutlet weak var loadingStory: UIActivityIndicatorView!
    @IBOutlet weak var navigationHeight: NSLayoutConstraint!
    
    @IBOutlet weak var taptocontinueLabel: UILabel!
    
    //MARK:- Vars
 
    var row: Int = 0
    var leftMessages: [String]! = []
    var rightMessages: [String]! = []
    var firstMessage = false
    
    var dictForNoKey = [Int() : ()]
    var indexOfRights = [Int():Int()]
    var indexOfLefts = [Int():Int()]
 
    var messengerFlowLayout: MessengerFlowLayout!
    let openPhoto: UIView = UIView()
    let forHeightLabel: UILabel! = UILabel()
    var lastMess = false
    
    //------timers----*
    var loadingStartTimer = Timer()
    var timerTaps = Timer()
    
    var cellOriginY: [Int:CGFloat] = [:]
    var layers: [Int: CALayer] = [:]
    
    var ref: DatabaseReference!
    var databaseHandle: DatabaseHandle?
    
    //let toBottomButton = UIButton()

    //MARK:- Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //setUpToBottom()
        
        self.view.backgroundColor = self.ratingView.backgroundColor
        
        var done = false
        messengerCollectionView.delegate = self
        messengerCollectionView.dataSource = self
        messengerFlowLayout = MessengerFlowLayout()
        messengerCollectionView.collectionViewLayout = messengerFlowLayout
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapForNextMessage(_:)))
        messengerCollectionView.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
        globalTen = self.view.frame.width * 0.0241545
        progress = UserDefaults.standard.integer(forKey: globalStoryName.lowercased())
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longTouch(press:)))
        longPress.minimumPressDuration = 0.3
        messengerCollectionView.addGestureRecognizer(longPress)
        
        if self.view.frame.height >= 812 {
           bottomOfRate.constant = 0 - ratingView.frame.height - 34
           navigationHeight.constant =  navigationHeight.constant + 44
          
        } else {
            bottomOfRate.constant = 0 - ratingView.frame.height
        }
        
        self.view.addSubview(forHeightLabel) // лэйбл для высот
        forHeightLabel.frame.size.width = self.view.frame.width - (self.view.frame.width * 0.02415 + self.view.frame.width * 0.2415 ) - globalTen * 2
        forHeightLabel.frame.size.height = 1000
        forHeightLabel.layer.opacity = 0
        forHeightLabel.numberOfLines = 0
        forHeightLabel.font = UIFont(name: ".SFUIText", size: view.frame.size.width * 0.0410628)
        messengerCollectionView.contentInset = UIEdgeInsetsMake(self.navigationView.frame.height + 20, 0, self.view.frame.height / 2.5, 0)
        messengerCollectionView.register(MessengerCell.self, forCellWithReuseIdentifier: "messengerCell")
        
        //-------------Start Messaging/Finish Loading Story ----------*
        loadingStory.startAnimating()
        loadingStartTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (true) in
            if  !globalHeight.isEmpty && done == true {
                self.loadingStartTimer.invalidate()
                CATransaction.begin()
                progress = UserDefaults.standard.integer(forKey: "\(globalStoryName.lowercased())")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                if progress > 0 {
                    if progress == 100 {
                        progress = 99
                        let progressRow = progress * (globalScheme.count - 1) / 100
                        for _ in 0 ... (progressRow + 1) {
                            self.autoMessenger()
                            self.sumOfRows()
                        }
                    } else {
                        let progressRow = progress * (globalScheme.count - 1) / 100
                        for _ in 0 ... progressRow {
                            self.autoMessenger()
                            self.sumOfRows()
                        }
                    }
                }
                
                    
                    self.loadingStory.stopAnimating()
                    self.loadingStory.isHidden = true
                    self.userName.isHidden = false
                    self.episodeNum.isHidden = false
                    if progress == 100 {
                        self.sumOfRows()
                    }
                    self.autoMessenger ()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                        self.firstMessage = true //14.06
              
                    })
                CATransaction.setCompletionBlock({
                    self.collectionView.scrollToItem(at: IndexPath(item: self.collectionView.numberOfItems(inSection: 0) - 1, section: 0), at: .bottom, animated: true)
                })
                CATransaction.commit()
                })
            }
            
            if !globalForRight.isEmpty && !globalForLeft.isEmpty && !globalScheme.isEmpty && done == false {
                
                
                if limitOfTaps <= 0 {
                self.timerTaps = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.timeForTaps), userInfo: nil, repeats: true)
                }
                //-------*
                
                self.leftsAndRights ()
                self.getMetadata()
                self.userName.isHidden = true
                self.episodeNum.isHidden = true
                episodeNumber = 1
                var forName: String = globalUserName.capitalizingFirstLetter()
                let intsArray = [1,2,3]
                for i in intsArray {
                    if forName.contains(String(i)) {
                        episodeNumber = i
                    }
                }
                
                var forConsist = ""
                var integer = 0
                
                if language == "english" {
                    self.thankLabel.text = "Thank you for your vote!"
                    self.episodeNum.text = "Episode \(episodeNumber)"
                    forConsist = "part"
                    integer = 7
                } else {
                    self.thankLabel.text = "Nous vous remercions pour votre vote!"
                    self.episodeNum.text = "Épisode \(episodeNumber)"
                    forConsist = " "
                    integer = 2
                }
                
                var z: [Character] = []
                
     
                for i in intsArray {
                if forName.contains(forConsist) && forName.contains(String(i)) {
              
                    z = []
                    var t: [Character] = []
                    for i in forName {
                        z.append(i)
                    }
                    for i in 0 ..< z.count - integer {
                        t.append(z[i])
                    }
           
                    forName = ""
                    for i in t {
                        forName += String(i)
                    }
                    
                    }}
                
                self.userName.text = forName
                //-------
                done = true
                
                self.setViews(completion: { (true) in
                    self.ref.child("conversion").observe(.value, with: { snapshot in
                        let conversionArray = snapshot.value ?? "nil"  as AnyObject
                        let viewsDict = conversionArray as? [String: [String: [String: Double]]]
                        
                    
                        if viewsDict != nil {
                            dictOfViews = viewsDict!
                 
                        }
                        
                    })
                })
                
            } else { return }
        })
        
        
        loadingStartTimer.fire()
        translate()
        

    }
    
    let longPressView = UIView()
    let longPressLabel = UILabel()
    
    @objc func longTouch(press: UILongPressGestureRecognizer) {
        
        let twenty = self.view.frame.width * 0.048309
        let ten = self.view.frame.width * 0.0241545
        
        let location = press.location(in: messengerCollectionView)
        
        if let indexPath = self.collectionView.indexPathForItem(at: location) {
            
            if let collectionViewCell = self.collectionView.cellForItem(at: indexPath) {
                
                if let cell = collectionViewCell as? MessengerCell {
                    
                    let cell = collectionViewCell as! MessengerCell
                    if press.state == .began {
                        
                        hideUIElements()
                        
                        if #available(iOS 10.0, *) {
                            let vibrate = UISelectionFeedbackGenerator()
                            vibrate.selectionChanged()
                        }
                        
                        if cell.leftLabel.text != "" {
                            
                            UIView.animate(withDuration: 0.2, delay: 0, options: [], animations: {
                                cell.leftLabel.alpha = 0
                            }) { (true) in
                                cell.leftMessage.alpha = 0
                                self.longPressView.frame.size = cell.leftMessage.frame.size
                                
                                self.longPressLabel.text = "Ça n’a aucun sens.\nOkay?" //
                                self.longPressLabel.frame.origin.y = ten
                                self.longPressLabel.sizeToFit()
                                self.longPressLabel.frame.origin.x = ten
                                self.longPressView.alpha = 1
                                
                                UIView.animate(withDuration: 0.2, delay: 0, options: [], animations: {
                                    self.longPressView.frame.size.width = self.longPressLabel.frame.size.width + twenty
                                    self.longPressView.frame.size.height = self.longPressLabel.frame.size.height + twenty
                                }, completion: { (true) in
                                    UIView.animate(withDuration: 0.2, animations: {
                                        self.longPressLabel.alpha = 1
                                    })
                                })
                            }
                            
                            // Поставить такое условие, чтобы высота переведенного сообщения считалась сразу, а не после первого нажатия
                            if longPressLabel.frame.size.height + 10 > cell.leftLabel.frame.size.height {
                                
                                //
                                var firstIndexPath = indexPath
                                firstIndexPath.item += 1
                                var secondIndexPath = indexPath
                                secondIndexPath.item += 2
                                var thirdIndexPath = indexPath
                                thirdIndexPath.item += 3
                                var fourthIndexPath = indexPath
                                fourthIndexPath.item += 4
                                var fifthIndexPath = indexPath
                                fifthIndexPath.item += 5
                                var sixthIndexPath = indexPath
                                sixthIndexPath.item += 6
                                var seventhIndexPath = indexPath
                                seventhIndexPath.item += 7
                                var eightthIndexPath = indexPath
                                eightthIndexPath.item += 8
                                var ninethIndexPath = indexPath
                                ninethIndexPath.item += 9
                                var tenthIndexPath = indexPath
                                tenthIndexPath.item += 10
                                var eleventhIndexPath = indexPath
                                eleventhIndexPath.item += 11
                                var twelvethIndexPath = indexPath
                                twelvethIndexPath.item += 12
                                var thirteenthIndexPath = indexPath
                                thirteenthIndexPath.item += 13
                                var fourteenthIndexPath = indexPath
                                fourteenthIndexPath.item += 14
                                var fifteenthIndexPath = indexPath
                                fifteenthIndexPath.item += 15
                                
                                if let firstCell = messengerCollectionView.cellForItem(at: firstIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        firstCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let secondCell = messengerCollectionView.cellForItem(at: secondIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        secondCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let thirdCell = messengerCollectionView.cellForItem(at: thirdIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        thirdCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let fourthCell = messengerCollectionView.cellForItem(at: fourthIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        fourthCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let fifthCell = messengerCollectionView.cellForItem(at: fifthIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        fifthCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let sixthCell = messengerCollectionView.cellForItem(at: sixthIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        sixthCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let seventhCell = messengerCollectionView.cellForItem(at: seventhIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        seventhCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let eightthCell = messengerCollectionView.cellForItem(at: eightthIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        eightthCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let ninethCell = messengerCollectionView.cellForItem(at: ninethIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        ninethCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let tenthCell = messengerCollectionView.cellForItem(at: tenthIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        tenthCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let eleventhCell = messengerCollectionView.cellForItem(at: eleventhIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        eleventhCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let twelvethCell = messengerCollectionView.cellForItem(at: twelvethIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        twelvethCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let thirteenthCell = messengerCollectionView.cellForItem(at: thirteenthIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        thirteenthCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let fourteenthCell = messengerCollectionView.cellForItem(at: fourteenthIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        fourteenthCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                
                                if let fifteenthCell = messengerCollectionView.cellForItem(at: fifteenthIndexPath) as? MessengerCell {
                                    
                                    UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                                        fifteenthCell.transform = CGAffineTransform(translationX: 0, y: 20)
                                    }, completion: nil)
                                    
                                }
                                //
                            }
                            
                            
                            longPressView.frame.origin.x = cell.frame.origin.x + cell.leftMessage.frame.origin.x
                            longPressView.frame.origin.y = cell.frame.origin.y - collectionView.contentOffset.y
                            longPressView.alpha = 0
                            longPressView.clipsToBounds = true
                            longPressView.layer.cornerRadius = 15
                            longPressView.backgroundColor = UIColor(red: 0.34, green: 0.33, blue: 0.39, alpha: 1.0)
                            view.addSubview(longPressView)
                            
                            //longPressLabel.frame = cell.leftLabel.frame
                            longPressLabel.alpha = 0
                            longPressLabel.textColor = cell.leftLabel.textColor
                            longPressLabel.font = cell.leftLabel.font
                            longPressLabel.textAlignment = cell.leftLabel.textAlignment
                            longPressLabel.numberOfLines = 0
                            longPressView.addSubview(longPressLabel)
                            
                        }else{
                            
                            cell.rightMessage.alpha = 0
                            
                            longPressView.frame.size = cell.rightMessage.frame.size
                            longPressView.frame.origin.x = cell.frame.origin.x + cell.rightMessage.frame.origin.x
                            longPressView.frame.origin.y = cell.frame.origin.y - collectionView.contentOffset.y
                            longPressView.alpha = 1
                            longPressView.clipsToBounds = true
                            longPressView.layer.cornerRadius = 15
                            longPressView.backgroundColor = UIColor(red: 0.43, green: 0.31, blue: 0.68, alpha: 1.0)
                            view.addSubview(longPressView)
                            
                            longPressLabel.frame = cell.rightLabel.frame
                            longPressLabel.text = cell.rightLabel.text
                            longPressLabel.textColor = .red//cell.rightLabel.textColor
                            longPressLabel.font = cell.rightLabel.font
                            longPressLabel.textAlignment = cell.rightLabel.textAlignment
                            longPressLabel.numberOfLines = 0
                            longPressView.addSubview(longPressLabel)
                        }
                        
                        print(indexPath)
                    }
                    // Если отпустить палец не на этом сообщении, то оно не появляется
                    if press.state == .ended || press.state == .cancelled {
                        var firstIndexPath = indexPath
                        firstIndexPath.item += 1
                        var secondIndexPath = indexPath
                        secondIndexPath.item += 2
                        var thirdIndexPath = indexPath
                        thirdIndexPath.item += 3
                        var fourthIndexPath = indexPath
                        fourthIndexPath.item += 4
                        var fifthIndexPath = indexPath
                        fifthIndexPath.item += 5
                        var sixthIndexPath = indexPath
                        sixthIndexPath.item += 6
                        var seventhIndexPath = indexPath
                        seventhIndexPath.item += 7
                        var eightthIndexPath = indexPath
                        eightthIndexPath.item += 8
                        var ninethIndexPath = indexPath
                        ninethIndexPath.item += 9
                        var tenthIndexPath = indexPath
                        tenthIndexPath.item += 10
                        var eleventhIndexPath = indexPath
                        eleventhIndexPath.item += 11
                        var twelvethIndexPath = indexPath
                        twelvethIndexPath.item += 12
                        var thirteenthIndexPath = indexPath
                        thirteenthIndexPath.item += 13
                        var fourteenthIndexPath = indexPath
                        fourteenthIndexPath.item += 14
                        var fifteenthIndexPath = indexPath
                        fifteenthIndexPath.item += 15
                        
                        UIView.animate(withDuration: 0.2, delay: 0, options: [], animations: {
                            self.longPressLabel.alpha = 0
                            self.longPressView.frame.size = cell.leftMessage.frame.size
                            
                            if let firstCell = self.messengerCollectionView.cellForItem(at: firstIndexPath) as? MessengerCell {
                            firstCell.transform = .identity
                            }
                            if let secondCell = self.messengerCollectionView.cellForItem(at: secondIndexPath) as? MessengerCell {
                            secondCell.transform = .identity
                            }
                            
                            if let thirdCell = self.messengerCollectionView.cellForItem(at: thirdIndexPath) as? MessengerCell {
                            thirdCell.transform = .identity
                            }
                            
                            if let fourthCell = self.messengerCollectionView.cellForItem(at: fourthIndexPath) as? MessengerCell {
                            fourthCell.transform = .identity
                            }
                            
                            if let fifthCell = self.messengerCollectionView.cellForItem(at: fifthIndexPath) as? MessengerCell {
                            fifthCell.transform = .identity
                            }
                            
                            if let sixthCell = self.messengerCollectionView.cellForItem(at: sixthIndexPath) as? MessengerCell {
                            sixthCell.transform = .identity
                            }
                            
                            if let seventhCell = self.messengerCollectionView.cellForItem(at: seventhIndexPath) as? MessengerCell {
                                seventhCell.transform = .identity
                            }
                            
                            if let eightthCell = self.messengerCollectionView.cellForItem(at: eightthIndexPath) as? MessengerCell {
                                eightthCell.transform = .identity
                            }
                            
                            if let ninethCell = self.messengerCollectionView.cellForItem(at: ninethIndexPath) as? MessengerCell {
                                ninethCell.transform = .identity
                            }
                            
                            if let tenthCell = self.messengerCollectionView.cellForItem(at: tenthIndexPath) as? MessengerCell {
                                tenthCell.transform = .identity
                            }
                            
                            if let eleventhCell = self.messengerCollectionView.cellForItem(at: eleventhIndexPath) as? MessengerCell {
                                eleventhCell.transform = .identity
                            }
                            
                            if let twelvethCell = self.messengerCollectionView.cellForItem(at: twelvethIndexPath) as? MessengerCell {
                                twelvethCell.transform = .identity
                            }
                            
                            if let thirteenthCell = self.messengerCollectionView.cellForItem(at: thirteenthIndexPath) as? MessengerCell {
                                thirteenthCell.transform = .identity
                            }
                            
                            if let fourteenthCell = self.messengerCollectionView.cellForItem(at: fourteenthIndexPath) as? MessengerCell {
                                fourteenthCell.transform = .identity
                            }
                            
                            if let fifteenthCell = self.messengerCollectionView.cellForItem(at: fifteenthIndexPath) as? MessengerCell {
                                fifteenthCell.transform = .identity
                            }
                        }) { (true) in
                            self.longPressView.alpha = 0
                            cell.leftMessage.alpha = 1
                            cell.rightMessage.alpha = 1
                            UIView.animate(withDuration: 0.2, animations: {
                                cell.leftLabel.alpha = 1
                                cell.rightLabel.alpha = 1
                            })
                        }
                        
                        //cell.leftMessage.alpha = 1
                        //cell.leftLabel.alpha = 1
                        //cell.rightMessage.alpha = 1
                        //cell.rightLabel.alpha = 1
                        print("Ended")
                    }
                }
            }
        }
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        statusBarColor = "messenger"
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            status.backgroundColor = collectionView.backgroundColor
        }
    }
    
    //MARK:- Private
    
    func setViews (completion: @escaping (Bool)->()) {
        self.ref = Database.database().reference().child("conversion/\(globalStoryName.lowercased())/views")
        self.ref.runTransactionBlock({ (currentData: MutableData) -> TransactionResult in
            var post = currentData.value as? [String : AnyObject]
            var starCount = post?["num"] as? Int ?? 0
            starCount += 1
            currentData.value = ["num": starCount]
            
            let comp = true
            completion(comp)
            return TransactionResult.success(withValue: currentData)
            
        }) { (error, committed, snapshot) in
            if let error = error {
                print(error.localizedDescription)
            }
        }
    }

    
    private func translate() {
        if language == "french" {
            taptocontinueLabel.text = "APPUYEZ POUR CONTINUER"
            chooseStoryOutlet.setTitle("CHOISIR UNE AUTRE HISTOIRE", for: .normal)
        }
    }

    

    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        contentOffset = -75.0
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let scrollPos = CGFloat(scrollView.contentOffset.y)
        
        if (scrollPos >= contentOffset) && navBarTopConstraint.constant == 0 {
            self.navBarTopConstraint.constant = -(self.navigationView.frame.height)
            UIView.animate(withDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
        } else if (scrollPos <= contentOffset) && navBarTopConstraint.constant != 0 {
            self.navBarTopConstraint.constant = 0
            UIView.animate(withDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
        }
        
        hideUIElements()
    
    }
    
//-------------БЛОК МЕССЕНДЖЕРА ----------------------------*
    
  
    
    @IBOutlet weak var navBarTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var navBarHeightConstraint: NSLayoutConstraint!
    
    var timer: Timer?
    
    @objc func showHiddedUIElements() {
        UIView.animate(withDuration: 0.5) {
            self.taptocontinueLabel.layer.opacity = 1
        }
        //self.taptocontinueLabel.isHidden = false
        //self.navBarHeightConstraint.constant = 70
    }

    func hideUIElements() {
        UIView.animate(withDuration: 0.5) {
            self.taptocontinueLabel.layer.opacity = 0
        }
        //self.taptocontinueLabel.isHidden = true
        //self.navBarHeightConstraint.constant = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 8, target: self, selector: #selector(self.showHiddedUIElements), userInfo: nil, repeats: false)
    }
    
    @IBAction func tapForNextMessage(_ sender: UITapGestureRecognizer) {
        
        hideUIElements()
        
        if limitOfTaps > 0 || UserDefaults.standard.bool(forKey: "com.pauldevelopers.ios.subscription") {
        if firstMessage {// 14.06
            sumOfRows()
            autoMessenger()
            limitOfTaps = limitOfTaps - 1
            UserDefaults.standard.set(limitOfTaps, forKey: "Taps")
            if limitOfTaps <= 0 && !self.timerTaps.isValid {
                let nowTime = Int(time(what: "hours"))!*60 + Int(time(what: "Min"))!
                let Month = Int(time(what: "Month"))
                let Day =  Int(time(what: "day"))
                UserDefaults.standard.set(Month!, forKey: "PreDataMonth")
                UserDefaults.standard.set(Day!, forKey: "PreDataDay")
                UserDefaults.standard.set(nowTime, forKey: "PreDataTime")
                self.timerTaps = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.timeForTaps), userInfo: nil, repeats: true)
            }
        }
        } else {
            self.performSegue(withIdentifier: "showPay", sender: self)
        }

    }
    
  //----------------------------------------
    
//--------------------ВЫВОД СООБЩЕНИЙ---------------------------------*
    
    func leftsAndRights (){
        var zeroLeft = 0
        var zeroRight = 0
        for i in 0...globalScheme.count - 1{
            if globalScheme[i] == "R" {
                indexOfRights.updateValue(zeroRight, forKey: i)
                zeroRight = zeroRight + 1
            }
            else if globalScheme[i] == "L" {
                indexOfLefts.updateValue(zeroLeft, forKey: i)
                zeroLeft = zeroLeft + 1
            }}
    }
    
    func getMetadata()  {
        globalImagesHeightR = []
        globalImagesHeightL = []
        
        let ten = self.view.frame.width * 0.0241545
        let queue = DispatchQueue.main
        queue.async{
        CATransaction.begin()
        for text in globalForRight {
            var size: CGSize! = CGSize()
            if text.contains("http"){
                let url = URL(string: text)
                if let img = CGImageSourceCreateWithURL(url! as CFURL, nil) {
                    DispatchQueue.main.async {
                        if let imageProperties = CGImageSourceCopyPropertiesAtIndex(img, 0, nil) as Dictionary? {
                            let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as! CGFloat
                            let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as! CGFloat
                            let selfHeight = self.view.frame.height * 0.4
                            let imgWidth = (pixelWidth) * (selfHeight / pixelHeight)
                            let imgSHeight = (pixelHeight) * (selfHeight / pixelHeight)
                            var coefWidth: CGFloat = 1
                            if imgWidth > self.view.frame.width * 0.7 {
                                coefWidth = self.view.frame.width * 0.7 / imgWidth
                            }
                            let width = imgWidth * coefWidth
                            let
                            
                            
                            height = imgSHeight * coefWidth
                           // print(CGSize(width: width, height: height))
                            
                            size = CGSize(width: width - (ten*2), height: height - (ten*2))
                            globalImagesHeightR.append(size)
                        }
                    }
                }
            }
        }
        for text in globalForLeft {
            var size: CGSize! = CGSize()
            if text.contains("http"){
                let url = URL(string: text)
                if let img = CGImageSourceCreateWithURL(url! as CFURL, nil) {
                    DispatchQueue.main.async {
                        if let imageProperties = CGImageSourceCopyPropertiesAtIndex(img, 0, nil) as Dictionary? {
                            let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as! CGFloat
                            let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as! CGFloat
                            let selfHeight = self.view.frame.height * 0.4
                            let imgWidth = (pixelWidth) * (selfHeight / pixelHeight)
                            let imgSHeight = (pixelHeight) * (selfHeight / pixelHeight)
                            var coefWidth: CGFloat = 1
                            if imgWidth > self.view.frame.width * 0.7 {
                                coefWidth = self.view.frame.width * 0.7 / imgWidth
                            }
                            let width = imgWidth * coefWidth
                            let height = imgSHeight * coefWidth
                            //print(CGSize(width: width, height: height))
                            
                            size = CGSize(width: width - (ten*2), height: height - (ten*2))
                            globalImagesHeightL.append(size)
                        }
                    }
                }
            }
            
        }
            CATransaction.setCompletionBlock(self.heightOfText)
        CATransaction.commit()
        
        }
    }
    
    func heightOfText() {
        let ten = self.view.frame.width * 0.0241545
        globalHeight = []
        forHeightLabel.text = ""
        var rights = 0
        var lefts = 0
        var rightImg = 0
        var leftImg = 0
        let width = self.view.frame.width - (self.view.frame.width * 0.02415 + self.view.frame.width * 0.2415 ) - (ten*2)
        for i in globalScheme {
            forHeightLabel.text = ""
            if UIScreen.main.bounds.height == 568 {
                forHeightLabel.font = UIFont(name: "Helvetica", size: 15)
                
            } else {
                forHeightLabel.font = UIFont(name: "Helvetica", size: 17)
            }
            //forHeightLabel.font = UIFont(name: ".SFUIText", size: view.frame.size.width * 0.0410628)
            if i == "R" {
                if globalForRight[rights].contains("http") {
                    forHeightLabel.text = globalForRight[rights]
                    rights = rights + 1
                    let height = globalImagesHeightR[rightImg].height  // высота картинки R
                    
                    globalHeight.append(CGSize(width: globalImagesHeightR[rightImg].width, height: height))
                    rightImg += 1
                }else{
                    forHeightLabel.text = globalForRight[rights]
                    rights = rights + 1
                    let height = forHeightLabel.textRect(forBounds: CGRect(x: 0, y: 0, width: width, height: 1000) , limitedToNumberOfLines: 20).size
                    globalHeight.append(height)
                }
            } else if i == "L" {
                if globalForLeft[lefts].contains("http") {
                    forHeightLabel.text = globalForLeft[lefts]
                    lefts = lefts + 1
                    let height = globalImagesHeightL[leftImg].height // высота картинки L
                    globalHeight.append(CGSize(width: globalImagesHeightL[leftImg].width, height: height))
                    leftImg += 1
                }else{
                    forHeightLabel.text = globalForLeft[lefts]
                    lefts = lefts + 1
                    let height = forHeightLabel.textRect(forBounds: CGRect(x: 0, y: 0, width: width, height: 1000) , limitedToNumberOfLines: 20).size
                    globalHeight.append(height)
                }}
        }
    
    }
    
    func autoMessenger() { //автовыбор функции
        
        if row >= globalScheme.count {row = globalScheme.count - 1}
        
        var nextMessage: String
        var checkScheme = globalScheme
        if row >= checkScheme.count - 1 {nextMessage = "NaN"} else {nextMessage = checkScheme[self.row + 1]}
        var rights: Int
        var lefts: Int
        if indexOfRights[row + 1] == nil {rights = 0}else{rights = indexOfRights[row + 1]!}
        if indexOfLefts[row] == nil {lefts = 0}else{lefts = indexOfLefts[row]!}
        
        if checkScheme[row] == "L" {
            dictForNoKey.updateValue(self.forNoKeyboardModeLeft (leftMessage: row, forLeftMess: lefts, next: nextMessage, forRight: rights) , forKey: row)
            
            
        }else if checkScheme[row] == "R" {
            dictForNoKey.updateValue(self.forNoKeyboardModeRight(rightMessage: row, forRightMess: indexOfRights[row]!, next: nextMessage, forRight: rights), forKey: row)    }
}
    
    func forNoKeyboardModeLeft (leftMessage: Int, forLeftMess: Int, next: String , forRight: Int) {
        if next == "L" || next == "NaN"{
            if self.row == leftMessage {
                appendingAndInserts(side: "left", forLeftMess: forLeftMess, forRightMess: "0")
                progress = row * 100 / (globalScheme.count - 1)}
            else {return}}
        else if next == "R" {
            if self.row == leftMessage {
                appendingAndInserts(side: "left", forLeftMess: forLeftMess, forRightMess: "0")
                progress = row * 100 / (globalScheme.count - 1)}
            else {return}
        }
    }
    
    func forNoKeyboardModeRight (rightMessage: Int, forRightMess: Int, next: String, forRight: Int) {
        if next == "L" || next == "NaN"{
            if self.row == rightMessage {
                appendingAndInserts(side: "right", forLeftMess: 0, forRightMess: String(forRightMess))
                progress = row * 100 / (globalScheme.count - 1)
            }else {return} }
        else if next == "R" {
            if self.row == rightMessage {
                appendingAndInserts(side: "right", forLeftMess: 0, forRightMess: String(forRightMess))
                progress = row * 100 / (globalScheme.count - 1)
            }else {return} }
    }
   
    func appendingAndInserts (side: String, forLeftMess: Int, forRightMess: String) {
        //ОШибочка
        var offset = self.messengerCollectionView.contentSize.height - (self.messengerCollectionView.frame.height - self.messengerCollectionView.contentInset.bottom) + globalHeight[self.row].height
        
        if progress == 100 {
            offset = self.messengerCollectionView.contentSize.height - (self.messengerCollectionView.frame.height - self.messengerCollectionView.contentInset.bottom)
        }
        
        if self.messengerCollectionView.contentOffset.y < offset  {
            
            UIView.animate(withDuration: 0.2, delay: 0, options: [UIViewAnimationOptions.curveLinear, UIViewAnimationOptions.beginFromCurrentState, UIViewAnimationOptions.allowUserInteraction], animations: {
                self.messengerCollectionView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                self.view.layoutIfNeeded()
            }, completion: nil)
        
        }
        
        //let ten = self.view.frame.width * 0.0241545
        if row != globalScheme.count && self.lastMess == false {
            if side == "right" { // правые
                if leftMessages == [] {
                        self.rightMessages = [globalForRight[Int(forRightMess)!]]
                        self.leftMessages = [""]
                        
                }else{
                        self.rightMessages.append(globalForRight[Int(forRightMess)!])
                        self.leftMessages.append("")
                }
                messengerCollectionView.reloadData() //13.06
            }else{ // левые
                if leftMessages == [] {
                    self.leftMessages = [globalForLeft[forLeftMess]]
                    self.rightMessages = [""]
                }else {
                    self.leftMessages.append(globalForLeft[forLeftMess]) ;
                    self.rightMessages.append("")
                }
                messengerCollectionView.reloadData()
            }
//-------- scroll when last mess & common scroll 13.06 -----------*
            if progress == 100 {
            lastMess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: {
                let indexPath = IndexPath(item: self.messengerCollectionView.numberOfItems(inSection: 0) - 1,section: 0)
                UIView.animate(withDuration: 0.5) {
                            self.bottomOfRate.constant = 0
                            //self.messengerCollectionView.contentInset = UIEdgeInsetsMake(self.navigationView.frame.height + 20, 0, self.view.frame.height / 2.5, 0)
                            //self.messengerCollectionView.scrollToItem(at: indexPath, at: .bottom, animated: false)
                            self.messengerCollectionView.setNeedsLayout()
                            self.view.layoutIfNeeded()
            }})}
        } else { return }
        
        
    }
    
    
    func sumOfRows () {
        if row == globalScheme.count - 1 {
            self.row = globalScheme.count - 1
        }else{
            row = row + 1
        }
        progress = row * 100 / (globalScheme.count - 1)
    }

    //MARK:- Actions

    @IBAction func dismiss(_ sender: Any) {
        
        UserDefaults.standard.set(progress, forKey: globalStoryName.lowercased())
        dictOfProgress.updateValue(progress, forKey: globalStoryName.lowercased())
        
        navigationView.isHidden = true
        ratingView.isHidden = true
        
        DispatchQueue.main.async {
            if self.loadingStartTimer.isValid {
                self.loadingStartTimer.invalidate()
            }
            
        }
        
        self.navBarTopConstraint.constant = 0
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
        
        if fromSearch == false {
            NotificationCenter.default.post(name: .reload, object: nil)
        } else {
            NotificationCenter.default.post(name: .SearchReload, object: nil)
        }
        NotificationCenter.default.post(name: .reloadFavourites, object: nil)
        NotificationCenter.default.post(name: .startScrolling, object: nil)
        self.dismiss(animated: true, completion: nil)
        
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
            }
    }
    
    @objc func timeForTaps () {
        let nowTime = Int(time(what: "hours"))!*60 + Int(time(what: "Min"))!
        let previouseM =  UserDefaults.standard.integer(forKey: "PreDataMonth")
        let previouseD =  UserDefaults.standard.integer(forKey: "PreDataDay")
        let previouseT =  UserDefaults.standard.integer(forKey: "PreDataTime")
        if Int(time(what: "Month"))! > previouseM {
            limitOfTaps = 100
            self.timerTaps.invalidate()
        }else if Int(time(what: "day"))! > previouseD {
            limitOfTaps = 100
            self.timerTaps.invalidate()
        }else if nowTime >= previouseT + 1440 {
            limitOfTaps = 100
            self.timerTaps.invalidate()
        }else{
            limitOfTaps = 0
        }
    }
    
    func time(what: String) -> String {
        
        let date = NSDate()
        let dateFormatter = DateFormatter()
        if what == "Month"  {
            dateFormatter.dateFormat = "MM"
            let dateString = dateFormatter.string(from: date as Date)
            return dateString
        }else if what == "day" {
            dateFormatter.dateFormat = "dd"
            let dateString = dateFormatter.string(from: date as Date)
            return dateString
        }else if what == "Time"{
            dateFormatter.dateFormat = "HH:mm"
            let dateString = dateFormatter.string(from: date as Date)
            return dateString
        }else if what == "Min"{
            dateFormatter.dateFormat = "mm"
            let dateString = dateFormatter.string(from: date as Date)
            return dateString
        }else{
            dateFormatter.dateFormat = "HH"
            let dateString = dateFormatter.string(from: date as Date)
            return dateString
        }
    }
    
    // MARK:- Rate the story
    @IBOutlet weak var firstStar: UIImageView!
    @IBOutlet weak var secondStar: UIImageView!
    @IBOutlet weak var thirdStar: UIImageView!
    @IBOutlet weak var fourthStar: UIImageView!
    @IBOutlet weak var fifthStar: UIImageView!
    @IBOutlet weak var starView: UIView!
    @IBOutlet weak var thankLabel: UILabel!
    @IBOutlet weak var choseBotomConstraint: NSLayoutConstraint!
    @IBOutlet weak var chooseStoryOutlet: UIButton!
    
    func rateTheStoryWith(rating: Double) {
        
        if rating >= 8 {
            
            if #available(iOS 10.3, *) {
                SKStoreReviewController.requestReview()
            }
            
        }
        
        let ref = Database.database().reference().child("conversion/\(globalStoryName.lowercased())/rating")
        ref.runTransactionBlock({ (currentData: MutableData) -> TransactionResult in
            var post = currentData.value as? [String : AnyObject]
            var starCount = post?["num"] as? Double ?? 0
            if rating > 0 {
                starCount = ( starCount + rating ) / 2
                currentData.value = ["num": starCount]
            }
            return TransactionResult.success(withValue: currentData)
            
        }) { (error, committed, snapshot) in
            if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    @IBAction func rateTheStoryFunction(_ sender: UIPanGestureRecognizer) {
        
        let location = sender.location(in: starView)

        
        if sender.state == .changed {
            
            if location.x > firstStar.center.x {
                firstStar.image = UIImage(named: "full star")
            }else{
                firstStar.image = UIImage(named: "empty star")
            }
            
            if location.x > secondStar.center.x {
                secondStar.image = UIImage(named: "full star")
            }else{
                secondStar.image = UIImage(named: "empty star")
            }
            
            if location.x > thirdStar.center.x {
                thirdStar.image = UIImage(named: "full star")
            }else{
                thirdStar.image = UIImage(named: "empty star")
            }
            
            if location.x > fourthStar.center.x {
                fourthStar.image = UIImage(named: "full star")
            }else{
                fourthStar.image = UIImage(named: "empty star")
            }
            
            if location.x > fifthStar.center.x {
                fifthStar.image = UIImage(named: "full star")
            }else{
                fifthStar.image = UIImage(named: "empty star")
            }
        }
        
        if sender.state == .ended {
            
            var rating = 0.0
            let location = sender.location(in: view)
            
            if location.x > firstStar.center.x {
                rating = 2.0
            }
            
            if location.x > secondStar.center.x {
                rating = 4.0
            }
            
            if location.x > thirdStar.center.x {
                rating = 6.0
            }
            
            if location.x > fourthStar.center.x {
                rating = 8.0
            }
            
            if location.x > fifthStar.center.x {
                rating = 10.0
            }
            
            if firstStar.image == UIImage(named: "full star") {
                starView.isUserInteractionEnabled = false
                UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                    self.starView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                    self.starView.frame.origin.y = 20
                    self.thankLabel.frame.origin.y = 20 + self.starView.frame.size.height + 15
                }) { (true) in
                    UIView.animate(withDuration: 0.3, animations: {
                        self.thankLabel.alpha = 1
                    })
                }
            }
        
            rateTheStoryWith(rating: rating)
        
        }
        
    }
 
    @IBAction func rateTheStorySecondFunction(_ sender: UITapGestureRecognizer) {
        
        let location = sender.location(in: starView)
        
        if firstStar.frame.contains(location) {
            firstStar.image = UIImage(named: "full star")
            secondStar.image = UIImage(named: "empty star")
            thirdStar.image = UIImage(named: "empty star")
            fourthStar.image = UIImage(named: "empty star")
            fifthStar.image = UIImage(named: "empty star")
            
            starView.isUserInteractionEnabled = false
            UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                self.starView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                self.starView.frame.origin.y = 20
                self.thankLabel.frame.origin.y = 20 + self.starView.frame.size.height + 15
            }) { (true) in
                UIView.animate(withDuration: 0.3, animations: {
                    self.thankLabel.alpha = 1
                })
            }
            
            rateTheStoryWith(rating: 2.0)
         
        }
        
        if secondStar.frame.contains(location) {
            firstStar.image = UIImage(named: "full star")
            secondStar.image = UIImage(named: "full star")
            thirdStar.image = UIImage(named: "empty star")
            fourthStar.image = UIImage(named: "empty star")
            fifthStar.image = UIImage(named: "empty star")
            
            starView.isUserInteractionEnabled = false
            UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                self.starView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                self.starView.frame.origin.y = 20
                self.thankLabel.frame.origin.y = 20 + self.starView.frame.size.height + 15
            }) { (true) in
                UIView.animate(withDuration: 0.3, animations: {
                    self.thankLabel.alpha = 1
                })
            }
            rateTheStoryWith(rating: 4.0)
     
        }
        
        if thirdStar.frame.contains(location) {
            firstStar.image = UIImage(named: "full star")
            secondStar.image = UIImage(named: "full star")
            thirdStar.image = UIImage(named: "full star")
            fourthStar.image = UIImage(named: "empty star")
            fifthStar.image = UIImage(named: "empty star")
            
            starView.isUserInteractionEnabled = false
            UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                self.starView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                self.starView.frame.origin.y = 20
                self.thankLabel.frame.origin.y = 20 + self.starView.frame.size.height + 15
            }) { (true) in
                UIView.animate(withDuration: 0.3, animations: {
                    self.thankLabel.alpha = 1
                })
            }
            rateTheStoryWith(rating: 6.0)
    
        }
        
        if fourthStar.frame.contains(location) {
            firstStar.image = UIImage(named: "full star")
            secondStar.image = UIImage(named: "full star")
            thirdStar.image = UIImage(named: "full star")
            fourthStar.image = UIImage(named: "full star")
            fifthStar.image = UIImage(named: "empty star")
            
            starView.isUserInteractionEnabled = false
            UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                self.starView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                self.starView.frame.origin.y = 20
                self.thankLabel.frame.origin.y = 20 + self.starView.frame.size.height + 15
            }) { (true) in
                UIView.animate(withDuration: 0.3, animations: {
                    self.thankLabel.alpha = 1
                })
            }
            rateTheStoryWith(rating: 8.0)
         
        }
        
        if fifthStar.frame.contains(location) {
            firstStar.image = UIImage(named: "full star")
            secondStar.image = UIImage(named: "full star")
            thirdStar.image = UIImage(named: "full star")
            fourthStar.image = UIImage(named: "full star")
            fifthStar.image = UIImage(named: "full star")
            
            starView.isUserInteractionEnabled = false
            UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                self.starView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                self.starView.frame.origin.y = 20
                self.thankLabel.frame.origin.y = 20 + self.starView.frame.size.height + 15
            }) { (true) in
                UIView.animate(withDuration: 0.3, animations: {
                    self.thankLabel.alpha = 1
                })
            }
            rateTheStoryWith(rating: 10.0)
   
        }
        
    }
    
    @IBAction func chooseAnotherStoryAction(_ sender: Any) {
        
        UserDefaults.standard.set(progress, forKey: globalStoryName.lowercased())
        dictOfProgress.updateValue(progress, forKey: globalStoryName.lowercased())
        
        navigationView.isHidden = true
        ratingView.isHidden = true
        
        DispatchQueue.main.async {
            if self.loadingStartTimer.isValid {
                self.loadingStartTimer.invalidate()
            }
            
        }
        
        self.navBarTopConstraint.constant = 0
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
        
        if fromSearch == false {
            NotificationCenter.default.post(name: .reload, object: nil)
        } else {
            NotificationCenter.default.post(name: .SearchReload, object: nil)
        }
        NotificationCenter.default.post(name: .reloadFavourites, object: nil)
        NotificationCenter.default.post(name: .startScrolling, object: nil)
        self.dismiss(animated: true, completion: nil)
        
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            status.backgroundColor = UIColor(displayP3Red: 42/255,
                                             green: 34/255,
                                             blue: 63/255,
                                             alpha: 1)
        }
    }
    
}

//MARK:- Extensions

extension String {
    func widthOfString(usingFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedStringKey.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }
}

extension MessengerViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return max(leftMessages.count, rightMessages.count)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let messageCell = messengerCollectionView.dequeueReusableCell(withReuseIdentifier: "messengerCell", for: indexPath) as! MessengerCell
        
        if indexPath.item > 0 {
            if globalScheme[indexPath.item] == globalScheme[indexPath.item - 1] {
                messageCell.leftName.isHidden = true
                messageCell.rightName.isHidden = true
            }
        }
        
        let twenty = self.view.frame.width * 0.048309
        let ten = self.view.frame.width * 0.0241545
        
        messageCell.leftMessage.frame.size.height = globalHeight[indexPath.item].height + twenty
        messageCell.leftMessage.frame.size.width = globalHeight[indexPath.item].width + twenty
        messageCell.leftMessage.frame.origin.x = self.view.frame.origin.x + ten
        
        messageCell.rightMessage.frame.size.height = globalHeight[indexPath.item].height + twenty
        messageCell.rightMessage.frame.size.width = globalHeight[indexPath.item].width + twenty
        messageCell.rightMessage.frame.origin.x = self.view.frame.width - (ten + globalHeight[indexPath.item].width + twenty)
        
//        // Вид баблов

        if layers.keys.contains(indexPath.item) {
            if globalScheme[indexPath.item] == "L" {
                messageCell.leftMessage.layer.mask = layers[indexPath.item]
            } else {
                messageCell.rightMessage.layer.mask = layers[indexPath.item]
            }
        } else if globalScheme[indexPath.item] == "L" {

            if indexPath.item - 1 >= 0 && globalScheme[indexPath.item - 1] == "L" {
                messageCell.leftName.isHidden = true
                if indexPath.item - 2 >= 0 && globalScheme[indexPath.item - 2] == "L" {
                    var preIndexPath = indexPath
                    preIndexPath.item -= 1
                    if let preCell = messengerCollectionView.cellForItem(at: preIndexPath) as? MessengerCell {
                        preCell.leftMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.01415), topRightRad: Double(self.view.frame.width * 0.03415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.01415), index: indexPath.item)
                        layers[preIndexPath.item] = preCell.leftMessage.layer.mask
                    }
                    messageCell.leftMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.01415), topRightRad: Double(self.view.frame.width * 0.03415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                    layers[indexPath.item] = messageCell.leftMessage.layer.mask

                } else if indexPath.item - 2 >= 0 && globalScheme[indexPath.item - 2] == "R" {
                    var preIndexPath = indexPath
                    preIndexPath.item -= 1
                    if let preCell = messengerCollectionView.cellForItem(at: preIndexPath) as? MessengerCell {
                        preCell.leftMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.03415), topRightRad: Double(self.view.frame.width * 0.03415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.01415), index: indexPath.item)
                        layers[preIndexPath.item] = preCell.leftMessage.layer.mask
                    }
                    messageCell.leftMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.01415), topRightRad: Double(self.view.frame.width * 0.03415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                    layers[indexPath.item] = messageCell.leftMessage.layer.mask
                } else {
                    var preIndexPath = indexPath
                    preIndexPath.item -= 1
                    if let preCell = messengerCollectionView.cellForItem(at: preIndexPath) as? MessengerCell {
                        preCell.leftMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.03415), topRightRad: Double(self.view.frame.width * 0.03415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.01415), index: indexPath.item)
                        layers[preIndexPath.item] = preCell.leftMessage.layer.mask
                    }
                    messageCell.leftMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.01415), topRightRad: Double(self.view.frame.width * 0.03415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                    layers[indexPath.item] = messageCell.leftMessage.layer.mask
                }
            } else {
                messageCell.leftMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.03415), topRightRad: Double(self.view.frame.width * 0.03415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                layers[indexPath.item] = messageCell.leftMessage.layer.mask
            }
        } else if globalScheme[indexPath.item] == "R" {

            if indexPath.item - 1 >= 0 && globalScheme[indexPath.item - 1] == "R" {
                messageCell.rightName.isHidden = true
                if indexPath.item - 2 >= 0 && globalScheme[indexPath.item - 2] == "R" {
                    var preIndexPath = indexPath
                    preIndexPath.item -= 1
                    if let preCell = messengerCollectionView.cellForItem(at: preIndexPath) as? MessengerCell {
                        preCell.rightMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.03415), topRightRad: Double(self.view.frame.width * 0.01415), bottomRightRad: Double(self.view.frame.width * 0.01415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                        layers[preIndexPath.item] = preCell.rightMessage.layer.mask
                    }
                    messageCell.rightMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.03415), topRightRad: Double(self.view.frame.width * 0.01415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                    layers[indexPath.item] = messageCell.rightMessage.layer.mask
                } else if indexPath.item - 2 >= 0 && globalScheme[indexPath.item - 2] == "L" {
                    var preIndexPath = indexPath
                    preIndexPath.item -= 1
                    if let preCell = messengerCollectionView.cellForItem(at: preIndexPath) as? MessengerCell {
                        preCell.rightMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.03415), topRightRad: Double(self.view.frame.width * 0.03415), bottomRightRad: Double(self.view.frame.width * 0.01415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                        layers[preIndexPath.item] = preCell.rightMessage.layer.mask
                    }
                    messageCell.rightMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.03415), topRightRad: Double(self.view.frame.width * 0.01415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                    layers[indexPath.item] = messageCell.rightMessage.layer.mask
                } else {
                    var preIndexPath = indexPath
                    preIndexPath.item -= 1
                    if let preCell = messengerCollectionView.cellForItem(at: preIndexPath) as? MessengerCell {
                        preCell.rightMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.03415), topRightRad: Double(self.view.frame.width * 0.03415), bottomRightRad: Double(self.view.frame.width * 0.01415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                        layers[preIndexPath.item] = preCell.rightMessage.layer.mask
                    }
                    messageCell.rightMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.03415), topRightRad: Double(self.view.frame.width * 0.01415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                    layers[indexPath.item] = messageCell.rightMessage.layer.mask
                }
            } else {
                messageCell.rightMessage.makeRoundedCorners(topLeftRad: Double(self.view.frame.width * 0.03415), topRightRad: Double(self.view.frame.width * 0.03415), bottomRightRad: Double(self.view.frame.width * 0.03415), bottomLeftRad: Double(self.view.frame.width * 0.03415), index: indexPath.item)
                layers[indexPath.item] = messageCell.rightMessage.layer.mask
            }
        }
        

        messageCell.leftName.sizeToFit()
        
        if UIScreen.main.bounds.height == 568 {
            messageCell.leftName.frame.size.width = (globalMiddle[0].widthOfString(usingFont: UIFont(name: "Helvetica-Bold", size: 11)!))
            messageCell.leftName.frame.origin.y = messageCell.leftMessage.frame.origin.y - 15
            messageCell.leftName.frame.origin.x = 16
        } else {
            messageCell.leftName.frame.size.width = (globalMiddle[0].widthOfString(usingFont: UIFont(name: "Helvetica-Bold", size: 13)!))
            messageCell.leftName.frame.origin.y = messageCell.leftMessage.frame.origin.y - 17
            messageCell.leftName.frame.origin.x = 20
        }
        
        messageCell.rightName.sizeToFit()
        
        if UIScreen.main.bounds.height == 568 {
            messageCell.rightName.frame.size.width += (globalMiddle[1].widthOfString(usingFont: UIFont(name: "Helvetica-Bold", size: 11)!))
            messageCell.rightName.frame.origin.y = messageCell.leftMessage.frame.origin.y - 15
            messageCell.rightName.frame.origin.x = self.collectionView.frame.width - (globalMiddle[1].widthOfString(usingFont: UIFont(name: "Helvetica-Bold", size: 11)!)) - 16
        }else {
            messageCell.rightName.frame.size.width += (globalMiddle[1].widthOfString(usingFont: UIFont(name: "Helvetica-Bold", size: 13)!))
            messageCell.rightName.frame.origin.y = messageCell.leftMessage.frame.origin.y - 17
            messageCell.rightName.frame.origin.x = self.collectionView.frame.width - (globalMiddle[1].widthOfString(usingFont: UIFont(name: "Helvetica-Bold", size: 13)!)) - 18
        }
        
            
        messageCell.leftLabel.frame.size.width = globalHeight[indexPath.item].width
        messageCell.leftLabel.frame.size.height = messageCell.leftMessage.frame.height
        messageCell.leftLabel.frame.origin.y = messageCell.leftMessage.frame.height / 2 - messageCell.leftLabel.frame.size.height / 2 - 0.5
        messageCell.leftLabel.frame.origin.x = messageCell.leftMessage.frame.width/2 - globalHeight[indexPath.item].width/2
        
        messageCell.rightLabel.frame.size.width = globalHeight[indexPath.item].width
        messageCell.rightLabel.frame.size.height = messageCell.rightMessage.frame.height
        messageCell.rightLabel.frame.origin.y = messageCell.rightMessage.frame.height / 2 - messageCell.rightLabel.frame.size.height / 2 - 0.5
        messageCell.rightLabel.frame.origin.x = messageCell.rightMessage.frame.width/2 - globalHeight[indexPath.item].width/2
        
        
        messageCell.rightImage.frame.origin.x = 0
        messageCell.rightImage.frame.size.width = messageCell.rightMessage.frame.width
        messageCell.rightImage.frame.size.height = messageCell.rightMessage.frame.height
        messageCell.rightImage.clipsToBounds = true
        messageCell.rightImage.image = nil
        
        messageCell.rightActivity.frame = messageCell.rightImage.frame
        messageCell.rightActivity.layer.opacity = 0
        
        messageCell.leftImage.frame.origin.x = 0
        messageCell.leftImage.frame.size.width = messageCell.leftMessage.frame.width
        messageCell.leftImage.frame.size.height = messageCell.leftMessage.frame.height
        messageCell.leftImage.clipsToBounds = true
        messageCell.leftImage.image = nil
        
        messageCell.leftActivity.frame = messageCell.leftImage.frame
        messageCell.leftActivity.layer.opacity = 0
        
        messageCell.leftLabel.text = "\(leftMessages[indexPath.item])"
        messageCell.rightLabel.text = "\(rightMessages[indexPath.item])"
        
        messageCell.tag = indexPath.item
        
        messageCell.rightImage.contentMode = .scaleAspectFill
        messageCell.leftImage.contentMode = .scaleAspectFill
        
        if rightMessages[indexPath.item].contains("http"){
            messageCell.rightActivity.layer.opacity = 1
            messageCell.rightActivity.startAnimating()
            if dictOfStoryPhotos.keys.contains(rightMessages[indexPath.item]) {
                messageCell.rightActivity.layer.opacity = 0
                messageCell.rightActivity.stopAnimating()
                if messageCell.tag == indexPath.item {
                    let img = dictOfStoryPhotos[rightMessages[indexPath.item]]
                    
                    messageCell.rightImage.image = img
                    
                }
            }else{
                let task = URLSession.shared.dataTask(with: URL(string: rightMessages[indexPath.item])!) { data, response, error in
                    guard let data = data, error == nil else { return }
                    DispatchQueue.main.async() {
                        if messageCell.tag == indexPath.row{
                            
                            messageCell.rightImage.image = UIImage(data: data)
                            UIView.animate(withDuration: 0.3, animations: {
                                
                                messageCell.rightActivity.layer.opacity = 0
                            }, completion: { (true) in
                                messageCell.rightActivity.stopAnimating()
                            })
                            
                            dictOfStoryPhotos.updateValue(UIImage(data: data)!, forKey: self.rightMessages[indexPath.item])
                        }}}
                task.resume()}
        }
        
        if leftMessages[indexPath.item].contains("http"){
            messageCell.leftActivity.layer.opacity = 1
            messageCell.leftActivity.startAnimating()
            if dictOfStoryPhotos.keys.contains(leftMessages[indexPath.item]) {
                messageCell.leftActivity.layer.opacity = 0
                messageCell.leftActivity.stopAnimating()
                if messageCell.tag == indexPath.item {
                    let img = dictOfStoryPhotos[leftMessages[indexPath.item]]
                    messageCell.leftImage.image = img
                    
                }
            }else{
                let task = URLSession.shared.dataTask(with: URL(string: leftMessages[indexPath.item])!) { data, response, error in
                    guard let data = data, error == nil else { return }
                    DispatchQueue.main.async() {
                        if messageCell.tag == indexPath.item {
                            
                            messageCell.leftImage.image = UIImage(data: data)
                            
                            UIView.animate(withDuration: 0.3, animations: {
                                messageCell.leftActivity.layer.opacity = 0
                            }, completion: { (true) in
                                messageCell.leftActivity.stopAnimating()
                            })
                            
                            dictOfStoryPhotos.updateValue(UIImage(data: data)!, forKey: self.leftMessages[indexPath.item])
                        }
                    }}
                task.resume()
                
            }
        }
        
        if leftMessages[indexPath.item].contains("http") || rightMessages[indexPath.item].contains("http") { // прячутся лэйблы
            if messageCell.tag == indexPath.item {
                messageCell.leftLabel.isHidden = true
                messageCell.rightLabel.isHidden = true
            }
        }else{
            messageCell.leftLabel.isHidden = false
            messageCell.rightLabel.isHidden = false
            
        }
        
        // АНИМАЦИЯ ВЫВОДА СООБЩЕНИЙ
        let endIndex = IndexPath(item: self.messengerCollectionView.numberOfItems(inSection: 0) - 1, section: 0)
        if indexPath == endIndex {
            var endPosition: CGPoint = CGPoint()
            if messageCell.leftLabel.text != "" {
                messageCell.leftMessage.layer.opacity = 0
                endPosition = messageCell.leftMessage.center
                messageCell.leftMessage.center.x = -(ten/2)
                messageCell.leftMessage.transform = CGAffineTransform(scaleX: 0.0, y: 0)
                messageCell.leftMessage.layer.opacity = 1
                messageCell.leftMessage.alpha = 0
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 3, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                    messageCell.leftMessage.transform = CGAffineTransform(scaleX: 1, y: 1)
                    messageCell.leftMessage.center.x = endPosition.x
                    messageCell.leftMessage.alpha = 1
                })
            }else{
                messageCell.rightMessage.layer.opacity = 0
                endPosition = messageCell.rightMessage.center
                messageCell.rightMessage.center.x = self.view.frame.width + (ten/2)
                messageCell.rightMessage.transform = CGAffineTransform(scaleX: 0.0, y: 0)
                messageCell.rightMessage.layer.opacity = 1
                messageCell.rightMessage.alpha = 0
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 3, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                    messageCell.rightMessage.transform = CGAffineTransform(scaleX: 1, y: 1)
                    messageCell.rightMessage.center.x = endPosition.x
                    messageCell.rightMessage.alpha = 1
                })}}
        //----------------------------------------
        
        //-----------------скрываем бабблы -------------*
        if  messageCell.leftLabel.text == "" && messageCell.rightLabel.text == "" {
            messageCell.rightMessage.isHidden = true
            messageCell.rightName.isHidden = true
            messageCell.leftMessage.isHidden = true
            messageCell.leftName.isHidden = true
        } else if messageCell.leftLabel.text != "" && messageCell.rightLabel.text == "" {
            messageCell.rightMessage.isHidden = true
            messageCell.rightName.isHidden = true
            messageCell.leftMessage.isHidden = false
            if indexPath.item == 0 || globalScheme[indexPath.item] != globalScheme[indexPath.item - 1] {
                messageCell.leftName.isHidden = false
            }
        } else if messageCell.leftLabel.text == "" && messageCell.rightLabel.text != "" {
            messageCell.rightMessage.isHidden = false
            if indexPath.item == 0 || globalScheme[indexPath.item] != globalScheme[indexPath.item - 1] {
                messageCell.rightName.isHidden = false
            }
            messageCell.leftMessage.isHidden = true
            messageCell.leftName.isHidden = true
        } else {
            messageCell.rightMessage.isHidden = true
            messageCell.rightName.isHidden = true
            messageCell.leftMessage.isHidden = true
            messageCell.leftName.isHidden = true
        }
        //------------------------------------------------
        
        messageCell.leftName.text = globalMiddle[0]
        messageCell.rightName.text = globalMiddle[1]
        
        
        return messageCell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedCell = messengerCollectionView.dequeueReusableCell(withReuseIdentifier: "messengerCell", for: indexPath) as! MessengerCell
        selectedCell.transform = CGAffineTransform(scaleX: 2, y: 2)
        
        print("Pressed")
    }
    
}

