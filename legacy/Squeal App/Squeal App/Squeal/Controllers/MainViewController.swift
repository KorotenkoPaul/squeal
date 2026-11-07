//
//  MainViewController.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit
import FirebaseDatabase
import SVProgressHUD
import SwiftyStoreKit

var dictOfProgress : [String : Int] = [:]
var dictOfDownloadImage: [String: UIImage]! = [:]
var dictOfViews: [String: [String: [String: Double]]] = [:]
var dictOfRatings: [String: [String: [String: Double]]] = [:]
var timeOfReadingVar: [String: Int] = [:]

var selected: IndexPath?
var selectedName: String?

var loadingIsOver = false

var storyIsOpen = false

var statusBarColor = "main"

var page = 1
var dotsAmount = 1
var pageView = UIView()
var pageFirstDot = UIView()
var pageSecondDot = UIView()
var pageThirdDot = UIView()
var pageFourthDot = UIView()
var pageFifthDot = UIView()
var pageCurrentDot = UIView()
var forLeftRight = [[String()]]

var changeGenre: String = "featured"
var animation: String = "finished"
var check: Bool = true
var selectedLocation: CGPoint? = nil

var episodeNumber = 1

class MainViewController: UIViewController {
    
    //MARK:- Vars

    let blurSlider = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
    let underView = UIView()
    let firstLabel = UILabel()
    let secondLabel = UILabel()
    let thirdLabel = UILabel()

