import Foundation

/// Human readable names for `K6_DataFuncType` (a.k.a. the `DataType` field of the
/// notification payload). Kept as raw ints so the app does not depend on how
/// Swift renames the Objective-C enum cases.
enum FuncType {
    static let names: [Int: String] = [
        0: "NULL",
        2: "DEVINFO",
        3: "BATTERY_INFO",
        4: "REAL_SPORT",
        5: "HISTORY_SPORT",
        6: "SLEEP",
        7: "REAL_HEART",
        8: "HISTORY_HEART",
        9: "DEV_SYNC",
        10: "MIX_SPORT",
        11: "FIND_PHONE_OR_DEVICE",
        12: "BLE_PAIR_STATUS",
        13: "USER_CHANGE",
        14: "MUSIC_CONTROL",
        15: "CALL_CONTROL_TO_APP",
        16: "GSENSOR_TEST",
        17: "EXERCISE_HEART",
        18: "REAL_BP",
        19: "REAL_ECG",
        20: "REAL_O2",
        21: "HR_CONTROL",
        22: "FUNCTION_CONTROL",
        23: "HARDWARE_INFO",
        24: "REAL_HR",
        25: "BTEDR_ADDR",
        26: "QR_CODE_INFO",
        27: "QR_CODE_DEL",
        28: "QR_CODE_CLEAN",
        29: "IPHONE_RESOLUTION",
        30: "SMS_REPLAY",
        31: "ALIPAY_RAW_DATA",
        40: "HISTORY_O2",
        42: "HISTORY_HRV",
        44: "GESTURE_CONFIG",
        45: "REAL_HRV",
        47: "HISTORY_TEMP",
        48: "SET_VALUABLE_ASSISTANT",
        102: "USERINFO",
        103: "LANGUAGE_SETTING",
        104: "TIME",
        105: "WEATHER",
        106: "ALARM",
        107: "MESSAGE_NOTICE",
        108: "APP_CLOSE",
        109: "SET_DATA_SWITCH",
        110: "APP_SYNC",
        111: "SET_TARGET",
        112: "OPEN_BLE_PAIR",
        113: "MUSIC_CONTENT",
        114: "SITTING_REMIND",
        115: "FORGET_DISTURB",
        116: "PHOTOGRAPH_ONOFF",
        117: "CALL_CONTROL_TO_DEV",
        118: "RESET",
        119: "SHUTDOWN",
        120: "PAIR_FINISH",
        121: "UNIT_SETTING",
        122: "CALL_ALARM",
        123: "MESSAGE_ALARM",
        124: "MESSAGE_SWITCH",
        125: "TARGET_ALARM",
        126: "DRINK_ALARM",
        127: "HAND_RISE_SWITCH",
        128: "HEART_AUTO_SWITCH",
        129: "WATCH_SETTING",
        130: "APP_SPORT",
        131: "WATCH_FACE_SYNC",
        132: "WATCH_FACE_INFO",
        133: "WOMAN_STAGE_INFO",
        134: "WATCH_FACE_START",
        135: "CONTACT_ADD",
        136: "CONTACT_DELETE",
        137: "CONTACT_CLEAR",
        138: "CONTACT_SYNC",
        139: "WEATHER_REAL_TIME",
        140: "PHOTO_WATCHFACE_DEL",
        141: "POWER_LOGO_DEL",
        143: "MOTION_GAME",
        144: "MOTION_DATA",
        150: "EXTERN_WEATHER",
        152: "LOCATION_INFO",
        157: "SET_LEFT_RIGHT_HAND",
        201: "OTA_STATUS",
        202: "OTA_DATA",
        203: "TEST_DEBUG",
        204: "APP_TEST",
        205: "FACTORY_TEST",
        206: "LEAKLIGHT_TEST",
        207: "CLEAN_DATA",
    ]

    static func name(_ raw: Int) -> String { names[raw] ?? "TYPE_\(raw)" }

    /// Short description of the *value* of a packet, used for the summary line.
    static func summary(_ raw: Int, _ payload: Any?) -> String {
        guard let dict = payload as? [String: Any] else { return "" }
        func s(_ k: String) -> String {
            if let v = dict[k] as? NSNumber { return v.stringValue }
            if let v = dict[k] as? String { return v }
            return "-"
        }
        switch raw {
        case 2:  return "ID=\(s("ID")) customer=\(s("customer_id")) mac=\(s("macAddr")) fw=\(s("version"))"
        case 3:  return "battery=\(s("battery_capacity"))%"
        case 4, 5: return "steps=\(s("walkSteps")) dist=\(s("walkDistance")) cal=\(s("walkCalories")) dur=\(s("walkDuration"))"
        case 6:  return "count=\(dict["curItemCount"] as? NSNumber ?? 0) items"
        case 7, 8, 17, 24: return "count=\(dict["curItemCount"] as? NSNumber ?? 0) items"
        case 18: return "count=\(dict["curItemCount"] as? NSNumber ?? 0) items"
        case 20, 40: return "count=\(dict["curItemCount"] as? NSNumber ?? 0) items"
        case 42, 45: return "HRV count=\(dict["curItemCount"] as? NSNumber ?? 0)"
        case 47: return "TEMP count=\(dict["curItemCount"] as? NSNumber ?? 0)"
        case 22: return "bp=\(s("showBP")) o2=\(s("showO2")) ecg=\(s("showECG")) hr24h=\(s("hasHR24h")) temp/gesture unsupported-in-doc"
        case 23: return "w=\(s("width")) h=\(s("height")) rgb=\(s("rgb"))"
        case 106: return "count=\(dict["curItemCount"] as? NSNumber ?? 0) alarms"
        default: return ""
        }
    }
}

