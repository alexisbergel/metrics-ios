//
//  TagsViewController.swift
//  Metrics
//
//  Created by Alexis on 15/09/2022.
//

import UIKit
import CoreData

protocol TagsViewControllerDelegate: AnyObject {
    func userSelectedTag(selectedTag: Tag)
}

class TagsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

    @IBOutlet weak var tableView: UITableView!

    weak var delegate: TagsViewControllerDelegate?
    private weak var limitTextField: UITextField?
    private var limitInCents: Int64 = 0 {
        didSet {
            limitTextField?.text = CurrencyFormatter.string(from: limitInCents, includesCurrencySymbol: false)
        }
    }
    
    let reuseIdentifier = "GenericCell"



    // MARK: - Init Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.delegate = self
        self.tableView.dataSource = self

        let nib = UINib(nibName: reuseIdentifier, bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: reuseIdentifier)
    }



    // MARK: - UITableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataManager.sharedInstance.tags.count + 1
    }


    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "GenericCell", for: indexPath) as! GenericCell

        if indexPath.row == 0 {
            cell.label.text = "Add New Tag"
            return cell
        }

        let tag = dataManager.sharedInstance.tags[indexPath.row - 1]
        cell.label.text = tag.name
        return cell

    }


    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if indexPath.row == 0 {

            let alert = UIAlertController(title: "New Tag", message: nil, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in

                let name = alert.textFields![0].text ?? ""
                if name.count == 0 { return }

                self.addNewTag(with: name, limitInCents: self.limitInCents)
            }))

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            alert.addTextField { textfield in

                textfield.placeholder = "Tag Name"
                textfield.autocapitalizationType = .sentences
            }

            alert.addTextField { textfield in

                textfield.keyboardType = .numberPad
                textfield.delegate = self
                textfield.text = CurrencyFormatter.string(from: self.limitInCents, includesCurrencySymbol: false)
                self.limitTextField = textfield
            }

            self.present(alert, animated: true)

        } else {

            let selectedTag = dataManager.sharedInstance.tags[indexPath.row - 1]
            self.dismiss(animated: true)
            delegate?.userSelectedTag(selectedTag: selectedTag)
        }
    }

    // MARK: - Textfield Delegate

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard textField == limitTextField else { return true }

        if string.isEmpty {
            limitInCents /= 10
            return false
        }

        guard string.count == 1,
              let character = string.first,
              let digit = character.wholeNumberValue else {
            return false
        }

        let (shiftedAmount, didOverflow) = limitInCents.multipliedReportingOverflow(by: 10)
        guard !didOverflow else { return false }

        let (newAmount, didAddOverflow) = shiftedAmount.addingReportingOverflow(Int64(digit))
        guard !didAddOverflow else { return false }

        limitInCents = newAmount
        return false
    }

    // MARK: - Events

    private func addNewTag(with name: String, limitInCents: Int64) {
        do {
            try dataManager.sharedInstance.addTag(name: name, limitInCents: limitInCents)
            tableView.reloadData()
        } catch {
            print("Could not add tag. \(error.localizedDescription)")
        }
    }
}
