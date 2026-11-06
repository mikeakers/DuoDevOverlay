//
//  RowsViewController.swift
//  DuoDevOverlayUIKitDemo
//
//  A table of rows that push a detail screen, with bar buttons that toggle
//  the overlay and present a modal.
//

import DuoDevOverlay
import UIKit

final class RowsViewController: UITableViewController {
    init(title: String, symbol: String) {
        super.init(style: .insetGrouped)
        self.title = title
        tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbol), tag: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Overlay", image: UIImage(systemName: "square.dashed"),
            primaryAction: UIAction { [weak self] _ in self?.toggleOverlay() })
        // Both items have an image so they can show in the vertical bar the
        // outer screen moves them to; their titles stay the accessibility labels.
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Modal", image: UIImage(systemName: "rectangle.portrait.on.rectangle.portrait"),
            primaryAction: UIAction { [weak self] _ in self?.presentModal() })
        // A text field, to check the keyboard still comes up with the overlay installed.
        navigationItem.searchController = UISearchController()
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        40
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = "Row \(indexPath.row + 1)"
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let detail = UIViewController()
        detail.view.backgroundColor = .systemBackground
        detail.title = "Row \(indexPath.row + 1)"
        navigationController?.pushViewController(detail, animated: true)
    }

    private func toggleOverlay() {
        guard let scene = view.window?.windowScene else { return }
        if DuoDevOverlay.isInstalled(in: scene) {
            DuoDevOverlay.uninstall(from: scene)
        } else {
            DuoDevOverlay.install(in: scene)
        }
    }

    private func presentModal() {
        let modal = UIViewController()
        modal.view.backgroundColor = .systemBackground
        modal.title = "Modal"
        modal.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak modal] _ in modal?.dismiss(animated: true) })
        present(UINavigationController(rootViewController: modal), animated: true)
    }
}
