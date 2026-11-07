//
//  SubscriptionViewController.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.

import UIKit
import StoreKit
import SVProgressHUD
import SwiftyStoreKit

class SubscriptionViewController: UIViewController {

    // MARK: outlets
    @IBOutlet weak var subscribeInscriptionOutlet: UILabel!
    @IBOutlet weak var threeDaysFreeOutlet: UIButton!
    @IBOutlet weak var weekPriceOutlet: UILabel!
    @IBOutlet weak var oneMonthOutlet: UIButton!
    @IBOutlet weak var oneYearOutlet: UIButton!
    @IBOutlet weak var alreadySubscribedOutlet: UIButton!
    @IBOutlet weak var recurringBillingOutlet: UILabel!
    @IBOutlet weak var flagImage: UIImageView!
    @IBOutlet weak var squealUnlimitedOutlet: UILabel!
    // Subscription buttons
    @IBOutlet weak var freeOutlet: UILabel!
    @IBOutlet weak var threeDayTrialOutlet: UILabel!
    @IBOutlet weak var thenOutlet: UILabel!
    @IBOutlet weak var forOneMonth: UILabel!
    @IBOutlet weak var forSixMonth: UILabel!
    @IBOutlet weak var monthPrice: UILabel!
    @IBOutlet weak var sixMonthsPrice: UILabel!
    
    private var selectedIndex:Int = 0
    

