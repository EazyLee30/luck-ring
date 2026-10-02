import Foundation
import CoreBluetooth
import BluetoothLibrary

/// Thin Swift façade over the vendor SDK (`BluetoothLibrary.framework`).
///
/// The whole SDK is built around one singleton, `CEProductK6`, plus three
/// NSNotification keys:
///   * `ScanPeripheralsNoticeKey`        -> [SearchPeripheral]
///   * `ProductStatusChangeNoticeKey`    -> NSNumber(ProductStatus)
///   * `CEProductK6ReceiveDataNoticeKey` -> userInfo dictionary
final class RingBLE {

    static let shared = RingBLE()

    // MARK: - Callbacks (all delivered on the main queue)

    var onPeripherals: (([SearchPeripheral]) -> Void)?
    var onStatus: ((ProductStatus) -> Void)?
    var onData: ((DataLog.Entry) -> Void)?

    // MARK: - Latest known device state

    private(set) var deviceInfo: [String: Any] = [:]
    private(set) var battery: Int?
    private(set) var functionControl: [String: Any] = [:]
    private(set) var hardwareInfo: [String: Any] = [:]
    private(set) var connectedName: String?
    private(set) var pid: Int = 0

    private var observerTokens: [NSObjectProtocol] = []
    private var handshakeDone = false

    private var k6: CEProductK6 { CEProductK6.shareInstance()! }

    private init() {
        k6.receiveOriginalDataHandler = { [weak self] data in
            guard let self, let data else { return }
            let e = DataLog.shared.appendHex(kind: "rx", data)
            DispatchQueue.main.async { self.onData?(e) }
        }
        k6.sendOriginalDataHandler = { [weak self] data in
            guard let self, let data else { return }
            let e = DataLog.shared.appendHex(kind: "tx", data)
            DispatchQueue.main.async { self.onData?(e) }
        }
        k6.connectStatusChanged = { [weak self] status in
            guard let self else { return }
            self.handle(status: status)
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard observerTokens.isEmpty else { return }
        DataLog.shared.start()

        let nc = NotificationCenter.default
        observerTokens.append(nc.addObserver(forName: Notification.Name(ScanPeripheralsNoticeKey),
                                             object: nil, queue: .main) { [weak self] note in
            self?.onPeripherals?(note.object as? [SearchPeripheral] ?? [])
        })
        observerTokens.append(nc.addObserver(forName: Notification.Name(ProductStatusChangeNoticeKey),
                                             object: nil, queue: .main) { [weak self] note in
            let raw = (note.object as? NSNumber)?.intValue ?? -1
            if let status = ProductStatus(rawValue: raw) { self?.handle(status: status) }
        })
        observerTokens.append(nc.addObserver(forName: Notification.Name(CEProductK6ReceiveDataNoticeKey),
                                             object: nil, queue: .main) { [weak self] note in
            self?.handlePayload(note.userInfo)
        })
    }

    func stop() {
        observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
        observerTokens.removeAll()
        DataLog.shared.stop()
    }

    private func handle(status: ProductStatus) {
        switch status {
        case .completed:
            if !handshakeDone { handshakeDone = true; postPairHandshake() }
        case .none, .powerOff, .searching, .connecting, .disconnected:
            if status != .searching { handshakeDone = false }
        @unknown default:
            break
        }
        onStatus?(status)
    }

    // MARK: - Scan / connect

    func startScan(seconds: TimeInterval = 4) {
        log("scanning for \(Int(seconds))s…", kind: "state")
        k6.startScan()
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.k6.stopScan()
        }
    }

    func stopScan() { k6.stopScan() }

    /// Keep only devices that speak this protocol revision (vendor demo filter).
    static func filter(_ all: [SearchPeripheral]) -> [SearchPeripheral] {
        all.filter { $0.version() > 4 || $0.isPairedSystem }
    }

    func connect(_ device: SearchPeripheral) {
        connectedName = device.name()
        log("connecting to \(device.name() ?? "?") id=\(device.deviceID() ?? "?") "
            + "mac=\(device.macAddress() ?? "?") ver=\(device.version())",
            kind: "state")
        guard let p = device.peripheral else {
            log("no CBPeripheral for \(device.deviceID() ?? "?")", kind: "state")
            return
        }
        k6.connect(p)
    }

    func disconnect() {
        handshakeDone = false
        log("releaseBind — also clears the auto-reconnect identity", kind: "state")
        k6.releaseBind()
    }

    func autoConnect() {
        log("startAutoConnect", kind: "state")
        k6.startAutoConnect()
    }

    func saveAutoConnectIdentity() {
        k6.saveConnectedUUid()
        log("auto-connect UUID saved: \(k6.lastConnectUUId ?? "-")", kind: "state")
    }

    var status: ProductStatus { k6.status }
    var statusText: String { RingBLE.describe(status) }

    static func describe(_ s: ProductStatus) -> String {
        switch s {
        case .none:         return "idle"
        case .powerOff:     return "bluetooth off"
        case .searching:    return "scanning"
        case .connecting:   return "connecting…"
        case .disconnected: return "disconnected"
        case .connected:    return "connected — tap the ring to confirm"
        case .completed:    return "paired & ready"
        @unknown default:   return "unknown(\(s.rawValue))"
        }
    }

    // MARK: - Commands

    /// The SDK owns a FIFO queue (one command in flight, next one goes out only
    /// after the ACK), so bursts are safe — everything still funnels through here
    /// so the console log and the JSONL capture stay in sync.
    func send(_ cmd: CE_Cmd, note: String) {
        let raw = cmd.funcType().rawValue
        log("→ \(note)  [funcType \(raw) \(FuncType.name(raw))]", kind: "state")
        k6.sendCmd(toDevice: cmd) { [weak self] error in
            if let error {
                self?.log("✗ \(note): \(error.localizedDescription)", kind: "state")
            } else {
                self?.log("✓ \(note) acked", kind: "state")
            }
        }
    }

