import UIKit
import BluetoothLibrary

/// Step 1 — find the ring, then connect.
final class ScanViewController: UIViewController {

    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let scanButton = UIButton(type: .system)
    private var devices: [SearchPeripheral] = []
    private var ble = RingBLE.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Luck Ring"
        view.backgroundColor = .systemBackground

        statusLabel.text = RingBLE.describe(ble.status)
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center

        scanButton.setTitle("Scan for ring", for: .normal)
        scanButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        scanButton.backgroundColor = .systemBlue
        scanButton.setTitleColor(.white, for: .normal)
        scanButton.layer.cornerRadius = 10
        scanButton.addTarget(self, action: #selector(scan), for: .touchUpInside)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Auto", style: .plain, target: self, action: #selector(autoConnect))

        let stack = UIStackView(arrangedSubviews: [statusLabel, scanButton, tableView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            scanButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        ble.onPeripherals = { [weak self] list in
            guard let self else { return }
            // The SDK reports every BLE device it sees; keep the ones that speak
            // this protocol.
            let filtered = RingBLE.filter(list)
            self.devices = filtered
            self.tableView.reloadData()
            if filtered.isEmpty {
                self.statusLabel.text = "no matching devices found — ring on, close, and nearby?"
            }
        }
        ble.onStatus = { [weak self] status in
            self?.statusLabel.text = RingBLE.describe(status)
        }
        scan()
    }

    @objc private func scan() {
        scanButton.isEnabled = false
        statusLabel.text = "scanning…"
        ble.startScan(seconds: 5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { [weak self] in
            self?.scanButton.isEnabled = true
        }
    }

    @objc private func autoConnect() {
        ble.autoConnect()
        let vc = ReaderViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension ScanViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let d = devices[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = d.name() ?? "(unnamed)"
        content.secondaryText = "id=\(d.deviceID() ?? "?")  mac=\(d.macAddress() ?? "?")  "
            + "ver=\(d.version())  rssi=\(d.rssi?.intValue ?? 0)"
            + (d.isPairedSystem ? "  [system-paired]" : "")
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        ble.connect(devices[indexPath.row])
        let vc = ReaderViewController()
        vc.title = devices[indexPath.row].name()
        navigationController?.pushViewController(vc, animated: true)
    }
}