//
//  TableViewController.swift
//  BNAppAuthExample
//
//  Created by Robin Bonin (BN) on 2023-09-01.
//

import BNAppAuth
import Foundation
import UIKit

class TableViewController: UITableViewController {
    
    lazy var loginButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .black
        button.addTarget(self, action: #selector(pressed), for: .touchUpInside)
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        return button
    }()
    
    lazy var refreshButton: UIButton = {
        let button = UIButton()
        button.setTitle("Force Refresh", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .systemGray6
        button.addTarget(self, action: #selector(refreshPressed), for: .touchUpInside)
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        return button
    }()
    
    lazy var getLoginToken: UIButton = {
        let button = UIButton()
        button.setTitle("Get Login Token", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .systemGray6
        button.addTarget(self, action: #selector(getLoginTokenPressed), for: .touchUpInside)
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigation()
        setupTableView()
        update()
    }
    
    private func setupTableView() {
        tableView.sectionHeaderTopPadding = 0
        tableView.estimatedRowHeight = 100
    }
    
    private func setupNavigation() {
        self.title = "BonnierNews AppAuth"
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.barTintColor = UIColor.black
        navigationController?.navigationBar.tintColor = UIColor.white
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.boldSystemFont(ofSize: 30)
        ]

        navigationController?.navigationBar.largeTitleTextAttributes = titleAttributes
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.isTranslucent = false
    }
    
    private var data: [(key: String, value: String)] = []
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            return data.count
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 189
        }
        return 30
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            let containerView = UIView()
            containerView.addSubview(loginButton)
            containerView.addSubview(refreshButton)
            containerView.addSubview(getLoginToken)
            loginButton.translatesAutoresizingMaskIntoConstraints = false
            refreshButton.translatesAutoresizingMaskIntoConstraints = false
            getLoginToken.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addConstraints([
                loginButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
                loginButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                loginButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                loginButton.heightAnchor.constraint(equalToConstant: 48),
                refreshButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 12),
                refreshButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                refreshButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                refreshButton.heightAnchor.constraint(equalToConstant: 44),
                getLoginToken.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 12),
                getLoginToken.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                getLoginToken.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                getLoginToken.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            return containerView
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return "Authentication tokens"
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "default") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "default")
        
        cell.textLabel?.text = data[indexPath.row].key
        cell.detailTextLabel?.text = data[indexPath.row].value
        cell.detailTextLabel?.numberOfLines = 0
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let selectedCell = tableView.cellForRow(at: indexPath) {
            let detailText = selectedCell.detailTextLabel?.text

            if let detailTextToCopy = detailText {
                UIPasteboard.general.string = detailTextToCopy
                showToast(message: "Copied \(selectedCell.textLabel?.text ?? "")")
            }
        }
    }
    
    private func showToast(message: String) {
        let toastLabel = UILabel(frame: CGRect(x: (self.view.frame.size.width - 325) / 2, y: self.view.frame.size.height-100, width: 325, height: 35))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true
        self.view.addSubview(toastLabel)

        UIView.animate(withDuration: 2.0, delay: 0.5, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: { _ in
            toastLabel.removeFromSuperview()
        })
    }
    
    @objc private func getLoginTokenPressed() {
        guard BNAppAuth.shared.isAuthorized else {
            showToast(message: "Du måste vara inloggad")
            return
        }
        
        BNAppAuth.shared.getIdToken(getLoginToken: true) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tokenResponse):
                    self?.data = [
                        tokenResponse.map { (key: "login_token", value: $0.loginToken!) }
                    ].compactMap { $0 }
                    DispatchQueue.main.async {
                        self?.tableView.reloadData()
                    }
                    self?.showToast(message: "Token uppdaterad")
                case .failure(let error):
                    self?.showToast(message: "Refresh misslyckades")
                    print("Refresh error: \(error)")
                }
            }
        }
    }
    
    @objc private func refreshPressed() {
        guard BNAppAuth.shared.isAuthorized else {
            showToast(message: "Du måste vara inloggad")
            return
        }
        
        BNAppAuth.shared.getIdToken(forceRefresh: true) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.update()
                    self?.showToast(message: "Token uppdaterad")
                case .failure(let error):
                    self?.showToast(message: "Refresh misslyckades")
                    print("Refresh error: \(error)")
                }
            }
        }
    }

    private func update() {
        loginButton.setTitle(!BNAppAuth.shared.isAuthorized ? "Logga in" : "Logga ut", for: .normal)
        
        BNAppAuth.shared.getIdToken { [weak self] result in
            switch result {
            case .success(let tokenResponse):
                self?.data = [
                    tokenResponse.map { (key: "x-bnidtoken", value: $0.idToken) }
                ].compactMap { $0 }
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
                
            case .failure(let error):
                print(error)
                self?.data = []
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    @objc private func pressed() {
        if !BNAppAuth.shared.isAuthorized {
            BNAppAuth.shared.login() { [weak self] _ in
                self?.update()
            }
        } else {
            BNAppAuth.shared.logout() { [weak self] result in
                self?.update()
                switch result {
                case .success(_):
                    print("Successfully logging out")
                case .failure(let error):
                    print("Error logging out: \(error)")
                }
                
            }
        }
    }
}
