//
//  HistoryCollectionViewController.swift
//  You've Got Mail
//
//  Created by Qingzhou Wang on 24/10/2016.
//  Copyright © 2016 Qingzhou Wang. All rights reserved.
//

import UIKit

private let reuseIdentifier = "Cell"

class HistoryCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    var allPhotos: [Photo] = []
    var allPhotosOnServer: [NSDictionary] = []
    let refreshControl = UIRefreshControl()
    
    var photoDataBuffer: Data!
    var minPhotoIndex = 0
    var maxPhotoIndex = 18
    
    var loadingData = false
    
    struct Photo {
        var date: String
        var location: String
        var imageData: Data?
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
//        self.collectionView!.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Do any additional setup after loading the view.
        
        downloadAllPhotos()
        
        // Add a refresh control to collection view.
        collectionView?.alwaysBounceVertical = true
        refreshControl.tintColor = UIColor.gray
        refreshControl.addTarget(self, action: #selector(self.refreshView), for: .valueChanged)
        
        DispatchQueue.main.async {
            SwiftSpinner.show("Loading photos").addTapHandler ({
                SwiftSpinner.hide()
            })
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        return allPhotos.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! HistoryCell
    
        // Configure the cell
        cell.photo.frame = cell.bounds
        if !refreshControl.isRefreshing && allPhotos[indexPath.row].imageData != nil
        {
            cell.photo.image = UIImage(data: allPhotos[indexPath.row].imageData!)
        }
        
        return cell
    }
    
    // Resize each item based on different screen size, to display 3 photos in a row.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let paddingSpace = 5 * (3 + 1)
        let cellWidth = view.frame.width - CGFloat(paddingSpace)
        let width = cellWidth / 3
        let newSize = CGSize(width: width, height: width)
        return newSize
    }
    
    // Display large photo and time for selected item in the collection view.
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let vc = storyboard!.instantiateViewController(withIdentifier: "SelectedHistoryImageController") as! HistoryViewController
        let cell = collectionView.cellForItem(at: indexPath) as! HistoryCell
        vc.imageToDisplay = cell.photo.image
        vc.time = allPhotos[indexPath.item].date
        show(vc, sender: nil)
    }
    
    // Load more photos when user scroll the view to bottom
    override func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if allPhotos.count != 0 && allPhotos.count < allPhotosOnServer.count
        {
            loadMorePhotos()
        }
    }
    
    // Display an activity indicator at the bottom of the view.
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        var footerView: LoadMoreCollectionReusableView!
        
        if kind == UICollectionElementKindSectionFooter
        {
            footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "LoadMoreResuableView", for: indexPath) as! LoadMoreCollectionReusableView
            footerView.actifityIndicator.isHidden = allPhotos.count == allPhotosOnServer.count
        }
        
        return footerView
    }
    
    // Download all photos from server, then load each photo's location.
    func downloadAllPhotos()
    {
        if let url = URL(string: "http://\(host):3000/photos/")
        {
            let task = URLSession.shared.dataTask(with: url, completionHandler: {
                (data, response, error) in
                if (error != nil)
                {
                    print(error)
                }
                else
                {
                    self.allPhotos.removeAll()
                    self.photoDataBuffer = data!
                    self.parsePhotoUrl()
                }
            })            

            task.resume()
        }
    }
    
    // Store photos' location into array.
    func parsePhotoUrl()
    {
        do
        {
            // First step, convert the web source from JSON format to NSDictionary.
            let json = try JSONSerialization.jsonObject(with: photoDataBuffer, options: .mutableContainers) as! NSDictionary
            // Then retrieve "photos" object from root.
            let photosAscending = json["photos"] as! [NSDictionary]
            // Reverse the array to get latest photo at first
            allPhotosOnServer = photosAscending.reversed()
            if allPhotosOnServer.count != 0
            {
                let dateformatter = DateFormatter()
                dateformatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                let formatterForClient = DateFormatter()
                formatterForClient.dateFormat = "dd/MM/yy HH:mm:ss"
                formatterForClient.locale = Locale.current
                
                // Add photos into all photos array for a particular range.
                for index in minPhotoIndex ..< maxPhotoIndex
                {
                    if index < allPhotosOnServer.count
                    {
                        let item = allPhotosOnServer[index]
                        let location = item["location"] as! String
                        let dateOnServer = dateformatter.date(from: item["date"] as! String)!
                        let dateOnClient = formatterForClient.string(from: dateOnServer)
                        if let url = URL(string: "http://\(host):3000\(location)")
                        {
                            allPhotos.append(Photo(date: dateOnClient, location: "\(host):3000\(location)", imageData: try? Data(contentsOf: url)))
                        }
                    }
                }
                
                // Call the table to reload data from main thread. If not called in the main thread reload will not work
                DispatchQueue.main.async(execute: {
                    self.refreshControl.endRefreshing()
                    self.collectionView?.reloadData()
                    SwiftSpinner.hide()
                })
                
                if !collectionView!.subviews.contains(refreshControl)
                {
                    collectionView?.addSubview(refreshControl)
                }
                loadingData = false
            }
            else
            {
                DispatchQueue.main.async(execute: { 
                    SwiftSpinner.show("Error: There's no photo on the server", animated: false).addTapHandler({
                        SwiftSpinner.hide()
                    })
                })
            }
        }
        catch
        {
            print("Error when parse data")
        }
    }
    
    // Refresh the entire collection view
    func refreshView()
    {
        if !loadingData
        {
            minPhotoIndex = 0
            maxPhotoIndex = 18
            downloadAllPhotos()
        }
        else
        {
            refreshControl.endRefreshing()
        }
    }
    
    // Load more photos when scroll down
    func loadMorePhotos()
    {
        if !loadingData && !refreshControl.isRefreshing
        {
            loadingData = true
            minPhotoIndex += 18
            maxPhotoIndex += 18
            let qualityOfServiceClass = DispatchQoS.QoSClass.background
            let backgroundQueue = DispatchQueue.global(qos: qualityOfServiceClass)
            backgroundQueue.async(execute: {
                self.parsePhotoUrl()
                
                DispatchQueue.main.async(execute: { () -> Void in
                    self.collectionView?.reloadData()
                })
            })
        }
    }
    
    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(collectionView: UICollectionView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(collectionView: UICollectionView, shouldShowMenuForItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func collectionView(collectionView: UICollectionView, canPerformAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) -> Bool {
        return false
    }

    override func collectionView(collectionView: UICollectionView, performAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) {
    
    }
    */

}
