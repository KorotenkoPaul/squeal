//
//  SearchViewController.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//

import UIKit
import FirebaseDatabase

var fromSearch: Bool = false
var selectedSearch: IndexPath? = nil
var currentMenu: [Story] = []

class SearchViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var searchBarOutlet: UISearchBar!

    

    private var searchMenu: [Story] = []
    private var currentMenu: [Story] = []
    private var emptyMenu: [Story] = []

    var inactiveDatasource = InactiveSearch()
    var emptyDatasource = EmptySearch()
    var dataSource: StoryDatasource!
    var tableView = UITableView(frame: .zero, style: .grouped)
    
    let line = UIView()
    let underView = UIView()
    let storyCounter = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    

        
        

        NotificationCenter.default.addObserver(self, selector: #selector(reloadTableData), name: .SearchReload , object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTableData), name: .reloadLang, object: nil)
        searchBarOutlet.delegate = self

        dataSource = StoryDatasource()
        
        view.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)

        // MARK: создать выбор жанра поиска также как и выбор жанра на главном экране и менять searchMenu в зависимости от выбранного жанра
        searchMenu = horrorMenu + romanceMenu + thrillerMenu
        selected = nil
        
        // languages
        if language == "english" {
            searchBarOutlet.placeholder = "Search"
        } else if language == "french" {
            searchBarOutlet.placeholder = "Rechercher"
        }

        // MARK: gestureRecognizers
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SearchViewController.dismissKeyboard(recognizer:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer.cancelsTouchesInView = false

        configurateTableView()


        NotificationCenter.default.addObserver(self, selector: #selector(performSegueToMessengerFromSearch(sender:)), name: Notification.Name.init("performSegueToMessengerFromSearch"), object: nil)
        // functions
        setUpLine()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.viewWithTag(666)?.removeFromSuperview()
        let loadingView = self.loadingView()
        loadingView.center = view.center
        view.addSubview(loadingView)
        
        if loadingIsOver {
            self.view.viewWithTag(666)?.isHidden = true
            self.tableView.isHidden = false
            self.searchBarOutlet.isHidden = false
            self.tableView.delegate = self.inactiveDatasource
            self.tableView.dataSource = self.inactiveDatasource
        } else {
            searchBarOutlet.isHidden = true
            tableView.isHidden = true
        }
    }

    func configurateTableView(){
        tableView.frame = view.bounds
        tableView.register(SearchTableViewCell.self, forCellReuseIdentifier: "inactiveCell")
        tableView.register(SearchTableViewCell.self, forCellReuseIdentifier: "emptyCell")
        tableView.rowHeight = 80
        tableView.separatorStyle = .none
        tableView.sectionFooterHeight = 0.01
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        view.addSubview(tableView)
        tableView.backgroundColor = .clear
        tableView.tableHeaderView = {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 0.01))
            view.backgroundColor = .clear
            return view
        }()

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: searchBarOutlet.bottomAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        tableView.showsVerticalScrollIndicator = false
    }
    
    private func loadingView() -> UIView {
        
        let view = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 300, height: 396 + 18 - 156)))
        view.tag = 666
        let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 300, height: 154)))
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "offline")
        view.addSubview(imageView)
        
        let offlineLabel = UILabel(frame: CGRect(origin: CGPoint(x: 0, y: imageView.frame.maxY + 16), size: CGSize(width: 300, height: 43)))
        if UserDefaults.standard.string(forKey: "Languages") == nil || UserDefaults.standard.string(forKey: "Languages") == "english" {
            offlineLabel.text = "You’re offline"
        } else {
           offlineLabel.text = "Vous n’êtes pas connecté"
        }
        offlineLabel.textAlignment = .center
        offlineLabel.numberOfLines = 1
        offlineLabel.adjustsFontSizeToFitWidth = true
        offlineLabel.textColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 1)
        offlineLabel.font = UIFont(name: "SFProDisplay-Regular", size: 36)
        offlineLabel.backgroundColor = .clear
        offlineLabel.sizeToFit()
        offlineLabel.center = CGPoint.init(x: imageView.center.x, y: offlineLabel.center.y)
        offlineLabel.frame = CGRect.init(x: 10, y: offlineLabel.frame.minY, width: 300, height: offlineLabel.frame.height)
        view.addSubview(offlineLabel)
        
