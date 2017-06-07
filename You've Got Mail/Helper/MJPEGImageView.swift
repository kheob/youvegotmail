//
//  MJPEGImage.swift
//  MJPEG
//
//  Created by Ugo Arangino on 15.03.15.
//  Copyright (c) 2015 Ugo Arangino. All rights reserved.
//

import UIKit

/**
    MJPEGImageView is a UIImageView subclass that has a MJPEGConnection and updates the image
*/
open class MJPEGImageView: UIImageView, URLConnectionDelegate {
    
    fileprivate var mjpegConnection: MJPEGConnection?

    open func setupMJPEGConnection(_ connectionData: ConnectionData) {
        mjpegConnection = MJPEGConnection(connectionData: connectionData, delegate: self)
    }
    
    open func startConnection() {
        mjpegConnection?.startConnection()
    }
    
    open func stopConnection() {
        mjpegConnection?.stopConnection()
    }
    
    open func restartConnection() {
        mjpegConnection?.restartConnection()
    }
    
    
    // MARK: - URLConnectionDelegate
    
    /**
    Override image with data from the MJPEGConnection
    
    :param: data ImageData
    */
    open func responseDidFinisch(_ data: Data) {
        if let mjpegImage = UIImage(data: data) {
            image = mjpegImage
        }
    }
    
}
