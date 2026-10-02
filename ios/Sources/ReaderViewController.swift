import UIKit
import BluetoothLibrary

/// Step 2 — read data. Every button sends one vendor command; every packet that
/// comes back is printed to the console and appended to a JSONL capture file.
final class ReaderViewController: UIViewController {

    private let ble = RingBLE.shared

    private let statusLabel = UILabel()
    private let summaryLabel = UILabel()
    private let logView = UITextView()
    private var lineCount = 0
    private var buttonsStack: UIStackView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save", style: .plain, target: self, action: #selector(saveLog))
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Unbind", style: .plain, target: self, action: #selector(unbind))

        buildUI()
        wireBLE()

        // A quick sanity read right away, in case we were pushed after connecting.
        ble.readDeviceInfo()
        ble.readBattery()
    }

    // MARK: - UI

    private func buildUI() {
        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = .systemBlue
        statusLabel.textAlignment = .center
        statusLabel.text = RingBLE.describe(ble.status)

        summaryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 0
        summaryLabel.text = "waiting for device…"

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 8

        let rows: [[(String, Selector)]] = [
            [("Device info", #selector(tapDeviceInfo)), ("Battery", #selector(tapBattery)),
             ("All info", #selector(tapAllInfo))],
            [("HR", #selector(tapHR)), ("BP", #selector(tapBP)),
             ("SpO2", #selector(tapO2))],
            [("User info", #selector(tapUserInfo)), ("Goal", #selector(tapGoal)),
             ("Pair status", #selector(tapPair))],
            [("Long-sit", #selector(tapLongSit)), ("Exercise", #selector(tapExercise)),
             ("OTA status", #selector(tapOTA))],
            [("Sync time", #selector(tapSyncTime)), ("Sync profile", #selector(tapSyncProfile)),
             ("Auto-reconnect", #selector(tapSave))],
            [("Sensor ON", #selector(tapSensorOn)), ("Sensor OFF", #selector(tapSensorOff)),
             ("Clear data ⚠︎", #selector(tapClear))],
        ]
        for row in rows {
            let h = UIStackView()
            h.axis = .horizontal
            h.spacing = 8
            h.distribution = .fillEqually
            for (label, action) in row {
                let b = UIButton(type: .system)
                b.setTitle(label, for: .normal)
                b.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
                b.titleLabel?.adjustsFontSizeToFitWidth = true
                b.backgroundColor = .secondarySystemBackground
                b.layer.cornerRadius = 8
                b.addTarget(self, action: action, for: .touchUpInside)
                h.addArrangedSubview(b)
            }
            grid.addArrangedSubview(h)
        }
        buttonsStack = grid

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        logView.backgroundColor = .secondarySystemBackground
        logView.layer.cornerRadius = 8
        logView.text = ""
        logView.accessibilityIdentifier = "console"

        let stack = UIStackView(arrangedSubviews: [statusLabel, grid, summaryLabel, logView])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            logView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
        ])
    }

    // MARK: - BLE wiring

    private func wireBLE() {
        ble.onStatus = { [weak self] status in
            guard let self else { return }
            self.statusLabel.text = RingBLE.describe(status)
            if status == .completed { self.ble.readAllInfo() }
        }
        ble.onData = { [weak self] entry in
            self?.append(DataLog.line(for: entry))
            self?.refreshSummary()
        }
    }

    private func append(_ text: String) {
        var lines = (logView.text ?? "").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        lines.append(text)
        // Keep the on-screen console bounded; the full capture lives in the JSONL file.
        if lines.count > 2000 { lines.removeFirst(lines.count - 2000) }
        logView.text = lines.joined(separator: "\n")
        lineCount = lines.count
        let end = NSRange(location: (logView.text as NSString).length - 1, length: 1)
        if !logView.text.isEmpty { logView.scrollRangeToVisible(end) }
        print("[console] \(text)")
    }

    private func refreshSummary() {
        var lines: [String] = []
        if !ble.deviceInfo.isEmpty {
            let d = ble.deviceInfo
            lines.append("device : \(d["ID"] ?? "?")  fw=\(d["version"] ?? "?")  mac=\(d["macAddr"] ?? "?")")
            lines.append("         customer=\(d["customer_id"] ?? "?")  pid=\(ble.pid)  name=\(ble.connectedName ?? "?")")
        }
        if let b = ble.battery { lines.append("battery: \(b)%") }
        if !ble.hardwareInfo.isEmpty {
            let h = ble.hardwareInfo
            lines.append("lcd    : \(h["width"] ?? "?")x\(h["height"] ?? "?")  rgb=\(h["rgb"] ?? "?")")
        }
        if !ble.functionControl.isEmpty {
            let f = ble.functionControl
            let flags = ["showBP", "showO2", "showECG", "hasHR24h", "hasEDR", "manualHr", "hasMenstrualCycle"]
                .compactMap { k -> String? in
                    guard let v = f[k] as? NSNumber else { return nil }
                    return v.boolValue ? k : nil
                }
            lines.append("caps   : \(flags.isEmpty ? "base" : flags.joined(separator: " "))")
        }
        summaryLabel.text = lines.isEmpty ? "waiting for device…" : lines.joined(separator: "\n")
    }

    // MARK: - Actions

    @objc private func tapDeviceInfo() { ble.readDeviceInfo() }
    @objc private func tapBattery()     { ble.readBattery() }
    @objc private func tapAllInfo()     { ble.readAllInfo() }
    @objc private func tapHR()         { ble.measure(.heart) }
    @objc private func tapBP()         { ble.measure(.bp) }
    @objc private func tapO2()         { ble.measure(.o2) }
    @objc private func tapUserInfo()    { ble.readUserInfo() }
    @objc private func tapGoal()        { ble.readGoal() }
    @objc private func tapPair()        { ble.readPairStatus() }
    @objc private func tapLongSit()     { ble.readLongSit() }
    @objc private func tapExercise()    { ble.readExercise() }
    @objc private func tapOTA()         { ble.readOTAStatus() }
    @objc private func tapSyncTime()    { ble.syncTime() }
    @objc private func tapSyncProfile() { ble.syncUserProfile() }
    @objc private func tapSave()        { ble.saveAutoConnectIdentity() }
    @objc private func tapSensorOn()    { ble.setSensor(true) }
    @objc private func tapSensorOff()   { ble.setSensor(false) }

    @objc private func tapClear() {
        let alert = UIAlertController(title: "Clear stored data?",
                                      message: "This erases the history stored on the ring (steps, sleep, HR). Cannot be undone.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Erase", style: .destructive) { [weak self] _ in
            self?.ble.clearDeviceData()
        })
        present(alert, animated: true)
    }

    @objc private func unbind() {
        let alert = UIAlertController(title: "Unbind ring?",
                                      message: "Clears the saved Bluetooth identity so the ring has to be paired again.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Unbind", style: .destructive) { [weak self] _ in
            self?.ble.disconnect()
        })
        present(alert, animated: true)
    }

    @objc private func saveLog() {
        let url = DataLog.shared.fileURL
        let text = logView.text ?? ""
        print("[export] capture: \(url.path)")
        print("[export] console:\n\(text)")

        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        share.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(share, animated: true)
    }
}