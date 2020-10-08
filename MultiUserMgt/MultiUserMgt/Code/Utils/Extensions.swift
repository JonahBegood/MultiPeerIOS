//
//  Extensions.swift
//  MultiUserMgt
//
//  Created by JB on 29/08/2020.
//  Copyright © 2020 IndianaDev. All rights reserved.
//

import Foundation
import UIKit
import ARKit

extension UIButton
{
    func Hide()
    {
        DispatchQueue.main.async
            {
                self.isHidden = true
            }
    }
    
    func UnHide()
    {
        DispatchQueue.main.async
            {
                self.isHidden = false
            }
    }
}

extension UILabel
{
    func Hide()
    {
        DispatchQueue.main.async
            {
                self.isHidden = true
            }
    }
    
    func UnHide()
    {
        DispatchQueue.main.async
            {
                self.isHidden = false
            }
    }

    func SetText(Text: String = "")
    {
        DispatchQueue.main.async
            {
                self.text = Text
            }
    }
}
