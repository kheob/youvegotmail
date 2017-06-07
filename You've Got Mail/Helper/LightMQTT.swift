//
//  LightMQTT.swift
//

import Foundation

extension UInt16 {
    var lowByte: UInt8 {
        return UInt8(self & 0x00FF)
    }
    
    var highByte: UInt8 {
        return UInt8((self & 0xFF00) >> 8)
    }
}

enum MQTTMessage: UInt8 {
    case connect = 0x10
    case connack = 0x20
    case publish = 0x30
    case puback = 0x40
    case pubrec = 0x50
    case pubrel = 0x60
    case pubcomp = 0x70
    case subscribe = 0x80
    case suback = 0x90
    case unsubscribe = 0xa0
    case unsuback = 0xb0
    case pingreq = 0xc0
    case pingresp = 0xd0
    case disconnect = 0xe0
}

enum MQTTClientState {
    case connectionClosed
    case initializing
    case connected
    case decodingHeader
    case decodingLength
    case decodingData
    case connectionError
}

protocol LightMQTTDelegate: class {
    func didReceiveMessage(_ topic: String, message: String)
}

let MQTT_BUFFER_SIZE: Int = 4096

final class LightMQTT: NSObject, StreamDelegate {
    
    fileprivate var clientState = MQTTClientState.connectionClosed
    
    fileprivate var inputStream: InputStream?
    fileprivate var outputStream: OutputStream?
    
    fileprivate var readBuffer = [UInt8](repeating: 0, count: MQTT_BUFFER_SIZE)
    
    fileprivate var messageBuffer: [UInt8] = []
    
    fileprivate var messageLength = 0
    fileprivate var messageLengthMultiplier = 1
    
    fileprivate var topicLength: Int?
    
    fileprivate var messageId: UInt16 = 0
    
    fileprivate var keepAliveTimer: Timer!
    
    fileprivate var host: String
    fileprivate var port: Int
    
    weak var delegate: LightMQTTDelegate?
    
    var keepAliveInterval: UInt16 = 10
    
    init(host: String, port: Int) {
        self.host = host
        self.port = port
        
        super.init()
    }
    
    deinit {
        endKeepAliveTimer()
        
        mqttDisconnect()
        disconnectSocket()
    }
    
    // MARK: - Public interface
    
    func connect() {
        connectSocket(host, port: port)
        mqttConnect()
        
        startKeepAliveTimer()
    }
    
    func disconnect() {
        endKeepAliveTimer()
        
        mqttDisconnect()
        disconnectSocket()
    }
    
    func subscribe(_ topic: String) {
        mqttSubscribe(topic)
    }
    
    func unsubscribe(_ topic: String) {
        mqttUnsubscribe(topic)
    }
    
    // MARK: - MQTT messages
    
    /**
     * |--------------------------------------
     * | 7 6 5 4 |     3    |  2 1  | 0      |
     * |  Type   | DUP flag |  QoS  | RETAIN |
     * |--------------------------------------
     */
    
    fileprivate func mqttConnect() {
        let baseIntA = Int(arc4random() % 65535)
        let baseIntB = Int(arc4random() % 65535)
        let client = "client_" + String(format: "%04X%04X", baseIntA, baseIntB)
        
        /**
         * |----------------------------------------------------------------------------------
         * |     7    |    6     |      5     |  4   3  |     2    |       1      |     0    |
         * | username | password | willretain | willqos | willflag | cleansession | reserved |
         * |----------------------------------------------------------------------------------
         */
        
        let connectBytes: [UInt8] = [
            0x10,                               // FIXED BYTE 1   1 = CONNECT, 0 = DUP QoS RETAIN, not used in CONNECT
            UInt8(client.utf8.count + 12),      // FIXED BYTE 2   remaining length, client id length + 12
            0x00,                               // VARIA BYTE 1   length MSB
            0x04,                               // VARIA BYTE 2   length LSB is 4
            0x4d,                               // VARIA BYTE 3   M
            0x51,                               // VARIA BYTE 4   Q
            0x54,                               // VARIA BYTE 5   T
            0x54,                               // VARIA BYTE 6   T
            0x04,                               // VARIA BYTE 7   Version = 4
            0x02,                               // VARIA BYTE 8   Username Password RETAIN QoS Will Clean flags
            keepAliveInterval.highByte,         // VARIA BYTE 9   Keep Alive MSB
            keepAliveInterval.lowByte,          // VARIA BYTE 10  Keep Alive LSB
            UInt16(client.utf8.count).highByte, // VARIA BYTE 11  client id length MSB
            UInt16(client.utf8.count).lowByte   // VARIA BYTE 12  client id length LSB
        ]
        
        let messageBytes = connectBytes + [UInt8](client.utf8)
        outputStream?.write(messageBytes, maxLength: messageBytes.count)
        
        clientState = MQTTClientState.initializing
    }
    