    // MARK: didSelect Vars

    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
    let popUpNewView = UIView()
    let popUpDismissView = UIView()
    let popUpView = UIView()
    let popUpImage = UIImageView()
    let popUpDarkGradient = UIImageView()
    let popUpGradient = UIImageView()
    let popUpLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFProDisplay-Bold", size: 38)
        label.numberOfLines = 0
        label.textAlignment = .left
        label.alpha = 0
        return label
    }()
    let popUpIndicators = UIView()
    let popUpEqualView = UIView()
    let popUpWhiteProgress = UIView()
    let popUpRedProgress = UIView()
    let popUpRateView = UIView()
    let popUpRateImage = UIImageView()
    let popUpRateLabel = UILabel()
    let popUpViewsView = UIView()
    let popUpViewImage = UIImageView()
    let popUpViewLabel = UILabel()
    let popUpTimeView = UIView()
    let popUpTimeImage = UIImageView()
    let popUpTimeLabel = UILabel()
    let popUpAboutLabel = UILabel()

    //EpisodesView
    var episodesView: EpisodePicker!
    var episode1name = ""
    var episode2name = ""
    var episode3name = ""

    let popUpCopyLabel = UILabel()
    let popUpRateCopyLabel = UILabel()
    let popUpViewCopyLabel = UILabel()
    let popUpTimeCopyLabel = UILabel()

    let popUpCornerRadius: CGFloat = 20
    let imageMultiplier: CGFloat = 1.5
    let labelMultiplier: CGFloat = 1.4
    let storyNameMultiplier: CGFloat = 1.4
    let indicatorsPadding: CGFloat = 3
    let imageToLabelPadding: CGFloat = 5
    let indicatorsBottomInset: CGFloat = 5
    let storyNameTopInset: CGFloat = 5

    let episodeAmount: CGFloat = 3

    let interSpacing: CGFloat = 15

    ////////////////////////////////

    var collectionView: UICollectionView!

    var dataSource = StoryDatasource()
    var completionTimer: Timer?
    let isLoadingDataSource = LoadingDataSource()

    func collectionViewConfigurate() {
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 17, bottom: 10, right: 17)
        layout.itemSize = CGSize(width: (self.view.bounds.width - 47) / 2,
                                 height: (self.view.bounds.width - 47) * 1.18 / 2)

        layout.headerReferenceSize = CGSize(width: self.view.bounds.width, height: (self.view.bounds.width - 61) * 0.653 + 104)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = UIColor(displayP3Red: 42/255,
                                                 green: 34/255,
                                                 blue: 63/255,
                                                 alpha: 1)
        //collectionView.delegate = self
        collectionView.register(StoryCollectionViewCell.self, forCellWithReuseIdentifier: "storyCell")
        collectionView.register(HeaderView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "headerView")
        collectionView.register(LoadingHeaderView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "loadingHeaderView")
        view.addSubview(collectionView)
        collectionView.showsVerticalScrollIndicator = false
    }
    
    @objc func reloadLang() {
        
        
        collectionView.reloadData()
    }

    override func viewDidLoad() {
        
        super.viewDidLoad()

        if UserDefaults.standard.object(forKey: "Favourite") != nil {
            let decoded  = UserDefaults.standard.object(forKey: "Favourite") as! Data
            let decodedTeams = NSKeyedUnarchiver.unarchiveObject(with: decoded) as! [String: [String: [Any]]]
            dictOfFavourite = decodedTeams
        }

        NotificationCenter.default.addObserver(self, selector: #selector(reloadTableData), name: .reload, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(performSegueToMessenger(sender:)), name: Notification.Name.init("performSegueToMessengerFromMain"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadLang), name: .reloadLang, object: nil)

        //NotificationCenter.default.addObserver(self, selector: #selector(self.sliderDidTapped(_:)), name: NSNotification.Name(rawValue: "sliderDidTapped"), object: nil)

        collectionViewConfigurate()
        //SVProgressHUD.show()
        isLoading(true)

        // language /
        let lang = UserDefaults.standard.string(forKey: "Languages")
        if lang == nil {
            language = "english"
        }else{
            language = UserDefaults.standard.string(forKey: "Languages")
        }

        // taps
        let taps = UserDefaults.standard.integer(forKey: "Taps")

        if taps == 0 {
            limitOfTaps = 100
        } else {
            limitOfTaps = taps
        }

        //GestureRecognizers

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longTouch(press:)))
        longPress.minimumPressDuration = 0.3
        collectionView.addGestureRecognizer(longPress)

        dataSource.get() { }
        checkConnection()
        //setUpGenres()
         
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func isLoading(_ flag: Bool) {
        if flag {
            self.collectionView.dataSource = isLoadingDataSource
            self.collectionView.reloadData()
        } else {
            self.collectionView.delegate = self
            self.collectionView.dataSource = dataSource
            self.collectionView.reloadData()
            self.collectionView.layoutIfNeeded()
        }
    }

    @objc private func checkComplete() {
        if compled == 5 && success == 11 && !slidesArray.isEmpty {
            completionTimer?.invalidate()
            isLoading(false)
            loadingIsOver = true
            NotificationCenter.default.post(name: .SearchReload, object: nil)
            NotificationCenter.default.post(name: .reloadFavourites, object: nil)
            NotificationCenter.default.post(name: .reloadLang, object: nil)
   
            //SVProgressHUD.dismiss()
        }
    }

    @objc private func reloadTableData(_ notification: Notification) {
        UIView.performWithoutAnimation {

            collectionView.reloadData()

            animation = "finished"
            if selected != nil  {
                if !selected!.isEmpty {
                    var stories: [Story]? = nil
                    if changeGenre == "horror" { stories = horrorMenu }
                    else if changeGenre == "romance" { stories = romanceMenu }
                    else if changeGenre == "thriller" { stories = thrillerMenu }
                    else {stories = featuredMenu}
                }}
        }
    }


    @objc func statusColor (recognizer: UITapGestureRecognizer) {
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            UIView.animate(withDuration: 0.2, delay: 0.4, options: [], animations: {
                status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
            }, completion: nil)
        }
    }

    @objc func dismiss (recognizer: UITapGestureRecognizer) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "showTheTabBar"), object: nil, userInfo: nil)
        let arrayOfIndexPath = collectionView.indexPathsForSelectedItems as [IndexPath]?
        guard let cell = collectionView.cellForItem(at: arrayOfIndexPath![0]) as? StoryCollectionViewCell else {
       
            return
        }
        cell.rateImage.alpha = 0
        cell.rateLabel.alpha = 0
        cell.viewsImage.alpha = 0
        cell.viewsLabel.alpha = 0
        cell.storyLabel.alpha = 0
        popUpView.clipsToBounds = true
        view.isUserInteractionEnabled = false

        popUpLabel.alpha = 1
        popUpRateLabel.alpha = 1
        popUpViewLabel.alpha = 1
        popUpTimeLabel.alpha = 1
        popUpCopyLabel.removeFromSuperview()
        popUpRateCopyLabel.removeFromSuperview()
        popUpViewCopyLabel.removeFromSuperview()
        popUpTimeCopyLabel.removeFromSuperview()

        UIView.animate(withDuration: 0.2, animations: {
            self.popUpLabel.alpha = 0
            self.popUpTimeView.alpha = 0
            self.popUpRateView.alpha = 0
            self.episodesView.alpha = 0
            self.popUpAboutLabel.alpha = 0
            self.popUpTimeView.alpha = 0
        }){(true) in
            UIView.animate(withDuration: 0.2, animations: {
                self.popUpView.translatesAutoresizingMaskIntoConstraints = false
                self.blurView.alpha = 0
                self.popUpIndicators.alpha = 0
                self.popUpView.layer.cornerRadius = 10
                
                self.popUpLabel.transform = .identity
                self.popUpViewLabel.transform = .identity
                self.popUpRateLabel.transform = .identity
                self.popUpTimeLabel.transform = .identity
                self.popUpRateView.transform = .identity
                self.popUpViewsView.transform = .identity
                self.popUpEqualView.transform = .identity
                self.popUpWhiteProgress.transform = .identity
                self.popUpView.layer.cornerRadius = cell.storyView.layer.cornerRadius
                //self.popUpImage.frame = self.popUpView.bounds
                //self.popUpGradient.frame = self.popUpView.bounds


                //Constraint
                self.popUpView.topAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
                self.popUpView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: self.popUpView.frame.height).isActive = true
                self.view.layoutIfNeeded()
                self.popUpView.layoutIfNeeded()

            }) { (true) in
                self.popUpIndicators.alpha = 1
                self.collectionView.scrollsToTop = true
                storyIsOpen = false
                UIView.animate(withDuration: 0.2, animations: {
                    cell.storyLabel.alpha = 1
                    cell.viewsImage.alpha = 1
                    cell.viewsLabel.alpha = 1
                    cell.rateImage.alpha = 1
                    cell.rateLabel.alpha = 1
                    self.popUpAboutLabel.alpha = 1
                    self.collectionView.isUserInteractionEnabled = true
                    self.view.isUserInteractionEnabled = true
                })
                self.popUpView.alpha = 1
                self.popUpLabel.alpha = 0
                self.popUpView.removeFromSuperview()
                self.blurView.removeFromSuperview()
                self.popUpNewView.removeFromSuperview()
            }
        }
    }

    func checkConnection() {
        completionTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(checkComplete), userInfo: nil, repeats: true)
    }

    func changeStoryFromServer (ganre: String, name: String, main: Bool) {
 
        globalForLeft = []
        globalForRight = []
        globalScheme = []
        globalMiddle = []
        globalStoryName = ""
        globalUserName = ""

        let ref = Database.database().reference()
        let connectionRef = Database.database().reference(withPath: ".info/connected")
        connectionRef.observe(.value, with: { (snapshot) in
            let connection = snapshot.value as? Bool
            if connection == true {
           
                ref.child("story").observe(DataEventType.value, with: { (snapshot) in
                    let postDict = snapshot.value as? [String : AnyObject] ?? [:]
                    let dictHorror = postDict["\(ganre.lowercased())Story"] ?? "nil"  as AnyObject
                    var lang: String = ""
                    if language == "english" {
                        lang = "eng"
                        
                    } else if language == "french" {
                        lang = "fr"
                    }
                    let engDict = dictHorror[lang] ?? "nil" as AnyObject
                    let mut = engDict as? NSMutableDictionary
                    
                    if mut != nil {
                        let firstStory = mut![name] as? [String : [String]]

                        let forLeft = firstStory?["forLeft"]
                        let forRight = firstStory?["forRight"]
                        let scheme = firstStory?["scheme"]
                        let middle = firstStory?["middle"]

                        if forLeft != nil && forRight != nil && scheme != nil {
                            if main == true {
                                globalForLeft = forLeft!
                                globalForRight = forRight!
                                globalScheme = scheme!
                                globalMiddle = middle!
                                globalStoryName = name.uppercased()
                                globalUserName = name.lowercased()

                            } else {
                                forLeftRight = []
                                forLeftRight.append(forLeft!)
                                forLeftRight.append(forRight!)
                                forLeftRight.append(scheme!)
                                forLeftRight.append(middle!)
                            }

                        }
                    }
                })
            }else {return}
        })
    }

    func storyForFavourite (ganre: String, name: String, completion: @escaping ([String : [String]])->()){
        var firstStory: [String : [String]] = [:]
        let ref = Database.database().reference()
        let connectionRef = Database.database().reference(withPath: ".info/connected")
        connectionRef.observe(.value, with: { (snapshot) in
            let connection = snapshot.value as? Bool
            if connection == true{
              
                ref.child("story").observe(DataEventType.value, with: { (snapshot) in
                    let postDict = snapshot.value as? [String : AnyObject] ?? [:]


                    let dictHorror = postDict["\(ganre.lowercased())Story"] ?? "nil"  as AnyObject

                    var lang: String = ""
                    if language == "english" {
                        lang = "eng"
                        
                    } else if language == "french" {
                        lang = "fr"
                    }
                    let engDict = dictHorror[lang] ?? "nil" as AnyObject
                    let mut = engDict as? NSMutableDictionary
                    
                    if mut != nil {
                        firstStory = mut![name] as? [String : [String]] ?? [:]


                        completion(firstStory)
                    }else{
                        let connectionRef = Database.database().reference(withPath: ".info/connected")
                        connectionRef.observe(.value, with: { (snapshot) in
                            let connection = snapshot.value as? Bool
                        
                        })
                      
                    }
                })

            }else {return}
        })


    }

    @objc func performSegueToMessenger(sender: Notification) {
        self.performSegue(withIdentifier: "openMessenger", sender: self)
    }
    @objc func openMessengerAction (recognizer: UITapGestureRecognizer) {
        fromSearch = false

        if selected != nil {
            let indexPath = selected!
            let cell = collectionView.cellForItem(at: indexPath) as! StoryCollectionViewCell


            globalStoryName = cell.storyLabel.text!
            var menu = featuredMenu
            if changeGenre == "horror" { menu = horrorMenu }
            else if changeGenre == "romance" { menu = romanceMenu }
            else if changeGenre == "thriller" { menu = thrillerMenu }
            else { menu = featuredMenu }

            if menu == featuredMenu {
                for i in featuredMenu {
                    if i.name.lowercased() == cell.storyLabel.text!.lowercased() {

                        changeStoryFromServer(ganre: i.genre!.lowercased() , name: cell.storyLabel.text!.lowercased(), main: true)
                      
                    }
                }

            } else {
                changeStoryFromServer(ganre: menu[indexPath.item].genre! , name: cell.storyLabel.text!.lowercased(), main: true)
            }

            self.performSegue(withIdentifier: "openMessenger", sender: self)
        }
    }

    // MARK: longPressGestureRecognizer
    let longPressNewView = UIView()
    let longPressBlackBackground = UIView()

    let longPressView = UIView()
    let longPressImage = UIImageView()
    let longPressGradient = UIImageView()
    let longPressIndicators = UIView()
    let longPressLabel = UILabel()
    let longPressWhiteProgress = UIView()
    let longPressRedProgress = UIView()
    let longPressEqualView = UIView()
    let longPressRateView = UIView()
    let longPressRateImage = UIImageView()
    let longPressRateLabel = UILabel()
    let longPressViewsView = UIView()
    let longPressViewImage = UIImageView()
    let longPressViewLabel = UILabel()

    let longPressResetProgress = UIView()
    let longPressResetProgressBlur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
    let longPressResetProgressImage = UIImageView()
    let longPressMore = UIView()
    let longPressMoreBlur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
    let longPressMoreImage = UIImageView()
    let longPressMoreLabel = UILabel()
    let longPressMoreReleaseLabel = UILabel()
    let longPressFavourites = UIView()
    let longPressFavouritesBlur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
    let longPressFavouritesImage = UIImageView()
    let longPressFavouritesCopyImage = UIImageView()

    let firstDetector = UIView()
    let secondDetector = UIView()
    let thirdDetector = UIView()
    let longPressPoint = UIView()

    let moreStartPlace = UIView()
    let resetStartPlace = UIView()
    let favouritesStartPlace = UIView()

    let moreHighlighted = UIView()
    let resetHighlighted = UIView()
    let favouritesHighlighted = UIView()

    var pressed = false

    @objc func longTouch(press: UILongPressGestureRecognizer) {

        let location = press.location(in: collectionView)

        if let indexPath = self.collectionView.indexPathForItem(at: location) {

            if let collectionViewCell = self.collectionView.cellForItem(at: indexPath) {

                if let cell = collectionViewCell as? StoryCollectionViewCell {
                    let cell = collectionViewCell as! StoryCollectionViewCell
                    if press.state == .began && cell.storyImage.image != nil && cell.storyImage.image != #imageLiteral(resourceName: "nill"){

                        pressed = true
                        selectedLocation = location

                        if #available(iOS 10.0, *) {
                            let vibrate = UISelectionFeedbackGenerator()
                            vibrate.selectionChanged()
                        }
                        
                        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                            status.backgroundColor = .clear
                        }

                        if changeGenre == "horror" {
                            let story = horrorMenu[indexPath.item]
                            longPressMoreLabel.text = story.author
                            longPressMoreReleaseLabel.text = story.releaseDate
                        }
                        else if changeGenre == "romance" {
                            let story = romanceMenu[indexPath.item]
                            longPressMoreLabel.text = story.author
                            longPressMoreReleaseLabel.text = story.releaseDate
                        }
                        else if changeGenre == "thriller" {
                            let story = thrillerMenu[indexPath.item]
                            longPressMoreLabel.text = story.author
                            longPressMoreReleaseLabel.text = story.releaseDate
                        }
                        else {
                            let story = featuredMenu[indexPath.item]
                            longPressMoreLabel.text = story.author
                            longPressMoreReleaseLabel.text = story.releaseDate
                        }


                        // frames
                        longPressNewView.frame.size = CGSize(width: view.frame.size.width, height: view.frame.size.height)
                        longPressNewView.frame.origin.y = 0
                        longPressNewView.frame.origin.x = 0
                        longPressNewView.clipsToBounds = true
                        longPressNewView.backgroundColor = UIColor.clear
                        longPressNewView.alpha = 1

                        longPressBlackBackground.frame = view.bounds
                        longPressBlackBackground.backgroundColor = .black
                        longPressBlackBackground.alpha = 0

                        longPressView.frame.size.width = cell.frame.size.width
                        longPressView.frame.size.height = cell.frame.size.height - collectionView.contentInset.top * 2/////////////
                        longPressView.frame.origin.x = cell.frame.origin.x + collectionView.contentInset.left/////////////
                        longPressView.frame.origin.y = cell.frame.origin.y - collectionView.contentOffset.y
                        longPressView.alpha = 1
                        longPressView.clipsToBounds = true
                        longPressView.layer.cornerRadius = cell.layer.cornerRadius
                        longPressView.backgroundColor = cell.backgroundColor

                        longPressImage.frame = longPressView.bounds
                        longPressImage.image = cell.storyImage.image
                        longPressImage.contentMode = .scaleAspectFill
                        
                        longPressGradient.frame = longPressView.bounds
                        longPressGradient.image = cell.storyGradient.image
                        longPressGradient.contentMode = .scaleAspectFill

                        longPressIndicators.frame = cell.storyView.frame
                        longPressIndicators.backgroundColor = cell.storyView.backgroundColor

                        longPressLabel.frame = cell.storyLabel.frame
                        longPressLabel.numberOfLines = 0
                        longPressLabel.text = cell.storyLabel.text
                        longPressLabel.textColor = cell.storyLabel.textColor
                        longPressLabel.font = cell.storyLabel.font
                        longPressLabel.textAlignment = .center

                        longPressRateImage.frame = cell.rateImage.frame
                        longPressRateImage.image = cell.rateImage.image
                        longPressRateImage.backgroundColor = .clear

                        longPressRateLabel.frame = cell.rateLabel.frame
                        longPressRateLabel.text = cell.rateLabel.text
                        longPressRateLabel.textColor = cell.rateLabel.textColor
                        longPressRateLabel.font = cell.rateLabel.font
                        longPressRateLabel.textAlignment = .center

                        longPressViewImage.frame = cell.viewsImage.frame
                        longPressViewImage.image = cell.viewsImage.image
                        longPressViewImage.contentMode = .scaleAspectFit
                        longPressViewImage.backgroundColor = .clear

                        longPressViewLabel.frame = cell.viewsLabel.frame
                        longPressViewLabel.text = cell.viewsLabel.text
                        longPressViewLabel.textColor = cell.viewsLabel.textColor
                        longPressViewLabel.font = cell.viewsLabel.font
                        longPressViewLabel.textAlignment = .center

                        longPressResetProgress.frame.size = CGSize(width: 50, height: 50)
                        longPressResetProgress.frame.origin.x = location.x - longPressResetProgress.frame.size.width / 2
                        longPressResetProgress.frame.origin.y = location.y - longPressResetProgress.frame.size.height / 2 - collectionView.contentOffset.y
                        longPressResetProgress.layer.cornerRadius = longPressResetProgress.frame.size.width / 2
                        longPressResetProgress.backgroundColor = .clear
                        longPressResetProgress.clipsToBounds = true
                        longPressResetProgress.alpha = 1

                        longPressResetProgressBlur.frame = longPressResetProgress.bounds
                        longPressResetProgressBlur.layer.cornerRadius = longPressResetProgressBlur.frame.size.width / 2
                        longPressResetProgressBlur.alpha = 0.5

                        longPressResetProgressImage.frame.size = CGSize(width: 25, height: 25)
                        longPressResetProgressImage.frame.origin.x = longPressResetProgress.frame.size.width / 2 - longPressResetProgressImage.frame.size.width / 2
                        longPressResetProgressImage.frame.origin.y = longPressResetProgress.frame.size.height / 2 - longPressResetProgressImage.frame.size.height / 2
                        longPressResetProgressImage.image = UIImage(named: "reset progress")
                        longPressResetProgressImage.contentMode = .scaleAspectFill

                        longPressMore.frame.size = CGSize(width: 50, height: 50)
                        longPressMore.frame.origin.x = location.x - longPressMore.frame.size.width / 2
                        longPressMore.frame.origin.y = location.y - longPressMore.frame.size.height / 2 - collectionView.contentOffset.y
                        longPressMore.layer.cornerRadius = longPressMore.frame.size.width / 2
                        longPressMore.backgroundColor = .clear
                        longPressMore.clipsToBounds = true
                        longPressMore.alpha = 1

                        longPressMoreBlur.frame = longPressMore.bounds
                        longPressMoreBlur.layer.cornerRadius = longPressMoreBlur.frame.size.width / 2
                        longPressMoreBlur.alpha = 0.5

                        longPressMoreImage.frame.size = CGSize(width: 20, height: 20)
                        longPressMoreImage.frame.origin.x = longPressMore.frame.size.width / 2 - longPressMoreImage.frame.size.width / 2
                        longPressMoreImage.frame.origin.y = longPressMore.frame.size.height / 2 - longPressMoreImage.frame.size.height / 2
                        longPressMoreImage.image = UIImage(named: "more")
                        longPressMoreImage.contentMode = .scaleAspectFill

                        longPressFavourites.frame.size = CGSize(width: 50, height: 50)
                        longPressFavourites.frame.origin.x = location.x - longPressFavourites.frame.size.width / 2
                        longPressFavourites.frame.origin.y = location.y - longPressFavourites.frame.size.height / 2 - collectionView.contentOffset.y
                        longPressFavourites.layer.cornerRadius = longPressFavourites.frame.size.width / 2
                        longPressFavourites.backgroundColor = .clear
                        longPressFavourites.clipsToBounds = true
                        longPressFavourites.alpha = 1

                        longPressFavouritesBlur.frame = longPressFavourites.bounds
                        longPressFavouritesBlur.layer.cornerRadius = longPressFavouritesBlur.frame.size.width / 2
                        longPressFavouritesBlur.alpha = 0.5

                        longPressFavouritesImage.frame.size = CGSize(width: 23, height: 23)
                        longPressFavouritesImage.frame.origin.x = longPressFavourites.frame.size.width / 2 - longPressFavouritesImage.frame.size.width / 2
                        longPressFavouritesImage.frame.origin.y = longPressFavourites.frame.size.height / 2 - longPressFavouritesImage.frame.size.height / 2 + 1
                        longPressFavouritesImage.image = UIImage(named: "empty heart")
                        longPressFavouritesImage.contentMode = .scaleAspectFill

                        longPressFavouritesCopyImage.frame = longPressFavouritesImage.frame
                        longPressFavouritesCopyImage.image = UIImage(named: "full heart")
                        longPressFavouritesCopyImage.contentMode = .scaleAspectFill
                        longPressFavouritesCopyImage.alpha = 0

                        // placing
                        resetStartPlace.frame.size = CGSize(width: 50, height: 50)
                        resetStartPlace.frame.origin.x = location.x - resetStartPlace.frame.size.width / 2
                        resetStartPlace.frame.origin.y = location.y - 85 - self.collectionView.contentOffset.y
                        resetStartPlace.layer.cornerRadius = resetStartPlace.frame.size.width / 2
                        resetStartPlace.backgroundColor = .orange
                        resetStartPlace.isHidden = true

                        moreStartPlace.frame.size = CGSize(width: 50, height: 50)
                        moreStartPlace.frame.origin.x = location.x - 75
                        moreStartPlace.frame.origin.y = location.y - 65 - self.collectionView.contentOffset.y
                        moreStartPlace.layer.cornerRadius = moreStartPlace.frame.size.width / 2
                        moreStartPlace.backgroundColor = .orange
                        moreStartPlace.isHidden = true

                        favouritesStartPlace.frame.size = CGSize(width: 50, height: 50)
                        favouritesStartPlace.frame.origin.x = location.x + 25
                        favouritesStartPlace.frame.origin.y = location.y - 65 - self.collectionView.contentOffset.y
                        favouritesStartPlace.layer.cornerRadius = favouritesStartPlace.frame.size.width / 2
                        favouritesStartPlace.backgroundColor = .orange
                        favouritesStartPlace.isHidden = true

                        resetHighlighted.frame.size = CGSize(width: 50, height: 50)
                        resetHighlighted.frame.origin.x = location.x - resetHighlighted.frame.size.width / 2
                        resetHighlighted.frame.origin.y = location.y - resetHighlighted.frame.size.height / 2 - 75 - collectionView.contentOffset.y
                        resetHighlighted.layer.cornerRadius = resetHighlighted.frame.size.width / 2
                        resetHighlighted.backgroundColor = .blue
                        resetHighlighted.isHidden = true

                        moreHighlighted.frame.size = CGSize(width: 50, height: 50)
                        moreHighlighted.frame.origin.x = location.x - moreHighlighted.frame.size.width / 2 - 60
                        moreHighlighted.frame.origin.y = location.y - moreHighlighted.frame.size.height / 2 - 50 - collectionView.contentOffset.y
                        moreHighlighted.layer.cornerRadius = moreHighlighted.frame.size.width / 2
                        moreHighlighted.backgroundColor = .blue
                        moreHighlighted.isHidden = true

                        favouritesHighlighted.frame.size = CGSize(width: 50, height: 50)
                        favouritesHighlighted.frame.origin.x = location.x - favouritesHighlighted.frame.size.width / 2 + 60
                        favouritesHighlighted.frame.origin.y = location.y - favouritesHighlighted.frame.size.height / 2 - 50 - collectionView.contentOffset.y
                        favouritesHighlighted.layer.cornerRadius = favouritesHighlighted.frame.size.width / 2
                        favouritesHighlighted.backgroundColor = .blue
                        favouritesHighlighted.isHidden = true

                        secondDetector.frame.size = CGSize(width: 50, height: 90)
                        secondDetector.frame.origin.x = location.x - secondDetector.frame.size.width / 2
                        secondDetector.frame.origin.y = location.y - secondDetector.frame.size.height - 15 - collectionView.contentOffset.y
                        secondDetector.layer.cornerRadius = secondDetector.frame.size.width / 2
                        secondDetector.backgroundColor = .cyan
                        secondDetector.isHidden = true

                        firstDetector.frame.size = CGSize(width: 70, height: 110)
                        firstDetector.frame.origin.x = location.x - firstDetector.frame.size.width / 2 - 60
                        firstDetector.frame.origin.y = location.y - firstDetector.frame.size.height / 2 - 40 - collectionView.contentOffset.y
                        firstDetector.backgroundColor = .cyan
                        firstDetector.isHidden = true

                        thirdDetector.frame.size = CGSize(width: 70, height: 110)
                        thirdDetector.frame.origin.x = location.x - thirdDetector.frame.size.width / 2 + 60
                        thirdDetector.frame.origin.y = location.y - thirdDetector.frame.size.height / 2 - 40 - collectionView.contentOffset.y
                        thirdDetector.backgroundColor = .cyan
                        thirdDetector.isHidden = true

                        longPressPoint.frame.size = CGSize(width: 5, height: 5)
                        longPressPoint.frame.origin.x = location.x - longPressPoint.frame.size.width / 2
                        longPressPoint.frame.origin.y = location.y - longPressPoint.frame.size.height / 2 - collectionView.contentOffset.y
                        longPressPoint.layer.cornerRadius = longPressPoint.frame.size.width / 2
                        longPressPoint.backgroundColor = .red
                        longPressPoint.isHidden = true

                        // subviews
                        view.addSubview(longPressBlackBackground)
                        view.addSubview(longPressNewView)
                        longPressNewView.addSubview(longPressView)
                        longPressView.addSubview(longPressImage)
                        longPressView.addSubview(longPressGradient)
                        longPressView.addSubview(longPressIndicators)
                        longPressIndicators.addSubview(longPressLabel)
                        longPressIndicators.addSubview(longPressWhiteProgress)
                        longPressWhiteProgress.addSubview(longPressRedProgress)
                        longPressIndicators.addSubview(longPressEqualView)
                        longPressEqualView.addSubview(longPressRateView)
                        longPressRateView.addSubview(longPressRateImage)
                        longPressRateView.addSubview(longPressRateLabel)
                        longPressEqualView.addSubview(longPressViewsView)
                        longPressViewsView.addSubview(longPressViewImage)
                        longPressViewsView.addSubview(longPressViewLabel)
                        view.addSubview(longPressResetProgress)
                        longPressResetProgress.addSubview(longPressResetProgressBlur)
                        longPressResetProgress.addSubview(longPressResetProgressImage)
                        view.addSubview(longPressMore)
                        longPressMore.addSubview(longPressMoreBlur)
                        longPressMore.addSubview(longPressMoreImage)
                        view.addSubview(longPressFavourites)
                        longPressFavourites.addSubview(longPressFavouritesBlur)
                        longPressFavourites.addSubview(longPressFavouritesImage)
                        longPressFavourites.addSubview(longPressFavouritesCopyImage)
                        view.addSubview(moreStartPlace)
                        view.addSubview(favouritesStartPlace)
                        view.addSubview(resetStartPlace)
                        view.addSubview(moreHighlighted)
                        view.addSubview(favouritesHighlighted)
                        view.addSubview(resetHighlighted)
                        view.addSubview(firstDetector)
                        view.addSubview(secondDetector)
                        view.addSubview(thirdDetector)
                        view.addSubview(longPressPoint)

                        // animation
                        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 5, initialSpringVelocity: 30, options: .curveEaseOut, animations: {

                            self.longPressResetProgress.frame = self.resetStartPlace.frame
                            self.longPressMore.frame = self.moreStartPlace.frame
                            self.longPressFavourites.frame = self.favouritesStartPlace.frame

                            self.longPressBlackBackground.alpha = 0.7
                            
                        }, completion: nil)

                        
                    }

                }

            }

        }

        if press.state == .changed {
            if pressed == true {

                longPressPoint.frame.origin.x = location.x - longPressPoint.frame.size.width / 2
                longPressPoint.frame.origin.y = location.y - longPressPoint.frame.size.height / 2 - collectionView.contentOffset.y

                if secondDetector.frame.contains(longPressPoint.frame) {
                    if self.longPressResetProgress.transform != CGAffineTransform(scaleX: 1.2, y: 1.2) {
                        if #available(iOS 10.0, *) {
                            let vibrate = UISelectionFeedbackGenerator()
                            vibrate.selectionChanged()
                        }
                    }
                    UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                        self.longPressResetProgress.center = self.resetHighlighted.center
                        self.longPressResetProgress.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                        self.longPressResetProgressBlur.alpha = 0.9
                    }, completion: nil)
                }else{
                    UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                        self.longPressResetProgress.center = self.resetStartPlace.center
                        self.longPressResetProgress.transform = .identity
                        self.longPressResetProgressBlur.alpha = 0.5
                    }, completion: nil)
                }

                if firstDetector.frame.contains(longPressPoint.frame) {



                    if self.longPressMore.transform != CGAffineTransform(scaleX: 1.2, y: 1.2) {
                        if #available(iOS 10.0, *) {
                            let vibrate = UISelectionFeedbackGenerator()
                            vibrate.selectionChanged()
                        }
                    }

                    longPressMoreLabel.frame.size = CGSize(width: longPressView.frame.size.width * 0.8, height: 20)

                    if longPressView.frame.origin.x + 20 < view.frame.size.width / 2 {
                        longPressMoreLabel.frame.origin.x = view.frame.size.width * 3 / 4 - longPressMoreLabel.frame.size.width / 2
                    } else {
                        longPressMoreLabel.frame.origin.x = view.frame.size.width / 4 - longPressMoreLabel.frame.size.width / 2
                    }

                    if longPressView.frame.origin.y < 40 {
                        longPressMoreLabel.frame.origin.y = longPressView.frame.origin.y + longPressView.frame.size.height - 5 - longPressMoreReleaseLabel.frame.size.height - 5 - longPressMoreLabel.frame.size.height
                    }else{
                        longPressMoreLabel.frame.origin.y = longPressView.frame.origin.y + 5
                    }

                    longPressMoreLabel.textColor = .white
                    longPressMoreLabel.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 27.6)
                    longPressMoreLabel.textAlignment = .left
                    longPressNewView.addSubview(longPressMoreLabel)


                    longPressMoreReleaseLabel.frame.size = CGSize(width: longPressView.frame.size.width * 0.9, height: 20)
                    longPressMoreReleaseLabel.frame.origin.x = longPressMoreLabel.frame.origin.x
                    longPressMoreReleaseLabel.frame.origin.y = longPressMoreLabel.frame.origin.y + longPressMoreLabel.frame.size.height + 5

                    longPressMoreReleaseLabel.textColor = .lightGray
                    longPressMoreReleaseLabel.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 27.6)
                    longPressMoreReleaseLabel.textAlignment = .left
                    longPressNewView.addSubview(longPressMoreReleaseLabel)



                    UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                        self.longPressMore.center = self.moreHighlighted.center
                        self.longPressMore.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                        self.longPressMoreBlur.alpha = 0.9
                        self.longPressBlackBackground.alpha = 0.9
                        self.longPressMoreLabel.alpha = 1
                        self.longPressMoreReleaseLabel.alpha = 1
                    }, completion: nil)

                }else{
                    UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                        self.longPressMore.center = self.moreStartPlace.center
                        self.longPressMore.transform = .identity
                        self.longPressMoreBlur.alpha = 0.5
                        self.longPressBlackBackground.alpha = 0.7
                        self.longPressMoreLabel.alpha = 0
                        self.longPressMoreReleaseLabel.alpha = 0
                    }, completion: nil)
                }

                if thirdDetector.frame.contains(longPressPoint.frame) {
                    if self.longPressFavourites.transform != CGAffineTransform(scaleX: 1.2, y: 1.2) {
                        if #available(iOS 10.0, *) {
                            let vibrate = UISelectionFeedbackGenerator()
                            vibrate.selectionChanged()
                        } else {
                            // Fallback on earlier versions
                        }
                    }
                    UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                        self.longPressFavourites.center = self.favouritesHighlighted.center
                        self.longPressFavourites.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                        self.longPressFavouritesBlur.alpha = 0.9
                    }, completion: nil)

                }else{
                    UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                        self.longPressFavourites.center = self.favouritesStartPlace.center
                        self.longPressFavourites.transform = .identity
                        self.longPressFavouritesBlur.alpha = 0.5
                    }, completion: nil)
                }

            }
        }

        if press.state == .ended {
            pressed = false

            if secondDetector.frame.contains(longPressPoint.frame) {

                // Сброс прогресса
                if selectedLocation != nil {
                    let indexPath = self.collectionView.indexPathForItem(at: selectedLocation!)
                    let cell = collectionView.cellForItem(at: indexPath! ) as? StoryCollectionViewCell
                    let queue = DispatchQueue.main
                    queue.async{
                        dictOfProgress.removeValue(forKey: "\(cell!.storyLabel.text!.lowercased())")
                        UserDefaults.standard.set(0, forKey: "\(cell!.storyLabel.text!.lowercased())")
                        self.collectionView.reloadItems(at: [indexPath!])
                    }
                    NotificationCenter.default.post(name: .reloadFavourites, object: nil)
                    selectedLocation = nil
                }


                //

                UIView.animate(withDuration: 0.1, animations: {
                    self.longPressMore.alpha = 0
                    self.longPressFavourites.alpha = 0
                })

                UIView.animate(withDuration: 1, delay: 0, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
                    self.longPressResetProgressImage.transform = CGAffineTransform.init(rotationAngle: .pi)
                    self.longPressResetProgressImage.transform = CGAffineTransform.init(rotationAngle: .pi * 2)
                }, completion: { (true) in
                    UIView.animate(withDuration: 0.1, animations: {
                        self.longPressBlackBackground.alpha = 0
                        self.longPressView.alpha = 0
                        self.longPressResetProgress.alpha = 0
                        self.longPressNewView.alpha = 0

                        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                            status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
                        }
                    }, completion: { (true) in
                        self.longPressResetProgressImage.transform = .identity
                        self.longPressResetProgress.transform = .identity
                        self.longPressMore.transform = .identity
                        self.longPressFavourites.transform = .identity
                    })
                })

            } else if firstDetector.frame.contains(longPressPoint.frame) {

                UIView.animate(withDuration: 0.1, animations: {
                    self.longPressBlackBackground.alpha = 0
                    self.longPressNewView.alpha = 0
                    self.longPressView.alpha = 0
                    self.longPressResetProgress.alpha = 0
                    self.longPressMore.alpha = 0
                    self.longPressFavourites.alpha = 0
                    self.longPressMoreLabel.alpha = 0
                    self.longPressMoreReleaseLabel.alpha = 0
                    
                    if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                        status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
                    }
                }, completion: { (true) in
                    self.longPressResetProgress.transform = .identity
                    self.longPressMore.transform = .identity
                    self.longPressFavourites.transform = .identity
                })

            } else if thirdDetector.frame.contains(longPressPoint.frame) {

                // Добавить в избранное
                
                var indexPath: IndexPath? = nil

                if selectedLocation != nil {
                    indexPath = self.collectionView.indexPathForItem(at: selectedLocation!)
                
                UIView.animate(withDuration: 0.1, animations: {
                    self.longPressMore.alpha = 0
                    self.longPressResetProgress.alpha = 0
                })

                UIView.animate(withDuration: 0.4, animations: {
                    self.longPressFavouritesCopyImage.alpha = 1
                }, completion: { (true) in
                    UIView.animate(withDuration: 0.1, delay: 0.3, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: [], animations: {
                        self.longPressBlackBackground.alpha = 0
                        self.longPressView.alpha = 0
                        self.longPressFavourites.alpha = 0
                        self.longPressNewView.alpha = 0
                        
                        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                            status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
                        }
                    }, completion: { (true) in
                        self.longPressResetProgress.transform = .identity
                        self.longPressMore.transform = .identity
                        self.longPressFavourites.transform = .identity
                    })
                })
                }
                if indexPath != nil {
                    var stories = featuredMenu

                    if changeGenre == "horror" {stories = horrorMenu}
                    else if changeGenre == "romance" {stories = romanceMenu}
                    else if changeGenre == "thriller" {stories = thrillerMenu}
                    else {stories = featuredMenu}

                    let oneStory = stories[indexPath!.item]


                    if stories == featuredMenu {
                        for i in featuredMenu {
                            if i.name.lowercased() == oneStory.name.lowercased() {
                                DispatchQueue.main.async(execute: { () -> Void in

                                    self.storyForFavourite(ganre: i.genre!.lowercased(), name: oneStory.name.lowercased(), completion: {(successfull) in
                                        if !successfull.isEmpty {

                                            let newFavourite = ["name": [oneStory.name.lowercased()], "description": [oneStory.storyDescription!.lowercased()], "author": [oneStory.author!.lowercased()], "data": [oneStory.releaseDate!.lowercased()], "status": [oneStory.status!.lowercased()], "genre": [oneStory.genre!.lowercased()], "image": [oneStory.images], "forLeft": successfull["forLeft"]!, "forRight": successfull["forRight"]!, "scheme": successfull["scheme"]!, "middle": successfull["middle"]! ] as! [String: [Any]]


                                            dictOfFavourite.updateValue(newFavourite, forKey: oneStory.name.lowercased())
                                            let encodedData = NSKeyedArchiver.archivedData(withRootObject: dictOfFavourite)
                                            UserDefaults.standard.set(encodedData, forKey: "Favourite")
                                            selectedLocation = nil
                                            NotificationCenter.default.post(name: .reloadFavourites, object: nil)
                                        }
                                    })
                                 
                                })

                            }
                        }

                    }else{
                        DispatchQueue.main.async(execute: { () -> Void in
                            self.storyForFavourite(ganre: changeGenre, name: oneStory.name.lowercased(), completion: {(successfull) in
                                if !successfull.isEmpty {

                                    let newFavourite = ["name": [oneStory.name.lowercased()], "description": [oneStory.storyDescription!.lowercased()], "author": [oneStory.author!.lowercased()], "data": [oneStory.releaseDate!.lowercased()], "status": [oneStory.status!.lowercased()], "genre": [oneStory.genre!.lowercased()], "image": [dictOfDownloadImageByUrl[oneStory.img.lowercased()]], "forLeft": successfull["forLeft"]!, "forRight": successfull["forRight"]!, "scheme": successfull["scheme"]!, "middle": successfull["middle"]! ] as! [String: [Any]]


                                    dictOfFavourite.updateValue(newFavourite, forKey: oneStory.name.lowercased())
                                    let encodedData = NSKeyedArchiver.archivedData(withRootObject: dictOfFavourite)
                                    UserDefaults.standard.set(encodedData, forKey: "Favourite")
                                    selectedLocation = nil

                                    NotificationCenter.default.post(name: .reloadFavourites, object: nil)
                                }
                            })
                        })
                    }
                }

                //

                UIView.animate(withDuration: 0.1, animations: {
                    self.longPressMore.alpha = 0
                    self.longPressResetProgress.alpha = 0
                })

                UIView.animate(withDuration: 0.4, animations: {
                    self.longPressFavouritesCopyImage.alpha = 1
                }, completion: { (true) in
                    UIView.animate(withDuration: 0.1, delay: 0.3, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: [], animations: {
                        self.longPressBlackBackground.alpha = 0
                        self.longPressView.alpha = 0
                        self.longPressFavourites.alpha = 0
                        self.longPressNewView.alpha = 0
                        
                        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                            status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
                        }
                    }, completion: { (true) in
                        self.longPressResetProgress.transform = .identity
                        self.longPressMore.transform = .identity
                        self.longPressFavourites.transform = .identity
                    })
                })

            } else {
                UIView.animate(withDuration: 0.1, animations: {
                    self.longPressBlackBackground.alpha = 0
                    self.longPressNewView.alpha = 0
                    self.longPressView.alpha = 0
                    self.longPressResetProgress.alpha = 0
                    self.longPressMore.alpha = 0
                    self.longPressFavourites.alpha = 0
                    self.longPressMoreLabel.alpha = 0
                    self.longPressMoreReleaseLabel.alpha = 0
                    
                    if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                        status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
                    }
                }, completion: { (true) in
                    self.longPressResetProgress.transform = .identity
                    self.longPressMore.transform = .identity
                    self.longPressFavourites.transform = .identity
                })
            }

        }

        if press.state == .cancelled {
            pressed = false

            UIView.animate(withDuration: 0.1, animations: {
                self.longPressBlackBackground.alpha = 0
                self.longPressNewView.alpha = 0
                self.longPressView.alpha = 0
                self.longPressResetProgress.alpha = 0
                self.longPressMore.alpha = 0
                self.longPressFavourites.alpha = 0
                self.longPressMoreLabel.alpha = 0
                self.longPressMoreReleaseLabel.alpha = 0
                
                if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                    status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
                }
            }, completion: { (true) in
                self.longPressResetProgress.transform = .identity
                self.longPressMore.transform = .identity
                self.longPressFavourites.transform = .identity
            })

        }
    }
}


