//
//  MenuViewController.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit
import MessageUI
import SwiftyStoreKit

var isAnimating = true
var language: String! = ""

class MenuViewController: UIViewController, MFMailComposeViewControllerDelegate {
    
    // MARK: outlets
    @IBOutlet weak var subscriptionOutlet: UIButton!
    @IBOutlet weak var languageOutlet: UIButton!
    @IBOutlet weak var rateOutlet: UIButton!
    @IBOutlet weak var shareOutlet: UIButton!
    @IBOutlet weak var restoreOutlet: UIButton!
    @IBOutlet weak var supportOutlet: UIButton!
    @IBOutlet weak var suggestOutlet: UIButton!
    @IBOutlet weak var englishOutlet: UIButton!
    @IBOutlet weak var frenchOutlet: UIButton!
    @IBOutlet weak var inscriptionOutlet: UILabel!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
        
        englishOutlet.transform = CGAffineTransform(translationX: -view.frame.size.width / 2, y: 0)
        frenchOutlet.transform = CGAffineTransform(translationX: -view.frame.size.width / 2, y: 0)
        
        if language == "english" {
            englishMenu()
        } else if language == "french" {
            frenchMenu()
        }
        
        // MARK: functions
        firstAnimationSetUp()
        optimization()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        statusBarColor = "menu"
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            status.backgroundColor = UIColor.clear
        }
        if storyIsOpen {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "showTheTabBar"), object: nil, userInfo: nil)
        }
        
        if isAnimating == true {
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                self.subscriptionOutlet.transform = .identity
                self.subscriptionOutlet.alpha = 1
                
            }, completion: nil)
            
            UIView.animate(withDuration: 0.7, delay: 0.1, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                    
                self.languageOutlet.alpha = 1
                self.languageOutlet.transform = .identity
                    
            }, completion: nil)
            
            UIView.animate(withDuration: 0.7, delay: 0.2, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                    
                self.rateOutlet.alpha = 1
                self.rateOutlet.transform = .identity
                    
            }, completion: nil)
            
            UIView.animate(withDuration: 0.7, delay: 0.3, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                    
                self.shareOutlet.alpha = 1
                self.shareOutlet.transform = .identity
                    
            }, completion: nil)
            
            UIView.animate(withDuration: 0.7, delay: 0.4, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                    
                self.restoreOutlet.alpha = 1
                self.restoreOutlet.transform = .identity
                    
            }, completion: nil)
            
                
            UIView.animate(withDuration: 0.7, delay: 0.5, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                    
                self.supportOutlet.alpha = 1
                self.supportOutlet.transform = .identity
                    
            }, completion: nil)
            
            UIView.animate(withDuration: 0.7, delay: 0.6, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                
                self.suggestOutlet.alpha = 1
                self.suggestOutlet.transform = .identity
                
            }, completion: nil)
            
            isAnimating = false
            
        }
    }
    
    // MARK: button actions
    @IBAction func languageAction(_ sender: Any) {
        
        if compled >= 5 {
        
        UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseIn, animations: {
            self.languageOutlet.transform = CGAffineTransform(translationX: self.view.frame.size.width / 1.5, y: 0)
            
        }) { (true) in
            UIView.animate(withDuration: 0.7, delay: 0.1, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                self.englishOutlet.transform = .identity
                self.englishOutlet.alpha = 1
            }, completion: nil)
            
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                self.frenchOutlet.transform = .identity
                self.frenchOutlet.alpha = 1
            }, completion: { (true) in
                self.languageOutlet.transform = CGAffineTransform(translationX: -self.view.frame.size.width / 1.5, y: 0)
                self.languageOutlet.alpha = 0
            })
        }
            
        }
        
    }
    
    @IBAction func changeToEnglish(_ sender: Any) {
        cancelLanguages()
        englishMenu()
        if language != "english" {
            let oldMenu = featuredMenu
            let newMenu = forAnotherLang["featured"] as! [Story]
            let oldMenuHorror = horrorMenu
            let newMenuHorror = forAnotherLang["horror"] as! [Story]
            let oldMenuRomance = romanceMenu
            let newMenuRomance = forAnotherLang["romance"] as! [Story]
            let oldMenuThriller = thrillerMenu
            let newMenuThriller = forAnotherLang["thriller"] as! [Story]
            romanceMenu = newMenuRomance
            forAnotherLang["romance"] = oldMenuRomance
            thrillerMenu = newMenuThriller
            forAnotherLang["thriller"] = oldMenuThriller
            featuredMenu = newMenu
            forAnotherLang["featured"] = oldMenu
            horrorMenu = newMenuHorror
            forAnotherLang["horror"] = oldMenuHorror
            NotificationCenter.default.post(name: .reloadLang, object: nil)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "chooseEnglishLanguageInHeaderView"), object: nil, userInfo: nil)
            
        }
        language = "english"
        UserDefaults.standard.set("english", forKey: "Languages")
    }
    
    @IBAction func changeToFrench(_ sender: Any) {
        cancelLanguages()
        frenchMenu()
        if language != "french" {
            let oldMenu = featuredMenu
            let newMenu = forAnotherLang["featured"] as! [Story]
            let oldMenuHorror = horrorMenu
            let newMenuHorror = forAnotherLang["horror"] as! [Story]
            let oldMenuRomance = romanceMenu
            let newMenuRomance = forAnotherLang["romance"] as! [Story]
            let oldMenuThriller = thrillerMenu
            let newMenuThriller = forAnotherLang["thriller"] as! [Story]
            romanceMenu = newMenuRomance
            forAnotherLang["romance"] = oldMenuRomance
            thrillerMenu = newMenuThriller
            forAnotherLang["thriller"] = oldMenuThriller
            featuredMenu = newMenu
            forAnotherLang["featured"] = oldMenu
            horrorMenu = newMenuHorror
            forAnotherLang["horror"] = oldMenuHorror
            NotificationCenter.default.post(name: .reloadLang, object: nil)
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "chooseFrenchLanguageInHeaderView"), object: nil, userInfo: nil)
            
            
        }
        language = "french"
        UserDefaults.standard.set("french", forKey: "Languages")
    }
    
    @IBAction func rateAction(_ sender: Any) {
        let appDelegate = AppDelegate()
        appDelegate.requestReview()
    }
    
    @IBAction func shareAction(_ sender: Any) {
        
        let activityVC = UIActivityViewController(activityItems: ["Download Squeal - Chat stories from the App Store.", URL.init(string: "https://itunes.apple.com/us/app/apple-store/id1388990468")!], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = self.view
        
        self.present(activityVC, animated: true, completion: nil)
        
    }
    
    @IBAction func restoreAction(_ sender: Any) {
        
        #if DEBUG
        let appleValidator = AppleReceiptValidator(service: .sandbox, sharedSecret: "REDACTED_SET_FROM_CONFIG")
        #else
        let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: "REDACTED_SET_FROM_CONFIG")
        #endif
        
        SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
            switch result {
            case .success(let receipt):
                let productIds = SquealProducts.productIdentifiers
                let purchaseResult = SwiftyStoreKit.verifySubscriptions(productIds: productIds, inReceipt: receipt)
                switch purchaseResult {
                case .purchased(let _, let _):
                    UserDefaults.standard.set(true, forKey: "com.pauldevelopers.ios.subscription")
                case .expired(let _, let _):
                    UserDefaults.standard.set(false, forKey: "com.pauldevelopers.ios.subscription")
                case .notPurchased:
                    UserDefaults.standard.set(false, forKey: "com.pauldevelopers.ios.subscription")
                }
            case .error(let error):
                print("Receipt verification failed: \(error)")
            }
        }
        
    }
    
    @IBAction func supportAction(_ sender: Any) {
        
        let mailComposeViewController = mailSupport()
        if MFMailComposeViewController.canSendMail() {
            self.present(mailComposeViewController, animated: true, completion: nil)
        } else {
            showMailError()
        }
    }
    
    @IBAction func suggestAction(_ sender: Any) {
        
        let mailComposeViewController = suggestStory()
        if MFMailComposeViewController.canSendMail() {
            self.present(mailComposeViewController, animated: true, completion: nil)
        } else {
            showMailError()
        }
        
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: functions
    func mailSupport() -> MFMailComposeViewController {
        let mailCimposerVC = MFMailComposeViewController()
        mailCimposerVC.mailComposeDelegate = self
        
        mailCimposerVC.setToRecipients(["squeal.feedback@gmail.com"])
        mailCimposerVC.setSubject("Feedback")
        mailCimposerVC.setMessageBody("", isHTML: false)
        
        return mailCimposerVC
    }
    
    func suggestStory() -> MFMailComposeViewController {
        let mailCimposerVC = MFMailComposeViewController()
        mailCimposerVC.mailComposeDelegate = self
        
        mailCimposerVC.setToRecipients(["squeal.stories@gmail.com"])
        mailCimposerVC.setSubject("Title")
        mailCimposerVC.setMessageBody("", isHTML: false)
        
        return mailCimposerVC
    }
    
    func showMailError() {
        let sendMailErrorAlert = UIAlertController(title: "Error", message: "Something's gone wrong", preferredStyle: .alert)
        let dismiss = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        sendMailErrorAlert.addAction(dismiss)
        self.present(sendMailErrorAlert, animated: true, completion: nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func cancelLanguages() {
        
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
            self.frenchOutlet.transform = CGAffineTransform(translationX: self.view.frame.size.width / 1.3, y: 0)
            
        }, completion: nil)
        
        UIView.animate(withDuration: 0.9, delay: 0, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
            self.englishOutlet.transform = CGAffineTransform(translationX: self.view.frame.size.width / 1.3, y: 0)
            
        }) { (true) in
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 5, initialSpringVelocity: 0, options: .curveEaseIn, animations: {
                self.languageOutlet.transform = .identity
                self.languageOutlet.alpha = 1
            }, completion: { (true) in
                self.englishOutlet.transform = CGAffineTransform(translationX: -self.view.frame.size.width / 2, y: 0)
                self.englishOutlet.alpha = 0
                self.frenchOutlet.transform = CGAffineTransform(translationX: -self.view.frame.size.width / 2, y: 0)
                self.frenchOutlet.alpha = 0
            })
        }
        
    }
    
    func firstAnimationSetUp() {
        if isAnimating == true {
            subscriptionOutlet.alpha = 0
            subscriptionOutlet.transform = CGAffineTransform(translationX: -50, y: 0)
            languageOutlet.alpha = 0
            languageOutlet.transform = CGAffineTransform(translationX: -70, y: 0)
            rateOutlet.alpha = 0
            rateOutlet.transform = CGAffineTransform(translationX: -90, y: 0)
            shareOutlet.alpha = 0
            shareOutlet.transform = CGAffineTransform(translationX: -150, y: 0)
            restoreOutlet.alpha = 0
            restoreOutlet.transform = CGAffineTransform(translationX: -110, y: 0)
            supportOutlet.alpha = 0
            supportOutlet.transform = CGAffineTransform(translationX: -130, y: 0)
            suggestOutlet.alpha = 0
            suggestOutlet.transform = CGAffineTransform(translationX: -170, y: 0)
        }
    }
    
    func optimization() {
        subscriptionOutlet.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 24)
        languageOutlet.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 24)
        englishOutlet.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 24)
        frenchOutlet.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 24)
        rateOutlet.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 24)
        shareOutlet.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 24)
        restoreOutlet.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 24)
        supportOutlet.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 24)
        suggestOutlet.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 24)
        inscriptionOutlet.font = UIFont(name: "SFProDisplay-Ultralight", size: view.frame.size.width / 34.5)
    }
    
    func englishMenu() {
        subscriptionOutlet.setTitle("Subscription", for: .normal)
        languageOutlet.setTitle("Language", for: .normal)
        rateOutlet.setTitle("Rate the App", for: .normal)
        shareOutlet.setTitle("Share the App", for: .normal)
        restoreOutlet.setTitle("Restore Purchases", for: .normal)
        supportOutlet.setTitle("Leave Feedback", for: .normal)
        suggestOutlet.setTitle("Suggest a Story", for: .normal)
        inscriptionOutlet.text = "For each suggested story we publish you get $20"
    }
    
    func frenchMenu() {
        subscriptionOutlet.setTitle("Abonnement", for: .normal)
        languageOutlet.setTitle("Langue", for: .normal)
        rateOutlet.setTitle("Évaluer l’Application", for: .normal)
        shareOutlet.setTitle("Partager l’Application", for: .normal)
        restoreOutlet.setTitle("Restaurer les Achats", for: .normal)
        supportOutlet.setTitle("Laisser une Évaluation", for: .normal)
        suggestOutlet.setTitle("Suggérer une Histoire", for: .normal)
        inscriptionOutlet.text = "Pour chaque histoire proposée et publiée vous obtiendrez $20"
    }
    
}

extension Notification.Name {
    static let reloadLang = Notification.Name("reloadLang")
    
}
