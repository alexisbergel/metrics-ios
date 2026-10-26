//
//  TagCell.swift
//  Metrics
//
//  Created by Alexis on 17/10/2022.
//

import Foundation
import UIKit

final class GenericCell: UITableViewCell {
    
    @IBOutlet weak var cellView: UIView!
    @IBOutlet weak var label: UILabel!
    
    
    
    // MARK: - Init Methods
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
