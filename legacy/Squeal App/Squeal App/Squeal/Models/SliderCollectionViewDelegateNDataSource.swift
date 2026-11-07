//
//  SliderCollectionViewDelegateNDataSource.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit
import FirebaseDatabase

var sliderIsOpen = false

class SliderCollectionViewDelegateNDataSource: NSObject, UICollectionViewDelegateFlowLayout {
    
    private var indexOfCellBeforeDragging = 0
    
    var collectionView: AutoScrolling
    var collectionViewFlowLayout: UICollectionViewFlowLayout
    var datasource: SliderDatasource
    var selectedSlide: IndexPath?

    var isScrollActive: Bool = true
    var indexOfPage: Int = 1

    //Window
    let window = UIApplication.shared.keyWindow

    init(collectionView: AutoScrolling, collectionViewFlowLayout: UICollectionViewFlowLayout, datasource: SliderDatasource){
        self.collectionView = collectionView
        self.collectionViewFlowLayout = collectionViewFlowLayout
        self.datasource = datasource
        super.init()
        self.collectionView.dataSource = datasource
        self.collectionView.delegate = self
        initCollectionView()
        NotificationCenter.default.addObserver(self, selector: #selector(startTimer), name: .startScrolling, object: nil)
    }
    
    func initCollectionView() {
        self.collectionView.scrollInterval = 3
        self.collectionViewFlowLayout.scrollDirection = .horizontal
        self.collectionViewFlowLayout.minimumInteritemSpacing = 0
        self.collectionViewFlowLayout.minimumLineSpacing = 0
        self.collectionViewFlowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        self.collectionView.startScrolling()
        self.collectionView.contentOffset = CGPoint(x: (collectionView.frame.width - 45) * CGFloat(datasource.numberOfSlides()) * 300, y: 0)
    }

    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        //print("here \(Support.shared.currentPage!)")
        
        // MARK: pageControl
        indexOfPage = Int(scrollView.contentOffset.x / (scrollView.frame.width - 45))
        if indexOfPage == 0 { indexOfPage = Support.shared.currentPage! }
        page = indexOfPage
        Support.shared.currentPage = page
    }
    
    //MARK: - objc methods

