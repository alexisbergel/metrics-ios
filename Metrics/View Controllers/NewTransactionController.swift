//
//  NewTransactionController.swift
//  Metrics
//
//  Created by Alexis on 04/06/2022.
//

import UIKit
import CoreData

protocol NewTransactionControllerDelegate: AnyObject {
    func userFinishedEditing(newTransaction: Transaction)
}

enum ButtonItemTag: Int {
    case withdraw
    case deposit
}

class NewTransactionController: UIViewController, UITextFieldDelegate, TagsViewControllerDelegate, UIPopoverPresentationControllerDelegate {
    
    @IBOutlet weak var header: Header!
    @IBOutlet weak var amount: UITextField!
    @IBOutlet weak var label: UITextField!
    @IBOutlet weak var dateButton: UIButton!
    @IBOutlet weak var tag: UITextField!
    
    weak var delegate: NewTransactionControllerDelegate?
    var managedObjectContext: NSManagedObjectContext = UIViewController.sharedViewContext()
    var currentDate: Date = Date()
    var selectedTag: Tag?

    private var amountInCents: Int64 = 0 {
        didSet {
            amount.text = CurrencyFormatter.string(from: amountInCents, includesCurrencySymbol: false)
        }
    }
    
    
    
    // MARK: - Initialization
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        header.title = "New transaction"
        
        setup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        amount.becomeFirstResponder()
    }

    private func setup() {
        
        // Toolbar
        let bar = UIToolbar()
        
        let withdrawalButton = UIBarButtonItem(title: "-", style: .plain, target: self, action: #selector(finishEditing(sender:)))
        withdrawalButton.tag = ButtonItemTag.withdraw.rawValue
        
        let depositButton = UIBarButtonItem(title: "+", style: .plain, target: self, action: #selector(finishEditing(sender:)))
        depositButton.tag = ButtonItemTag.deposit.rawValue
        
        bar.items = [withdrawalButton, depositButton]
        bar.sizeToFit()
        
        // Amount Textfield
        amount.keyboardType = .numberPad
        amount.delegate = self
        amount.inputAccessoryView = bar
        amount.text = CurrencyFormatter.string(from: amountInCents, includesCurrencySymbol: false)
        
        // Label Textfield
        label.autocapitalizationType = .words
        label.inputAccessoryView = bar
        
        // Date Button
        dateButton.addTarget(self, action: #selector(showDatePicker), for: .touchUpInside)
        dateButton.setTitle("Aujourd'hui", for: .normal)
        
        // Tag Textfield
        tag.delegate = self
        tag.placeholder = "Tag"
    }
    
    
    
    // MARK: - User Events
    
    @objc private func finishEditing(sender: UIBarButtonItem) {
        
        guard amountInCents != 0 else {
            return
        }
        
        // dayKey
        guard let dayKeyInt = Int32(DateHelper.dayKeyFormatter.string(from: currentDate)) else {
            return
        }
        
        let signedAmountInCents = signedAmountInCents(for: sender.tag)
        let newTransaction = makeTransaction(amountInCents: signedAmountInCents, dayKeyInt: dayKeyInt)
        persistChanges()

        self.dismiss(animated: true)
        self.delegate?.userFinishedEditing(newTransaction: newTransaction)
    }

    private func signedAmountInCents(for buttonTag: Int) -> Int64 {
        buttonTag == ButtonItemTag.withdraw.rawValue ? -amountInCents : amountInCents
    }

    private func makeTransaction(amountInCents: Int64, dayKeyInt: Int32) -> Transaction {
        
        let newTransaction = Transaction(context: self.managedObjectContext)
        newTransaction.createdAt = Date()
        newTransaction.dayKey = dayKeyInt
        newTransaction.amountInCents = amountInCents
        newTransaction.name = label.text
        newTransaction.id = UUID()
        newTransaction.tag = selectedTag
        
        return newTransaction
    }

    private func persistChanges() {
        guard managedObjectContext.hasChanges else { return }
        do {
            try managedObjectContext.save()
        } catch {
            fatalError("Unresolved error \(error)")
        }
    }
    
    @objc private func showDatePicker() {
        
        // Hide keyboard
        view.endEditing(true)
        
        // Create Picker
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.date = currentDate
        
        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
        
        // Controller for the Picker
        let vc = UIViewController()
        vc.view.addSubview(datePicker)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: vc.view.topAnchor),
            datePicker.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            datePicker.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor)
        ])
        vc.preferredContentSize = datePicker.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        
        // Popover presentation
        vc.modalPresentationStyle = .popover
        if let popover = vc.popoverPresentationController {
            popover.sourceView = dateButton
            popover.sourceRect = dateButton.bounds
            popover.permittedArrowDirections = [.up, .down]
            popover.delegate = self
        }
        present(vc, animated: true)
    }
    
    @objc func dateChanged(_ sender:UIDatePicker) {
        
        currentDate = sender.date
        
        let dateString = Calendar.current.isDateInToday(currentDate) ? "Aujourd'hui" : currentDate.formatted(date: .abbreviated, time: .omitted)
        
        dateButton.setTitle(dateString, for: .normal)
        
        dismiss(animated: true)
    }


    
    // MARK: - Textfield Delegate

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard textField == amount else { return true }

        if string.isEmpty {
            amountInCents /= 10
            return false
        }

        guard string.count == 1,
              let character = string.first,
              let digit = character.wholeNumberValue else {
            return false
        }

        let (shiftedAmount, didOverflow) = amountInCents.multipliedReportingOverflow(by: 10)
        guard !didOverflow else { return false }

        let (newAmount, didAddOverflow) = shiftedAmount.addingReportingOverflow(Int64(digit))
        guard !didAddOverflow else { return false }

        amountInCents = newAmount
        return false
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        
        if textField == tag {
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let tagViewController = storyboard.instantiateViewController(withIdentifier: "TagsViewController") as! TagsViewController
            tagViewController.delegate = self
            self.present(tagViewController, animated: true)
            
            return false
        }
        
        return true
    }
    
    
    
    // MARK: - TagsViewController Delegate
    
    func userSelectedTag(selectedTag: Tag) {
        
        self.selectedTag = selectedTag
        self.tag.text = selectedTag.name
    }
    
    
    // MARK: - UIPopoverPresentationStyle Delegate
    
    /// Indispensable sur iPhone, sinon le popover s'affiche en plein écran
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }
}
