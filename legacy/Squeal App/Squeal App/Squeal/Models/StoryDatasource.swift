//
//  Datasource.swift
//  Squeal
//
//  Created by Paul Korotenko.
//  Copyright © 2018 Squeal. All rights reserved.
//
//  Story name shouldn't be longer than 20 symbols.
//  Story description should have 185 symbols.

import UIKit
import FirebaseDatabase

var compled: Int = 0

var slidesArray: [Slider] = []
var featuredMenu: [Story] = []
var horrorMenu: [Story] = []
var romanceMenu: [Story] = []
var thrillerMenu: [Story] = []
var forAnotherLang: [String: [Story]] = [:]
var slideUrl: [[String]] = []

var dictOfAllStories: [String: Story] = [:]
var dictOfAllAnotherStories: [String: Story] = [:]

class StoryDatasource: NSObject {
    
    //MARK:- Vars
    
    var ref: DatabaseReference!
    var databaseHandle: DatabaseHandle?
    var timer = Timer()
    var arrayForSlider = [Story]()
    
    //MARK:- Public
    //var upload: [String: [String]] = ["forLeft": ["Pas grande chose, et toi?","Tu me sembles affaiblie.","C’est à propos Harry?","Alors?","Mon Dieu! Il va bien?","Wow! C’est pas rien!","C’est grave! Qu’est-ce que tu vas faire?","Quoi?","Et tu as gardé ça pour toi  jusqu’à maintenant?","Alors détective Al, tu as trouvé quelque chose?","Tu as des pistes?","Des appels tard la nuit, tout le temps accroché à son téléphone… Qu’est-ce qui est bizarre exactement?","Quelle excuse a-t-il?","Ah c’est varié! lol.","Donc tu l’as suivi ou pas encore?","Peut-être que je peux le faire pour toi?","A quoi servent les sœurs sinon?","Quand vas-tu arrêter de dramatiser?","Oui","Oui, dis-moi tout ce que tu sais.","Ok, donc commençons avec les mardis et jeudis.","Ne t’inquiète pas!","Mis à part les réunions, il y a autre chose?","Peut-être que c’était pour toi.","Quoi d’autre?","Pourquoi?","Cela aurait pu être vrai?","Qu’est-ce que tu veux dire?","Preuves circonstancielles lol.","Tu as vérifié son téléphone?","Tout va bien? Tu sembles bouleversée.","Tu as accès à son mail?","Ok, et qu’est-ce qu’il dit?","Wow! C’est fou! Peut-être que c’est un cadeau pour toi","Hey, calme-toi ok? J’essaie de t’aider.","Et bien, qu’est-ce que je suis supposée dire? T’encourager à divorcer sur une intuition?","Ou suis-je censé châtier ses actions et vous dire à quel point vous êtes pitoyable?","Faisons cela. Votre mari est le pire homme jamais vu!!","Oui! Il joue avec les femmes et garde ensuite leurs rouges à lèvres comme souvenirs!","Non,  attends s’il-te-plaît! Puis il va et dépense 1270 dollars sur une nana au hasard!","Ou peut-être qu’il te trompe! C’est ce que tu veux entendre!","QUOI?","Parce que tu me l’as dit!","Je dois rentrer à la maison, bye!"], "forRight": ["Salut! Quoi de neuf?","Rien ici non plus.","Nan! Le petit Harry va bien!","C’est son père.","Je le suspecte de me tromper.","Je sais et le pire est que je n’en suis même pas sûre.","Je ne suis pas sûre si je veux creuser ou pas pour en savoir plus.","Et bien, je le surveille depuis deux semaines?","Parce que je n’étais pas sûre et je ne voulais pas faire une scène.","Arh! Not pas encore, mais je vais bientôt trouver!","Juste un comportement étrange.","Non rien de tout ça, il est suffisamment intelligent pour couvrir ses traces.","Je suis tout le temps mise en attente quand je l’appelle.","Quelque soit l’heure du jour où je l’appelle.","J’étais dehors! J’étais à une réunion!","Ce qui malheureusement ne correspond pas à la version de sa secrétaire","Oh, merci beaucoup! J’étais inquiète et je ne savais pas à qui confier cette tâche.","Et si jamais il découvre que je l’ai fait suivre?","C’est facile à dire pour toi, tu es encore célibataire!","Eh bien, nous connaîtrons la vérité d'une manière ou d'une autre","Bon alors voici comment tout a commencé","Les mardis et jeudis, il sort régulièrement à midi.","Je l'ai confirmé de sa secrétaire il n'y a pas de réunions ces jours-là","Sarah, s’il-te-plait ne te fais pas attraper. ","Je ne veux pas ruiner notre relation s’il est honnête.","Oui, j’ai trouvé un rouge-à-lèvre dans son sac.","Un déjà utilisé?","Lequel j’ai découvert par moi-même?","Et d’une couleur que je ne porterai jamais.","Il m’a dit qu’il avait un dîner d’urgence pour son travail.","Ce week-end, il a annulé notre plan d’aller voir un film à la dernière minute.","Sarah? Un dîner d’entreprise d’urgence","Un dîner d’entreprise d’urgence, informé par un message qu’il a lu en souriant.","Je suis sûre Sarah","Il y a un mot de passe","Oh mon!","Oui, je viens de recevoir un message sur son mail.","C’est attaché à notre compte joint.","Une facture d'un montant énorme a été payée dans un restaurant","DANS UN RESTAURANT?!","Sérieusement??","Oui, désolée. Je ne voulais pas t’accuser.","Non! Tu as raison!","J’ai dit que j’étais désolée!","Sarah!","Je suis déjà blessée, Sarah!","Peut-être qu'il organise une fête pour ses collègues","Sarah?","Comment tu sais que David a dépensé $1270 dans ce restaurant restaurant?","Je ne t’ai jamais donné le montant.","Mais tu n’étais pas déjà chez toi?","Allo?","Sarah?","Tu es là??"], "middle": ["Sarah","Alana"], "scheme": ["R","L","R","L","L","R","L","R","L","R","L","R","L","R","L","R","L","R","L","R","L","R","L","R","R","R","L","R","L","R","L","L","R","L","R","L","R","R","L","R","L","R","R","L","R","R","L","L","R","L","R","R","R","L", "R","L","R","L","R","L","R","R","L","L","R","R","L","R","L","R","L","R","L","R","R","L","R","L","R","L","R","L","R","L","R","L","R","L","R","L","R","L","R","L","R","R","R","R"]]
    
    
    
    
    open func get(success: @escaping () -> Void)  { //Функция скачивает с сервера все данные
        
        ref = Database.database().reference()
        
        
        
        let connectionRef = Database.database().reference(withPath: ".info/connected")
        connectionRef.observe(.value, with: { (snapshot) in
            let connection = snapshot.value as? Bool
            if connection == true {
                print ("connect")
                
                
                
                self.ref.child("conversion").observe(.value, with: { snapshot in
                    let conversionArray = snapshot.value ?? "nil"  as AnyObject
                    let viewsDict = conversionArray as? [String: [String: [String: Double]]]
                    
                    if viewsDict != nil {
                        dictOfViews = viewsDict!
                        print(dictOfViews)
                    } else {
                        print("Error views")
                    }
                    
                })
                
                
                self.ref.child("ganres").observe(DataEventType.value, with: { (snapshot) in
                    let postDict = snapshot.value as? [String : AnyObject] ?? [:]
                    
                    let dictFeatured = postDict["featuredMenu"] ?? "nil"  as AnyObject
                    var engFr: [String: Any?] = [:]
                    let engDictEng = dictFeatured["eng"] ?? "nil" as AnyObject
                    let engDictFr = dictFeatured["fr"] ?? "nil" as AnyObject
                    engFr.updateValue(engDictEng, forKey: "eng")
                    engFr.updateValue(engDictFr, forKey: "fr")
                    
                    var featured: NSMutableDictionary = NSMutableDictionary()
                    
                    
                    
                    if language == "english" {
                        featured = engFr["eng"] as! NSMutableDictionary
                        
                        
                    } else if language == "french" {
                        featured = engFr["fr"] as! NSMutableDictionary
                        
                        
                    }
                    
                    let FeaturedCount = featured.allKeys.count
                    
                    
                    featuredMenu = []
                    var checks = 0
                    for i in featured.allKeys as! [String] {

/**/                   var serverFeatured = featured[i] as? [AnyObject]
                        var episodes: [String] = []
                        if serverFeatured?.count == 8 {
                            episodes = serverFeatured![7] as! [String]
                        }
                        self.makeGanre(ganre: "featured", name: serverFeatured![0] as! String, storyDescription: serverFeatured![1] as! String, author: serverFeatured![2]  as! String , releaseDate: serverFeatured![3] as? String, status: serverFeatured![4] as! String, image: serverFeatured![6] as! String, serverGanre: serverFeatured![5] as! String, episodes: episodes)
                        checks += 1
                        if checks == FeaturedCount { compled = compled + 1 }
                        if checks == FeaturedCount  {
                            print("Dict of all stories")
                            for (name, story) in dictOfAllStories{
                                print("\(name) \(story)")
                            }
                            self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.allFuncs), userInfo: nil, repeats: true)
                            success()
                        }
                    }
                    for (name, story) in dictOfAllStories{
                        print("\(name) \(story)")
                    }
                })
                
            

            }else{
                
                print ("disconnect")
                
            }
        })
        
    }
    
    //MARK:- Private
    
    private func makeGanre(ganre: String, name: String, storyDescription: String, author: String , releaseDate: String?, status: String, image: String, serverGanre: String, episodes: [String]) {
        if ganre == "horror"{
            let story = Story(name: name, storyDescription: storyDescription, author: author, releaseDate: releaseDate, status: status, genre: serverGanre, image: image, episodes: episodes)
            horrorMenu.append(story)
            dictOfAllStories.updateValue(story, forKey: name.lowercased())
            sortHorror()
        }else if ganre == "romance"{
            let story = Story(name: name, storyDescription: storyDescription, author: author, releaseDate: releaseDate, status: status, genre: serverGanre, image: image, episodes: episodes)
            romanceMenu.append(Story(name: name, storyDescription: storyDescription, author: author, releaseDate: releaseDate, status: status, genre: serverGanre, image: image, episodes: episodes))
            dictOfAllStories.updateValue(story, forKey: name.lowercased())
            sortRomance()
        }else if ganre == "thriller"{
            let story = Story(name: name, storyDescription: storyDescription, author: author, releaseDate: releaseDate, status: status, genre: serverGanre, image: image, episodes: episodes)
            thrillerMenu.append(Story(name: name, storyDescription: storyDescription, author: author, releaseDate: releaseDate, status: status, genre: serverGanre, image: image, episodes: episodes))
            dictOfAllStories.updateValue(story, forKey: name.lowercased())
            sortThriller()
        }else if ganre == "slider"{
            self.arrayForSlider.append(Story(name: name, storyDescription: storyDescription, author: author, releaseDate: releaseDate, status: status, genre: serverGanre, image: image, episodes: episodes))
            slidesArray = [Slider(slides: arrayForSlider )]
        }else {
            featuredMenu.append(Story(name: name, storyDescription: storyDescription, author: author, releaseDate: releaseDate, status: status, genre: serverGanre, image: image, episodes: episodes))
            sortFeatured()
        }
    }
    
    var forTimeOf = true
    @objc private func allFuncs () {
        self.doNext { (true) in
            print("done")
        }
        if forTimeOf == true {
            forTimeOf = false
          self.timeOf()
        }
        
        
    }
    
    private func timeOf () {
        
        ref = Database.database().reference()
        
        
        
        ref.child("story").observe(DataEventType.value, with: { (snapshot) in
            let postDict = snapshot.value as? [String : AnyObject] ?? [:]

            
                let genresHorror = postDict["horrorStory"] ?? "nil"  as AnyObject
                let genresRomance = postDict["romanceStory"] ?? "nil"  as AnyObject
                let genresTriller = postDict["thrillerStory"] ?? "nil"  as AnyObject
            
                let genreHorror = genresHorror as? [String : [String: [String: [String]]]]
                let genreRomance = genresRomance as? [String : [String: [String: [String]]]]
                let genreTriller = genresTriller as? [String : [String: [String: [String]]]]
            
                let langHEng = genreHorror!["eng"]
                let langHFr = genreHorror!["fr"]
                let langREng = genreRomance!["eng"]
                let langRFr = genreRomance!["fr"]
                let langTEng = genreTriller!["eng"]
                let langTFr = genreTriller!["fr"]
            
                let arrayOfLang = [langHEng,langHFr,langREng,langRFr,langTEng,langTFr]
            
                print("genre?.keys")
            
            
                for i in arrayOfLang {
                    for j in i!.keys {
                        let names = i!["\(j)".lowercased()]
                        let scheme = names!["scheme"]
                        
                        if scheme != nil {
                            let sec = Double(scheme!.count) * 5.truncatingRemainder(dividingBy: 60)
                            
                            let min = round(sec / 60 )
                            
                            timeOfReadingVar.updateValue(Int(min), forKey: "\(j)".lowercased())
                            print("time \(timeOfReadingVar)")
                            
                        }
                    }
                  
                }
                
            
        })
    }
    
    @objc private func doNext (completion: @escaping (Bool) -> ()) {
        
        if success >= 8 && compled == 1 {
            
            print("complete \(compled)")
            print("success \(success)")
            
            timer.invalidate()
            self.ref.child("ganres").observe(DataEventType.value, with: { (snapshot) in
                let postDict = snapshot.value as? [String : AnyObject] ?? [:]
                let dictFeatured = postDict["featuredMenu"] ?? "nil"  as AnyObject
                let dictHorror = postDict["horrorMenu"] ?? "nil"  as AnyObject
                let dictRomance = postDict["romanceMenu"] ?? "nil"  as AnyObject
                let dictMystery = postDict["thrillerMenu"] ?? "nil"  as AnyObject
                
                
                var engFr: [String: Any?] = [:]
                var engFrH: [String: Any?] = [:]
                var engFrR: [String: Any?] = [:]
                var engFrT: [String: Any?] = [:]
                
                let engDictEng = dictFeatured["eng"] ?? "nil" as AnyObject
                let engDictFr = dictFeatured["fr"] ?? "nil" as AnyObject
                let engDictEngH = dictHorror["eng"] ?? "nil" as AnyObject
                let engDictFrH = dictHorror["fr"] ?? "nil" as AnyObject
                let engDictEngR = dictRomance["eng"] ?? "nil" as AnyObject
                let engDictFrR = dictRomance["fr"] ?? "nil" as AnyObject
                let engDictEngT = dictMystery["eng"] ?? "nil" as AnyObject
                let engDictFrT = dictMystery["fr"] ?? "nil" as AnyObject
                
                
                engFr.updateValue(engDictEng, forKey: "eng")
                engFr.updateValue(engDictFr, forKey: "fr")
                engFrH.updateValue(engDictEngH, forKey: "eng")
                engFrH.updateValue(engDictFrH, forKey: "fr")
                engFrR.updateValue(engDictEngR, forKey: "eng")
                engFrR.updateValue(engDictFrR, forKey: "fr")
                engFrT.updateValue(engDictEngT, forKey: "eng")
                engFrT.updateValue(engDictFrT, forKey: "fr")
                
                var another: NSMutableDictionary = NSMutableDictionary()
                var horror: NSMutableDictionary = NSMutableDictionary()
                var anotherHorror: NSMutableDictionary = NSMutableDictionary()
                var romance: NSMutableDictionary = NSMutableDictionary()
                var anotherRomance: NSMutableDictionary = NSMutableDictionary()
                var thriller: NSMutableDictionary = NSMutableDictionary()
                var anotherThriller: NSMutableDictionary = NSMutableDictionary()
                
                
                if language == "english" {
                    another = engFr["fr"] as! NSMutableDictionary
                    horror = engFrH["eng"] as! NSMutableDictionary
                    anotherHorror = engFrH["fr"] as! NSMutableDictionary
                    romance = engFrR["eng"] as! NSMutableDictionary
                    anotherRomance = engFrR["fr"] as! NSMutableDictionary
                    thriller = engFrT["eng"] as! NSMutableDictionary
                    anotherThriller = engFrT["fr"] as! NSMutableDictionary
                    
                } else if language == "french" {
                    another = engFr["eng"] as! NSMutableDictionary
                    horror = engFrH["fr"] as! NSMutableDictionary
                    anotherHorror = engFrH["eng"] as! NSMutableDictionary
                    romance = engFrR["fr"] as! NSMutableDictionary
                    anotherRomance = engFrR["eng"] as! NSMutableDictionary
                    thriller = engFrT["fr"] as! NSMutableDictionary
                    anotherThriller = engFrT["eng"] as! NSMutableDictionary
                    
                }
                
                let AnotherCount = another.allKeys.count
                let HorrorCount = horror.allKeys.count
                let AnotherHCount = anotherHorror.allKeys.count
                let RomanceCount = romance.allKeys.count
                let AnotherRCount = anotherRomance.allKeys.count
                let ThrillerCount = thriller.allKeys.count
                let AnotherTCount = anotherThriller.allKeys.count
                
                forAnotherLang.updateValue([], forKey: "featured")
                forAnotherLang.updateValue([], forKey: "horror")
                forAnotherLang.updateValue([], forKey: "romance")
                forAnotherLang.updateValue([], forKey: "thriller")
                
                horrorMenu = []
                romanceMenu = []
                thrillerMenu = []
                
                var checkHorror = 0
                var checkRomance = 0
                var checkThriller = 0
                
                for i in horror.allKeys as! [String] {
                    var serverHorror = horror[i] as! [AnyObject]
                    var episodes: [String] = []
                    if serverHorror.count == 8 {
                        episodes = serverHorror[7] as! [String]
                    }
                    self.makeGanre(ganre: "horror", name: serverHorror[0] as! String, storyDescription: serverHorror[1] as! String, author: serverHorror[2]as! String , releaseDate: serverHorror[3] as? String, status: serverHorror[4] as! String, image: serverHorror[6] as! String, serverGanre: serverHorror[5] as! String, episodes: episodes)
                    checkHorror += 1
                    if checkHorror == HorrorCount {compled = compled + 1
                        print("horror")
                    }
                }
                for i in romance.allKeys as! [String] {
                    
                    var serverRomance = romance[i] as! [AnyObject]
                    var episodes: [String] = []
                    if serverRomance.count == 8 {
                        episodes = serverRomance[7] as! [String]
                    }
                    self.makeGanre(ganre: "romance", name: serverRomance[0] as! String, storyDescription: serverRomance[1] as! String, author: serverRomance[2]as! String , releaseDate: serverRomance[3] as? String, status: serverRomance[4] as! String, image: serverRomance[6] as! String, serverGanre: serverRomance[5] as! String, episodes: episodes)
                    checkRomance += 1
                    if checkRomance == RomanceCount {compled = compled + 1
                        print("romance")
                    }
                }
                for i in thriller.allKeys as! [String] {
                    var serverThriller = thriller[i] as! [AnyObject]
                    var episodes: [String] = []
                    if serverThriller.count == 8 {
                        episodes = serverThriller[7] as! [String]
                    }
                    self.makeGanre(ganre: "thriller", name: serverThriller[0] as! String, storyDescription: serverThriller[1] as! String, author: serverThriller[2]as! String , releaseDate: serverThriller[3] as? String, status: serverThriller[4] as! String, image: serverThriller[6] as! String, serverGanre: serverThriller[5] as! String, episodes: episodes)
                    checkThriller += 1
                    if checkThriller == ThrillerCount {compled = compled + 1
                        print("thriller")
                    }
                }
                if compled == 5 {
                    completion(true)
                }
                
                for i in another.allKeys as! [String] {
                    var serverFeatured = another[i] as? [AnyObject]
                    var episodes: [String] = []
                    if serverFeatured?.count == 8 {
                        episodes = serverFeatured![7] as! [String]
                    }
                    let story = Story(name: serverFeatured![0] as! String, storyDescription: serverFeatured![1] as! String, author: serverFeatured![2]  as! String , releaseDate: serverFeatured![3] as? String, status: serverFeatured![4] as! String, genre: serverFeatured![5] as! String, image: serverFeatured![6] as! String, episodes: episodes)
                    forAnotherLang["featured"]?.append(story)
                    dictOfAllAnotherStories.updateValue(story, forKey: (serverFeatured![0] as! String).lowercased())
                }
                
                for i in anotherHorror.allKeys as! [String] {
                    var serverFeatured = anotherHorror[i] as? [AnyObject]
                    var episodes: [String] = []
                    if serverFeatured?.count == 8 {
                        episodes = serverFeatured![7] as! [String]
                    }
                    let story = Story(name: serverFeatured![0] as! String, storyDescription: serverFeatured![1] as! String, author: serverFeatured![2]  as! String , releaseDate: serverFeatured![3] as? String, status: serverFeatured![4] as! String, genre: serverFeatured![5] as! String, image: serverFeatured![6] as! String, episodes: episodes)
                    forAnotherLang["horror"]?.append(story)
                    dictOfAllAnotherStories.updateValue(story, forKey: (serverFeatured![0] as! String).lowercased())
                }
                
                for i in anotherRomance.allKeys as! [String] {
                    var serverFeatured = anotherRomance[i] as? [AnyObject]
                    var episodes: [String] = []
                    if serverFeatured?.count == 8 {
                        episodes = serverFeatured![7] as! [String]
                    }
                    let story = Story(name: serverFeatured![0] as! String, storyDescription: serverFeatured![1] as! String, author: serverFeatured![2]  as! String , releaseDate: serverFeatured![3] as? String, status: serverFeatured![4] as! String, genre: serverFeatured![5] as! String, image: serverFeatured![6] as! String, episodes: episodes)
                    forAnotherLang["romance"]?.append(story)
                    dictOfAllAnotherStories.updateValue(story, forKey: (serverFeatured![0] as! String).lowercased())
                }
                
                for i in anotherThriller.allKeys as! [String] {
                    var serverFeatured = anotherThriller[i] as? [AnyObject]
                    var episodes: [String] = []
                    if serverFeatured?.count == 8 {
                        episodes = serverFeatured![7] as! [String]
                    }
                    let story = Story(name: serverFeatured![0] as! String, storyDescription: serverFeatured![1] as! String, author: serverFeatured![2]  as! String , releaseDate: serverFeatured![3] as? String, status: serverFeatured![4] as! String, genre: serverFeatured![5] as! String, image: serverFeatured![6] as! String, episodes: episodes)
                    forAnotherLang["thriller"]?.append(story)
                    dictOfAllAnotherStories.updateValue(story, forKey: (serverFeatured![0] as! String).lowercased())
                }
                
                
            })
            
            self.ref.child("slider").observe(.value, with: { snapshot in
                let sliderArray = snapshot.value ?? "nil"  as AnyObject
                let slider = sliderArray as! [AnyObject]
                slideUrl = slider as! [[String]]
                var slidesForFrontend = [Story]()
                var checks = 0
                for i in 0 ..< slider.count {
                    var serverSlider = slider[i] as! [String]
                    
                    let commonMenu = horrorMenu + romanceMenu + thrillerMenu
                    for i in commonMenu {
                        if i.img.contains(serverSlider[0]) {
                            print(serverSlider)
                            slidesForFrontend.append(i)
                        }
                    }
                }
                

                    slidesArray = [Slider(slides: slidesForFrontend )]
                
                
                compled = compled + 1
                
                    
                //}
                print("complete \(compled)")
                print("success \(success)")
            })
            
            let ganres = [horrorMenu, romanceMenu, thrillerMenu]
            
            for i in ganres {
                for j in i {
                    dictOfProgress.updateValue(UserDefaults.standard.integer(forKey: "\(j.name.lowercased())"), forKey: j.name )
                    
                }
            }
        }
        
    }

    private func sortFeatured() {
        featuredMenu = featuredMenu.sorted(by: { (story1, story2) -> Bool in
            return story1.date > story2.date
        })
    }
    
    private func sortThriller() {
        thrillerMenu = thrillerMenu.sorted(by: { (story1, story2) -> Bool in
            return story1.date > story2.date
        })
    }
    
    private func sortRomance() {
        romanceMenu = romanceMenu.sorted(by: { (story1, story2) -> Bool in
            return story1.date > story2.date
        })
    }
    
    private func sortHorror() {
        horrorMenu = horrorMenu.sorted(by: { (story1, story2) -> Bool in
            return story1.date > story2.date
        })
        
    }
}

