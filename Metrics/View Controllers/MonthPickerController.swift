//
//  MonthPickerController.swift
//  Metrics
//
//  Created by Alexis on 11/12/2022.
//

import UIKit

protocol MonthPickerControllerDelegate:AnyObject {
    func userChangedSelectedMonth(selectedKeyMonth:Int32)
}

/// Écran de sélection du mois à afficher.
///
/// - Charge depuis CoreData la liste des `monthKey` (format "yyyyMM"),
///   dérivée des `dayKey` existants, dédupliquée et triée du plus récent au plus ancien.
/// - Chaque cellule affiche le mois formaté via `DateHelper` (ex. "Octobre 2026").
/// - Au choix d'un mois, renvoie le `selectedMonthKey` à son delegate pour qu'il mette à jour son contenu.
class MonthPickerController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!

    weak var delegate: MonthPickerControllerDelegate?
    private var months: [Int32] = []
    private let reuseIdentifier = "GenericCell"
    
    
    
    // MARK: - Initialization
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init Table View
        let nib = UINib(nibName: reuseIdentifier, bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: reuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        
        if let sheet = self.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }

        loadMonths()
    }

    /// Récupère le `monthKey` pour chaque mois contenant au moins une transaction + celui du mois en cours
    private func loadMonths() {
        
        // Ajouter le mois en cours, même si aucune transaction n'est créée
        var monthKeys: Set<Int32> = [DateHelper.monthKey()]
        
        do {
            monthKeys.formUnion(try DataManager.sharedInstance.monthKeys())
        } catch {
            presentError(error, title: "Impossible de charger les mois")
        }
        
        months = monthKeys.sorted(by: >)
    }

    
    
    // MARK: - UITableView
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return months.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as! GenericCell
        cell.label.text = DateHelper.monthTitle(forMonthKey: months[indexPath.row])

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        delegate?.userChangedSelectedMonth(selectedKeyMonth: months[indexPath.row])
        dismiss(animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 64
    }
}