extension MainViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "hideTheTabBar"), object: nil, userInfo: nil)
        let cell = collectionView.cellForItem(at: indexPath) as! StoryCollectionViewCell
        selected = indexPath
        selectedName = cell.storyLabel.text!
        globalUserName = cell.storyLabel.text!
        
        storyIsOpen = true
        collectionView.scrollsToTop = false
        collectionView.isUserInteractionEnabled = false

        // MARK: gestureRecognizers
        let popUpDismissGestureRecognizer = UITapGestureRecognizer()
        popUpDismissGestureRecognizer.addTarget(self, action: #selector(dismiss(recognizer:)))
        popUpDismissGestureRecognizer.addTarget(self, action: #selector(statusColor(recognizer:)))
        popUpDismissGestureRecognizer.numberOfTapsRequired = 1
        popUpDismissView.isUserInteractionEnabled = true
        popUpDismissView.addGestureRecognizer(popUpDismissGestureRecognizer)

        let blurViewGestureRecognizer = UITapGestureRecognizer()
        blurViewGestureRecognizer.addTarget(self, action: #selector(dismiss(recognizer:)))
        blurViewGestureRecognizer.addTarget(self, action: #selector(statusColor(recognizer:)))
        blurViewGestureRecognizer.numberOfTapsRequired = 1
        blurView.isUserInteractionEnabled = true
        blurView.addGestureRecognizer(blurViewGestureRecognizer)

        let openMessengerGestureRecognizer = UITapGestureRecognizer()
        openMessengerGestureRecognizer.addTarget(self, action: #selector(dismiss(recognizer:)))
        openMessengerGestureRecognizer.addTarget(self, action: #selector(openMessengerAction(recognizer:)))
        openMessengerGestureRecognizer.numberOfTapsRequired = 1
        popUpView.isUserInteractionEnabled = true
        popUpView.addGestureRecognizer(openMessengerGestureRecognizer)

        // MARK: frames
        blurView.frame = view.bounds
        blurView.alpha = 0

        popUpNewView.frame.size = CGSize(width: view.frame.size.width, height: view.frame.size.height)
        popUpNewView.frame.origin.y = 0
        popUpNewView.frame.origin.x = 0
        popUpNewView.clipsToBounds = true
        popUpNewView.backgroundColor = UIColor.clear
        popUpNewView.alpha = 1
        popUpNewView.clipsToBounds = true

        popUpDismissView.frame = popUpNewView.bounds
        popUpDismissView.backgroundColor = UIColor.clear

        popUpView.frame.size = cell.frame.size
        popUpView.frame.origin.x = cell.frame.origin.x
        popUpView.frame.origin.y = cell.frame.origin.y - collectionView.contentOffset.y
        popUpView.layer.cornerRadius = cell.layer.cornerRadius
        popUpView.backgroundColor = cell.backgroundColor
        popUpView.clipsToBounds = true

        popUpImage.frame = popUpView.bounds
        popUpImage.image = cell.storyImage.image
        popUpImage.contentMode = .scaleAspectFill

        popUpGradient.frame = popUpView.bounds
        popUpGradient.image = UIImage(named: "gradient")
        popUpGradient.contentMode = .scaleAspectFill
        
        popUpDarkGradient.frame = popUpView.bounds
        popUpDarkGradient.image = UIImage(named: "dark gradient")
        popUpDarkGradient.contentMode = .scaleAspectFill
        popUpDarkGradient.alpha = 0

        popUpIndicators.frame = cell.storyView.frame
        popUpIndicators.backgroundColor = cell.storyView.backgroundColor

        popUpLabel.numberOfLines = 0
        popUpLabel.text = cell.storyLabel.text
        popUpLabel.textColor = cell.storyLabel.textColor
        popUpLabel.alpha = 0
        popUpLabel.font = UIFont(name: "SFProDisplay-Bold", size: 38)

        popUpRateImage.frame = cell.rateImage.frame
        popUpRateImage.image = UIImage(named: "big rating")
        popUpRateImage.backgroundColor = .clear
        popUpRateImage.contentMode = .scaleAspectFill

        popUpRateLabel.frame = cell.rateLabel.frame
        popUpRateLabel.text = cell.rateLabel.text
        popUpRateLabel.textColor = cell.rateLabel.textColor
        popUpRateLabel.font = UIFont(name: "ArialMT", size: 14)
        popUpRateLabel.textAlignment = .left

        popUpTimeImage.frame = cell.viewsImage.frame
        popUpTimeImage.image = UIImage(named: "clock")
        
        popUpTimeImage.contentMode = .scaleAspectFill
        popUpTimeImage.backgroundColor = .clear//cyan

        popUpTimeLabel.frame.origin.x = cell.viewsLabel.frame.origin.x
        popUpTimeLabel.frame.origin.y = cell.viewsLabel.frame.origin.y
        popUpTimeLabel.font = UIFont(name: "ArialMT", size: 14)
        popUpTimeLabel.textAlignment = .left
        popUpTimeLabel.textColor = cell.viewsLabel.textColor
        popUpTimeLabel.sizeToFit()

        

        if timeOfReadingVar != [:] {
            if timeOfReadingVar.keys.contains(cell.storyLabel.text!.lowercased()){
                popUpTimeLabel.text = "\(timeOfReadingVar[cell.storyLabel.text!.lowercased()]!) min" // Cюда вставить то, откуда лейбл будет брать время прочтения
            }else{
                popUpTimeLabel.text = "9 min"
            }
        }else{
            popUpTimeLabel.text = "8 min" // Cюда вставить то, откуда лейбл будет брать время прочтения
        }


        popUpTimeView.frame.size = CGSize(width: 9 + popUpTimeImage.frame.size.width + popUpTimeLabel.frame.size.width, height: popUpViewsView.frame.size.height)
        popUpTimeView.frame.origin.y = popUpEqualView.frame.size.height / 2 - popUpTimeView.frame.size.height / 2
        popUpTimeView.frame.origin.x = popUpViewsView.frame.origin.x - popUpTimeView.frame.size.width / 2
        popUpTimeView.alpha = 0

        popUpAboutLabel.frame.size.width = view.frame.size.width / 1.3
        popUpAboutLabel.frame.origin.x = popUpView.frame.size.width / 2 - popUpAboutLabel.frame.size.width / 2
        popUpAboutLabel.frame.origin.y = popUpView.frame.size.height

        let style = collectionView.frame.size.width / 16
        
        if changeGenre == "featured"{
            for i in featuredMenu {
                if i.name.lowercased() == cell.storyLabel.text?.lowercased() {
                    let attributedString = NSMutableAttributedString(string: i.storyDescription!)
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.maximumLineHeight = style
                    paragraphStyle.minimumLineHeight = style
                    attributedString.addAttribute(NSAttributedStringKey.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, attributedString.length))
                    popUpAboutLabel.attributedText = attributedString
                }
            }
        }else if changeGenre == "horror" {
            for i in horrorMenu {
                if i.name.lowercased() == cell.storyLabel.text?.lowercased() {
                    let attributedString = NSMutableAttributedString(string: i.storyDescription!)
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.maximumLineHeight = style
                    paragraphStyle.minimumLineHeight = style
                    attributedString.addAttribute(NSAttributedStringKey.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, attributedString.length))
                    popUpAboutLabel.attributedText = attributedString
                }
            }
        }else if changeGenre == "romance" {
            for i in romanceMenu {
                if i.name.lowercased() == cell.storyLabel.text?.lowercased() {
                    let attributedString = NSMutableAttributedString(string: i.storyDescription!)
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.maximumLineHeight = style
                    paragraphStyle.minimumLineHeight = style
                    attributedString.addAttribute(NSAttributedStringKey.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, attributedString.length))
                    popUpAboutLabel.attributedText = attributedString
                }
            }
        }else if changeGenre == "thriller" {
            for i in thrillerMenu {
                if i.name.lowercased() == cell.storyLabel.text?.lowercased() {
                    let attributedString = NSMutableAttributedString(string: i.storyDescription!)
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.maximumLineHeight = style
                    paragraphStyle.minimumLineHeight = style
                    attributedString.addAttribute(NSAttributedStringKey.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, attributedString.length))
                    popUpAboutLabel.attributedText = attributedString
                }
            }
        }
        popUpAboutLabel.numberOfLines = 0
        popUpAboutLabel.textColor = UIColor.white
        popUpAboutLabel.font = UIFont(name: "SFProDisplay-Medium", size: 17)
        popUpAboutLabel.textAlignment = .left
        popUpAboutLabel.sizeToFit()
        popUpAboutLabel.alpha = 0

        if UIScreen.main.bounds.height == 568 {
            popUpAboutLabel.font = UIFont(name: "SFProDisplay-Medium", size: 15)
            popUpLabel.font = UIFont(name: "SFProDisplay-Bold", size: 31)
        }

        //EpisodeView
        var numberOfEpisodes = 0
        if dictOfAllStories[selectedName!.lowercased()]?.episodes.count != nil {
            numberOfEpisodes = (dictOfAllStories[selectedName!.lowercased()]?.episodes.count)!
        }else{
            numberOfEpisodes = (dictOfAllAnotherStories[selectedName!.lowercased()]?.episodes.count)!
        }
        
        // Выводит значение от одного до трех, при условии, что в массиве с эпизодами может быть , максимум, 2 названия
        if numberOfEpisodes == 0 {
            episodesView = EpisodePicker(numberOfEpisodes: 1, frame: CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width * 0.86, height: 38)))
        } else {
            episodesView = EpisodePicker(numberOfEpisodes: numberOfEpisodes, frame: CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width  * 0.86, height: 38)))
        }

        episodesView.alpha = 0
        episodesView.delegatePicker = self


        if numberOfEpisodes == 0 {
            episode1name = selectedName!
            episode2name = ""
            episode3name = ""
        } else {
            var include = [String]()
            if dictOfAllStories[selectedName!.lowercased()]?.episodes != nil {
                include  = (dictOfAllStories[selectedName!.lowercased()]?.episodes)!
            }else{
                include  = (dictOfAllAnotherStories[selectedName!.lowercased()]?.episodes)!
            }
            for x in include {
                if Int(String((x.last)!)) == 1 {
                    episode1name = x
                } else if Int(String((x.last)!)) == 2{
                    episode2name = x
                } else {
                    episode3name = x
                }
            }
            if Int(String((selectedName!.last)!)) == 1 {
                episodesView.button1.isActive = true
            } else if Int(String((selectedName!.last)!)) == 2{
                episodesView.button2.isActive = true
            } else {
                episodesView.button3.isActive = true
            }
        }
        
        

        // MARK: animation

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            cell.storyLabel.alpha = 0
            cell.viewsImage.alpha = 0
            cell.viewsLabel.alpha = 0
            cell.rateImage.alpha = 0
            cell.rateLabel.alpha = 0

            self.popUpLabel.alpha = 0
            self.popUpRateView.alpha = 0
            self.popUpTimeView.alpha = 0
            self.popUpAboutLabel.alpha = 0
            self.episodesView.alpha = 0
            
            if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                status.backgroundColor = UIColor.clear
            }
        }){(flag) in
            if !sliderIsOpen {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
                // MARK: subviews
                self.view.addSubview(self.blurView)
                self.view.addSubview(self.popUpNewView)
                self.popUpNewView.addSubview(self.popUpDismissView)
                self.popUpNewView.addSubview(self.popUpView)
                self.popUpView.addSubview(self.popUpImage)
                self.popUpView.addSubview(self.popUpGradient)
                self.popUpView.addSubview(self.popUpDarkGradient)
                self.popUpView.addSubview(self.popUpIndicators)
                self.popUpIndicators.addSubview(self.popUpLabel)
                self.popUpIndicators.addSubview(self.popUpEqualView)
                self.popUpEqualView.addSubview(self.popUpRateView)
                self.popUpRateView.addSubview(self.popUpRateImage)
                self.popUpRateView.addSubview(self.popUpRateLabel)
                self.popUpEqualView.addSubview(self.popUpViewsView)
                self.popUpViewsView.addSubview(self.popUpViewImage)
                self.popUpViewsView.addSubview(self.popUpViewLabel)
                self.popUpEqualView.addSubview(self.popUpTimeView)
                self.popUpTimeView.addSubview(self.popUpTimeImage)
                self.popUpTimeView.addSubview(self.popUpTimeLabel)
                self.popUpView.addSubview(self.popUpAboutLabel)
                // episode subviews
                self.popUpView.addSubview(self.episodesView)

                self.blurView.alpha = 1
                self.popUpDarkGradient.alpha = 1
                
                //self.popUpGradient.frame = self.popUpView.bounds
                //self.popUpGradient.contentMode = .scaleAspectFill

//                self.popUpTimeView.alpha = 1
//                self.popUpAboutLabel.alpha = 1
//                self.episodesView.alpha = 1
//                self.popUpLabel.alpha = 1
                self.popUpView.layer.cornerRadius = self.popUpCornerRadius

                //////////////// CONSTRAINTS //////////////////////////////////

                //  popUpRateView

                self.episodesView.translatesAutoresizingMaskIntoConstraints = false

                self.popUpRateView.translatesAutoresizingMaskIntoConstraints = false
                self.popUpRateLabel.translatesAutoresizingMaskIntoConstraints = false
                self.popUpRateImage.translatesAutoresizingMaskIntoConstraints = false

                self.popUpTimeView.translatesAutoresizingMaskIntoConstraints = false
                self.popUpTimeLabel.translatesAutoresizingMaskIntoConstraints = false
                self.popUpTimeImage.translatesAutoresizingMaskIntoConstraints = false

                self.popUpEqualView.translatesAutoresizingMaskIntoConstraints = false

                self.popUpIndicators.translatesAutoresizingMaskIntoConstraints = false
                self.popUpLabel.translatesAutoresizingMaskIntoConstraints = false

                self.popUpImage.translatesAutoresizingMaskIntoConstraints = false
                self.popUpGradient.translatesAutoresizingMaskIntoConstraints = false
                self.popUpDarkGradient.translatesAutoresizingMaskIntoConstraints = false
                self.popUpAboutLabel.translatesAutoresizingMaskIntoConstraints = false
                self.popUpView.translatesAutoresizingMaskIntoConstraints = false

                self.popUpRateImage.widthAnchor.constraint(equalToConstant: 16).isActive = true
                self.popUpRateImage.heightAnchor.constraint(equalToConstant: 16).isActive = true
                self.popUpRateImage.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor,constant: 20).isActive = true
                self.popUpRateImage.bottomAnchor.constraint(equalTo: self.popUpAboutLabel.topAnchor, constant: -12).isActive = true

                self.popUpRateLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true
                self.popUpRateLabel.heightAnchor.constraint(equalToConstant: 17).isActive = true
                self.popUpRateLabel.leadingAnchor.constraint(equalTo: self.popUpRateImage.trailingAnchor, constant: 6).isActive = true
                self.popUpRateLabel.centerYAnchor.constraint(equalTo: self.popUpRateImage.centerYAnchor).isActive = true

                //  popUpTimeView


                self.popUpTimeImage.widthAnchor.constraint(equalToConstant: 18).isActive = true
                self.popUpTimeImage.heightAnchor.constraint(equalToConstant: 18).isActive = true
                self.popUpTimeImage.leadingAnchor.constraint(equalTo: self.popUpRateLabel.trailingAnchor,constant: 16).isActive = true
                self.popUpTimeImage.centerYAnchor.constraint(equalTo: self.popUpRateLabel.centerYAnchor).isActive = true

                self.popUpTimeLabel.widthAnchor.constraint(equalToConstant: 43).isActive = true
                self.popUpTimeLabel.heightAnchor.constraint(equalToConstant: 17).isActive = true
                self.popUpTimeLabel.leadingAnchor.constraint(equalTo: self.popUpTimeImage.trailingAnchor, constant: 6).isActive = true
                self.popUpTimeLabel.centerYAnchor.constraint(equalTo: self.popUpTimeImage.centerYAnchor).isActive = true

                //  popUpIndicators
                self.popUpLabel.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor,constant: 19).isActive = true
                self.popUpLabel.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor, constant: -21).isActive = true
                self.popUpLabel.bottomAnchor.constraint(equalTo: self.popUpRateLabel.topAnchor, constant: -8).isActive = true

                self.popUpImage.topAnchor.constraint(equalTo: self.popUpView.topAnchor).isActive = true
                self.popUpImage.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor).isActive = true
                self.popUpImage.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor).isActive = true
                self.popUpImage.bottomAnchor.constraint(equalTo: self.popUpView.bottomAnchor).isActive = true
                
                self.popUpGradient.topAnchor.constraint(equalTo: self.popUpView.topAnchor, constant: self.popUpView.frame.size.height / 3).isActive = true
                self.popUpGradient.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor).isActive = true
                self.popUpGradient.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor).isActive = true
                self.popUpGradient.bottomAnchor.constraint(equalTo: self.popUpView.bottomAnchor).isActive = true
                
                self.popUpDarkGradient.topAnchor.constraint(equalTo: self.popUpView.topAnchor, constant: self.view.frame.size.height / 3.68).isActive = true
                self.popUpDarkGradient.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor).isActive = true
                self.popUpDarkGradient.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor).isActive = true
                self.popUpDarkGradient.bottomAnchor.constraint(equalTo: self.popUpView.bottomAnchor).isActive = true

                let episodesAbove = collectionView.frame.size.width / 16.56
                
                self.popUpAboutLabel.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor, constant: 17).isActive = true
                self.popUpAboutLabel.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor, constant: -17).isActive = true
                self.popUpAboutLabel.bottomAnchor.constraint(equalTo: self.episodesView.topAnchor, constant: -episodesAbove).isActive = true

                self.popUpView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
                self.popUpView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
                self.popUpView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.86).isActive = true
                
                if UIScreen.main.bounds.height >= 812 {
                    self.popUpView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.650).isActive = true
                }else{
                    self.popUpView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.729).isActive = true
                }

                let episodesBelow = collectionView.frame.size.width / 13.8

                //EpisodesView
                self.episodesView.heightAnchor.constraint(equalToConstant: 38).isActive = true
                self.episodesView.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor,constant: 0).isActive = true
                self.episodesView.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor,constant: 0).isActive = true
                self.episodesView.bottomAnchor.constraint(equalTo: self.popUpView.bottomAnchor,constant: -episodesBelow).isActive = true

                
                self.view.layoutIfNeeded()
            }) {(flag) in
                UIView.animate(withDuration: 0.2, animations: {
                    self.popUpLabel.alpha = 1
                    self.popUpRateView.alpha = 1
                    self.popUpTimeView.alpha = 1
                    self.popUpAboutLabel.alpha = 1
        
                    self.episodesView.alpha = 1
                })
            }
            }else{
                UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                    cell.storyLabel.alpha = 1
                    cell.viewsImage.alpha = 1
                    cell.viewsLabel.alpha = 1
                    cell.rateImage.alpha = 1
                    cell.rateLabel.alpha = 1
                    self.collectionView.isUserInteractionEnabled = true
                    storyIsOpen = false
                }, completion: nil)
            }
        }
    }

}

