//
//  CustomTabBarController.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 PaulDevelopersGroupe. All rights reserved.
//

import UIKit

class CustomTabBarController: UITabBarController, UITabBarControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.selectedIndex = 1
        self.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(self.hideTheTabBar(sender:)), name: NSNotification.Name(rawValue: "hideTheTabBar"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.showTheTabBar(sender:)), name: NSNotification.Name(rawValue: "showTheTabBar"), object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc
    func hideTheTabBar(sender: Notification) {
        UIView.animate(withDuration: 0.2, animations: {
            self.tabBar.alpha = 0
        })
    }
    @objc
    func showTheTabBar(sender: Notification) {
        UIView.animate(withDuration: 0.2, animations: {
            self.tabBar.alpha = 1
        })
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
    }
}