    @objc func statusColor (button: UIButton) {
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            UIView.animate(withDuration: 0.2, delay: 0.4, options: [], animations: {
                status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
            }, completion: nil)
        }
    }
    
    @objc func startTimer () {
        self.collectionView.startScrolling()
    }
    

    @objc func dismissForButton(button: UIButton) { // Закрытие по кнопке
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "showTheTabBar"), object: nil, userInfo: nil)
        self.collectionView.startScrolling()
        let arrayOfIndexPath = collectionView.indexPathsForSelectedItems as [IndexPath]?
        let cell = collectionView.cellForItem(at: selectedSlide!) as? HeaderCollectionViewCell

        cell?.storyLabel.alpha = 0
        cell?.viewsLabel.alpha = 0
        cell?.rateLabel.alpha = 0
        
        window?.isUserInteractionEnabled = false

        popUpLabel.alpha = 1
        popUpRateLabel.alpha = 1
        popUpViewLabel.alpha = 1
        popUpTimeLabel.alpha = 1
        popUpCopyLabel.removeFromSuperview()
        popUpRateCopyLabel.removeFromSuperview()
        popUpViewCopyLabel.removeFromSuperview()
        popUpTimeCopyLabel.removeFromSuperview()

        // Анимация закрытия
        UIView.animate(withDuration: 0.2, animations: {
            self.popUpLabel.alpha = 0
            self.popUpTimeView.alpha = 0
            self.popUpRateView.alpha = 0
            self.popUpAboutLabel.alpha = 0
            self.popUpTimeView.alpha = 0
            self.popUpDismissButton.alpha = 0
            self.episodesView.alpha = 0
        }){(true) in
            UIView.animate(withDuration: 0.2, animations: {
                self.popUpView.translatesAutoresizingMaskIntoConstraints = false
                self.blurView.alpha = 0
                self.popUpGradient.alpha = 0
                self.popUpIndicators.alpha = 0
                self.popUpView.layer.cornerRadius = 10

                let theAttributes:UICollectionViewLayoutAttributes! = self.collectionView.layoutAttributesForItem(at: self.selectedSlide!)
                let cellFrameInSuperview:CGRect!  = self.collectionView.convert(theAttributes.frame, to: self.collectionView.superview)

                // Вроде уже не нужно с новым дизайном
                self.popUpLabel.transform = .identity
                self.popUpViewLabel.transform = .identity
                self.popUpRateLabel.transform = .identity
                self.popUpTimeLabel.transform = .identity
                self.popUpRateView.transform = .identity
                self.popUpViewsView.transform = .identity
                self.popUpEqualView.transform = .identity
                self.popUpWhiteProgress.transform = .identity
                self.popUpView.layer.cornerRadius = cell?.storyView.layer.cornerRadius ?? 16.0

                //Constraints
                self.popUpView.topAnchor.constraint(equalTo: (self.window?.bottomAnchor)!, constant: 0).isActive = true
                self.popUpView.bottomAnchor.constraint(equalTo: (self.window?.bottomAnchor)!, constant: (self.window?.frame.height)!).isActive = true
                self.popUpView.leadingAnchor.constraint(equalTo: (self.window?.leadingAnchor)!, constant: 0).isActive = true
                self.popUpView.trailingAnchor.constraint(equalTo: (self.window?.trailingAnchor)!, constant: 0).isActive = true
                self.window?.layoutIfNeeded()
                self.popUpView.layoutIfNeeded()

            }) { (true) in
                self.popUpIndicators.alpha = 1
                sliderIsOpen = false
                UIView.animate(withDuration: 0.2, animations: {
                    cell?.storyLabel.alpha = 1
                    cell?.viewsLabel.alpha = 1
                    cell?.genreLabel.alpha = 1

                    cell?.rateLabel.alpha = 1
                    self.popUpAboutLabel.translatesAutoresizingMaskIntoConstraints = false
                    
                    self.collectionView.isUserInteractionEnabled = true
                    self.window?.isUserInteractionEnabled = true
                })
                self.popUpView.alpha = 1
                self.popUpLabel.alpha = 0
                self.blurView.removeFromSuperview()
                self.popUpNewView.removeFromSuperview()
            }
        }
    }

    @objc func dismiss(recognizer: UITapGestureRecognizer) { // Закрытие при нажатии на историю
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "showTheTabBar"), object: nil, userInfo: nil)
        _ = collectionView.indexPathsForSelectedItems as [IndexPath]?
        let cell = collectionView.cellForItem(at: selectedSlide!) as? HeaderCollectionViewCell

        cell?.storyLabel.alpha = 0
        cell?.viewsLabel.alpha = 0
        cell?.rateLabel.alpha = 0
        
        window?.isUserInteractionEnabled = false
        
        popUpLabel.alpha = 1
        popUpRateLabel.alpha = 1
        popUpViewLabel.alpha = 1
        popUpTimeLabel.alpha = 1
        popUpCopyLabel.removeFromSuperview()
        popUpRateCopyLabel.removeFromSuperview()
        popUpViewCopyLabel.removeFromSuperview()
        popUpTimeCopyLabel.removeFromSuperview()

        // Анимация закрытия
        UIView.animate(withDuration: 0.2, animations: {
            self.popUpLabel.alpha = 0
            self.popUpTimeView.alpha = 0
            self.popUpRateView.alpha = 0
            self.popUpAboutLabel.alpha = 0
            self.popUpTimeView.alpha = 0
            self.popUpDismissButton.alpha = 0
        }){(true) in
            UIView.animate(withDuration: 0.2, animations: {
                self.popUpView.translatesAutoresizingMaskIntoConstraints = false
                self.blurView.alpha = 0
                self.popUpGradient.alpha = 0
                self.popUpIndicators.alpha = 0
                self.popUpView.layer.cornerRadius = 10
                
                let theAttributes:UICollectionViewLayoutAttributes! = self.collectionView.layoutAttributesForItem(at: self.selectedSlide!)
                let _:CGRect!  = self.collectionView.convert(theAttributes.frame, to: self.collectionView.superview)

                // Вроде уже не нужно с новым дизайном
                self.popUpLabel.transform = .identity
                self.popUpViewLabel.transform = .identity
                self.popUpRateLabel.transform = .identity
                self.popUpTimeLabel.transform = .identity
                self.popUpRateView.transform = .identity
                self.popUpViewsView.transform = .identity
                self.popUpEqualView.transform = .identity
                self.popUpWhiteProgress.transform = .identity
                self.popUpView.layer.cornerRadius = cell?.storyView.layer.cornerRadius ?? 16
                
                //Constraints
                self.popUpView.topAnchor.constraint(equalTo: (self.window?.bottomAnchor)!, constant: 0).isActive = true
                self.popUpView.bottomAnchor.constraint(equalTo: (self.window?.bottomAnchor)!, constant: (self.window?.frame.height)!).isActive = true
                self.popUpView.leadingAnchor.constraint(equalTo: (self.window?.leadingAnchor)!, constant: 0).isActive = true
                self.popUpView.trailingAnchor.constraint(equalTo: (self.window?.trailingAnchor)!, constant: 0).isActive = true
                self.window?.layoutIfNeeded()
                self.popUpView.layoutIfNeeded()

            }) { (true) in
                self.popUpIndicators.alpha = 1
                sliderIsOpen = false
                UIView.animate(withDuration: 0.2, animations: {
                    cell?.storyLabel.alpha = 1
                    cell?.viewsLabel.alpha = 1
                    cell?.genreLabel.alpha = 1

                    cell?.rateLabel.alpha = 1
                    self.popUpAboutLabel.translatesAutoresizingMaskIntoConstraints = false
                    
                    self.collectionView.isUserInteractionEnabled = true
                    self.window?.isUserInteractionEnabled = true
                })
                self.popUpView.alpha = 1
                self.popUpLabel.alpha = 0
                self.blurView.removeFromSuperview()
                self.popUpNewView.removeFromSuperview()
            }
        }
    }
    
    func changeStoryFromServer (ganre: String, name: String, main: Bool) {
        print("начали качать историю")

        globalForLeft = []
        globalForRight = []
        globalScheme = []
        globalMiddle = []
        globalStoryName = ""
        var forGenres = ganre
        if ganre == "horreur" {
            forGenres = "horror"
        }else{
            forGenres = ganre
        }

        let ref = Database.database().reference()
        let connectionRef = Database.database().reference(withPath: ".info/connected")
        connectionRef.observe(.value, with: { (snapshot) in
            let connection = snapshot.value as? Bool
            if connection == true {
                print ("connect")
                ref.child("story").observe(DataEventType.value, with: { (snapshot) in
                    let postDict = snapshot.value as? [String : AnyObject] ?? [:]
                    let dictHorror = postDict["\(forGenres.lowercased())Story"] ?? "nil"  as AnyObject
                    print(dictHorror)
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

                            } else {
                                forLeftRight = []
                                forLeftRight.append(forLeft!)
                                forLeftRight.append(forRight!)
                                forLeftRight.append(scheme!)
                                forLeftRight.append(middle!)
                            }

                        }
                    } else {
                        print("Story is corrupedsis")
                    }
                })
            }else {return}
        })
    }

    @objc func openMessengerAction (recognizer: UITapGestureRecognizer) {
        fromSearch = false

        if selectedSlide != nil {
            let indexPath = selectedSlide!

            let slide = slidesArray[0].slideAt([0, indexPath.item % 10000])
            globalStoryName = slide.name
            
            changeStoryFromServer(ganre: slide.genre!.lowercased() , name: globalStoryName.lowercased(), main: true)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "performSegueToMessengerFromMain"), object: nil, userInfo: nil)
        }

    }
    
    // MARK: collectionView methods
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = CGSize(width: collectionView.frame.width - 45, height: collectionView.frame.height)
        return size
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    // MARK: didSelect Vars
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
    let popUpNewView = UIView()
    let popUpDismissView = UIView()
    let popUpView = UIView()
    let popUpImage = UIImageView()
    let popUpGradient = UIImageView()
    let popUpLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 42)
        label.numberOfLines = 0
        label.textAlignment = .left
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
    let popUpDismissButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "arrow down"), for: .normal)
        button.alpha = 0
        return button
    }()
    
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
    
    //EpisodesView
    var episodesView: EpisodePicker!
    var episode1name = ""
    var episode2name = ""
    var episode3name = ""
    
    let episodeAmount: CGFloat = 3
    
    let interSpacing: CGFloat = 15
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        selectedSlide = indexPath
        
        // Центр
        let height = UIScreen.main.bounds.height
        let width = UIScreen.main.bounds.width
        let center = CGPoint(x: width / 2, y: height / 2)

        window?.frame.size = CGSize(width: width, height: height)
        window?.center = center
        window?.makeKeyAndVisible()
        window?.accessibilityElementsHidden = false
        window?.clipsToBounds = false
        
        sliderIsOpen = true
        collectionView.isUserInteractionEnabled = false

        let slide = collectionView.cellForItem(at: indexPath) as! HeaderCollectionViewCell
        
        slide.bufCollectionView = self.collectionView
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "sliderDidTapped"), object: slide, userInfo: ["size": self.collectionView.contentOffset])
        
        // Закомментить self.collectionView.stopScrolling(), чтобы протестить баг
        //self.collectionView.stopScrolling()

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "hideTheTabBar"), object: nil, userInfo: nil)

        let cell = collectionView.cellForItem(at: indexPath) as! HeaderCollectionViewCell
        selected = IndexPath(item: indexPath.item % datasource.numberOfSlides(), section: 0)
        selectedName = cell.storyLabel.text!
        globalUserName = cell.storyLabel.text!

        // Все, что связано с эпизодами
        let numberOfEpisodes = dictOfAllStories[selectedName!.lowercased()]?.episodes.count// Выводит значение от одного до трех, при условии, что в массиве с эпизодами может быть, максимум, 2 названия
        if numberOfEpisodes == 0 || numberOfEpisodes == nil {
            episodesView = EpisodePicker(numberOfEpisodes: 1, frame: CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 38)))
        } else {
            episodesView = EpisodePicker(numberOfEpisodes: numberOfEpisodes!, frame: CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 38)))
        }

        episodesView.alpha = 0
        episodesView.delegatePicker = self


        if numberOfEpisodes == 0 || numberOfEpisodes == nil {
            episode1name = selectedName!
            episode2name = ""
            episode3name = ""
        } else {
            for x in (dictOfAllStories[selectedName!.lowercased()]?.episodes)! {
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


        // gestureRecognizers
        let popUpDismissGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismiss(recognizer:)))
        popUpDismissGestureRecognizer.numberOfTapsRequired = 1
        popUpDismissView.isUserInteractionEnabled = true
        popUpDismissView.addGestureRecognizer(popUpDismissGestureRecognizer)

        let blurViewGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismiss(recognizer:)))
        blurViewGestureRecognizer.numberOfTapsRequired = 1
        blurView.isUserInteractionEnabled = true
        blurView.addGestureRecognizer(blurViewGestureRecognizer)

        let openMessengerGestureRecognizer = UITapGestureRecognizer()
        openMessengerGestureRecognizer.addTarget(self, action: #selector(dismiss(recognizer:)))
        openMessengerGestureRecognizer.addTarget(self, action: #selector(openMessengerAction(recognizer:)))
        openMessengerGestureRecognizer.numberOfTapsRequired = 1
        popUpView.isUserInteractionEnabled = true
        popUpView.addGestureRecognizer(openMessengerGestureRecognizer)


        // frames для popUp и его элементов
        blurView.frame = UIScreen.main.bounds
        blurView.alpha = 0

        popUpNewView.frame = (window?.frame)!
        popUpNewView.frame.origin.x = 0
        popUpNewView.clipsToBounds = false
        popUpNewView.backgroundColor = UIColor.clear
        popUpNewView.alpha = 1

        popUpDismissView.frame = popUpNewView.bounds
        popUpDismissView.backgroundColor = UIColor.clear

        let theAttributes:UICollectionViewLayoutAttributes! = self.collectionView.layoutAttributesForItem(at: indexPath)
        let cellFrameInSuperview:CGRect!  = self.collectionView.convert(theAttributes.frame, to: self.collectionView.superview)

        // Положение popUp слайдера при открытии
        self.popUpView.frame = cellFrameInSuperview
        self.popUpView.frame.size.width -= 16
        self.popUpView.frame.origin.x += 16 // Нужно дописать "+ contentOffset основного collectionView"
        if UIScreen.main.bounds.height == 812 {
            self.popUpView.frame.origin.y += 44
        } else {
            self.popUpView.frame.origin.y += 20
        }
        print("\(popUpView.frame.origin.x)")

        popUpView.layer.cornerRadius = 10
        popUpView.backgroundColor = cell.backgroundColor
        popUpView.clipsToBounds = true

        popUpImage.frame = popUpView.bounds
        popUpImage.image = cell.storyImage.image
        popUpImage.contentMode = .scaleAspectFill

        popUpGradient.frame = popUpView.bounds
        popUpGradient.image = UIImage(named: "gradient")
        popUpGradient.contentMode = .scaleAspectFill
        popUpGradient.alpha = 0

        popUpIndicators.frame = cell.storyView.frame
        popUpIndicators.backgroundColor = cell.storyView.backgroundColor

        popUpLabel.text = cell.storyLabel.text
        popUpLabel.textColor = cell.storyLabel.textColor
        popUpLabel.font = UIFont(name: "SFProDisplay-Bold", size: 42)
        popUpLabel.textAlignment = .left
        popUpLabel.alpha = 0

        popUpRateImage.image = UIImage(named: "big rating")
        popUpRateImage.backgroundColor = .clear
        popUpRateImage.contentMode = .scaleAspectFill
        popUpRateLabel.frame = cell.rateLabel.frame
        popUpRateLabel.text = cell.rateLabel.text
       
        popUpRateLabel.textColor = cell.rateLabel.textColor
        popUpRateLabel.font = UIFont(name: "ArialMT", size: 14)
        popUpRateLabel.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
        popUpRateLabel.textAlignment = .left

        popUpTimeImage.image = UIImage(named: "clock")

        popUpTimeImage.contentMode = .scaleAspectFill
        popUpTimeImage.backgroundColor = .clear//cyan

        popUpTimeLabel.frame.origin.x = cell.viewsLabel.frame.origin.x
        popUpTimeLabel.frame.origin.y = cell.viewsLabel.frame.origin.y
        popUpTimeLabel.font = popUpRateLabel.font
        popUpTimeLabel.textAlignment = .left
        if timeOfReadingVar != [:] {
            if timeOfReadingVar.keys.contains(cell.storyLabel.text!.lowercased()){
                popUpTimeLabel.text = "\(timeOfReadingVar[cell.storyLabel.text!.lowercased()]!) min" // Время прочтения
            }else{
                popUpTimeLabel.text = "9 min"
            }
        }else{
            popUpTimeLabel.text = "8 min"
        }

        popUpTimeLabel.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
        popUpTimeLabel.textAlignment = .left
        popUpTimeLabel.sizeToFit()

        popUpTimeView.frame.size = CGSize(width: 9 + popUpTimeImage.frame.size.width + popUpTimeLabel.frame.size.width, height: popUpViewsView.frame.size.height)
        popUpTimeView.frame.origin.y = popUpEqualView.frame.size.height / 2 - popUpTimeView.frame.size.height / 2
        popUpTimeView.frame.origin.x = popUpViewsView.frame.origin.x - popUpTimeView.frame.size.width / 2
        popUpTimeView.alpha = 0

        popUpAboutLabel.frame.size.width = width / 1.3
        popUpAboutLabel.frame.origin.x = popUpView.frame.size.width / 2 - popUpAboutLabel.frame.size.width / 2
        popUpAboutLabel.frame.origin.y = popUpView.frame.size.height
        let commonMenu = horrorMenu + romanceMenu + thrillerMenu
        
        // Шрифт описания истории
        let style = collectionView.frame.size.width / 16
        
            for i in commonMenu {
                if i.name.lowercased() == cell.storyLabel.text?.lowercased() {
                    let attributedString = NSMutableAttributedString(string: i.storyDescription!)
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.maximumLineHeight = style
                    paragraphStyle.minimumLineHeight = style
                    attributedString.addAttribute(NSAttributedStringKey.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, attributedString.length))
                    popUpAboutLabel.attributedText = attributedString
                }
            }

        popUpAboutLabel.numberOfLines = 0
        popUpAboutLabel.textColor = UIColor.white
        popUpAboutLabel.font = UIFont.boldSystemFont(ofSize: 17)
        popUpAboutLabel.textAlignment = .left
        popUpAboutLabel.sizeToFit()
        popUpAboutLabel.alpha = 0
        
        if UIScreen.main.bounds.height == 568 {
            popUpAboutLabel.font = UIFont.boldSystemFont(ofSize: 15)
            popUpLabel.font = UIFont(name: "SFProDisplay-Bold", size: 31)
        }

        popUpDismissButton.addTarget(self, action: #selector(dismissForButton(button:)), for: .touchUpInside)
        popUpDismissButton.addTarget(self, action: #selector(statusColor(button:)), for: .touchUpInside)

        popUpRateView.alpha = 0

        // Анимация открытия popUp
        UIView.animate(withDuration: 0.2, animations: {
            cell.storyLabel.alpha = 0
            cell.genreLabel.alpha = 0
            if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                status.backgroundColor = UIColor.clear
            }
        }) {(true) in
            if !storyIsOpen { // Условия для того, чтобы не открывались одновременно слайдер и история
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
                
                // subviews
                self.window!.addSubview(self.blurView)
                self.window!.addSubview(self.popUpNewView)
                self.popUpNewView.addSubview(self.popUpDismissView)
                self.popUpNewView.addSubview(self.popUpView)
                self.popUpView.addSubview(self.popUpImage)
                self.popUpView.addSubview(self.popUpDismissButton)
                self.popUpView.addSubview(self.popUpGradient)
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
                self.popUpView.addSubview(self.episodesView)

                self.blurView.alpha = 1
                self.popUpGradient.alpha = 1
                self.popUpView.layer.cornerRadius = 0
                cell.genreLabel.alpha = 0
                
                // Constraints
                
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
                self.popUpAboutLabel.translatesAutoresizingMaskIntoConstraints = false
                
                self.popUpView.translatesAutoresizingMaskIntoConstraints = false
                
                self.popUpDismissButton.translatesAutoresizingMaskIntoConstraints = false
                
                //  popUpRateView
                self.popUpRateImage.widthAnchor.constraint(equalToConstant: 16).isActive = true
                self.popUpRateImage.heightAnchor.constraint(equalToConstant: 16).isActive = true
                self.popUpRateImage.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor,constant: 23).isActive = true
                self.popUpRateImage.bottomAnchor.constraint(equalTo: self.popUpAboutLabel.topAnchor, constant: -16).isActive = true
                
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
                
                // Others
                self.popUpLabel.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor,constant: 23).isActive = true
                self.popUpLabel.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor, constant: -21).isActive = true
                self.popUpLabel.bottomAnchor.constraint(equalTo: self.popUpRateImage.topAnchor, constant: -10).isActive = true
                
                self.popUpImage.topAnchor.constraint(equalTo: self.popUpView.topAnchor).isActive = true
                self.popUpImage.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor).isActive = true
                self.popUpImage.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor).isActive = true
                self.popUpImage.bottomAnchor.constraint(equalTo: self.popUpView.bottomAnchor).isActive = true
                
                self.popUpGradient.topAnchor.constraint(equalTo: self.popUpView.topAnchor).isActive = true
                self.popUpGradient.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor).isActive = true
                self.popUpGradient.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor).isActive = true
                self.popUpGradient.bottomAnchor.constraint(equalTo: self.popUpView.bottomAnchor).isActive = true
                
                let episodesAbove = collectionView.frame.size.width / 16.56
                
                self.popUpAboutLabel.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor, constant: 23).isActive = true
                self.popUpAboutLabel.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor, constant: -23).isActive = true
                self.popUpAboutLabel.bottomAnchor.constraint(equalTo: self.episodesView.topAnchor, constant: -episodesAbove).isActive = true
                
                
                self.popUpView.topAnchor.constraint(equalTo: self.popUpNewView.topAnchor, constant: 0).isActive = true
                self.popUpView.trailingAnchor.constraint(equalTo: self.popUpNewView.trailingAnchor, constant: 0).isActive = true
                self.popUpView.leadingAnchor.constraint(equalTo: self.popUpNewView.leadingAnchor, constant: 0).isActive = true
                self.popUpView.bottomAnchor.constraint(equalTo: self.popUpNewView.bottomAnchor, constant: 0).isActive = true
                
                self.popUpDismissButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
                self.popUpDismissButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
                self.popUpDismissButton.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor, constant: -9).isActive = true
                if UIScreen.main.bounds.height >= 812 {
                    self.popUpDismissButton.topAnchor.constraint(equalTo: self.popUpView.topAnchor, constant: 40).isActive = true
                }else{
                    self.popUpDismissButton.topAnchor.constraint(equalTo: self.popUpView.topAnchor, constant: 28).isActive = true
                }
                
                let episodesBelow = collectionView.frame.size.width / 13.8
                
                // EpisodesView
                self.episodesView.heightAnchor.constraint(equalToConstant: 38).isActive = true
                self.episodesView.leadingAnchor.constraint(equalTo: self.popUpView.leadingAnchor,constant: 0).isActive = true
                self.episodesView.trailingAnchor.constraint(equalTo: self.popUpView.trailingAnchor,constant: 0).isActive = true
                if UIScreen.main.bounds.height >= 812 {
                    self.episodesView.bottomAnchor.constraint(equalTo: self.popUpView.bottomAnchor,constant: -50).isActive = true
                }else{
                    self.episodesView.bottomAnchor.constraint(equalTo: self.popUpView.bottomAnchor,constant: -episodesBelow).isActive = true
                }
                
                self.window?.layoutIfNeeded()
            }) {(flag) in
                UIView.animate(withDuration: 0.3, animations: {
                    self.popUpTimeView.alpha = 1
                    self.popUpAboutLabel.alpha = 1
                    //self.episodesView.alpha = 1
                    self.popUpDismissButton.alpha = 1
                    self.popUpRateView.alpha = 1
                    self.popUpLabel.alpha = 1
                    self.episodesView.alpha = 1
                })
            }
            }else{ // Условие на случай одновременного нажатия на слайдер и историю
                UIView.animate(withDuration: 0.2, delay: 0.2, options: [], animations: {
                    cell.storyLabel.alpha = 1
                    cell.genreLabel.alpha = 1
                    self.collectionView.isUserInteractionEnabled = true
                    self.collectionView.startScrolling()
                    sliderIsOpen = false
                }, completion: nil)
            }
        }
    }
}


