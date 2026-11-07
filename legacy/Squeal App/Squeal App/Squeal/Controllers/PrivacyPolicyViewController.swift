//
//  PrivacyPolicyViewController.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit

class PrivacyPolicyViewController: UIViewController {

    let privacyPolicyView = UIView()
    let webView = UIWebView()
    let dismissButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if language == "english" {
            dismissButton.setTitle("Close", for: .normal)
        } else if language == "french" {
            dismissButton.setTitle("Fermer", for: .normal)
        }
        
        privacyPolicyView.frame.size.height = view.frame.size.height * 0.78
        privacyPolicyView.frame.size.width = view.frame.size.width * 0.95
        privacyPolicyView.frame.origin.x = view.frame.size.width / 2 - privacyPolicyView.frame.size.width / 2
        privacyPolicyView.frame.origin.y = view.frame.size.height / 2 - privacyPolicyView.frame.size.height / 2
        privacyPolicyView.backgroundColor = UIColor(displayP3Red: 38/255, green: 34/255, blue: 65/255, alpha: 1)
        privacyPolicyView.layer.cornerRadius = 7
        privacyPolicyView.clipsToBounds = true
        view.addSubview(privacyPolicyView)
        
        dismissButton.frame.size.height = privacyPolicyView.frame.size.height / 12
        dismissButton.frame.size.width = privacyPolicyView.frame.size.width
        dismissButton.frame.origin.x = privacyPolicyView.frame.size.width / 2 - dismissButton.frame.size.width / 2
        dismissButton.frame.origin.y = privacyPolicyView.frame.size.height - dismissButton.frame.size.height
        dismissButton.titleLabel?.font = UIFont(name: "SFProDisplay-Regular", size: view.frame.size.width / 23)
        dismissButton.setTitleColor(.white, for: .normal)
        privacyPolicyView.addSubview(dismissButton)
        
        dismissButton.addTarget(self, action: #selector(dismissPrivacyPolicy), for: .touchUpInside)
        
        if let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "pdf") {
            
        webView.frame.size = CGSize(width: privacyPolicyView.frame.size.width, height: privacyPolicyView.frame.size.height - dismissButton.frame.size.height)
        webView.frame.origin.x = 0
        webView.frame.origin.y = 0
        let urlRequest = URLRequest(url: url)
        webView.loadRequest(urlRequest as URLRequest)
        privacyPolicyView.addSubview(webView)
            
        }
        
        dismissButton.backgroundColor = UIColor(displayP3Red: 38/255, green: 34/255, blue: 65/255, alpha: 1)

    }
    
    @objc func dismissPrivacyPolicy() {
        dismiss(animated: true, completion: nil)
    }
}
