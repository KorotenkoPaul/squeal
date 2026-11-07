//
//  EpisodePicker.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 PaulDevelopersGroupe. All rights reserved.
//

import UIKit

protocol EpisodePickerDelegate: class {
    func episode1()
    func episode2()
    func episode3()
}

class EpisodePicker: UIView {

    var delegatePicker: EpisodePickerDelegate?
    let button1 = EpisodeButton()
    let button2 = EpisodeButton()
    let button3 = EpisodeButton()

    init(numberOfEpisodes number: Int, frame: CGRect) {// принимает от 1 до 3 кнопок
        super.init(frame: frame)

        button1.translatesAutoresizingMaskIntoConstraints = false
        button2.translatesAutoresizingMaskIntoConstraints = false
        button3.translatesAutoresizingMaskIntoConstraints = false

        button1.setTitle("1", for: .normal)
        button2.setTitle("2", for: .normal)
        button3.setTitle("3", for: .normal)

        button1.addTarget(self, action: #selector(button1method(sender:)), for: .touchUpInside)
        button2.addTarget(self, action: #selector(button2method(sender:)), for: .touchUpInside)
        button3.addTarget(self, action: #selector(button3method(sender:)), for: .touchUpInside)


        if number == 1 {
            self.addSubview(button1)
            button1.isActive = true

            button1.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
            button1.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
            button1.widthAnchor.constraint(equalToConstant: 38).isActive = true
            button1.heightAnchor.constraint(equalToConstant: 38).isActive = true
        } else if number == 2 {
            self.addSubview(button1)
            self.addSubview(button2)

            button1.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
            button1.centerXAnchor.constraint(equalTo: self.leadingAnchor, constant: 0.3333 * self.frame.width).isActive = true
            button1.widthAnchor.constraint(equalToConstant: 38).isActive = true
            button1.heightAnchor.constraint(equalToConstant: 38).isActive = true

            button2.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
            button2.centerXAnchor.constraint(equalTo: self.leadingAnchor, constant: 0.6666 * self.frame.width).isActive = true
            button2.widthAnchor.constraint(equalToConstant: 38).isActive = true
            button2.heightAnchor.constraint(equalToConstant: 38).isActive = true
        } else {
            self.addSubview(button1)
            self.addSubview(button2)
            self.addSubview(button3)

            button1.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
            button1.centerXAnchor.constraint(equalTo: self.leadingAnchor, constant: 0.25 * self.frame.width).isActive = true
            button1.widthAnchor.constraint(equalToConstant: 38).isActive = true
            button1.heightAnchor.constraint(equalToConstant: 38).isActive = true

            button2.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
            button2.centerXAnchor.constraint(equalTo: self.leadingAnchor, constant: 0.5 * self.frame.width).isActive = true
            button2.widthAnchor.constraint(equalToConstant: 38).isActive = true
            button2.heightAnchor.constraint(equalToConstant: 38).isActive = true


            button3.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
            button3.centerXAnchor.constraint(equalTo: self.leadingAnchor, constant: 0.75 * self.frame.width).isActive = true
            button3.widthAnchor.constraint(equalToConstant: 38).isActive = true
            button3.heightAnchor.constraint(equalToConstant: 38).isActive = true
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func button1method(sender: UIButton) {
        UIView.animate(withDuration: 0.2, animations: {
            self.button1.isActive = true
            self.button2.isActive = false
            self.button3.isActive = false
        })


        self.delegatePicker?.episode1()
    }
    @objc
    func button2method(sender: UIButton) {
        UIView.animate(withDuration: 0.2, animations: {
            self.button1.isActive = false
            self.button2.isActive = true
            self.button3.isActive = false
        })
        self.delegatePicker?.episode2()
    }
    @objc
    func button3method(sender: UIButton) {
        UIView.animate(withDuration: 0.2, animations: {
            self.button1.isActive = false
            self.button2.isActive = false
            self.button3.isActive = true
        })
        self.delegatePicker?.episode3()
    }
}
