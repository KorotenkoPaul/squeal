//
//  AppDelegate.swift
//  Squeal
//
//  Created by mac on 12.06.2018.
//  Copyright © 2018 PaulDevelopersGroup. All rights reserved.
//

import UIKit
import StoreKit
import Firebase
import SVProgressHUD
import SwiftyStoreKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        UIApplication.shared.statusBarStyle = .lightContent
        
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.dark)
        SVProgressHUD.setRingNoTextRadius(10)
        
        FirebaseApp.configure()
        //requestReview()
        
        // see notes below for the meaning of Atomic / Non-Atomic
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    if purchase.needsFinishTransaction {
                        // Deliver content from server, then:
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                // Unlock content
                case .failed, .purchasing, .deferred:
                    break // do nothing
                }
            }
        }
    

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
        //SVProgressHUD.show()
        
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
            
            //SVProgressHUD.dismiss()
        }
        
    }
    
    func requestReview() {
        if #available(iOS 10.3, *) {
            SKStoreReviewController.requestReview()
        }
    }

}

