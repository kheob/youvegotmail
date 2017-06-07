//
//  HistoryViewController.swift
//  You've Got Mail
//
//  Created by Qingzhou Wang on 24/10/2016.
//  Copyright © 2016 Qingzhou Wang. All rights reserved.
//

import UIKit

class HistoryViewController: UIViewController {

    @IBOutlet weak var image: UIImageView!
    var imageToDisplay: UIImage!
    var time: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        image.image = imageToDisplay
        navigationItem.title = time
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
