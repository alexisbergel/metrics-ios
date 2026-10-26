//
//  TransactionCell.swift
//  Metrics
//
//  Created by Alexis on 22/06/2022.
//

import Foundation
import UIKit

final class TransactionCell: UICollectionViewCell {
    
    @IBOutlet weak var cellView: UIView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var tagLabel: UILabel!
    @IBOutlet private weak var executedIndicator: UIView!
    
    private var isExecuted = false
    
    var executed: Bool {
        set {
            if newValue != isExecuted {
                isExecuted = newValue
                setExecutedStyle()
            }
        }
        
        get {
            return isExecuted
        }
    }

    
    
    // MARK: - Init Methods
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setContent()
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    private func setContent() {
        //selectionStyle = .none
        
        executedIndicator.layer.cornerRadius = 6
        executedIndicator.isHidden = true
    }
    
    
    private func setExecutedStyle() {
        switch isExecuted {
            
        case true:
            executedIndicator.isHidden = false
            amountLabel.layer.opacity = 0.3
            nameLabel.layer.opacity = 0.3
            
        case false:
            executedIndicator.isHidden = true
            amountLabel.layer.opacity = 1
            nameLabel.layer.opacity = 1
        }
    }
}