extension MainViewController: EpisodePickerDelegate {

    func episode1() {
        fromSearch = false

        if selected != nil {
            let indexPath = selected!
            let cell = collectionView.cellForItem(at: indexPath) as! StoryCollectionViewCell


            globalUserName = episode1name.lowercased()
            globalUserName = episode1name.lowercased()
            var menu = featuredMenu
            if changeGenre == "horror" { menu = horrorMenu }
            else if changeGenre == "romance" { menu = romanceMenu }
            else if changeGenre == "thriller" { menu = thrillerMenu }
            else { menu = featuredMenu }
            episodeNumber = 1
            changeStoryFromServer(ganre: menu[indexPath.item].genre! , name: globalUserName.lowercased(), main: true)

            self.performSegue(withIdentifier: "openMessenger", sender: self)
        }
        dismiss(recognizer: UITapGestureRecognizer())
    }
    
    func episode2() {
        fromSearch = false

        if selected != nil {
            let indexPath = selected!
            let cell = collectionView.cellForItem(at: indexPath) as! StoryCollectionViewCell

            globalUserName = episode2name.lowercased()
            globalUserName = episode2name.lowercased()
            var menu = featuredMenu
            if changeGenre == "horror" { menu = horrorMenu }
            else if changeGenre == "romance" { menu = romanceMenu }
            else if changeGenre == "thriller" { menu = thrillerMenu }
            else { menu = featuredMenu }
            episodeNumber = 2
            changeStoryFromServer(ganre: menu[indexPath.item].genre! , name: globalUserName.lowercased(), main: true)

            self.performSegue(withIdentifier: "openMessenger", sender: self)
        }
        dismiss(recognizer: UITapGestureRecognizer())
    }

    func episode3() {
        fromSearch = false

        if selected != nil {
            let indexPath = selected!
            let cell = collectionView.cellForItem(at: indexPath) as! StoryCollectionViewCell


            globalUserName = episode3name.lowercased()
            globalUserName = episode3name.lowercased()
            
            var menu = featuredMenu
            if changeGenre == "horror" { menu = horrorMenu }
            else if changeGenre == "romance" { menu = romanceMenu }
            else if changeGenre == "thriller" { menu = thrillerMenu }
            else { menu = featuredMenu }
            episodeNumber = 3
            changeStoryFromServer(ganre: menu[indexPath.item].genre! , name: globalUserName.lowercased(), main: true)

            self.performSegue(withIdentifier: "openMessenger", sender: self)
        }
        dismiss(recognizer: UITapGestureRecognizer())
    }
}