/// Append-only JSONL capture of everything the SDK hands us, so a session can be
/// pulled out of the app through the Files app (`UIFileSharingEnabled`).
final class DataLog {
    static let shared = DataLog()

    /// One decoded line: what arrived, when, and the payload.
    struct Entry {
        let ts: Date
        let kind: String          // data | tx | rx | state
        let funcType: Int?
        let label: String
        let payload: Any?
    }

    private(set) var entries: [Entry] = []
    private let queue = DispatchQueue(label: "com.luckring.datalog")
    private var handle: FileHandle?
    private(set) var fileURL: URL = URL(fileURLWithPath: "/dev/null")

    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    func start() {
        queue.sync {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("captures", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let name = "luckring-\(Int(Date().timeIntervalSince1970)).jsonl"
            let url = dir.appendingPathComponent(name)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
            fileURL = url
            print("[DataLog] capturing to \(url.path)")
        }
    }

    func stop() {
        queue.sync {
            try? handle?.close()
            handle = nil
        }
    }

    @discardableResult
    func append(kind: String, funcType: Int? = nil, label: String = "", payload: Any? = nil) -> Entry {
        let entry = Entry(ts: Date(), kind: kind, funcType: funcType, label: label, payload: payload)
        queue.async {
            self.entries.append(entry)
            if self.entries.count > 5000 { self.entries.removeFirst(self.entries.count - 5000) }
            guard let h = self.handle else { return }
            var obj: [String: Any] = [
                "ts": Self.formatter.string(from: entry.ts),
                "kind": entry.kind,
            ]
            if let t = entry.funcType {
                obj["funcType"] = t
                obj["funcTypeName"] = FuncType.name(t)
            }
            if !entry.label.isEmpty { obj["label"] = entry.label }
            if let p = entry.payload { obj["payload"] = Self.jsonSafe(p) }
            if let line = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
               let text = String(data: line, encoding: .utf8) {
                h.write(Data((text + "\n").utf8))
            }
        }
        return entry
    }

    func appendHex(kind: String, _ data: Data) -> Entry {
        let hex = data.map { String(format: "%02x", $0) }.joined(separator: " ")
        return append(kind: kind, label: "\(data.count)B", payload: hex)
    }

    /// NSDictionary values can contain non-JSON objects; normalise them.
    static func jsonSafe(_ object: Any) -> Any {
        let obj: Any
        if let d = object as? NSDictionary {
            var out: [String: Any] = [:]
            for (k, v) in d { out["\(k)"] = jsonSafe(v) }
            obj = out
        } else if let a = object as? NSArray {
            obj = a.map { jsonSafe($0) }
        } else if object is NSNumber || object is NSString || object is NSNull {
            obj = object
        } else {
            obj = "\(object)"
        }
        if JSONSerialization.isValidJSONObject(obj) { return obj }
        return "\(object)"
    }

    /// Pretty one-line summary for the on-screen console.
    static func line(for entry: Entry) -> String {
        let time = formatter.string(from: entry.ts)
        let head: String
        switch entry.kind {
        case "data":
            let t = entry.funcType ?? -1
            head = "DATA \(t) \(FuncType.name(t))"
        case "tx": head = "TX"
        case "rx": head = "RX"
        default:   head = entry.kind.uppercased()
        }
        var text = "\(time)  \(head)"
        let extra = FuncType.summary(entry.funcType ?? -1, entry.payload)
        if !extra.isEmpty { text += "  |  \(extra)" }
        if !entry.label.isEmpty { text += "  |  \(entry.label)" }
        if let p = entry.payload, extra.isEmpty, entry.kind != "rx", entry.kind != "tx" {
            let s = describe(p)
            if !s.isEmpty { text += "  |  \(s)" }
        }
        return text
    }

    /// Compact, deterministic rendering of a decoded payload for the console.
    static func describe(_ payload: Any?, depth: Int = 0) -> String {
        guard depth < 3 else { return "…" }
        if let d = payload as? [String: Any] {
            let body = d.keys.sorted().map { key -> String in
                let v = describe(d[key], depth: depth + 1)
                return "\(key)=\(v)"
            }.joined(separator: " ")
            return depth == 0 ? body : "{\(body)}"
        }
        if let a = payload as? [Any] {
            if a.isEmpty { return "[]" }
            let head = a.prefix(3).map { describe($0, depth: depth + 1) }.joined(separator: ",")
            return "[\(head)\(a.count > 3 ? ",…\(a.count)" : "")]"
        }
        if let n = payload as? NSNumber {
            // NSNumber happily bridges to Bool; keep it readable.
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
            if n.doubleValue == n.doubleValue.rounded() { return "\(n.intValue)" }
            return "\(n.doubleValue)"
        }
        if let s = payload as? String { return s.contains(" ") ? "\"\(s)\"" : s }
        return "\(payload ?? "nil")"
    }
}