//        let tapLabel = UILabel(frame: CGRect(origin: CGPoint(x: 13, y: offlineLabel.frame.maxY+16), size: CGSize(width: 300, height: 18)))
//        if UserDefaults.standard.string(forKey: "Languages") == nil || UserDefaults.standard.string(forKey: "Languages") == "english" {
//            tapLabel.text = "Tap anywhere to retry"
//        } else {
//            tapLabel.text = "Toucher l’écran\npour réessayer"
//        }
//
//        tapLabel.textAlignment = .center
//        tapLabel.numberOfLines = 0
//        tapLabel.textColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.6)
//        tapLabel.font = UIFont(name: "LucidaGrande", size: 16)
//        tapLabel.backgroundColor = .clear
//        tapLabel.sizeToFit()
//        tapLabel.center = CGPoint.init(x: imageView.center.x, y: tapLabel.center.y)//CGRect(origin: CGPoint(x: 0, y: offlineLabel.frame.maxY+16), size: CGSize(width: 200, height: tapLabel.frame.height))
//        view.addSubview(tapLabel)
        
        return view
        
    }

    @objc func reloadTableData(_ notification: Notification){

        currentMenu = horrorMenu + romanceMenu + thrillerMenu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    
        UIView.animate(withDuration: 0.2, animations: {
            self.view.viewWithTag(666)?.isHidden = true
            self.tableView.isHidden = false
            self.searchBarOutlet.isHidden = false
            self.tableView.delegate = self.inactiveDatasource
            self.tableView.dataSource = self.inactiveDatasource
            self.tableView.reloadData()
            self.view.layoutIfNeeded()
        })
        }


    }

    @objc
    func performSegueToMessengerFromSearch(sender: Notification) {
        openMessengerAction()
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
                                globalUserName = name
                                globalStoryName = name.lowercased()
                               

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

    func openMessengerAction() {
        if selectedSearch != nil {
            let indexPath = selectedSearch!
            let cell = tableView.cellForRow(at: indexPath) as! SearchTableViewCell
            fromSearch = true

            globalStoryName = cell.storyLabel.text!
            var genre = (cell.genreLabel.text?.lowercased())!
            
            if genre.lowercased() == "horreur" {
                genre = "horror".uppercased()
            }else{
                genre = genre.uppercased() ?? "CLASSIC OF GENRE"
            }
            
            changeStoryFromServer(ganre: genre , name: cell.storyLabel.text!.lowercased(), main: true)
            if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
                status.backgroundColor = UIColor.clear
            }
            self.performSegue(withIdentifier: "openMessengerFromSearch", sender: self)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.searchBarOutlet.text = ""
            }
        }
    }

    func setUpLine() {
        line.frame.size = CGSize(width: view.frame.size.width, height: 0.5)
        line.frame.origin.x = 0
        line.frame.origin.y = searchBarOutlet.frame.size.height - line.frame.size.height
        line.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        line.alpha = 0
        searchBarOutlet.addSubview(line)
    }


    
    // MARK:- SearchBar methods
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let status = UIApplication.shared.value(forKey: "statusBar") as? UIView {
            status.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
        }
        
        if storyIsOpen {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "showTheTabBar"), object: nil, userInfo: nil)
        }
        
        let textFieldInsideSearchBar = searchBarOutlet.value(forKey: "searchField") as? UITextField
        textFieldInsideSearchBar?.textColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 1)
        textFieldInsideSearchBar?.font = UIFont(name: "SFProDisplay-Medium", size: 17)
        if language == "english" {
            if let cancelButton = searchBarOutlet.value(forKey: "cancelButton") as? UIButton {
                UIView.performWithoutAnimation {
                    cancelButton.setTitle("Cancel", for: .normal)
                    cancelButton.titleLabel?.font = UIFont(name: ".SFUIText", size: 16)
                    cancelButton.layoutIfNeeded()
                }
            }
        } else if language == "french" {
            
            if let cancelButton = searchBarOutlet.value(forKey: "cancelButton") as? UIButton {
                UIView.performWithoutAnimation {
                    cancelButton.setTitle("Annuler", for: .normal)
                    cancelButton.titleLabel?.font = UIFont(name: ".SFUIText", size: 14.5)
                    cancelButton.layoutIfNeeded()
                }
            }
        }
    }
    
    var showUnderView = false
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard !searchText.isEmpty else {
            searchMenu = emptyMenu
            tableView.delegate = emptyDatasource
            tableView.dataSource = emptyDatasource
            tableView.reloadData()
            return
        }
        searchMenu = currentMenu.filter({ searchMenu -> Bool in
            searchMenu.name.lowercased().contains(searchText.lowercased())
        })
     
        showUnderView = true
        if searchMenu.isEmpty {
            tableView.delegate = emptyDatasource
            tableView.dataSource = emptyDatasource
            tableView.reloadData()
        } else {
            tableView.delegate = self
            tableView.dataSource = self
            tableView.reloadData()
        }
    }
    
    // MARK: dismiss functions
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.dismiss(animated: true, completion: nil)
        NotificationCenter.default.post(.init(name: .reload))
        searchBarOutlet.endEditing(true)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBarOutlet.endEditing(true)
        if let cancelButton = searchBarOutlet.value(forKey: "cancelButton") as? UIButton {
            cancelButton.isEnabled = true
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBarOutlet.endEditing(true)
        if let cancelButton = searchBarOutlet.value(forKey: "cancelButton") as? UIButton {
            cancelButton.isEnabled = true
        }
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        currentMenu = horrorMenu + thrillerMenu + romanceMenu
        searchBarOutlet.setShowsCancelButton(true, animated: true)
        
        if language == "english" {
            if let cancelButton = searchBarOutlet.value(forKey: "cancelButton") as? UIButton {
                UIView.performWithoutAnimation {
                    cancelButton.setTitle("Cancel", for: .normal)
                    cancelButton.titleLabel?.font = UIFont(name: ".SFUIText", size: 16)
                    cancelButton.layoutIfNeeded()
                }
            }
        } else if language == "french" {
            
            if let cancelButton = searchBarOutlet.value(forKey: "cancelButton") as? UIButton {
                UIView.performWithoutAnimation {
                    cancelButton.setTitle("Annuler", for: .normal)
                    cancelButton.titleLabel?.font = UIFont(name: ".SFUIText", size: 14.5)
                    cancelButton.layoutIfNeeded()
                }
            }
        }
        
        if (searchBar.text?.isEmpty)! {
            tableView.delegate = emptyDatasource
            tableView.dataSource = emptyDatasource
            tableView.reloadData()
        }
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBarOutlet.setShowsCancelButton(false, animated: true)
        if (searchBar.text?.isEmpty)! {
            tableView.delegate = inactiveDatasource
            tableView.dataSource = inactiveDatasource
            tableView.reloadData()
        }
    }

    
    
    @objc func dismissKeyboard(recognizer: UITapGestureRecognizer) {
        if currentMenu == emptyMenu {
            searchBarOutlet.endEditing(true)
            self.dismiss(animated: true, completion: nil)
        }else{
            view.endEditing(true)
            if let cancelButton = searchBarOutlet.value(forKey: "cancelButton") as? UIButton {
                cancelButton.isEnabled = true
            }
        }
    }


    //TableViewDelegate and DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchMenu.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "inactiveCell") as? SearchTableViewCell else {
            fatalError()
        }
        if !searchMenu.isEmpty {
            cell.storyImage.image = searchMenu[indexPath.row].images ?? UIImage(named: "loading")
            cell.storyLabel.text = searchMenu[indexPath.row].name.capitalizingFirstLetter()
            cell.genreLabel.text = searchMenu[indexPath.row].genre?.uppercased() ?? "CLASSIC OF GENRE"
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedSearch = indexPath
        globalStoryName = ((tableView.cellForRow(at: indexPath) as! SearchTableViewCell).storyLabel.text?.capitalizingFirstLetter())!
        if Int(String(globalStoryName.last!)) != nil {
            episodeNumber = Int(String(globalStoryName.last!))!
        } else {
            episodeNumber = 1
        }
        NotificationCenter.default.post(name: .init("performSegueToMessengerFromSearch"), object: nil)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.000001
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.00001
    }
}