    fileprivate func mqttSubscribe(_ topic: String) {
        messageId += 1
        
        let subscribeBytes: [UInt8] = [
            0x82,                               // FIXED BYTE 1   8 = SUBSCRIBE, 2 = DUP QoS RETAIN
            UInt8(topic.utf8.count + 5),        // FIXED BYTE 2   remaining length, msg id + topic length + topic
            messageId.highByte,                 // VARIA BYTE 1   message id MSB
            messageId.lowByte,                  // VARIA BYTE 2   message id LSB
            UInt16(topic.utf8.count).highByte,  // VARIA BYTE 3   topic length MSB
            UInt16(topic.utf8.count).lowByte    // VARIA BYTE 4   topic length LSB
        ]
        
        let requestedQosByte: [UInt8] = [
            0x00                                // Requested QoS
        ]
        
        let messageBytes = subscribeBytes + [UInt8](topic.utf8) + requestedQosByte
        outputStream?.write(messageBytes, maxLength: messageBytes.count)
    }
    
    fileprivate func mqttUnsubscribe(_ topic: String) {
        messageId += 1
        
        let unsubscribeBytes: [UInt8] = [
            0xa2,                               // FIXED BYTE 1   a = UNSUBSCRIBE, 2 = DUP QoS RETAIN
            UInt8(topic.utf8.count + 4),        // FIXED BYTE 2   remaining length, topic id length + 4
            messageId.highByte,                 // VARIA BYTE 1   message id MSB
            messageId.lowByte,                  // VARIA BYTE 2   message id LSB
            UInt16(topic.utf8.count).highByte,  // VARIA BYTE 3   topic length MSB
            UInt16(topic.utf8.count).lowByte    // VARIA BYTE 4   topic length LSB
        ]
        
        let messageBytes = unsubscribeBytes + [UInt8](topic.utf8)
        outputStream?.write(messageBytes, maxLength: messageBytes.count)
    }
    
    dynamic fileprivate func mqttPing() {
        let messageBytes: [UInt8] = [
            0xc0,                               // FIXED BYTE 1   c = PINGREQ, 0 = DUP QoS RETAIN (not used)
            0x00                                // FIXED BYTE 2   remaining length = 0
        ]
        
        outputStream?.write(messageBytes, maxLength: messageBytes.count)
    }
    
    fileprivate func mqttDisconnect() {
        let messageBytes: [UInt8] = [
            0xe0,                               // FIXED BYTE 1   e = DISCONNECT, 0 = DUP QoS RETAIN (not used)
            0x00                                // FIXED BYTE 2   remaining length = 0
        ]
        
        outputStream?.write(messageBytes, maxLength: messageBytes.count)
        
        clientState = MQTTClientState.connectionClosed
    }
    
    // MARK: - Keep alive timer
    
