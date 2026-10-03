import SwiftUI
import BluetoothLibrary

/// Binds `RingBridge` to the vendor SDK. Only compiled into the device target —
/// the simulator/preview target uses `DemoRingBridge`.
final class DeviceRingBridge: RingBridge {

    var onRecords: (([IngestedRecord]) -> Void)?
    var onConnection: ((RingConnection) -> Void)?
    var onDiscovered: (([DiscoveredRing]) -> Void)?
    var onLogLine: ((String) -> Void)?

    private(set) var connection: RingConnection = .idle
    private var handshakeDone = false
    private var streaming = false

    private var k6: CEProductK6 { CEProductK6.shareInstance()! }
    private var tokens: [NSObjectProtocol] = []

    /// Packets the SDK declares but does not decode. See MotionResearch: there is
    /// no raw IMU stream exposed, and this captures the only evidence that could
    /// disprove that. Main-actor isolated because the inspector is observable.
    @MainActor lazy var motionInspector = MotionPacketInspector()

    func start() {
        DataLog.shared.start()

        k6.receiveOriginalDataHandler = { [weak self] data in
            guard let data else { return }
            DataLog.shared.appendHex(kind: "rx", data)
            self?.latestRawFrame = data
            self?.onLogLine?("rx \(data.count)B")
        }
        k6.sendOriginalDataHandler = { [weak self] data in
            guard let data else { return }
            DataLog.shared.appendHex(kind: "tx", data)
            self?.onLogLine?("tx \(data.count)B")
        }
        k6.connectStatusChanged = { [weak self] status in
            self?.apply(status: status)
        }

        let nc = NotificationCenter.default
        tokens.append(nc.addObserver(forName: Notification.Name(ScanPeripheralsNoticeKey),
                                     object: nil, queue: .main) { [weak self] note in
            let list = (note.object as? [SearchPeripheral] ?? [])
                .filter { $0.version() > 4 || $0.isPairedSystem }
            self?.onDiscovered?(list.map(Self.flatten))
        })
        tokens.append(nc.addObserver(forName: Notification.Name(CEProductK6ReceiveDataNoticeKey),
                                     object: nil, queue: .main) { [weak self] note in
            self?.parse(note.userInfo)
        })
        tokens.append(nc.addObserver(forName: Notification.Name(ProductStatusChangeNoticeKey),
                                     object: nil, queue: .main) { [weak self] note in
            let raw = (note.object as? NSNumber)?.intValue ?? -1
            if let s = ProductStatus(rawValue: raw) { self?.apply(status: s) }
        })

        onConnection?(.idle)
        scan()
    }

