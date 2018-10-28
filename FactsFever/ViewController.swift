//
//  ViewController.swift
//  FactsFever
//
//  Created by Gauri Bhagwat on 09/10/18.
//  Copyright © 2018 Development. All rights reserved.
//

import UIKit
import Foundation
import MobileCoreServices
import Firebase
import FirebaseStorage
import FirebaseDatabase
import SDWebImage
import ProgressHUD
import IDMPhotoBrowser
import ChameleonFramework

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    //MARK: Outlets
    
    @IBOutlet weak var uploadButtonOutlet: UIBarButtonItem!
    @IBOutlet weak var collectionView: UICollectionView!
    
    //MARK:- Properties
    
    var images: [UIImage] = []
    var factsArray:[Facts] = [Facts]()
    var reverUrl:[String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
//        retriveDataFromDataBase()
        observeFactsFromFirebase()
        self.view.addSubview(refreshControl)
        self.view.backgroundColor = UIColor.randomFlat()
//        if let btn = self.navigationItem.rightBarButtonItem {
//            btn.isEnabled = false
//            btn.tintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
//            btn.title = ""
//        }
        ProgressHUD.show("Welcome To FactsFever, Loading Facts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            ProgressHUD.dismiss()
        }
        
       
    }


    

    //MARK:- Upload Facts
    
    @IBAction func uploadButtonPressed(_ sender: Any) {
        selectPhoto()
    }
    // Pull To refresh
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action:
            #selector(self.handleRefresh(_:)),
                                 for: UIControl.Event.valueChanged)
        refreshControl.tintColor = #colorLiteral(red: 1, green: 0.8508075984, blue: 0.02254329405, alpha: 1)
        
        return refreshControl
    }()
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        
        self.collectionView.reloadData()
        refreshControl.endRefreshing()
    }
    // Image Picker View
    func selectPhoto(){
        uploadButtonOutlet.isEnabled = false
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = false
        picker.mediaTypes = [kUTTypeImage] as [String]
        present(picker, animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        var selectedImageFromPicker : UIImage?
        if let editedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage{
           print("Edited Image Size\(editedImage.size)")
            selectedImageFromPicker = editedImage
        }
        else if let orginalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            print("Size \(orginalImage.size)")
            selectedImageFromPicker = orginalImage
        
        }
        
        if let selectedImage = selectedImageFromPicker {
            uploadImageToFirebaseStorage(image: selectedImage) { (imageUrl) in
                print("Image Url\(imageUrl)")
                print("Image uploaded successfully ")
//                self.factLink.append(imageUrl)
                self.addToDatabase(imageUrl: imageUrl)
            }
        }
        
        dismiss(animated: true, completion: nil)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    private func uploadImageToFirebaseStorage(image: UIImage, completion: @escaping (_ imageUrl: String) -> ()){
        let imageName = NSUUID().uuidString + ".jpg"
        let ref = Storage.storage().reference().child("message_images").child(imageName)
        
        if let uploadData = image.jpegData(compressionQuality: 0.2){
            ref.putData(uploadData, metadata: nil, completion: { (metadata, error) in
                if error != nil {
                    print(" Failed to upload Image", error)
                }
                ref.downloadURL(completion: { (url, err) in
                    if let err = err {
                        print("Unable to upload image into storage due to \(err)")
                    }
                    let messageImageURL = url?.absoluteString
                    completion(messageImageURL!)
                    
                })
                
            })
        }
    }
    
    func addToDatabase(imageUrl:String){
        let Id = NSUUID().uuidString
        let factsDB = Database.database().reference().child("Facts")
        let factsDictionary = ["factsLink": imageUrl, "likes": 0, "factsId": Id] as [String : Any]
        factsDB.child(Id).setValue(factsDictionary){
            (error, reference) in
            
            if error != nil {
                print(error)
                ProgressHUD.showError("Image Upload Failed")
                self.uploadButtonOutlet.isEnabled = true
                return
                
            } else{
                print("Message Saved In DB")
                ProgressHUD.showSuccess("image Uploded Successfully")
                self.uploadButtonOutlet.isEnabled = true
//                self.retriveDataFromDataBase()
                self.observeFactsFromFirebase()
            }
        }
    }
    
    func retriveDataFromDataBase(){
       
        let messageDB = Database.database().reference().child("Facts")
        messageDB.observe(.childAdded) { (snapshot) in
            let snapshotValue = snapshot.value as! [String: AnyObject]
            print("snapshotvalue \(snapshotValue)")
            let messageLink =  snapshotValue["factsLink"] as! String
            let messageId = snapshotValue["factsId"] as! String
            let messageLike = snapshotValue["likes"] as! Int
            
            let fact = Facts(dictionary: snapshotValue as [String : AnyObject])
            self.factsArray.insert(fact, at: 0)
            
            self.downloadImage(imageUrl: messageLink, completion: { (uiImage) in
                guard let uiImage = uiImage else {return}
                if self.images.contains(uiImage) {

                }else{
                   self.images.append(uiImage)
                }

            })
            
            }
            
            self.collectionView.reloadData()
            
        
        
    }
    var imageUrl: [String] = []
    func observeFactsFromFirebase(){
        
        let factsDB = Database.database().reference().child("Facts")
        factsDB.observe(.value) { (snapshot) in
            print("Observer Data snapshot \(snapshot.value)")
            
            self.factsArray = []
            self.imageUrl = []
            
            if let snapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for snap in snapshot {
                    
                    if let postDictionary = snap.value as? Dictionary<String, AnyObject> {
                        let id = snap.key
                        let facts = Facts(dictionary: postDictionary)
                        self.factsArray.insert(facts, at: 0)
                        self.imageUrl.insert(facts.factsLink, at: 0)
                        
                    }
                }
            }
            self.collectionView.reloadData()
  
        }
    }
    // Download Image From Database

    func downloadImage(imageUrl: String,  completion: @escaping(_ image: UIImage?) -> Void) {
     
        let imageURL = NSURL(string: imageUrl)

        let imageFileName = (imageUrl.components(separatedBy: "%").last!).components(separatedBy: "?").first!


        if fileExistAtPath(path: imageFileName) {
            if let contentsOfFile = UIImage(contentsOfFile: fileInDocumentsDirectory(fileName: imageFileName)) {
                completion(contentsOfFile)
                ProgressHUD.dismiss()
            } else {
                print("could not generate image")
                completion(nil)
                
            }
        } else {
            let downloadQueue = DispatchQueue(label: "imageDownloadQueue")

            downloadQueue.async {

                let fetchedData = try? Data(contentsOf: imageURL! as URL)
                if fetchedData != nil {

                    var docURL = self.getDocumentsURL()
                    docURL = docURL.appendingPathComponent(imageFileName, isDirectory: false)

                    let imageToReturn = UIImage(data: fetchedData!)!
                    DispatchQueue.main.async {
                        completion(imageToReturn)
                    }
                }else {
                    DispatchQueue.main.async {
                        print("no image in database")
                        completion(nil)
                    }

                }
            }
        }
      

    }
    
    func fileInDocumentsDirectory(fileName: String) -> String {
        let fileURL = getDocumentsURL().appendingPathComponent(fileName)
        
        return fileURL.path
    }
    
    func getDocumentsURL() -> URL {
        let decumentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
        return decumentURL!
    }
    
    func fileExistAtPath(path: String) -> Bool {
        
        var doesExist = false
        
        let filePath = fileInDocumentsDirectory(fileName: path)
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: filePath) {
            doesExist = true
        } else {
            doesExist = false
        }
        
        return doesExist
    }
    let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
    
    
   
    
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //MARK: Data Source
extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
       return factsArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as! PhotoCell
        
        
        cell.imageView.layer.cornerRadius = 20
        cell.imageView.layer.masksToBounds = true
        cell.imageView.layer.shouldRasterize = true
        cell.imageView.backgroundColor = UIColor.clear
        cell.imageView.sd_showActivityIndicatorView()
        cell.imageView.sd_setIndicatorStyle(.gray)
        
        cell.imageView.sd_setImage(with: URL(string: factsArray[indexPath.row].factsLink))
        
        return cell
    }
    
  
}
extension ViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let photos = IDMPhoto.photos(withURLs: imageUrl)
        let browser = IDMPhotoBrowser(photos: photos)
        browser?.setInitialPageIndex(UInt(indexPath.row))
        self.present(browser!, animated: true, completion: nil)
    }
}

