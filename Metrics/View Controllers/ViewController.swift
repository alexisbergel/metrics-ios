//
//  ViewController.swift
//  Metrics
//
//  Created by Alexis on 28/05/2022.
//

import UIKit

class ViewController: UIViewController, NewTransactionControllerDelegate, MonthPickerControllerDelegate,UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var header: Header!
    @IBOutlet weak var mainButton: MainButton!
    @IBOutlet weak var monthPickerButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
        
    private var transactions: [Transaction] = []
    
    private var tagsAmountsInCents: [String: Int64] = [:]

    var currentMonthKey: Int32 = 0 {
        didSet {
            loadTransactions()
            calculateAmounts()
            updateMonthPickerButtonTitle()
        }
    }
    
    
    
    // MARK: - Init Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        currentMonthKey = DateHelper.monthKey()
        
        NotificationCenter.default.addObserver(self, selector: #selector(tagsDidChange),
                                                 name: DataManager.tagsDidChangeNotification, object: nil)

        // Soldes : recalculés après chaque modification des transactions
        NotificationCenter.default.addObserver(self, selector: #selector(calculateAmounts),
                                               name: DataManager.transactionsDidChangeNotification, object: nil)

        mainButton.addTarget(self, action: #selector(newTransaction), for: .touchUpInside)
        monthPickerButton.addTarget(self, action: #selector(openMonthPickerView), for: .touchUpInside)
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true
        collectionView.collectionViewLayout = createLayout()
        
        let nib = UINib(nibName: "TransactionCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "TransactionCell")
        
        let tagItemNib = UINib(nibName: "TagItem", bundle: nil)
        collectionView.register(tagItemNib, forCellWithReuseIdentifier: "TagItem")
        
        let executeGesture = UITapGestureRecognizer(target: self, action: #selector(executeGesture(tapGestureRecognizer:)))
        executeGesture.numberOfTapsRequired = 2
        collectionView.addGestureRecognizer(executeGesture)
        
        let deleteGesture = UILongPressGestureRecognizer(target: self, action: #selector(deleteGesture(longPressGestureRecognizer:)))
        deleteGesture.minimumPressDuration = 1
        collectionView.addGestureRecognizer(deleteGesture)
    }

    /// Charge les transactions de `currentMonthKey`.
    private func loadTransactions() {
        
        do {
            transactions = try DataManager.sharedInstance.transactions(forMonth: currentMonthKey)
        } catch {
            transactions = []
            presentError(error, title: "Impossible de charger les transactions")
        }
    }
    
    
    /// Affiche les soldes jusqu'à la fin du mois affiché (`currentMonthKey`) :
    /// - titre : solde prévisionnel (toutes les transactions)
    /// - sous-titre : solde actuel (transactions exécutées)
    @objc private func calculateAmounts() {

        do {
            let balances = try DataManager.sharedInstance.balances(upToMonth: currentMonthKey)
            header.title = CurrencyFormatter.string(from: balances.forecastInCents)
            header.subtitle = CurrencyFormatter.string(from: balances.executedInCents)
        } catch {
            presentError(error, title: "Impossible de calculer les soldes")
        }
    }


    /// Uses `DateHelper` to get Text from `currentMonthKey`
    private func updateMonthPickerButtonTitle() {

        let title = DateHelper.monthTitle(forMonthKey: currentMonthKey)
        monthPickerButton.setTitle(title, for: .normal)
    }



    // MARK: - Collection View Layout
    
    private func createLayout() -> UICollectionViewLayout {

        return UICollectionViewCompositionalLayout { sectionIndex, environment in

            switch sectionIndex {
            case 0:

                return self.tagsSectionLayout()
            case 1:

                return self.transactionsSectionLayout()
            default:
                return nil
            }
        }
    }
    
    private func tagsSectionLayout() -> NSCollectionLayoutSection {
        
        let itemSpacing = 8.0
        let itemWidth = 70.0
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                              heightDimension: .fractionalHeight(1))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(itemWidth + itemSpacing),
                                               heightDimension: .absolute(107))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: itemSpacing)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 0)
        section.orthogonalScrollingBehavior = .continuous
        
        return section
    }
    
    
    private func transactionsSectionLayout() -> NSCollectionLayoutSection {
        
        let itemHeight = 60.0
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .fractionalHeight(1.0))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(itemHeight))
        
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        
        return section
    }
    
    
    
    // MARK: - UICollectionView
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        switch section {
            
            case 0:
                return DataManager.sharedInstance.tags.count
            
            case 1:
                return transactions.count
            
            default:
                return 0
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // Tags
        if indexPath.section == 0 {
            
            let tag = DataManager.sharedInstance.tags[indexPath.row]
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagItem", for: indexPath) as! TagItem
        
            if let tagName = tag.name {
                //cell.label.text = CurrencyFormatter.string(from: tagsAmountsInCents[tagName] ?? 0)
                // Provisoire
                cell.label.text = "\(tagName)"
            }
    
            return cell
        
        // Transactions
        } else {
            
            let transaction = transactions[indexPath.row]
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TransactionCell", for: indexPath) as! TransactionCell
            cell.nameLabel.text = transaction.name
            cell.tagLabel.text = transaction.tag?.name ?? "Autre"
            cell.amountLabel.text = CurrencyFormatter.string(from: transaction.amountInCents)
            cell.executed = transaction.executed
            
            return cell
        }
    }
    
    
    
    // MARK: - Events
    // 1. NewTransaction › open NewTransactionController
    // 2. ExecuteGesture
    // 3. DeleteGesture
    // 4. Open Month Picker View
    
    @objc private func newTransaction() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let newTransactionController = storyboard.instantiateViewController(withIdentifier: "NewTransactionController") as! NewTransactionController
        newTransactionController.modalPresentationStyle = .pageSheet
        newTransactionController.delegate = self
    
        self.present(newTransactionController, animated: true)
    }
    
    
    @objc private func executeGesture(tapGestureRecognizer: UITapGestureRecognizer) {
        
        let point = tapGestureRecognizer.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        
        if indexPath.section != 1 { return }
        
        let transaction = transactions[indexPath.row]
        
        do {
            try DataManager.sharedInstance.toggleExecuted(transaction)
            
            if let cell = collectionView.cellForItem(at: indexPath) as? TransactionCell {
                cell.executed = transaction.executed
            }
        } catch {
            presentError(error, title: "Impossible de modifier la transaction")
        }
    }
    
    
    @objc private func deleteGesture(longPressGestureRecognizer: UILongPressGestureRecognizer) {
        
        if longPressGestureRecognizer.state == .ended {
            let point = longPressGestureRecognizer.location(in: collectionView)
            guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
            
            if indexPath.section != 1 { return }
            
            let transaction = transactions[indexPath.row]
            
            do {
                try DataManager.sharedInstance.deleteTransaction(transaction)
                
                transactions.remove(at: indexPath.row)
                collectionView.deleteItems(at: [indexPath])
            } catch {
                presentError(error, title: "Impossible de supprimer la transaction")
            }
        }
    }
    
    
    @objc private func tagsDidChange() {
        collectionView.reloadSections(IndexSet(integer: 0))
    }


    @objc private func openMonthPickerView() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let monthPickerController = storyboard.instantiateViewController(withIdentifier: "MonthPickerController") as! MonthPickerController
        monthPickerController.modalPresentationStyle = .pageSheet
        monthPickerController.delegate = self
        self.present(monthPickerController, animated: true)
    }

        
    
    // MARK: - New Transaction Controller Delegate

    func userFinishedEditing(newTransaction: Transaction) {
        
        let transactionMonthKey = Int(newTransaction.dayKey) / 100
        
        let isCurrentMonth = transactionMonthKey == currentMonthKey
        
        // Add transaction to current view only if its month matches the view's month
        if isCurrentMonth {
            transactions.insert(newTransaction, at: 0)
            let indexPath = IndexPath(row: 0, section: 1)
            collectionView.insertItems(at: [indexPath])
        }
    }
    
    
    
    // MARK: - Month Picker Controller Delegate

    func userChangedSelectedMonth(selectedKeyMonth: Int32) {

        guard selectedKeyMonth != currentMonthKey else { return }
        currentMonthKey = selectedKeyMonth
        collectionView.reloadData()
    }
}
