//
//  GameViewController.swift
//  MultiUserMgt
//
//  Created by JB on 29/08/2020.
//  Copyright © 2020 IndianaDev. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit
import MultipeerConnectivity

class GameViewController: UIViewController, SCNPhysicsContactDelegate, SCNSceneRendererDelegate
{
    //------------------------------------------------------------------------------------------------------
    // MARK: - Properties
    //------------------------------------------------------------------------------------------------------

    var tSubViews3D: Array<UIView> = []
    var MPCSessionStatus: UILabel!
    var Message: UILabel!
    var Master: UIButton!
    var Slave: UIButton!
    var DebugButton: UIButton!

    var SingleTapGesture: UITapGestureRecognizer!
    var DoubleTapGesture: UITapGestureRecognizer!
    var SwipeRightGesture: UISwipeGestureRecognizer!
    var SwipeLeftGesture: UISwipeGestureRecognizer!
    var SwipeUpGesture: UISwipeGestureRecognizer!
    var SwipeDownGesture: UISwipeGestureRecognizer!

    var CurrentMovement: eTypeMovement = .None
    var LastMovementBroadcasted: eTypeMovement = .None
    var SwipeMovement: eTypeMovement = .None
    
    var Ball: SCNNode!
    
    var SessionMPC: MPCSessionClass!
    var DataToSend: Dictionary<String, Any> = [:]

    override func viewDidLoad()
    {
        super.viewDidLoad()
        SessionMPC = MPCSessionClass()
        SessionMPC.VCRef = self
        
            // Initialisation de la view
        let scnView = self.view as! SCNView
        scnView.delegate = self
        scnView.isPlaying = true
        scnView.allowsCameraControl = false
        scnView.showsStatistics = true
        scnView.backgroundColor = UIColor.black
//        scnView.preferredFramesPerSecond = 10

            // Initialisation de la scene
        let scene = SCNScene(named: "art.scnassets/Test.scn")!
        scnView.scene = scene
        scnView.scene!.physicsWorld.contactDelegate = self
        scnView.scene!.physicsWorld.gravity = SCNVector3Zero

            // Initialisation de la caméra
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 10)

            // Initialisation des lumières
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
                        
            // Chargement des subviews de la view depuis le NIB
            // En attendant de comprendre comment faire une view universelle...
        switch UIDevice.current.model
        {
        case "iPhone", "iPhone Simulator", "iPod touch":
            tSubViews3D = (Bundle.main.loadNibNamed("View iPhone", owner: nil, options: nil)![0] as! SCNView).subviews
            
        case "iPad", "iPad Simulator":
            tSubViews3D = (Bundle.main.loadNibNamed("View iPad", owner: nil, options: nil)![0] as! SCNView).subviews
            
        default:
            tSubViews3D = (Bundle.main.loadNibNamed("View iPhone", owner: nil, options: nil)![0] as! SCNView).subviews
        }

        MPCSessionStatus = tSubViews3D[0] as? UILabel
        Message = tSubViews3D[1] as? UILabel
        Master = tSubViews3D[2] as? UIButton
        Slave = tSubViews3D[3] as? UIButton
        DebugButton = tSubViews3D[4] as? UIButton
        for ViewElement in tSubViews3D { self.view.addSubview(ViewElement) }

