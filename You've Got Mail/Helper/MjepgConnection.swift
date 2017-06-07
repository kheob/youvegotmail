//
//  MjepgConnection.swift
//  ip-camera-viewer
//
//  Created by Ugo Arangino on 12.03.15.
//  Copyright (c) 2015 Ugo Arangino. All rights reserved.
//

import Foundation

/**
    MJPEG Connection is a NSURLConnection subclass that takes an url, username and password
*/
open class MJPEGConnection {
    
    fileprivate var connection: URLConnection
    fileprivate var connectionData: ConnectionData
    fileprivate var request: URLRequest
    fileprivate var connectionDataDelegate: URLConnectionDataDelegate
    fileprivate var connectionDelegate: URLConnectionDelegate
    fileprivate var isConnectionSetup = false
    
    
    public init(connectionData: ConnectionData, delegate: URLConnectionDelegate) {
        self.connectionData = connectionData
        self.connectionDelegate = delegate
        
        self.request = URLRequest(url: connectionData.URL as URL)
        self.connectionDataDelegate = URLConnectionDataDelegate(connectionData: connectionData)
        self.connection = URLConnection()
    }
    
    fileprivate func createURLConnection() -> URLConnection? {
        return URLConnection(request: self.request, delegate: self.connectionDataDelegate)
    }
    
    fileprivate func setupConnection() {
        if let connection = createURLConnection() {
            self.connection = connection
            self.connection.delegate = connectionDelegate
            connectionDataDelegate.connection = self.connection
            
            isConnectionSetup = true
        } else {
            print("cant create connection")
        }
    }
    
    open func startConnection() {
        // setupConnection if needed
        if !isConnectionSetup {
            setupConnection()
        }
        connection.start()
    }
    
    open func stopConnection() {
        connection.cancel()
        // reset isConnectionSetup status
        isConnectionSetup = false
    }
    
    open func restartConnection() {
        stopConnection()
        startConnection()
    }
    
}