    // Reads
    func readDeviceInfo() { send(CE_RequestDevInfoCmd(), note: "read device info") }
    func readBattery()     { send(CE_RequestBatteryCmd(), note: "read battery") }
    func readAllInfo()     { send(CE_RequestAllInfoCmd(), note: "read all info") }
    func readUserInfo()    { send(CE_RequestUserInfo(), note: "read user info") }
    func readPairStatus()  { send(CE_RequestSystemPairStatusCmd(), note: "read system pair status") }
    func readGoal()        { send(CE_RequestGoalCmd(), note: "read goal") }
    func readLongSit()     { send(CE_RequestLongSitCmd(), note: "read long-sit") }
    func readExercise()    { send(CE_RequestExerciseStatusCmd(), note: "read exercise status") }
    func readOTAStatus()   { send(CE_RequestOTAStatusCmd(), note: "read OTA status") }

    enum MeasureKind { case heart, bp, o2 }

    /// Ask the ring to run a live measurement; the result arrives asynchronously
    /// as DATA_TYPE_REAL_HEART / _BP / _O2.
    func measure(_ kind: MeasureKind) {
        switch kind {
        case .heart:
            let c = CE_SyncHeartRateCmd(); c.status = 1; send(c, note: "measure heart rate")
        case .bp:
            let c = CE_SyncBloodPressureCmd(); c.status = 1; send(c, note: "measure blood pressure")
        case .o2:
            let c = CE_SyncHeartO2Cmd(); c.status = 1; send(c, note: "measure SpO2")
        }
    }

    /// Historical steps / sleep / HR history are pushed by the device rather than
    /// requested. The ring only streams them while the sensor switch is open.
    func setSensor(_ on: Bool) {
        let c = CE_SensorCmd(); c.onoff = on ? 1 : 0
        send(c, note: on ? "sensor data ON (device will stream history)" : "sensor data OFF")
    }

    func syncTime() {
        let c = CE_SyncTimeCmd()
        c.absTime = UInt32(Date().timeIntervalSince1970)
        c.offsetTime = Int32(TimeZone.current.secondsFromGMT())
        c.format = 1      // 24h
        c.mdFormat = 1    // day-month
        send(c, note: "sync time")
    }

    func syncUserProfile(age: UInt8 = 28, height: UInt8 = 175, weight: UInt8 = 70, rightHand: Bool = true) {
        let c = CE_SyncUserInfoCmd()
        c.userId = 0
        c.sex = 0
        c.age = age
        c.height = height
        c.weight = weight
        c.lrHand = rightHand ? 1 : 0
        send(c, note: "sync user profile")
    }

    func clearDeviceData() { send(CE_ClearDataCmd(), note: "⚠︎ CLEAR device stored data") }

    // MARK: - Pairing handshake

    /// Vendor docs: after pairing completes the app must (1) open the sensor data
    /// switch, (2) announce system pairing, (3) push time, (4) read device info,
    /// (5) read OTA status.
    private func postPairHandshake() {
        log("paired — running post-connect handshake", kind: "state")
        setSensor(true)
        let sys = CE_SystemPairCmd(); sys.onoff = 1
        send(sys, note: "system pair ON")
        syncTime()
        syncUserProfile()
        let pair = CE_SyncPairOKCmd(); pair.firstPairStatus = 0
        send(pair, note: "confirm pairing")
        readDeviceInfo()
        readBattery()
        readOTAStatus()
        readAllInfo()
        saveAutoConnectIdentity()
    }

    // MARK: - Payload decoding

    private func handlePayload(_ userInfo: [AnyHashable: Any]?) {
        guard let info = userInfo else { return }
        let type = (info["DataType"] as? NSNumber)?.intValue ?? -1
        let desc = info["DataType_Description"] as? String ?? ""
        let err = info["error_msg"] as? String ?? ""
        let payload: Any? = info["Data"]

        // DATA_TYPE_DEV_SYNC (mixed packet) carries an array of sub-packets; fan
        // them out so every record lands in the log on its own line.
        if type == 9, let list = payload as? [Any] {
            _ = DataLog.shared.append(kind: "data", funcType: type, label: "mixed packet, \(list.count) records")
            for sub in list {
                guard let d = sub as? [String: Any] else { continue }
                let subType = (d["DataType"] as? NSNumber)?.intValue ?? -1
                let subDesc = d["DataType_Description"] as? String ?? ""
                let e = DataLog.shared.append(kind: "data", funcType: subType,
                                              label: subDesc, payload: d["Data"] ?? d)
                DispatchQueue.main.async { self.onData?(e) }
            }
            return
        }

        switch type {
        case 2:
            if let d = payload as? [String: Any] { deviceInfo = d; pid = k6.pid }
        case 3:
            if let d = payload as? [String: Any],
               let c = d["battery_capacity"] as? NSNumber { battery = c.intValue }
        case 22:
            if let d = payload as? [String: Any] { functionControl = d }
        case 23:
            if let d = payload as? [String: Any] { hardwareInfo = d }
        default:
            break
        }

        let label = [desc, err.isEmpty ? nil : "err=\(err)"].compactMap { $0 }.joined(separator: " ")
        let e = DataLog.shared.append(kind: "data", funcType: type, label: label, payload: payload)
        DispatchQueue.main.async { self.onData?(e) }
    }

    private func log(_ text: String, kind: String) {
        print("[RingBLE] \(text)")
        let e = DataLog.shared.append(kind: kind, label: text)
        DispatchQueue.main.async { self.onData?(e) }
    }
}