            // Initialisation des actions sur les subviews
        Master.addTarget(self, action: #selector(self.LaunchMasterMgt), for: UIControl.Event.touchUpInside)
        Slave.addTarget(self, action: #selector(self.LaunchSlaveMgt), for: UIControl.Event.touchUpInside)
        DebugButton.addTarget(self, action: #selector(self.DebugButtonActionMgt), for: UIControl.Event.touchUpInside)

        Ball = scene.rootNode.childNode(withName: "Ball", recursively: true)!

           // initialisation des gestures
        SingleTapGesture = UITapGestureRecognizer(target: self, action: #selector(RespondToSingleTappedGesture))
        DoubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(RespondToDoubleTappedGesture))
        SwipeRightGesture = UISwipeGestureRecognizer(target: self, action: #selector(RespondToSwipeGesture))
        SwipeLeftGesture = UISwipeGestureRecognizer(target: self, action: #selector(RespondToSwipeGesture))
        SwipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(RespondToSwipeGesture))
        SwipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(RespondToSwipeGesture))
        
        SingleTapGesture.numberOfTapsRequired = 1
        scnView.addGestureRecognizer(SingleTapGesture)

        DoubleTapGesture.numberOfTapsRequired = 2
        scnView.addGestureRecognizer(DoubleTapGesture)

        SwipeRightGesture.direction = UISwipeGestureRecognizer.Direction.right
        scnView.addGestureRecognizer(SwipeRightGesture)

        SwipeLeftGesture.direction = UISwipeGestureRecognizer.Direction.left
        scnView.addGestureRecognizer(SwipeLeftGesture)

        SwipeUpGesture.direction = UISwipeGestureRecognizer.Direction.up
        scnView.addGestureRecognizer(SwipeUpGesture)

        SwipeDownGesture.direction = UISwipeGestureRecognizer.Direction.down
        scnView.addGestureRecognizer(SwipeDownGesture)
    }
       
    override var shouldAutorotate: Bool { return true }
    
    override var prefersStatusBarHidden: Bool { return true }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask
    {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
    //------------------------------------------------------------------------------------------------------
    // MARK: - Event management
    //------------------------------------------------------------------------------------------------------
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
    }

        // Ball movement is managed here for master
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval)
    {
        if gStatusApp == .Started
        {
        switch gStatusUser
            {
            case .Master:
                ManageNodeMovementKInRenderer()
                MPCBroadcastNodesPosition()
                
            case .Slave:
                // Ball positionning is done in ProcessMPCDataReceived based on position received from master
            break
            }
        }
    }

    func physicsWorld(_ world: SCNPhysicsWorld,  didBegin contact: SCNPhysicsContact)
    {
        CurrentMovement = CurrentMovement.Inverse()
    }

    @objc func RespondToSwipeGesture(Gesture: UIGestureRecognizer)
    {
        if gStatusApp == .Started
        {
            if let SwipeGesture = Gesture as? UISwipeGestureRecognizer
            {
                switch SwipeGesture.direction
                {
                case UISwipeGestureRecognizer.Direction.right:
                    SwipeMovement = .Right
                    
                case UISwipeGestureRecognizer.Direction.down:
                    SwipeMovement = .Down
                    
                case UISwipeGestureRecognizer.Direction.left:
                    SwipeMovement = .Left
                    
                case UISwipeGestureRecognizer.Direction.up:
                    SwipeMovement = .Up
                    
                default:
                    break
                }
                
                CurrentMovement = SwipeMovement
                
                DataToSend = [:]
                DataToSend[eTypeData.EventType.rawValue] = eTypeEvent.SetMovement.rawValue
                DataToSend[eTypeData.Movement.rawValue] = CurrentMovement.rawValue
                SessionMPC.MPCSendData(DataToSend: self.DataToSend, ViaStream: true)
            }
        }
    }

    @objc func RespondToSingleTappedGesture()
    {
        if gStatusApp == .Started
        {
            CurrentMovement = .None

            DataToSend = [:]
            DataToSend[eTypeData.EventType.rawValue] = eTypeEvent.SetMovement.rawValue
            DataToSend[eTypeData.Movement.rawValue] = CurrentMovement.rawValue
            SessionMPC.MPCSendData(DataToSend: self.DataToSend, ViaStream: true)
        }
    }

    @objc func RespondToDoubleTappedGesture()
    {
        if gStatusApp == .Started
        {
            Ball.position = SCNVector3(0, 0, 0)
            CurrentMovement = .None

            DataToSend = [:]
            DataToSend[eTypeData.EventType.rawValue] = eTypeEvent.SetMovement.rawValue
            DataToSend[eTypeData.Movement.rawValue] = CurrentMovement.rawValue
            SessionMPC.MPCSendData(DataToSend: self.DataToSend, ViaStream: true)
            DataToSend = [:]
            DataToSend[eTypeData.EventType.rawValue] = eTypeEvent.SetPosition.rawValue
            DataToSend[eTypeData.Position.rawValue] = SCNVector3(0, 0, 0)
            SessionMPC.MPCSendData(DataToSend: self.DataToSend, ViaStream: true)
        }

    }

    @objc func DebugButtonActionMgt(_ sender: UIButton)
    {
    }

        // Management of ball movement with Kinematic physicsbody
    func ManageNodeMovementKInRenderer()
    {
        switch CurrentMovement
        {
        case .Right:
            Ball.position = SCNVector3.init(Ball.presentation.position.x + Float(gInitialSpeed3D), Ball.presentation.position.y, Ball.presentation.position.z)

        case .Left:
            Ball.position = SCNVector3.init(Ball.presentation.position.x - Float(gInitialSpeed3D), Ball.presentation.position.y, Ball.presentation.position.z)

        case .Up:
            Ball.position = SCNVector3.init(Ball.presentation.position.x , Ball.presentation.position.y + Float(gInitialSpeed3D), Ball.presentation.position.z)

        case .Down:
            Ball.position = SCNVector3.init(Ball.presentation.position.x , Ball.presentation.position.y - Float(gInitialSpeed3D), Ball.presentation.position.z)

        default:
            break
        }
    }
    
    func MPCBroadcastNodesPosition()
    {
        if CurrentMovement != .None
        {
            DataToSend = [:]
            DataToSend[eTypeData.EventType.rawValue] = eTypeEvent.SetPosition.rawValue
            DataToSend[eTypeData.Position.rawValue] = Ball.position

            SessionMPC.MPCSendData(DataToSend: DataToSend, ViaStream: true)
        }
    }

    //------------------------------------------------------------------------------------------------------
    // MARK: - MPC initialization functions
    // !!!!!! Work only for 2 devices
    //------------------------------------------------------------------------------------------------------
        
        // Master - Advertiser launch
    @objc func LaunchMasterMgt(_ sender: UIButton)
    {
        gStatusApp = .WaitingForMPCInit
        gStatusUser = .Master
        
        Master.Hide()
        Slave.Hide()

            // Création de la session Master
        SessionMPC.PeerID = MCPeerID(displayName: "Master (" + UIDevice.current.name + ")")
        SessionMPC.MPCSession = MCSession(peer: SessionMPC.PeerID, securityIdentity: nil, encryptionPreference: .none)
        SessionMPC.MPCSession.delegate = SessionMPC
        
            // Lancement de l'advertiser en direct (sans passer par l'assistant)
        SessionMPC.ServiceAdvertiser = MCNearbyServiceAdvertiser(peer: SessionMPC.PeerID, discoveryInfo: nil, serviceType: "ARMvt")
        SessionMPC.ServiceAdvertiser.delegate = SessionMPC
        SessionMPC.ServiceAdvertiser.startAdvertisingPeer()
        
        MPCSessionStatus.SetText(Text: "Advertiser launched, waiting for slave...")
    }
    
        // Slave - Browser launch
    @objc func LaunchSlaveMgt(_ sender: UIButton)
    {
        gStatusApp = .WaitingForMPCInit
        gStatusUser = .Slave

            // Suppression des boutons
        Master.Hide()
        Slave.Hide()
        
            // Création de la session Slave
        SessionMPC.PeerID = MCPeerID(displayName: "Slave (" + UIDevice.current.name + ")")
        SessionMPC.MPCSession = MCSession(peer: SessionMPC.PeerID, securityIdentity: nil, encryptionPreference: .none)
        SessionMPC.MPCSession.delegate = SessionMPC
        
            // Lancement du browser en direct (sans passer par l'assistant)
        SessionMPC.ServiceBrowser = MCNearbyServiceBrowser(peer: SessionMPC.PeerID,  serviceType: "ARMvt")
        SessionMPC.ServiceBrowser.delegate = SessionMPC
        SessionMPC.ServiceBrowser.startBrowsingForPeers()
        
        MPCSessionStatus.SetText(Text: "Browser launched, waiting for master...")
    }
        
}
