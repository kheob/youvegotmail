//
//  CameraViewController.swift
//  You've Got Mail
//
//  Created by Qingzhou Wang on 24/10/2016.
//  Copyright © 2016 Qingzhou Wang. All rights reserved.
//

import UIKit

class CameraViewController: UIViewController {

    @IBOutlet weak var image: MJPEGImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        navigationItem.title = "Camera"
        
        // Start the stream video
        if let url = URL(string: "http://\(host):3000/stream?start=true")
        {
            let task = URLSession.shared.dataTask(with: url)
            task.resume()
        }
        
        // Check the stream video status, if it's online then connect to server, otherwise show an alert about the error message
        if let url = URL(string: "http://\(host):3000/stream/status")
        {
            let task = URLSession.shared.dataTask(with: url, completionHandler: {
                (data, response, error) in
                self.checkServerStatus(data!)
            })            

            task.resume()
        }
    }
    
    func checkServerStatus(_ data: Data)
    {
        do
        {
            // First step, convert the web source from JSON format to NSDictionary.
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as! NSDictionary
            // Then retrieve "photos" object from root.
            let message = json["message"] as! String
            
            if message == "Stream online."
            {
                if let streamUrl = URL(string: "http://\(host):8090/?action=stream")
                {
                    // Source from https://github.com/ugoArangino/MJPEG-Framework
                    // Connect to the server and load stream video
                    DispatchQueue.main.async(execute: {
                        let connectionData = ConnectionData(URL: streamUrl)
                        self.image.setupMJPEGConnection(connectionData)
                        self.image.startConnection()
                    })
                }
            }
            else
            {
                ShowSimpleAlert("Error", message: "Stream video is offline. Please check the server.")
            }
        }
        catch let error
        {
            print(error)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Stop the video after the view disappear
        if let url = URL(string: "http://\(host):3000/stream?start=false")
        {
            let task = URLSession.shared.dataTask(with: url)
            task.resume()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Shows a simple alert
    func ShowSimpleAlert(_ title: String, message: String) {
        let alertController: UIAlertController = {
            let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
            return controller
        }()
        self.present(alertController, animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