//MARK:- Extensions

extension StoryDatasource: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            var numberOfItems = featuredMenu.count
            if changeGenre == "horror" { numberOfItems = horrorMenu.count }
            else if changeGenre == "romance" { numberOfItems = romanceMenu.count }
            else if changeGenre == "thriller" { numberOfItems = thrillerMenu.count }
            else { numberOfItems = featuredMenu.count }
            return numberOfItems
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        


        var container: [Story]? = nil
        if changeGenre == "horror" { container = horrorMenu }
        else if changeGenre == "romance" { container = romanceMenu }
        else if changeGenre == "thriller" { container = thrillerMenu }
        else { container = featuredMenu }

        let storyCell = collectionView.dequeueReusableCell(withReuseIdentifier: "storyCell", for: indexPath) as! StoryCollectionViewCell
        
        storyCell.isLoading(false)
        storyCell.tag = indexPath.item
        

        
        let keyes = dictOfAllStories.keys
        let anotherKey = dictOfAllAnotherStories.keys

        for i in keyes {
            let j = dictOfAllStories[i]!
                dictOfProgress.updateValue(UserDefaults.standard.integer(forKey: "\(j.name.lowercased())"), forKey: j.name )
            
        }
        
        for i in anotherKey {
            let j = dictOfAllAnotherStories[i]!
            dictOfProgress.updateValue(UserDefaults.standard.integer(forKey: "\(j.name.lowercased())"), forKey: j.name )
        }

        if !dictOfViews.isEmpty {

            if dictOfViews.keys.contains(container![indexPath.item].name.lowercased()) {
                let storyName = container![indexPath.item].name.lowercased()
                let storyViews = dictOfViews[storyName]!["views"]!["num"]!
                if let storyRating = dictOfViews[storyName]!["rating"]?["num"] {
                    let numberFormatter = NumberFormatter()
                    numberFormatter.maximumFractionDigits = 1
                    let number = NSNumber(value: storyRating)
                    let ratingString = numberFormatter.string(from: number)
                    storyCell.rateLabel.text = ratingString
                } else {
                    storyCell.rateLabel.text = "8.9"
                }

                storyCell.viewsLabel.text = storyViews.formatPoints()

            }else{
                storyCell.viewsLabel.text = String(113)
            }
        }

        if changeGenre == "horror" { // HORROR

            let story = horrorMenu[indexPath.item]

            storyCell.storyImage.image = story.images
            storyCell.storyLabel.text = story.name.lowercased().capitalizingFirstLetter()
            
            if storyCell.storyImage.image == nil || storyCell.storyImage.image == #imageLiteral(resourceName: "nill") {
                storyCell.storyGradient.isHidden = true
            }else{
                storyCell.storyGradient.isHidden = false
            }

            return storyCell

        } else if changeGenre == "romance" { // ROMANCE
            
            let story = romanceMenu[indexPath.item]

            storyCell.storyImage.image = story.images
            storyCell.storyLabel.text = story.name.lowercased().capitalizingFirstLetter()
            
            if storyCell.storyImage.image == nil || storyCell.storyImage.image == #imageLiteral(resourceName: "nill") {
                storyCell.storyGradient.isHidden = true
            }else{
                storyCell.storyGradient.isHidden = false
            }

            return storyCell
        } else if changeGenre == "thriller" { // THRILLER

            let story = thrillerMenu[indexPath.item]

            storyCell.storyImage.image = story.images
            storyCell.storyLabel.text = story.name.lowercased().capitalizingFirstLetter()
            
            if storyCell.storyImage.image == nil || storyCell.storyImage.image == #imageLiteral(resourceName: "nill") {
                storyCell.storyGradient.isHidden = true
            }else{
                storyCell.storyGradient.isHidden = false
            }


            return storyCell
        } else { // FEATURED

            let story = featuredMenu[indexPath.item]

            storyCell.storyImage.image = story.images
            storyCell.storyLabel.text = story.name.lowercased().capitalizingFirstLetter()
            
            
            if storyCell.storyImage.image == nil || storyCell.storyImage.image == #imageLiteral(resourceName: "nill") {
                storyCell.storyGradient.isHidden = true
                
            }else{
                storyCell.storyGradient.isHidden = false
                
            }

            return storyCell
        }

    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionElementKindSectionHeader:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                             withReuseIdentifier: "headerView",
                                                                             for: indexPath) as! HeaderView
            headerView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: (UIScreen.main.bounds.width - 61) * 0.653 + 104)
            headerView.isEnglishLanguage = language == "english" ? true : false
            return headerView
        default:
            assert(false, "Unexpected element kind")
            // То, что ниже написали для архивации
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                             withReuseIdentifier: "headerView",
                                                                             for: indexPath) as! HeaderView
            return headerView
        }
    }
}