    fileprivate func startKeepAliveTimer() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(
            timeInterval: Double(keepAliveInterval) / 2.0,
            target: self,
            selector: #selector(self.mqttPing),
            userInfo: nil,
            repeats: true)
    }
    
    fileprivate func endKeepAliveTimer() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }
    
    // MARK: - Socket connection
    
    fileprivate func connectSocket(_ host: String, port: Int) -> Bool {
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        
        if inputStream == nil || outputStream == nil { return false }
        
        inputStream?.delegate = self
        outputStream?.delegate = self
        
        inputStream?.open()
        outputStream?.open()
        
        inputStream?.schedule(in: .main, forMode: RunLoopMode.defaultRunLoopMode)
        outputStream?.schedule(in: .main, forMode: RunLoopMode.defaultRunLoopMode)
        
        return true
    }
    
    fileprivate func disconnectSocket() {
        inputStream?.remove(from: .main, forMode: RunLoopMode.defaultRunLoopMode)
        outputStream?.remove(from: .main, forMode: RunLoopMode.defaultRunLoopMode)
        
        inputStream?.close()
        outputStream?.close()
        
        inputStream?.delegate = nil
        outputStream?.delegate = nil
        
        inputStream = nil;
        outputStream = nil;
    }
    
    // MARK: - Stream delegate
    
    dynamic internal func stream(_ stream: Stream, handle eventCode: Stream.Event) {
        switch stream {
        case inputStream!:
            switch (eventCode) {
            case Stream.Event.hasBytesAvailable:
                
                if clientState == .decodingHeader {
                    
                    let count = inputStream!.read(&readBuffer, maxLength: 1)
                    
                    if count > 0 {
                        if let message = MQTTMessage(rawValue: readBuffer[0] & 0xf0) {
                            switch message {
                            case .connack:
                                break
                            case .suback:
                                break
                            case .disconnect:
                                clientState = .connectionClosed
                            case .publish:
                                clientState = .decodingLength
                            default:
                                break
                            }
                        }
                        
                    } else {
                        clientState = .connectionError
                    }
                }
                
                while clientState == .decodingLength {
                    
                    let count = inputStream!.read(&readBuffer, maxLength: 1)
                    
                    if count == 0 {
                        break
                    } else if count == -1 {
                        clientState = .connectionError
                    }
                    
                    messageLength += Int(readBuffer[0] & 127) * messageLengthMultiplier
                    if readBuffer[0] & 128 == 0x00 {
                        clientState = .decodingData
                    } else {
                        messageLengthMultiplier *= 128
                    }
                    
                }
                
                if clientState == .decodingData {
                    
                    var bytesToRead = messageLength - messageBuffer.count
                    if bytesToRead > readBuffer.count {
                        bytesToRead = readBuffer.count
                    }
                    
                    let count = inputStream!.read(&readBuffer, maxLength: bytesToRead)
                    
                    if count == -1 {
                        clientState = .connectionError
                    } else {
                        messageBuffer += readBuffer[0 ..< count]
                    }
                    
                    if messageBuffer.count == messageLength {
                        parseMessage()
                        
                        messageBuffer = []
                        messageLength = 0
                        messageLengthMultiplier = 1
                        
                        clientState = MQTTClientState.decodingHeader
                    }
                }
                
                
            case Stream.Event.openCompleted:
                clientState = MQTTClientState.decodingHeader
            case Stream.Event.errorOccurred:
                clientState = MQTTClientState.connectionError
            case Stream.Event.endEncountered:
                clientState = MQTTClientState.connectionClosed
            case Stream.Event():
                break
            default:
                break
            }
            
        default:
            break
        }
    }
    
    // MARK: - Message parsing
    
    fileprivate func parseMessage() {
        let topicLengthMSB = messageBuffer[0]
        let topicLengthLSB = messageBuffer[1]
        
        let topicLength = Int(topicLengthMSB) * 256 + Int(topicLengthLSB)
        
        let topic = String(bytes: messageBuffer[2 ..< topicLength + 2], encoding: String.Encoding.utf8)
        let message = String(bytes: messageBuffer[topicLength + 2 ..< messageBuffer.count], encoding: String.Encoding.utf8)
        
        if let topic = topic, let message = message {
            delegate?.didReceiveMessage(topic, message: message)
        }
    }
}
