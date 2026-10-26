//
//  ViewController.swift
//  Metrics
//
//  Created by Alexis on 28/05/2022.
//

import UIKit
import CoreData

class ViewController: UIViewController, NewTransactionControllerDelegate, MonthPickerControllerDelegate,UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var header: Header!
    @IBOutlet weak var mainButton: MainButton!
    @IBOutlet weak var monthPickerButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
        
    private var transactions: [NSManagedObject] = []
    
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
    
        // Set Current Month Key
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.year, .month], from: Date())
        currentMonthKey = Int32(currentComponents.year! * 100 + currentComponents.month!)
        
        NotificationCenter.default.addObserver(self, selector: #selector(tagsDidChange),
                                                 name: dataManager.tagsDidChangeNotification, object: nil)

        // Soldes : recalculés après chaque sauvegarde
        NotificationCenter.default.addObserver(self, selector: #selector(calculateAmounts),
                                                 name: .NSManagedObjectContextDidSave, object: context)

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
        
        let deleteGesture = UILongPressGestureRecognizer(target: self, action: #selector(deleteGesture(tapGestureRecognizer:)))
        deleteGesture.minimumPressDuration = 1
        collectionView.addGestureRecognizer(deleteGesture)
    }

    /// Load Transactions for `currentMonthKey`
    private func loadTransactions() {

        let nextMonthKey = DateHelper.nextMonthKey(after: currentMonthKey)

        let startDayKey = currentMonthKey * 100 + 1
        let endDayKeyExclusive = nextMonthKey * 100 + 1

        let predicate = NSPredicate(
            format: "dayKey >= %@ AND dayKey < %@",
            argumentArray: [NSNumber(value: startDayKey), NSNumber(value: endDayKeyExclusive)]
        )
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Transaction")
        let sortByDay = NSSortDescriptor(key: #keyPath(Transaction.dayKey), ascending: false)
        let sortByCreation = NSSortDescriptor(key: #keyPath(Transaction.createdAt), ascending: false)
        fetchRequest.sortDescriptors = [sortByDay, sortByCreation]
        fetchRequest.predicate = predicate

        do {
            transactions = try context.fetch(fetchRequest)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
    
    
    /// Recalcule les soldes depuis la base (seule source de vérité), jusqu'à la fin du mois affiché (`currentMonthKey`) :
    /// - solde actuel : transactions exécutées
    /// - solde prévisionnel : toutes les transactions
    /// Une seule requête agrégée groupée par `executed` : SQLite fait la somme, aucun objet n'est chargé.
    /// La requête lit la base et pas le contexte : à appeler après `save()`.
    @objc private func calculateAmounts() {

        // Borne exclue : 1er jour du mois suivant le mois affiché
        let nextMonthKey = DateHelper.nextMonthKey(after: currentMonthKey)
        let endDayKeyExclusive = nextMonthKey * 100 + 1

        let sumExpression = NSExpressionDescription()
        sumExpression.name = "totalInCents"
        sumExpression.expression = NSExpression(forFunction: "sum:",
                                                arguments: [NSExpression(forKeyPath: #keyPath(Transaction.amountInCents))])
        sumExpression.expressionResultType = .integer64AttributeType

        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Transaction")
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.predicate = NSPredicate(format: "dayKey < %@",
                                             argumentArray: [NSNumber(value: endDayKeyExclusive)])
        fetchRequest.propertiesToFetch = [#keyPath(Transaction.executed), sumExpression]
        fetchRequest.propertiesToGroupBy = [#keyPath(Transaction.executed)]

        var executedInCents: Int64 = 0
        var pendingInCents: Int64 = 0

        do {
            // Au plus 2 lignes : executed = true / executed = false
            for row in try context.fetch(fetchRequest) {
                let totalInCents = (row["totalInCents"] as? NSNumber)?.int64Value ?? 0

                if (row[#keyPath(Transaction.executed)] as? NSNumber)?.boolValue == true {
                    executedInCents += totalInCents
                } else {
                    pendingInCents += totalInCents
                }
            }
        } catch let error as NSError {
            print("Could not calculate amounts. \(error), \(error.userInfo)")
            return
        }

        header.title = CurrencyFormatter.string(from: executedInCents + pendingInCents)
        header.subtitle = CurrencyFormatter.string(from: executedInCents)
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
                return dataManager.sharedInstance.tags.count
            
            case 1:
                return transactions.count
            
            default:
                return 0
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // Tags
        if indexPath.section == 0 {
            
            let tag = dataManager.sharedInstance.tags[indexPath.row]
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagItem", for: indexPath) as! TagItem
        
            if let tagName = tag.name {
                //cell.label.text = CurrencyFormatter.string(from: tagsAmountsInCents[tagName] ?? 0)
                // Provisoire
                cell.label.text = "\(tagName)"
            }
    
            return cell
        
        // Transactions
        } else {
            
            let transaction = transactions[indexPath.row] as! Transaction
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TransactionCell", for: indexPath) as! TransactionCell
            cell.nameLabel.text = transaction.name
            cell.tagLabel.text = (transaction.tag == nil) ? "Autre" : transaction.tag!.name
            
            if transaction.tag != nil && transaction.tag!.limitInCents > 0 {
                
                let amountString = CurrencyFormatter.string(from: transaction.amountInCents)
                let limitString = " / \(CurrencyFormatter.string(from: transaction.tag!.limitInCents))"
                
                let limitAttribute = [NSAttributedString.Key.foregroundColor : UIColor.gray]
                
                let attrString1 = NSMutableAttributedString(string: amountString)
                let attrString2 = NSMutableAttributedString(string: limitString, attributes: limitAttribute)
                attrString1.append(attrString2)
                
                cell.amountLabel.attributedText = attrString1
                
            } else {
                
                cell.amountLabel.text = CurrencyFormatter.string(from: transaction.amountInCents)
            }
            
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
    
    
    @objc private func executeGesture(tapGestureRecognizer:UITapGestureRecognizer) {
        
        let point = tapGestureRecognizer.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        
        if indexPath.section != 1 { return }
        
        let transaction = transactions[indexPath.row] as! Transaction
        transaction.executed = transaction.executed ? false : true
        
        let cell = collectionView.cellForItem(at: indexPath) as! TransactionCell
        cell.executed = transaction.executed
        
        saveContext()
    }
    
    
    @objc private func deleteGesture(tapGestureRecognizer:UITapGestureRecognizer) {
        
        if tapGestureRecognizer.state == .ended {
            let point = tapGestureRecognizer.location(in: collectionView)
            guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
            
            if indexPath.section != 1 { return }
            
            let transaction = transactions[indexPath.row]
            
            self.context.delete(transaction)
            saveContext()
            transactions.remove(at: indexPath.row)
            collectionView.deleteItems(at: [indexPath])
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
