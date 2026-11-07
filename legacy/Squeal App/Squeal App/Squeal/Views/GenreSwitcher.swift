//
//  GenreSwitcher.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 PaulDevelopersGroupe. All rights reserved.
//

import Foundation
import UIKit

class GenreButton: UIButton {
    var isActive = false {
        didSet{
            if isActive {
                UIView.animate(withDuration: 0.5, animations: {
                    self.titleLabel?.font = UIFont(name: "Avenir-Heavy", size: 11)
                    if UIScreen.main.bounds.height == 568 {
                        self.titleLabel?.font = UIFont(name: "Avenir-Heavy", size: 9)
                    }
                    self.setTitleColor(UIColor(displayP3Red: 38/255, green: 35/255, blue: 66/255, alpha: 1), for: .normal)
                    //self.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 1)
                    self.layoutIfNeeded()
                })
            } else {
                UIView.animate(withDuration: 0.5, animations: {
                    self.titleLabel?.font = UIFont(name: "Avenir-Heavy", size: 10)
                    if UIScreen.main.bounds.height == 568 {
                        self.titleLabel?.font = UIFont(name: "Avenir-Heavy", size: 8)
                    }
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
                    self.titleLabel?.alpha = 0
                    self.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
                    self.frame.size = CGSize(width: 65, height: 14)
                    self.layer.cornerRadius = 7
                    self.isEnabled = false
                self.setNeedsLayout()
            } else {
                    self.titleLabel?.alpha = 1
                    self.backgroundColor = .clear
                    self.frame.size = CGSize(width: 75, height: 26)
                    self.layer.cornerRadius = 13
                    self.isEnabled = true
                    self.setNeedsLayout()
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

    let animView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 13
        if UIScreen.main.bounds.height == 568 {
            view.layer.cornerRadius = 12
        }
        
        return view
    }()
    var genre1: GenreButton!
    var genre2: GenreButton!
    var genre3: GenreButton!
    var genre4: GenreButton!
    var genresButtonArray: [GenreButton]!

    func isLoading(_ flag: Bool) {
        for button in genresButtonArray {
            button.isLoading = flag
        }
        if flag {
            animView.alpha = 0
            for button in genresButtonArray {
                button.frame.size = CGSize(width: self.frame.width * 65 / 375, height: 14)
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.animView.alpha = 1
            })
        }
        genre1.center = CGPoint(x: self.frame.width / 5, y: self.frame.height / 2) // центрируем кнопки жанров
        genre2.center = CGPoint(x: self.frame.width / 5 * 2, y: self.frame.height / 2)
        genre3.center = CGPoint(x: self.frame.width * 3 / 5, y: self.frame.height / 2)
        genre4.center = CGPoint(x: self.frame.width / 5 * 4, y: self.frame.height / 2)

    }

    init(frame: CGRect,fourGenresButtons genres: [GenreButton]) { //Инициализатор принимает только 4 Кнопки
        super.init(frame: frame)
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if genres.count == 4 {

            animView.frame.size = CGSize(width: 80, height: 26)
            if UIScreen.main.bounds.height == 568 {
                animView.frame.size = CGSize(width: 70, height: 24)
            }
            animView.center = CGPoint(x: self.frame.width / 5, y: self.frame.height / 2)
            self.addSubview(animView)


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

            NotificationCenter.default.addObserver(self, selector: #selector(reloadGenreSwitcher(sender:)), name: .reloadGenreSwircher, object: nil)
        } else {
            fatalError()
        }
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    @objc
    func ButtonIsTapped(sender: GenreButton) {
        UIView.animate(withDuration: 0.3, animations: {
            self.animView.center = sender.center
        })
        switch sender {
            case genre1:
                changeGenre = "featured"
            case genre2:
                changeGenre = "horror"
            case genre3:
                changeGenre = "romance"
            case genre4:
                changeGenre = "thriller"
            default:
                break
        }

        for button in self.genresButtonArray {
            if button == sender {
                button.isActive = true
            } else {
                button.isActive = false
            }
        }
        NotificationCenter.default.post(.init(name: .reload))
    }


    @objc
    func reloadGenreSwitcher(sender: Notification) {
        switch changeGenre {
        case "featured":
            genre1.isActive = true
            genre2.isActive = false
            genre3.isActive = false
            genre4.isActive = false
        case "horror":
            genre1.isActive = false
            genre2.isActive = true
            genre3.isActive = false
            genre4.isActive = false
        case "romance":
            genre1.isActive = false
            genre2.isActive = false
            genre3.isActive = true
            genre4.isActive = false
        case "thriller":
            genre1.isActive = false
            genre2.isActive = false
            genre3.isActive = false
            genre4.isActive = true
        default:
            break
        }

    }

}