class InactiveSearch: NSObject, UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var menu: [Story] = []
        switch section {
        case 0:
            menu = horrorMenu
        case 1:
            menu = romanceMenu
        case 2:
            menu = thrillerMenu
        default:
            menu = []
        }
        return menu.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "inactiveCell") as? SearchTableViewCell else {
            fatalError()
        }
        var menu: [Story] = []
        switch indexPath.section {
        case 0:
            menu = horrorMenu

        case 1:
            menu = romanceMenu
        case 2:
            menu = thrillerMenu
        default:
            menu = []
        }
        if !menu.isEmpty {
            cell.storyImage.image = menu[indexPath.row].images ?? UIImage(named: "loading")
            cell.storyLabel.text = menu[indexPath.row].name.capitalizingFirstLetter()
            
            if menu[indexPath.row].genre?.lowercased() == "horror" && language == "french" {
                cell.genreLabel.text = "horreur".uppercased()
            }else{
                print (menu[indexPath.row].genre?.uppercased())
                cell.genreLabel.text = menu[indexPath.row].genre?.uppercased() ?? "CLASSIC OF GENRE"
            }
            
        }
        cell.selectionStyle = .none
        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedSearch = indexPath
        NotificationCenter.default.post(name: .init("performSegueToMessengerFromSearch"), object: nil)

    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 34))
        let label = UILabel(frame: CGRect(x: 23, y: 15, width: 119, height: 13))
        label.font = UIFont(name: "Helvetica-Bold", size: 12)
        label.textAlignment = .left
        label.backgroundColor = .clear
        view.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
        label.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 0.5)
        view.addSubview(label)
        switch section {
            case 0:
                if language == "english" {
                    label.text = "HORROR"
                } else if language == "french" {
                    label.text = "HORREUR"
                }
            case 1:
                if language == "english" {
                    label.text = "ROMANCE"
                } else if language == "french" {
                    label.text = "ROMANCE"
                }
            case 2:
                if language == "english" {
                    label.text = "THRILLER"
                } else if language == "french" {
                    label.text = "THRILLER"
                }
            default:
                return view
        }
        return view
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 34
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.00001
    }
}

class EmptySearch: NSObject, UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "emptyCell") as? SearchTableViewCell else {
            fatalError()
        }
        cell.isLoading = true
        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 36))
        let label = UILabel(frame: CGRect(x: 18, y: 15, width: 65, height: 14))
        label.font = UIFont(name: "Helvetica-Bold", size: 12)
        label.textAlignment = .left
        label.backgroundColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.25)
        label.layer.cornerRadius = 7
        label.clipsToBounds = true
        view.backgroundColor = UIColor(displayP3Red: 42/255, green: 34/255, blue: 63/255, alpha: 1)
        label.textColor = UIColor(displayP3Red: 250/255, green: 250/255, blue: 250/255, alpha: 0.5)
        view.addSubview(label)
        return view
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.00001
    }
}