    var initialTouchPoint: CGPoint = CGPoint(x: 0,y: 0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if language == "english" {
            englishSubscription()
        } else if language == "french" {
            frenchSubscription()
        }
        
        // MARK: functions
        optimization()
        
        SwiftyStoreKit.retrieveProductsInfo(SquealProducts.productIdentifiers) { result in
            if let product = result.retrievedProducts.first {
                let priceString = product.localizedPrice!
        
            }
            else if let invalidProductId = result.invalidProductIDs.first {
                print("Invalid product identifier: \(invalidProductId)")
            }
            else {
                print("Error: \(result.error)")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            status.backgroundColor = UIColor.clear
        }
    }
    
    // MARK: functions
    func englishSubscription() {
        squealUnlimitedOutlet.text = "Squeal Unlimited"
        subscribeInscriptionOutlet.text = "Subscribe to unlock unlimited stories with no interruptions"
        freeOutlet.text = "Free  "
        threeDayTrialOutlet.text = "3 day Trial"
        thenOutlet.text = "then $3.99 a week"
        forOneMonth.text = "for 1 month"
        forSixMonth.text = "for 6 months"
        weekPriceOutlet.text = "Try Squeal Unlimited free 3 day trial"
        alreadySubscribedOutlet.setTitle("Select this package", for: .normal)
        recurringBillingOutlet.text = "Recurring billing. Cancel anytime. With Squeal Unlimited, you get unlimited access to hundreds of original chat stories in the Squeal library. The subscription will automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period. You can go to your iTunes Account settings to manage your subscription and turn off auto-renew. Your iTunes Account will be charged when the purchase is confirmed. If you subscribe before your trial ends, the rest of your free trial will be forfeited as soon as your purchase is confirmed. By using Squeal, you agree to our Terms of Use and Community Guidelines."
    }
    
    func frenchSubscription() {
        squealUnlimitedOutlet.text = "Squeal Illimité"
        subscribeInscriptionOutlet.text = "S’abonner pour avoir accès à un nombre illimité d’histoires sans interruption"
        freeOutlet.text = "Gratuit"
        threeDayTrialOutlet.text = "3 jours d’essai"
        thenOutlet.text = "puis $3.99 par semaine"
        forOneMonth.text = "pour un mois"
        forSixMonth.text = "pour 6 mois"
        weekPriceOutlet.text = "Essayez Squeal Illimité avec 3 jours d’essai gratuit"
        alreadySubscribedOutlet.setTitle("Sélectionner un forfait", for: .normal)
        recurringBillingOutlet.text = "Paiement régulier. Annulation à tout moment. Avec Squeal Illimité, vous aurez un accès illimité à des centaines d’histoires originales dans la Librairie Squeal. L’abonnement sera automatiquement renouvelé à moins que l’option «renouvellement automatique» ne soit désactivée au moins 24h avant la fin de votre abonnement. Vous pouvez gérer votre abonnement depuis les réglages de votre Compte iTunes et désactiver l’option renouvellement automatique. Votre Compte iTunes sera débité uniquement après confirmation de votre achat. Si vous vous abonnez avant la fin de votre période d’essai gratuit, vous perdrez le restant de votre période d’essai aussitôt que votre achat sera confirmé. En utilisant Squeal, vous acceptez nos Conditions d’Utilisation et Directives Communautaires."
    }
    
    func optimization() {
        squealUnlimitedOutlet.font = UIFont(name: ".SFUIDisplay-Semibold", size: view.frame.size.width / 12.93)
        subscribeInscriptionOutlet.font = UIFont(name: "SFProDisplay-Medium", size: view.frame.size.width / 19.71)
        weekPriceOutlet.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 27.6)
        freeOutlet.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 13.8)
        monthPrice.font = UIFont(name: ".SFUIText", size: view.frame.size.width / 18)
        sixMonthsPrice.font = UIFont(name: ".SFUIText", size: view.frame.size.width / 18)
        alreadySubscribedOutlet.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 24.3)
        threeDaysFreeOutlet.layer.cornerRadius = view.frame.size.width / 41.4
        oneMonthOutlet.layer.cornerRadius = view.frame.size.width / 41.4
        oneYearOutlet.layer.cornerRadius = view.frame.size.width / 41.4
    }
    
    
    @IBAction func panGestureRecognizerHandler(_ sender: UIPanGestureRecognizer) {
        
        let touchPoint = sender.location(in: self.view?.window)
        
        if sender.state == UIGestureRecognizerState.began {
            initialTouchPoint = touchPoint
        } else if sender.state == UIGestureRecognizerState.changed {
            
            if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                if statusBarColor == "messenger" {
                    status.backgroundColor = view.backgroundColor
                }else{
                    status.backgroundColor = UIColor.clear
                }
            }
            
            if touchPoint.y - initialTouchPoint.y > 0 {
                self.view.frame = CGRect(x: 0, y: touchPoint.y - initialTouchPoint.y, width: self.view.frame.size.width, height: self.view.frame.size.height)
            }
        } else if sender.state == UIGestureRecognizerState.ended || sender.state == UIGestureRecognizerState.cancelled {
            if touchPoint.y - initialTouchPoint.y > 100 {
                
                if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                    if statusBarColor == "messenger" {
                    status.backgroundColor = view.backgroundColor
                    }else{
                    status.backgroundColor = UIColor.clear
                    }
                }
                
                self.dismiss(animated: true, completion: nil)
            } else {
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
                }) { (true) in
                    if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                        status.backgroundColor = UIColor.clear
                    }
                }
                
            }
        }
        
    }
    
    @IBAction func trialButtonPressed(_ sender: Any) {
        
        selectedIndex = 0

        UIView.animate(withDuration: 0.2, animations: {
            self.oneYearOutlet.backgroundColor = UIColor(displayP3Red: 38/255, green: 34/255, blue: 65/255, alpha: 1)
            self.threeDaysFreeOutlet.backgroundColor = UIColor(displayP3Red: 110/255, green: 80/255, blue: 174/255, alpha: 1)
            self.oneMonthOutlet.backgroundColor = UIColor(displayP3Red: 38/255, green: 34/255, blue: 65/255, alpha: 1)
            self.flagImage.image = UIImage(named: "inactive flag")
        })
        if language == "english" {
            
            weekPriceOutlet.text = "Try Squeal Unlimited free 3 day trial"
        } else if language == "french" {
            weekPriceOutlet.text = "Essayez Squeal Illimité avec 3 jours d’essai gratuit"
        }
    }
    @IBAction func monthButtonPressed(_ sender: Any) {
        
        selectedIndex = 1

        UIView.animate(withDuration: 0.2, animations: {
            self.oneYearOutlet.backgroundColor = UIColor(displayP3Red: 38/255, green: 34/255, blue: 65/255, alpha: 1)
            self.threeDaysFreeOutlet.backgroundColor = UIColor(displayP3Red: 38/255, green: 34/255, blue: 65/255, alpha: 1)
            self.oneMonthOutlet.backgroundColor = UIColor(displayP3Red: 110/255, green: 80/255, blue: 174/255, alpha: 1)
            self.flagImage.image = UIImage(named: "inactive flag")
        })
        if language == "english" {
            weekPriceOutlet.text = "Squeal Unlimited $11.99 per month"
        } else if language == "french" {
            weekPriceOutlet.text = "Squeal Illimité pour $11.99 par mois"
        }
    }
    @IBAction func yearButtonPressed(_ sender: Any) {
        
        selectedIndex = 2

        UIView.animate(withDuration: 0.2, animations: {
            self.oneYearOutlet.backgroundColor = UIColor(displayP3Red: 110/255, green: 80/255, blue: 174/255, alpha: 1)
            self.threeDaysFreeOutlet.backgroundColor = UIColor(displayP3Red: 38/255, green: 34/255, blue: 65/255, alpha: 1)
            self.oneMonthOutlet.backgroundColor = UIColor(displayP3Red: 38/255, green: 34/255, blue: 65/255, alpha: 1)
            self.flagImage.image = UIImage(named: "active flag")
        })
        if language == "english" {
            weekPriceOutlet.text = "Squeal Unlimited $8.3 per month"
        } else if language == "french" {
            weekPriceOutlet.text = "Squeal Illimité pour $8.3 par mois"
        }
    }
    
    @IBAction func purchaseAction(_ sender: Any) {
        
        SVProgressHUD.show()
        
        var product:String = ""
        
        switch selectedIndex {
        case 0:
            product = SquealProducts.SquealTrial
        case 1:
            product = SquealProducts.SquealMonth
        case 2:
            product = SquealProducts.SquealSixMonth
        default:
            return
        }
        
        SwiftyStoreKit.purchaseProduct(product) { [weak self] (result) in
            
            switch result {
            case .success(let purchase):
                SVProgressHUD.showSuccess(withStatus: nil)
                UserDefaults.standard.set(true, forKey: "com.pauldevelopers.ios.subscription")
                self?.dismissAction(sender)
            case .error(let error):
                SVProgressHUD.showError(withStatus: error.localizedDescription)
            }
            
        }
        
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            if statusBarColor == "messenger" {
                status.backgroundColor = view.backgroundColor
            }else{
                status.backgroundColor = UIColor.clear
            }
        }
        self.dismiss(animated: true, completion: nil)
    }
    
}
