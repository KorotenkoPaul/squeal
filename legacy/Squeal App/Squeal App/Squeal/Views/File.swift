//
//  File.swift
//  Squeal
//
//  Created by Vlad Zaitsev on 20.09.2018.
//  Copyright © 2018 PaulDevelopersGroupe. All rights reserved.
//

import Foundation
import UIKit

class GenreButton: UIButton {
    var isActive = false {
        didSet{
            if isActive {
                UIView.animate(withDuration: 0.5, animations: {
                    self.titleLabel?.font = UIFont(name: "Avenir-Heavy", size: 12)
                    self.setTitleColor(UIColor(displayP3Red: 38/255, green: 35/255, blue: 66/255, alpha: 1), for: .normal)
                    self.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 1)
                    self.layoutIfNeeded()
                })
            } else {
                UIView.animate(withDuration: 0.5, animations: {
                    self.titleLabel?.font = UIFont(name: "Avenir-Heavy", size: 10)
                    self.setTitleColor(UIColor(displayP3Red: 133/255, green: 128/255, blue: 150/255, alpha: 1), for: .normal)
                    self.backgroundColor = .clear
                    self.layoutIfNeeded()
                })
            }
        }
    }
    var isLoading = false {
        didSet{
            if isLoading {
                UIView.animate(withDuration: 0.5, animations: {
                    self.titleLabel?.alpha = 0
                    self.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
                    self.frame.size = CGSize(width: 65, height: 14)
                    self.layer.cornerRadius = 7
                    self.layoutIfNeeded()
                })
            } else {
                UIView.animate(withDuration: 0.5, animations: {
                    self.titleLabel?.alpha = 1
                    self.backgroundColor = .clear
                    self.frame.size = CGSize(width: 75, height: 26)
                    self.layer.cornerRadius = 13
                    self.layoutIfNeeded()
                })
            }
        }
    }

    init(genreName genre: String) {
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: 75, height: 26)))
        self.setTitle(genre, for: .normal)
        self.titleLabel?.font = UIFont(name: "Avenir-Heavy", size: 10)
        self.setTitleColor(UIColor(displayP3Red: 133/255, green: 128/255, blue: 150/255, alpha: 1), for: .normal)
        self.titleLabel?.textAlignment = .center
        self.layer.cornerRadius = 13
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class GenreSwitcher: UIView {
    var genre1: GenreButton!
    var genre2: GenreButton!
    var genre3: GenreButton!
    var genre4: GenreButton!
    var genresButtonArray: [GenreButton]!


    func isLoading(_ flag: Bool) {
        for button in genresButtonArray {
            button.isLoading = true
        }
    }

    init(frame: CGRect,genresButtons genres: [GenreButton]) { //Инициализатор принимает только 4 Кнопки
        super.init(frame: frame)
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if genres.count == 4 {
            genre1 = genres[0]
            genre2 = genres[1]
            genre3 = genres[2]
            genre4 = genres[3]

            genre1.isActive = true

            genresButtonArray = [genres[0], genres[1], genres[2], genres[3]]

            genre1.center = CGPoint(x: self.frame.width / 5, y: self.frame.height / 2) // центрируем кнопки жанров
            self.addSubview(genre1)
            genre2.center = CGPoint(x: self.frame.width / 5 * 2, y: self.frame.height / 2)
            self.addSubview(genre2)
            genre3.center = CGPoint(x: self.frame.width * 3 / 5, y: self.frame.height / 2)
            self.addSubview(genre3)
            genre4.center = CGPoint(x: self.frame.width / 5 * 4, y: self.frame.height / 2)
            self.addSubview(genre4)

            genre1.addTarget(self, action: #selector(ButtonIsTapped(sender:)), for: .touchUpInside)
            genre2.addTarget(self, action: #selector(ButtonIsTapped(sender:)), for: .touchUpInside)
            genre3.addTarget(self, action: #selector(ButtonIsTapped(sender:)), for: .touchUpInside)
            genre4.addTarget(self, action: #selector(ButtonIsTapped(sender:)), for: .touchUpInside)
        } else {
            fatalError()
        }
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    @objc
    func ButtonIsTapped(sender: GenreButton) {
        for button in self.genresButtonArray {
            if button == sender {
                button.isActive = true
                changeGenre = (button.titleLabel?.text!.lowercased())!
            } else {
                button.isActive = false
            }
        }
    }
}