    func scan() {
        connection = .scanning
        onConnection?(.scanning)
        k6.startScan()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.k6.stopScan()
            if self?.connection == .scanning {
                self?.connection = .idle
                self?.onConnection?(.idle)
            }
        }
    }

    func connect(_ ring: DiscoveredRing) {
        connection = .connecting
        onConnection?(.connecting)
        guard let peripheral = peripheral(for: ring) else {
            onLogLine?("peripheral gone, rescan needed")
            connection = .idle
            onConnection?(.idle)
            return
        }
        k6.connect(peripheral)
    }

    func disconnect() {
        handshakeDone = false
        k6.releaseBind()
        connection = .idle
        onConnection?(.idle)
    }

    func refreshAll() {
        let cmds: [(CE_Cmd, String)] = [
            (CE_RequestDevInfoCmd(), "device info"),
            (CE_RequestBatteryCmd(), "battery"),
            (CE_RequestAllInfoCmd(), "all info"),
            (CE_RequestUserInfo(), "user info"),
            (CE_RequestSystemPairStatusCmd(), "pair status"),
        ]
        for (cmd, note) in cmds { send(cmd, note: note) }
    }

    func setSensorStreaming(_ on: Bool) {
        streaming = on
        let cmd = CE_SensorCmd()
        cmd.onoff = on ? 1 : 0
        send(cmd, note: on ? "sensor data ON — device will upload history" : "sensor data OFF")
    }

    func measure(kind: VitalKind) {
        switch kind {
        case .heart:
            let c = CE_SyncHeartRateCmd(); c.status = 1; send(c, note: "measure HR")
        case .bloodPressure:
            let c = CE_SyncBloodPressureCmd(); c.status = 1; send(c, note: "measure BP")
        case .oxygen:
            let c = CE_SyncHeartO2Cmd(); c.status = 1; send(c, note: "measure SpO2")
        }
    }

    // MARK: - Internals

    private var lastDiscovered: [SearchPeripheral] = []

    private func peripheral(for ring: DiscoveredRing) -> CBPeripheral? {
        lastDiscovered.first { Self.flatten($0).id == ring.id }?.peripheral
    }

    private func send(_ cmd: CE_Cmd, note: String) {
        let raw = cmd.funcType().rawValue
        onLogLine?("→ \(note) [funcType \(raw) \(FuncType.name(raw))]")
        k6.sendCmd(toDevice: cmd) { [weak self] error in
            if let error {
                self?.onLogLine?("✗ \(note): \(error.localizedDescription)")
            } else {
                self?.onLogLine?("✓ \(note)")
            }
        }
    }

    private func apply(status: ProductStatus) {
        switch status {
        case .completed:
            connection = .ready
            onConnection?(.ready)
            if !handshakeDone {
                handshakeDone = true
                postPairHandshake()
            }
        case .connected:
            connection = .awaitingConfirm
            onConnection?(.awaitingConfirm)
        case .connecting:
            connection = .connecting
            onConnection?(.connecting)
        case .searching:
            connection = .scanning
            onConnection?(.scanning)
        case .disconnected, .powerOff, .none:
            handshakeDone = false
            connection = .idle
            onConnection?(.idle)
        @unknown default:
            break
        }
    }

    /// Vendor-documented post-pair sequence.
    private func postPairHandshake() {
        onLogLine?("paired — handshake")
        setSensorStreaming(true)
        let sys = CE_SystemPairCmd(); sys.onoff = 1
        send(sys, note: "system pair ON")

        let time = CE_SyncTimeCmd()
        time.absTime = UInt32(Date().timeIntervalSince1970)
        time.offsetTime = Int32(TimeZone.current.secondsFromGMT())
        time.format = 1
        time.mdFormat = 1
        send(time, note: "sync time")

        let user = CE_SyncUserInfoCmd()
        user.userId = 0; user.sex = 0; user.age = 28; user.height = 175; user.weight = 70; user.lrHand = 1
        send(user, note: "sync user profile")

        let pair = CE_SyncPairOKCmd(); pair.firstPairStatus = 0
        send(pair, note: "confirm pairing")

        refreshAll()
        k6.saveConnectedUUid()
    }

    /// Turn a vendor payload into domain records.
    private func parse(_ userInfo: [AnyHashable: Any]?) {
        guard let info = userInfo else { return }
        let type = (info["DataType"] as? NSNumber)?.intValue ?? -1
        let payload = info["Data"]

        // Mixed packet: an array of sub-packets, each with its own DataType.
        if type == 9, let list = payload as? [Any] {
            var out: [IngestedRecord] = []
            for sub in list {
                guard let d = sub as? [String: Any] else { continue }
                let subType = (d["DataType"] as? NSNumber)?.intValue ?? -1
                out += records(for: subType, data: d["Data"])
            }
            onRecords?(out)
            return
        }

        if MotionResearch.undecodedFuncTypes.contains(type) {
            let frame = latestRawFrame
            Task { @MainActor in motionInspector.record(funcType: type, raw: frame) }
        }
        onRecords?(records(for: type, data: payload))
    }

    /// Last frame handed over by the SDK, kept so an undecoded payload can be
    /// examined as it arrived.
    private var latestRawFrame = Data()

    private func records(for type: Int, data: Any?) -> [IngestedRecord] {
        guard let dict = data as? [String: Any] else { return [] }
        var out: [IngestedRecord] = []

        switch type {
        case 2:  // DEVINFO
            let id = dict["ID"] as? NSNumber
            let mac = dict["macAddr"] as? String ?? dict["mac"] as? String
            out.append(.deviceInfo(mac ?? (id.map { "Ring \($0)" } ?? "Luck Ring"),
                                   dict["version"] as? String ?? "—"))

        case 3:  // BATTERY
            if let c = dict["battery_capacity"] as? NSNumber { out.append(.battery(c.intValue)) }

        case 6:  // SLEEP
            let list = dict["sleepInfos"] as? [[String: Any]] ?? []
            for item in list {
                guard let ts = (item["SleepStartTime"] as? NSNumber)?.doubleValue,
                      let raw = item["SleepType"] as? NSNumber,
                      let stage = SleepStage(rawValue: raw.intValue) else { continue }
                out.append(.sleepTransition(Date(timeIntervalSince1970: ts), stage))
            }

        case 4, 5:  // REAL / HISTORY SPORT
            let list = dict["sportInfos"] as? [[String: Any]] ?? []
            for item in list {
                let start = (item["startSecs"] as? NSNumber)?.doubleValue ?? 0
                out.append(.activity(ActivitySummary(
                    date: Date(timeIntervalSince1970: start),
                    steps: (item["walkSteps"] as? NSNumber)?.intValue ?? 0,
                    distanceMetres: (item["walkDistance"] as? NSNumber)?.intValue ?? 0,
                    activeSeconds: (item["walkDuration"] as? NSNumber)?.intValue ?? 0,
                    calories: (item["walkCalories"] as? NSNumber)?.intValue ?? 0)))
            }

        case 7, 8, 17, 24:  // REAL / HISTORY / EXERCISE HEART, auto HR
            let list = dict["heartInfos"] as? [[String: Any]] ?? []
            for item in list {
                guard let ts = item["time"] as? NSNumber, let bpm = item["heartNum"] as? NSNumber else { continue }
                out.append(.heartRate(HeartRateSample(
                    time: ts.doubleValue > 1e9
                        ? Date(timeIntervalSince1970: ts.doubleValue)
                        : Date(timeIntervalSince1970: ts.doubleValue * 1000),
                    bpm: bpm.intValue)))
            }

        case 18:  // BP
            for item in dict["data"] as? [[String: Any]] ?? [] {
                guard let ts = item["time"] as? NSNumber,
                      let s = item["systolic"] as? NSNumber,
                      let d = item["diastolic"] as? NSNumber else { continue }
                out.append(.bloodPressure(BloodPressureSample(
                    time: Date(timeIntervalSince1970: ts.doubleValue),
                    systolic: s.intValue, diastolic: d.intValue)))
            }

        case 20, 40:  // SpO2
            for item in dict["data"] as? [[String: Any]] ?? [] {
                guard let ts = item["time"] as? NSNumber,
                      let v = item["O2"] as? NSNumber else { continue }
                out.append(.oxygen(OxygenSample(
                    time: Date(timeIntervalSince1970: ts.doubleValue), spo2: v.intValue)))
            }

        case 42, 45:  // HRV history / realtime
            for item in dict["data"] as? [[String: Any]] ?? dict["hrvInfos"] as? [[String: Any]] ?? [] {
                guard let ts = item["time"] as? NSNumber,
                      let v = (item["HRV"] as? NSNumber) ?? (item["hrv"] as? NSNumber) else { continue }
                out.append(.hrv(HRVSample(
                    time: Date(timeIntervalSince1970: ts.doubleValue), ms: v.intValue)))
            }

        case 47:  // skin temperature
            for item in dict["data"] as? [[String: Any]] ?? dict["tempInfos"] as? [[String: Any]] ?? [] {
                guard let ts = item["time"] as? NSNumber,
                      let v = (item["temp"] as? NSNumber) ?? (item["temperature"] as? NSNumber) else { continue }
                out.append(.temperature(TemperatureSample(
                    time: Date(timeIntervalSince1970: ts.doubleValue),
                    celsius: v.doubleValue / 10.0)))
            }

        default:
            break
        }

        return out
    }

    private static func flatten(_ p: SearchPeripheral) -> DiscoveredRing {
        DiscoveredRing(id: p.deviceID() ?? UUID().uuidString,
                       name: p.name() ?? "Luck Ring",
                       deviceID: p.deviceID(),
                       mac: p.macAddress(),
                       rssi: p.rssi?.intValue ?? 0,
                       protocolVersion: p.version(),
                       systemPaired: p.isPairedSystem)
    }
}