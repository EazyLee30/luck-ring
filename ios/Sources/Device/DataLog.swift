import Foundation

/// `funcType` labels, so captured packets are readable rather than bare numbers.
/// Kept as raw ints so nothing depends on how Swift renames the ObjC enum.
enum FuncType {
    static let names: [Int: String] = [
        0: "NULL", 2: "DEVINFO", 3: "BATTERY_INFO", 4: "REAL_SPORT", 5: "HISTORY_SPORT",
        6: "SLEEP", 7: "REAL_HEART", 8: "HISTORY_HEART", 9: "DEV_SYNC", 10: "MIX_SPORT",
        11: "FIND_PHONE_OR_DEVICE", 12: "BLE_PAIR_STATUS", 13: "USER_CHANGE", 14: "MUSIC_CONTROL",
        15: "CALL_CONTROL_TO_APP", 16: "GSENSOR_TEST", 17: "EXERCISE_HEART", 18: "REAL_BP",
        19: "REAL_ECG", 20: "REAL_O2", 21: "HR_CONTROL", 22: "FUNCTION_CONTROL", 23: "HARDWARE_INFO",
        24: "REAL_HR", 25: "BTEDR_ADDR", 26: "QR_CODE_INFO", 27: "QR_CODE_DEL", 28: "QR_CODE_CLEAN",
        29: "IPHONE_RESOLUTION", 30: "SMS_REPLAY", 31: "ALIPAY_RAW_DATA",
        40: "HISTORY_O2", 42: "HISTORY_HRV", 44: "GESTURE_CONFIG", 45: "REAL_HRV",
        47: "HISTORY_TEMP", 48: "SET_VALUABLE_ASSISTANT",
        102: "USERINFO", 103: "LANGUAGE_SETTING", 104: "TIME", 105: "WEATHER", 106: "ALARM",
        107: "MESSAGE_NOTICE", 108: "APP_CLOSE", 109: "SET_DATA_SWITCH", 110: "APP_SYNC",
        111: "SET_TARGET", 112: "OPEN_BLE_PAIR", 113: "MUSIC_CONTENT", 114: "SITTING_REMIND",
        115: "FORGET_DISTURB", 116: "PHOTOGRAPH_ONOFF", 117: "CALL_CONTROL_TO_DEV", 118: "RESET",
        119: "SHUTDOWN", 120: "PAIR_FINISH", 121: "UNIT_SETTING", 122: "CALL_ALARM",
        123: "MESSAGE_ALARM", 124: "MESSAGE_SWITCH", 125: "TARGET_ALARM", 126: "DRINK_ALARM",
        127: "HAND_RISE_SWITCH", 128: "HEART_AUTO_SWITCH", 129: "WATCH_SETTING", 130: "APP_SPORT",
        131: "WATCH_FACE_SYNC", 132: "WATCH_FACE_INFO", 133: "WOMAN_STAGE_INFO",
        134: "WATCH_FACE_START", 135: "CONTACT_ADD", 136: "CONTACT_DELETE", 137: "CONTACT_CLEAR",
        138: "CONTACT_SYNC", 139: "WEATHER_REAL_TIME", 140: "PHOTO_WATCHFACE_DEL",
        141: "POWER_LOGO_DEL", 143: "MOTION_GAME", 144: "MOTION_DATA",
        150: "EXTERN_WEATHER", 152: "LOCATION_INFO", 157: "SET_LEFT_RIGHT_HAND",
        201: "OTA_STATUS", 202: "OTA_DATA", 205: "FACTORY_TEST", 207: "CLEAN_DATA",
    ]

    static func name(_ raw: Int) -> String { names[raw] ?? "TYPE_\(raw)" }
}

/// Append-only JSONL capture of every frame in and out, plus each decoded
/// payload. Lands in `Documents/captures/` and is exposed to the Files app so a
/// session can be pulled off the device for analysis.
final class DataLog {
    static let shared = DataLog()

    private let queue = DispatchQueue(label: "com.luckring.datalog")
    private var handle: FileHandle?
    private(set) var fileURL = URL(fileURLWithPath: "/dev/null")

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
            let url = dir.appendingPathComponent("luckring-\(Int(Date().timeIntervalSince1970)).jsonl")
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
    func append(kind: String, funcType: Int? = nil, label: String = "", payload: Any? = nil) {
        queue.async {
            var obj: [String: Any] = [
                "ts": Self.formatter.string(from: Date()),
                "kind": kind,
            ]
            if let t = funcType {
                obj["funcType"] = t
                obj["funcTypeName"] = FuncType.name(t)
            }
            if !label.isEmpty { obj["label"] = label }
            if let p = payload { obj["payload"] = Self.jsonSafe(p) }

            guard let h = self.handle,
                  let line = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
                  let text = String(data: line, encoding: .utf8) else { return }
            h.write(Data((text + "\n").utf8))
        }
    }

    @discardableResult
    func appendHex(kind: String, _ data: Data) {
        let hex = data.map { String(format: "%02x", $0) }.joined(separator: " ")
        return append(kind: kind, label: "\(data.count)B", payload: hex)
    }

    /// NSDictionary values can hold non-JSON objects; normalise before encoding.
    static func jsonSafe(_ object: Any) -> Any {
        let out: Any
        if let d = object as? NSDictionary {
            var map: [String: Any] = [:]
            for (k, v) in d { map["\(k)"] = jsonSafe(v) }
            out = map
        } else if let a = object as? NSArray {
            out = a.map { jsonSafe($0) }
        } else if object is NSNumber || object is NSString || object is NSNull {
            out = object
        } else {
            out = "\(object)"
        }
        return JSONSerialization.isValidJSONObject(out) ? out : "\(object)"
    }
}