extension SliderCollectionViewDelegateNDataSource: EpisodePickerDelegate {
    func episode1() {
        fromSearch = false

        if selectedSlide != nil {
            let indexPath = selectedSlide!
            print(indexPath)
            guard let cell = collectionView.cellForItem(at: indexPath) as? HeaderCollectionViewCell else {
                print("Cell не каститься до HeaderCollectionViewCell")
                return
            }
            globalStoryName = episode1name.capitalizingFirstLetter()
            changeStoryFromServer(ganre: (cell.genreLabel.text?.lowercased())! , name: globalStoryName.lowercased(), main: true)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "performSegueToMessengerFromMain"), object: nil, userInfo: nil)
        }
        dismissForButton(button: UIButton())
    }
    func episode2() {
        fromSearch = false

        if selectedSlide != nil {
            let indexPath = selectedSlide!
            print(indexPath)
            guard let cell = collectionView.cellForItem(at: indexPath) as? HeaderCollectionViewCell else {
                print("Cell не каститься до HeaderCollectionViewCell")
                return
            }
            globalStoryName = episode3name
            changeStoryFromServer(ganre: (cell.genreLabel.text?.lowercased())! , name: globalStoryName.lowercased(), main: true)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "performSegueToMessengerFromMain"), object: nil, userInfo: nil)
        }
        dismissForButton(button: UIButton())
    }
    func episode3() {
        fromSearch = false

        if selectedSlide != nil {
            let indexPath = selectedSlide!
            print(indexPath)
            guard let cell = collectionView.cellForItem(at: indexPath) as? HeaderCollectionViewCell else {
                print("Cell не каститься до HeaderCollectionViewCell")
                return
            }
            globalStoryName = episode3name
            changeStoryFromServer(ganre: (cell.genreLabel.text?.lowercased())! , name: globalStoryName.lowercased(), main: true)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "performSegueToMessengerFromMain"), object: nil, userInfo: nil)
        }
        dismissForButton(button: UIButton())
    }
}

