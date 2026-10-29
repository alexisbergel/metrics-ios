//
//  DataManager.swift
//  Metrics
//
//  Created by Alexis on 23/10/2022.
//

import CoreData

enum DataManagerError: LocalizedError {
    case zeroAmount
    case invalidDate
    
    var errorDescription: String? {
        switch self {
        case .zeroAmount: return "Le montant ne peut pas être nul"
        case .invalidDate: return "La date de la transaction est invalide"
        }
    }
}

final class DataManager {

    static let sharedInstance = DataManager()
    
    static let tagsDidChangeNotification = Notification.Name("DataManager.tagsDidChange")
    static let transactionsDidChangeNotification = Notification.Name("DataManager.transactionsDidChange")

    private(set) var tags: [Tag] = []

    /// Seul propriétaire du stockage de l'app.
    private let container: NSPersistentContainer

    private var context: NSManagedObjectContext {
        container.viewContext
    }

    /// Le store SQLite est local : `loadPersistentStores` est synchrone, il est donc
    /// chargé avant le premier fetch. Sans store, l'app ne peut pas fonctionner et
    /// un `static let` ne peut pas lever d'erreur : `fatalError` est justifié ici.
    private init() {
        container = NSPersistentContainer(name: "Metrics")
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Impossible de charger le store Core Data : \(error)")
            }
        }

        do {
            try reloadTags()
        } catch {
            fatalError("Impossible de charger les tags depuis le store Core Data : \(error)")
        }
    }
    
    /// Sauvegarde le contexte. En cas d'échec, annule **toutes** les modifications
    /// non sauvegardées du contexte, puis relance l'erreur.
    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
    
    
    
    // MARK: - Tags
    
    /// Recharge le cache `tags` depuis le store, trié par nom.
    private func reloadTags() throws {
        let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.name), ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))]

        tags = try context.fetch(fetchRequest)
    }

    /// Crée un tag, sauvegarde, puis rafraîchit le cache `tags`.
    @discardableResult
    func addTag(name: String) throws -> Tag {
        let newTag = Tag(context: context)
        newTag.name = name

        try saveTagsAndRefreshCache()
        return newTag
    }

    private func saveTagsAndRefreshCache() throws {
        try save()
        try reloadTags()
        NotificationCenter.default.post(name: Self.tagsDidChangeNotification, object: nil)
    }
    
    
    
    // MARK: - Transactions
    
    /// Sauvegarde, puis prévient que les transactions ont changé.
    private func saveTransactionsAndNotify() throws {
        try save()
        NotificationCenter.default.post(name: Self.transactionsDidChangeNotification, object: nil)
    }

    /// Transactions du mois `monthKey` (format yyyyMM), de la plus récente à la plus ancienne :
    /// triées par jour (`dayKey`), puis par date de création pour un même jour.
    func transactions(forMonth monthKey: Int32) throws -> [Transaction] {
        
        let nextMonthKey = DateHelper.nextMonthKey(after: monthKey)

        let startDayKey = monthKey * 100 + 1
        let endDayKeyExclusive = nextMonthKey * 100 + 1

        let predicate = NSPredicate(
            format: "dayKey >= %@ AND dayKey < %@",
            argumentArray: [NSNumber(value: startDayKey), NSNumber(value: endDayKeyExclusive)]
        )
        let fetchRequest = NSFetchRequest<Transaction>(entityName: "Transaction")
        let sortByDay = NSSortDescriptor(key: #keyPath(Transaction.dayKey), ascending: false)
        let sortByCreation = NSSortDescriptor(key: #keyPath(Transaction.createdAt), ascending: false)
        fetchRequest.sortDescriptors = [sortByDay, sortByCreation]
        fetchRequest.predicate = predicate

        return try context.fetch(fetchRequest)
    }
    
    /// Crée une transaction datée de `date`, puis sauvegarde.
    /// - Throws: `DataManagerError` si le montant est nul ou la date invalide, ou l'erreur de sauvegarde.
    @discardableResult
    func addTransaction(
        amountInCents: Int64,
        date: Date,
        name: String?,
        tag: Tag?
    ) throws -> Transaction {
        
        guard amountInCents != 0 else {
            throw DataManagerError.zeroAmount
        }
        
        guard let dayKeyInt = Int32(DateHelper.dayKeyFormatter.string(from: date)) else {
            throw DataManagerError.invalidDate
        }
        
        let newTransaction = Transaction(context: context)
        newTransaction.id = UUID()
        newTransaction.createdAt = Date()
        newTransaction.dayKey = dayKeyInt
        newTransaction.amountInCents = amountInCents
        newTransaction.name = name
        newTransaction.tag = tag
        
        try saveTransactionsAndNotify()
        
        return newTransaction
    }
    
    /// Soldes cumulés jusqu'à la fin du mois `monthKey` (inclus) :
    /// - `executedInCents` : transactions exécutées
    /// - `forecastInCents` : toutes les transactions
    /// Une seule requête agrégée groupée par `executed` : SQLite fait la somme, aucun objet n'est chargé.
    /// La requête lit la base et pas le contexte : à appeler après `save()`.
    func balances(upToMonth monthKey: Int32) throws -> (executedInCents: Int64, forecastInCents: Int64) {

        // Borne exclue : 1er jour du mois suivant `monthKey`
        let nextMonthKey = DateHelper.nextMonthKey(after: monthKey)
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

        // Au plus 2 lignes : executed = true / executed = false
        for row in try context.fetch(fetchRequest) {
            let totalInCents = (row["totalInCents"] as? NSNumber)?.int64Value ?? 0

            if (row[#keyPath(Transaction.executed)] as? NSNumber)?.boolValue == true {
                executedInCents += totalInCents
            } else {
                pendingInCents += totalInCents
            }
        }

        return (executedInCents: executedInCents, forecastInCents: executedInCents + pendingInCents)
    }
    
    /// Clés de mois (yyyyMM) contenant au moins une transaction, de la plus récente à la plus ancienne.
    func monthKeys() throws -> [Int32] {
        
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Transaction")
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = [#keyPath(Transaction.dayKey)]
        fetchRequest.returnsDistinctResults = true
        
        // Le fetch renvoie des jours distincts : le Set dédoublonne les mois.
        var monthKeys: Set<Int32> = []
       
        for result in try context.fetch(fetchRequest) {
            if let dayKey = (result["dayKey"] as? NSNumber)?.int32Value {
                monthKeys.insert(dayKey / 100)
            }
        }
        
        return monthKeys.sorted(by: >)
    }
    
    /// Inverse l'état exécuté de `transaction`, puis sauvegarde.
    /// En cas d'échec, `transaction` retrouve son état d'origine (voir `save()`).
    func toggleExecuted(_ transaction: Transaction) throws {
        transaction.executed.toggle()
        try saveTransactionsAndNotify()
    }

    /// Supprime `transaction`, puis sauvegarde.
    /// En cas d'échec, la suppression est annulée et `transaction` reste valide (voir `save()`).
    func deleteTransaction(_ transaction: Transaction) throws {
        context.delete(transaction)
        try saveTransactionsAndNotify()
    }
    
}
