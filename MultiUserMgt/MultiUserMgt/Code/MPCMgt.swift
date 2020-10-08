//
//  MPCMgt.swift
//  MultiUserMgt
//
//  Created by JB on 29/08/2020.
//  Copyright © 2020 IndianaDev. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import SceneKit
import ARKit

class MPCSessionClass: NSObject, MCSessionDelegate, StreamDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate
{
        // Propriérés MCP
    let ServiceType = "Test"
    
    var DataToSend: Dictionary<String, Any> = [:]
    var PeerID: MCPeerID!
    var MPCSession: MCSession!
    var ServiceAdvertiser: MCNearbyServiceAdvertiser!
    var ServiceBrowser: MCNearbyServiceBrowser!
    var OutStream: OutputStream!
    var InStream: InputStream!
    var Compteur: Int = 0
    
    var VCRef: GameViewController!

        // Data sending either via stream or direct
    func MPCSendData(DataToSend: Dictionary<String, Any>, ViaStream: Bool = false)
    {
        var DataFilledToSend = DataToSend
        var DataConverted = try! NSKeyedArchiver.archivedData(withRootObject: DataFilledToSend, requiringSecureCoding: true)
        var TailleData: Int = 0
        var NewTailleData: Int = 0

        if ViaStream
        {
                // On remplit le paquet de data jusqu'à kSizeDataPack pour n'envoyer que des paquets de taille identiques sinon on en perd à l'arrivée
                // Plus la taille de kSizeDataPack est grande pire est le problème de saccade
                // Est-il possible d'envoyer des paquets de taille variable ?
                // A optimiser pour éviter 2 filling successifs car exécuté depuis la boucle renderer côté Master
            Compteur = Compteur + 1
            VCRef.Message.SetText(Text: String(Compteur))
            DataFilledToSend[eTypeData.Compteur.rawValue] = Compteur
            DataFilledToSend[eTypeData.FillingData.rawValue] = "A"
            TailleData = DataConverted.count
            DataFilledToSend[eTypeData.FillingData.rawValue] = String(repeating: "A", count: kSizeDataPack - TailleData)
            DataConverted = try! NSKeyedArchiver.archivedData(withRootObject: DataFilledToSend, requiringSecureCoding: false)
            NewTailleData = DataConverted.count
            DataFilledToSend[eTypeData.FillingData.rawValue] = String(repeating: "A", count: kSizeDataPack - TailleData - (NewTailleData - kSizeDataPack))
            DataConverted = try! NSKeyedArchiver.archivedData(withRootObject: DataFilledToSend, requiringSecureCoding: false)
            
            if OutStream!.hasSpaceAvailable
            {
                let bytesWritten = DataConverted.withUnsafeBytes { OutStream!.write($0, maxLength: DataConverted.count) }

                if bytesWritten == -1 { print("Erreur send stream") }
            }
        }
        else    // Direct
        {
            let Peer = MPCSession.connectedPeers.first!
            try! MPCSession.send(DataConverted, toPeers: [Peer], with: .reliable)
        }
    }

        // Process of data received
    func ProcessMPCDataReceived(RawData: Data)
    {
        let DataReceived: Dictionary = (try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(RawData) as! [String : Any])

        switch DataReceived[eTypeData.EventType.rawValue] as! String
        {
        case eTypeEvent.SetMovement.rawValue:
            VCRef.CurrentMovement = eTypeMovement(rawValue: DataReceived[eTypeData.Movement.rawValue] as! String)!
         
        case eTypeEvent.SetPosition.rawValue:
//            SCNTransaction.begin()
//            SCNTransaction.animationDuration = 0
            DispatchQueue.main.async
            { [self] in
                VCRef.Ball.position = DataReceived[eTypeData.Position.rawValue] as! SCNVector3
            }
//            SCNTransaction.commit()
                
        default:
            break
        }
    }
    
        // --- Functions for MCSessionDelegate, StreamDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate
    
        // Called when status change
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState)
    {
        var Message: String = ""
        
        switch state
        {
            // Connextion d'un peer
        case .connected:
            switch gStatusUser
            {
                // Appelé depuis le master
            case .Master:
                Message = "Slave (" + peerID.displayName + ") connected"
                
                    // Arrêt de l'advertiser
                ServiceAdvertiser.stopAdvertisingPeer()
                ServiceAdvertiser.delegate = nil
                
                    // Ouverture du stream Master -> Slave
                try! OutStream = session.startStream(withName: "Stream " + peerID.displayName, toPeer: peerID)
                OutStream!.delegate = self
                OutStream!.schedule(in: RunLoop.main, forMode:RunLoop.Mode.default)
                OutStream!.open()
                
                gStatusApp = .Started

                // Appelé depuis le slave
            case .Slave:
                Message = "Master (" + peerID.displayName + ") connected"
                ServiceBrowser.stopBrowsingForPeers()
                ServiceBrowser.delegate = nil
                        
                    // Ouverture du stream Slave -> Master
                try! OutStream = session.startStream(withName: "Stream " + peerID.displayName, toPeer: peerID)
                OutStream!.delegate = self
                OutStream!.schedule(in: RunLoop.main, forMode:RunLoop.Mode.default)
                OutStream!.open()
                
                gStatusApp = .Started

            default:
                break
            }
                    
        case .connecting:
            Message = peerID.displayName + " connecting"
                    
        case .notConnected:
            Message = peerID.displayName + " notConnected"
        }

         VCRef.MPCSessionStatus.SetText(Text: Message)
    }
    
        // Called when data are received (outside of a stream)
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID)
    {
        ProcessMPCDataReceived(RawData: data as Data)
    }
    
        // Called when new stream open
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID)
    {
        InStream = stream
        InStream.delegate = self
        InStream.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
        InStream.open()
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
    
        // Called when browser detected
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?)
    {
        print("foundPeer named " + peerID.displayName)
        browser.invitePeer(peerID, to: MPCSession, withContext: nil, timeout: 0)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) { }
    
        // Called when connection is launched
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void)
    {
        print("didReceiveInvitationFromPeer by " + peerID.displayName)
        invitationHandler(true, MPCSession)
    }

        // Called when data received in an open stream
    func stream(_ aStream: Stream, handle eventCode: Stream.Event)
    {
        DispatchQueue(label:"StreamReceiver", qos: .userInteractive).async
        {
            switch(eventCode)
            {
            case Stream.Event.hasBytesAvailable:
                self.Compteur = self.Compteur + 1
                self.VCRef.Message.SetText(Text: String(self.Compteur))
                let InputStream = aStream as! InputStream
                var Buffer = [UInt8](repeating: 0, count: kSizeDataPack)
                let NumberBytes = InputStream.read(&Buffer, maxLength: kSizeDataPack)
                let DataString = NSData(bytes: &Buffer, length: NumberBytes)
                if let _ = NSKeyedUnarchiver.unarchiveObject(with: DataString as Data) as? [String:Any] //deserializing the NSData
                {
                    self.ProcessMPCDataReceived(RawData: DataString as Data)
                }
                
            case Stream.Event.hasSpaceAvailable:
                break
                
            case Stream.Event.errorOccurred:
                print("ErrorOccurred: \(String(describing: aStream.streamError?.localizedDescription))")
                
            default:
                break
            }

        }
    }
}
