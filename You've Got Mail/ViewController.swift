//
//  ViewController.swift
//  You've Got Mail
//
//  Created by Qingzhou Wang on 24/10/2016.
//  Copyright © 2016 Qingzhou Wang. All rights reserved.
//

import UIKit
import Instructions

var host = "144.138.51.105"
let mqttClient = LightMQTT(host: host, port: 1883)

class ViewController: UIViewController, LightMQTTDelegate, CoachMarksControllerDataSource, CoachMarksControllerDelegate {

    @IBOutlet weak var mailboxView: UIView!
    @IBOutlet weak var historyView: UIView!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var circle: KDCircularProgress!
    @IBOutlet weak var percentageLabel: UILabel!
    @IBOutlet weak var checkTodayBtn: UIButton!
    @IBOutlet weak var checkHistoryBtn: UIButton!
    @IBOutlet weak var cameraBtn: UIBarButtonItem!
    
    // Use Coach Mark package to display instructions for the app
    let coachMarksController = CoachMarksController()
    lazy var pointOfInterest = [UIView?](repeating: nil, count: 4)
    let hintText = ["Click here to open stream camera.", "This area shows current mailbox status.", "View all photos taken by the camera for Today.", "View all historical photos taken by the camera."]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
//        let gesture = UITapGestureRecognizer(target: self, action: #selector(self.showVideo))
//        image.addGestureRecognizer(gesture)
        
        navigationItem.title = "Home"
        circle.angle = 0
        percentageLabel.text = "0%"
        setUIViewInterface(mailboxView)
        setUIViewInterface(historyView)
        
        connectToServer()
        
        self.coachMarksController.dataSource = self
        self.coachMarksController.allowOverlayTap = true
//        pointOfInterest[0] = image
        pointOfInterest[0] = cameraBtn.value(forKey: "view") as? UIView
        pointOfInterest[1] = circle
        pointOfInterest[2] = checkTodayBtn
        pointOfInterest[3] = checkHistoryBtn
        
//        // Set skip view for tutorial
//        let skipView = CoachMarkSkipDefaultView()
//        skipView.setTitle("Skip", forState: .Normal)
//        
//        self.coachMarksController.skipView = skipView
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        connectToServer()
        
        // Display the instruction if it's the first time launch the app
        if !UserDefaults.standard.bool(forKey: "everLaunched")
        {
            UserDefaults.standard.set(true, forKey: "everLaunched")
            self.coachMarksController.startOn(self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // The flow should always be stopped once the view disappear.
        self.coachMarksController.stop(immediately: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func openStream(_ sender: AnyObject) {
        showVideo()
    }
    
    func setUIViewInterface(_ view: UIView) {
        let maskPath = UIBezierPath(roundedRect: view.bounds,byRoundingCorners: [.topLeft, .topRight, .bottomLeft, .bottomRight], cornerRadii: CGSize(width: 10.0, height: 10.0))
        let maskLayer = CAShapeLayer(layer: maskPath)
        maskLayer.frame = view.bounds
        maskLayer.path = maskPath.cgPath
        view.layer.mask = maskLayer
    }
    
    func connectToServer()
    {
        // Subscribe to MQTT topics
        mqttClient.delegate = self
        mqttClient.connect()
        mqttClient.subscribe("/mailbox")
    }
    
    // Change circle's angel and percentage after receive any message from MQTT server.
    func didReceiveMessage(_ topic: String, message: String) {
        if topic == "/mailbox"
        {
            setAngel(percentage: Int(message)!)
        }
    }

    // Display stream video controller
    func showVideo()
    {
        let vc = storyboard!.instantiateViewController(withIdentifier: "LiveVideoController")
        show(vc, sender: nil)
    }
    
    // Calculate the circle's angel and display percentage in the middle.
    func setAngel(percentage: Int)
    {
        let newAngel = Double(percentage) / 100 * 360
        
        circle.animateFromAngle(circle.angle, toAngle: Int(newAngel), duration: 0.5, completion: nil)
        percentageLabel.text = "\(percentage)%"
    }
    
    // Converts a JSON string to a dictionary object
    // Source: http://stackoverflow.com/a/30480777/6601606
    func convertStringToDictionary(_ text: String) -> NSDictionary? {
        if let data = text.data(using: String.Encoding.utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary
            } catch let error as NSError {
                print(error)
            }
        }
        return nil
    }
    
    // Mandatory function from coach marks, return number of coach marks to display
    func numberOfCoachMarksForCoachMarksController(_ coachMarksController: CoachMarksController) -> Int {
        return 4
    }
    
    // Customize how a coach mark will position and appear.
    func coachMarksController(_ coachMarksController: CoachMarksController, coachMarksForIndex index: Int) -> CoachMark {
        return coachMarksController.coachMarkForView(self.pointOfInterest[index])
    }
    
    // The third one supplies two views (much like cellForRowAtIndexPath) in the form a Tuple. The body view is mandatory, as it's the core of the coach mark. The arrow view is optional.
    func coachMarksController(_ coachMarksController: CoachMarksController, coachMarkViewsForIndex index: Int, coachMark: CoachMark) -> (bodyView: CoachMarkBodyView, arrowView: CoachMarkArrowView?) {
        
        let coachViews = coachMarksController.defaultCoachViewsWithArrow(true, arrowOrientation: coachMark.arrowOrientation, hintText: hintText[index], nextText: nil)
        
        return (coachViews.bodyView, coachViews.arrowView)
    }

    
//    // Change the server with an alert asking for the new server address
//    // Adapted from: http://stackoverflow.com/a/26567485/6601606
//    @IBAction func changeServer(sender: AnyObject) {
//        let alert = UIAlertController(title: "Change Server", message: "Please enter the IP address of the new server", preferredStyle: .Alert)
//        
//        alert.addTextFieldWithConfigurationHandler { (textField) in
//            textField.text = ""
//        }
//        
//        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (_) in
//            let textField = alert.textFields![0]
//            host = textField.text!
//        }))
//        
//        alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
//        
//        self.presentViewController(alert, animated: true, completion: { Void in
//            self.connectToServer()
//        })
//    }

}

