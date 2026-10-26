//
//  TagItem.swift
//  Metrics
//
//  Created by Alexis on 05/11/2022.
//

import Foundation
import UIKit

final class TagItem: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIView!
    @IBOutlet weak var label: UILabel!
 
 
    
    // MARK: - Init Methods
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setContent()
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    
    private func setContent() {
        
        imageView.layer.cornerRadius = 70 / 2
    }
}
