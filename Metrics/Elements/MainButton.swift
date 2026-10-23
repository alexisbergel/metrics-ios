//
//  MainButton.swift
//  Metrics
//
//  Created by Alexis on 01/06/2022.
//

import Foundation
import UIKit

@IBDesignable
final class MainButton: UIButton {
    
    override init(frame: CGRect) {
        super .init(frame: frame)
        setContent()
    }
    
    
    required init?(coder: NSCoder) {
        super .init(coder: coder)
        setContent()
    }
    
    
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setContent()
    }
    
    
    private func setContent() {
       
        self.layer.cornerRadius = self.bounds.width / 2
        self.clipsToBounds = true
        self.tintColor = .gray
        self.setImage(.add, for: .normal)
        
        // Set title to void is the only way to have a single image button
        self.setTitle("", for: .normal)
    }
}
