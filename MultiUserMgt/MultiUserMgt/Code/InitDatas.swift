//
//  InitDatas.swift
//  MultiUserMgt
//
//  Created by JB on 29/08/2020.
//  Copyright © 2020 IndianaDev. All rights reserved.
//

import Foundation
import UIKit

//------------------------------------------------------------------------------------------------------
// MARK: - Initialisation des variables/constantes globales
//------------------------------------------------------------------------------------------------------
var gInitialSpeed3D: Double = 0.002
let kSizeDataPack: Int = 1024

var gMvtMgtMode: eMvtMgtMode = .Kinematic1
enum eMvtMgtMode: String
{
    case Kinematic1     // !!!!!!!! -> Le Physicsbody de la balle doit être de type Kinematic dans Test.scn
    case Dynamic        // !!!!!!!! -> Le Physicsbody de la balle doit être de type Dynamic dans Test.scn
}

var gStatusApp: eStatusApp = .Init
enum eStatusApp: String
{
    case Init
    case WaitingForMPCInit
    case Started
}

var gStatusUser: eStatusUser = .Master
enum eStatusUser: String
{
    case Master
    case Slave
}

enum eTypeMovement: String
{
    case None
    case Up
    case Down
    case Right
    case Left
    
    func Inverse() -> eTypeMovement
    {
        switch self
        {
        case .Right:
            return .Left
            
        case .Left:
            return .Right
            
        case .Up:
            return .Down
            
        case .Down:
            return .Up
            
        case .None:
            return .None
         }
    }
}

enum eTypeEvent: String
{
    case SetMovement
    case SetPosition
}

enum eTypeData: String
{
    case FillingData
    case Compteur
    case EventType
    case Movement
    case Position
}