extension SliderCollectionViewDelegateNDataSource: UIScrollViewDelegate {
    
    private func indexOfMajorCell() -> Int {
        let itemWidth = collectionView.frame.width - 45
        let proportionalOffset = collectionView.collectionViewLayout.collectionView!.contentOffset.x / itemWidth
        let index = Int(round(proportionalOffset))
        let safeIndex = max(0, min(10000 - 1, index))
        return safeIndex
    }
    
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        indexOfCellBeforeDragging = indexOfMajorCell()
        
        collectionView.stopScrolling()
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Stop scrollView sliding:
        targetContentOffset.pointee = scrollView.contentOffset
        
        // calculate where scrollView should snap to:
        let indexOfMajorCell = self.indexOfMajorCell()
        
        // calculate conditions:
        let swipeVelocityThreshold: CGFloat = 0.2 // after some trail and error
        let hasEnoughVelocityToSlideToTheNextCell = indexOfCellBeforeDragging + 1 < 10000 && velocity.x > swipeVelocityThreshold
        let hasEnoughVelocityToSlideToThePreviousCell = indexOfCellBeforeDragging - 1 >= 0 && velocity.x < -swipeVelocityThreshold
        let majorCellIsTheCellBeforeDragging = indexOfMajorCell == indexOfCellBeforeDragging
        let didUseSwipeToSkipCell = majorCellIsTheCellBeforeDragging && (hasEnoughVelocityToSlideToTheNextCell || hasEnoughVelocityToSlideToThePreviousCell)
        
        if didUseSwipeToSkipCell {
            
            let snapToIndex = indexOfCellBeforeDragging + (hasEnoughVelocityToSlideToTheNextCell ? 1 : -1)
            let toValue = (collectionView.frame.width-45) * CGFloat(snapToIndex)
            
            // Damping equal 1 => no oscillations => decay animation:
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: velocity.x, options: .allowUserInteraction, animations: {
                scrollView.contentOffset = CGPoint(x: toValue, y: 0)
                scrollView.layoutIfNeeded()
            }, completion: nil)
            
        } else {
            // This is a much better way to scroll to a cell:
            let indexPath = IndexPath(row: indexOfMajorCell, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .left, animated: true)
        }
        
        collectionView.startScrolling()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        collectionView.startScrolling()
    }
}
