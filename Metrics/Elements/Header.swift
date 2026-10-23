//
//  Header.swift
//  Metrics
//
//  Created by Alexis on 30/05/2022.
//

import Foundation
import UIKit

@IBDesignable
final class Header: UIView {
    
    @IBOutlet var contentView: UIView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var accessoryLabel: UILabel!
    
    var title: String {
        set {
            label.text = newValue
        }
        
        get {
            return (label.text == nil) ? "" : label.text!
        }
    }
    
    var subtitle: String {
        set {
            accessoryLabel.text = newValue
        }
        
        get {
            return (accessoryLabel.text == nil) ? "" : accessoryLabel.text!
        }
    }
    
    
    // MARK: - Init Methods
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setContent()
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setContent()
    }
    
    private func setContent() {
        let bundle = Bundle(for: Header.self)
        let nib = UINib(nibName: String(describing: Header.self), bundle: bundle)
        nib.instantiate(withOwner: self)
        addSubview(contentView)
        contentView.frame = self.bounds
        
        accessoryLabel.textColor = .lightGray
    }
}
