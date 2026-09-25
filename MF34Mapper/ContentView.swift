import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

// MARK: - Colors (9% Deep Gray Theme & Mode Indicators)
extension Color {
    static let deepGrayBg = Color(red: 0.09, green: 0.09, blue: 0.09) // 9% Chrome Dark
    static let buttonDarkGray = Color(red: 0.16, green: 0.16, blue: 0.17)
    static let surfaceGray = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let accentRed = Color(red: 0.95, green: 0.20, blue: 0.20)
    static let deepCobaltBlue = Color(red: 0.18, green: 0.34, blue: 0.52)
    
    // 파란놈 / 노란놈 인디케이터 색상
    static let modeBlue = Color(red: 0.20, green: 0.55, blue: 0.95)   // Wireless
    static let modeYellow = Color(red: 0.98, green: 0.78, blue: 0.18) // Wired
}

// MARK: - App Language Support
enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "한국어"
    case english = "English"
    
    var id: String { rawValue }
}

// MARK: - Connection Mode
enum MF34ConnectionMode: String, CaseIterable, Identifiable, Codable {
    case wired = "Wired"
    case wireless = "Wireless"
    
    var id: String { rawValue }
}

// MARK: - Models
struct MF34Key: Identifiable, Hashable {
    let id: String
    let defaultCode: String
    let displayLabel: String
    let isGrayKeycap: Bool
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

struct KeyMapping: Identifiable, Codable {
    var id: String { keyId }
    let keyId: String
    var toKeyCode: String
    var modifiers: [String]
    var isModified: Bool
}

// MARK: - Helper Functions
func sanitizeKarabinerKeyCode(_ code: String) -> String {
    let lower = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch lower {
    case "key_24", "=": return "equal_sign"
    case "key_27", "-": return "hyphen"
    case "key_33", "[": return "open_bracket"
    case "key_30", "]": return "close_bracket"
    case "key_42", "\\": return "backslash"
    case "key_41", ";": return "semicolon"
    case "key_39", "'": return "quote"
    case "key_43", ",": return "comma"
    case "key_47", ".": return "period"
    case "key_44", "/": return "slash"
    case "key_50", "`": return "grave_accent_and_tilde"
    case "key_49": return "spacebar"
    case "key_36": return "return_or_enter"
    case "key_51": return "delete_or_backspace"
    case "key_48": return "tab"
    case "key_53": return "escape"
    default:
        return lower
    }
}

func isKeypadKeyCode(_ code: String) -> Bool {
    let lower = code.lowercased()
    return lower.starts(with: "keypad_")
}

func formatModifierSymbols(_ modifiers: [String]) -> String {
    var symbols = ""
    if modifiers.contains("left_control") { symbols += "⌃" }
    if modifiers.contains("left_option") { symbols += "⌥" }
    if modifiers.contains("left_shift") { symbols += "⇧" }
    if modifiers.contains("left_command") { symbols += "⌘" }
    return symbols
}

func formatDisplayKeyLabel(_ rawCode: String) -> String {
    let sanitized = sanitizeKarabinerKeyCode(rawCode)
    switch sanitized {
    case "keypad_0": return "0"
    case "keypad_1": return "1"
    case "keypad_2": return "2"
    case "keypad_3": return "3"
    case "keypad_4": return "4"
    case "keypad_5": return "5"
    case "keypad_6": return "6"
    case "keypad_7": return "7"
    case "keypad_8": return "8"
    case "keypad_9": return "9"
    case "keypad_slash": return "/"
    case "keypad_asterisk": return "*"
    case "keypad_hyphen": return "-"
    case "keypad_plus": return "+"
    case "keypad_period": return "."
    case "keypad_enter": return "ENT"
    case "keypad_equal_sign", "equal_sign": return "="
    case "hyphen": return "-"
    case "open_bracket": return "["
    case "close_bracket": return "]"
    case "comma": return ","
    case "period": return "."
    case "semicolon": return ";"
    case "quote": return "'"
    case "grave_accent_and_tilde": return "`"
    case "backslash": return "\\"
    case "slash": return "/"
    case "left_option", "right_option": return "⌥"
    case "left_command", "right_command": return "⌘"
    case "left_shift", "right_shift": return "⇧"
    case "left_control", "right_control": return "⌃"
    case "up_arrow": return "↑"
    case "down_arrow": return "↓"
    case "left_arrow": return "←"
    case "right_arrow": return "→"
    case "return_or_enter": return "⏎"
    case "delete_or_backspace": return "⌫"
    case "delete_forward": return "DEL"
    case "escape": return "ESC"
    case "tab": return "TAB"
    case "spacebar": return "SPC"
    case "f13": return "F13"
    case "f14": return "F14"
    case "f15", "al_calculator": return "F15"
    default:
        return sanitized.replacingOccurrences(of: "keypad_", with: "").uppercased()
    }
}

// MARK: - ViewModel
class MF34ViewModel: ObservableObject {
    @Published var activeProfileIndex: Int = 1 {
        didSet {
            mappings = profiles[activeProfileIndex] ?? defaultMappings()
            if let savedMode = profileModes[activeProfileIndex] {
                connectionMode = savedMode
            }
            selectedKey = nil
            stagingCode = ""
            stagingModifiers = []
            lastModifiedMessage = nil
            UserDefaults.standard.set(activeProfileIndex, forKey: "MF34_ActiveProfileIndex")
        }
    }
    
    // 기본 언어: 한국어
    @Published var appLanguage: AppLanguage = .korean {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "MF34_AppLanguage")
        }
    }
    
    @Published var profileModes: [Int: MF34ConnectionMode] = [
        1: .wireless,
        2: .wireless,
        3: .wireless
    ]
    
    @Published var connectionMode: MF34ConnectionMode = .wireless {
        didSet {
            UserDefaults.standard.set(connectionMode.rawValue, forKey: "MF34_ConnectionMode")
        }
    }
    
    @Published var wiredVendorId: Int = 1046 {
        didSet { UserDefaults.standard.set(wiredVendorId, forKey: "MF34_WiredVID") }
    }
    @Published var wiredProductId: Int = 41184 {
        didSet { UserDefaults.standard.set(wiredProductId, forKey: "MF34_WiredPID") }
    }
    
    let wirelessVendorId: Int = 1578
    let wirelessProductId: Int = 16641
    
    var currentVendorId: Int {
        connectionMode == .wireless ? wirelessVendorId : wiredVendorId
    }
    
    var currentProductId: Int {
        connectionMode == .wireless ? wirelessProductId : wiredProductId
    }
    
    var currentKeyboardImageName: String {
        connectionMode == .wired ? "image_03" : "image_02"
    }
    
    @Published var profiles: [Int: [String: KeyMapping]] = [:]
    @Published var mappings: [String: KeyMapping] = [:]
    @Published var selectedKey: MF34Key? = nil
    
    @Published var stagingCode: String = ""
    @Published var stagingModifiers: [String] = []
    @Published var lastModifiedMessage: String? = nil
    
    let keys: [MF34Key] = [
        // --- [Row 0: 상단 7키 (모두 그레이 키캡)] ---
        MF34Key(id: "esc", defaultCode: "escape", displayLabel: "ESC", isGrayKeycap: true, x: 105.0, y: 144.5, width: 73.9, height: 75.6),
        MF34Key(id: "space_top", defaultCode: "spacebar", displayLabel: "SPC", isGrayKeycap: true, x: 178.1, y: 144.5, width: 72.2, height: 75.6),
        MF34Key(id: "equal_top", defaultCode: "equal_sign", displayLabel: "=", isGrayKeycap: true, x: 250.7, y: 144.5, width: 73.1, height: 75.6),
        
        MF34Key(id: "f13", defaultCode: "f13", displayLabel: "F13", isGrayKeycap: true, x: 345.7, y: 144.5, width: 73.1, height: 75.6),
        MF34Key(id: "f14", defaultCode: "f14", displayLabel: "F14", isGrayKeycap: true, x: 418.3, y: 144.5, width: 72.2, height: 75.6),
        MF34Key(id: "calc", defaultCode: "f15", displayLabel: "F15", isGrayKeycap: true, x: 491.0, y: 144.5, width: 73.1, height: 75.6),
        MF34Key(id: "bs_top", defaultCode: "delete_or_backspace", displayLabel: "⌫", isGrayKeycap: true, x: 564.5, y: 144.5, width: 73.9, height: 75.6),
        
        // --- [Row 1: 좌측 3키 (그레이) & 넘버패드 상단 4키 (그레이)] ---
        MF34Key(id: "tab", defaultCode: "tab", displayLabel: "TAB", isGrayKeycap: true, x: 105.0, y: 240.7, width: 73.9, height: 74.8),
        MF34Key(id: "home", defaultCode: "home", displayLabel: "HOME", isGrayKeycap: true, x: 178.1, y: 240.7, width: 72.2, height: 74.8),
        MF34Key(id: "pgup", defaultCode: "page_up", displayLabel: "PGUP", isGrayKeycap: true, x: 250.7, y: 240.7, width: 73.1, height: 74.8),
        
        MF34Key(id: "numlock", defaultCode: "keypad_num_lock", displayLabel: "NUM", isGrayKeycap: true, x: 345.7, y: 240.7, width: 73.1, height: 74.8),
        MF34Key(id: "kp_slash", defaultCode: "keypad_slash", displayLabel: "/", isGrayKeycap: true, x: 418.3, y: 240.7, width: 72.2, height: 74.8),
        MF34Key(id: "kp_ast", defaultCode: "keypad_asterisk", displayLabel: "*", isGrayKeycap: true, x: 491.0, y: 240.7, width: 73.1, height: 74.8),
        MF34Key(id: "kp_minus", defaultCode: "keypad_hyphen", displayLabel: "-", isGrayKeycap: true, x: 564.5, y: 240.7, width: 73.9, height: 74.8),
        
        // --- [Row 2: 좌측 3키 (그레이), 7/8/9 (화이트), + (그레이 2U)] ---
        MF34Key(id: "del", defaultCode: "delete_forward", displayLabel: "DEL", isGrayKeycap: true, x: 105.0, y: 314.2, width: 73.9, height: 72.2),
        MF34Key(id: "end", defaultCode: "end", displayLabel: "END", isGrayKeycap: true, x: 178.1, y: 314.2, width: 72.2, height: 72.2),
        MF34Key(id: "pgdn", defaultCode: "page_down", displayLabel: "PGDN", isGrayKeycap: true, x: 250.7, y: 314.2, width: 73.1, height: 72.2),
        
        MF34Key(id: "kp_7", defaultCode: "keypad_7", displayLabel: "7", isGrayKeycap: false, x: 345.7, y: 314.2, width: 73.1, height: 72.2),
        MF34Key(id: "kp_8", defaultCode: "keypad_8", displayLabel: "8", isGrayKeycap: false, x: 418.3, y: 314.2, width: 72.2, height: 72.2),
        MF34Key(id: "kp_9", defaultCode: "keypad_9", displayLabel: "9", isGrayKeycap: false, x: 491.0, y: 314.2, width: 73.1, height: 72.2),
        MF34Key(id: "kp_plus", defaultCode: "keypad_plus", displayLabel: "+", isGrayKeycap: true, x: 564.5, y: 348.6, width: 73.9, height: 141.1),
        
        // --- [Row 3: 넘버패드 4, 5, 6 (모두 화이트 키캡)] ---
        MF34Key(id: "kp_4", defaultCode: "keypad_4", displayLabel: "4", isGrayKeycap: false, x: 345.7, y: 384.7, width: 73.1, height: 68.9),
        MF34Key(id: "kp_5", defaultCode: "keypad_5", displayLabel: "5", isGrayKeycap: false, x: 418.3, y: 384.7, width: 72.2, height: 68.9),
        MF34Key(id: "kp_6", defaultCode: "keypad_6", displayLabel: "6", isGrayKeycap: false, x: 491.0, y: 384.7, width: 73.1, height: 68.9),
        
        // --- [Row 4: 방향키 위(화이트), 넘버패드 1, 2, 3 (화이트), ENTER (2U)] ---
        MF34Key(id: "up", defaultCode: "up_arrow", displayLabel: "↑", isGrayKeycap: false, x: 178.1, y: 454.9, width: 72.2, height: 71.4),
        
        MF34Key(id: "kp_1", defaultCode: "keypad_1", displayLabel: "1", isGrayKeycap: false, x: 345.7, y: 454.9, width: 73.1, height: 71.4),
        MF34Key(id: "kp_2", defaultCode: "keypad_2", displayLabel: "2", isGrayKeycap: false, x: 418.3, y: 454.9, width: 72.2, height: 71.4),
        MF34Key(id: "kp_3", defaultCode: "keypad_3", displayLabel: "3", isGrayKeycap: false, x: 491.0, y: 454.9, width: 73.1, height: 71.4),
        MF34Key(id: "kp_enter", defaultCode: "keypad_enter", displayLabel: "ENT", isGrayKeycap: false, x: 564.5, y: 490.6, width: 73.9, height: 142.8),
        
        // --- [Row 5: 방향키 좌/하/우 (화이트), 넘버패드 0 (화이트 2U), . (화이트)] ---
        MF34Key(id: "left", defaultCode: "left_arrow", displayLabel: "←", isGrayKeycap: false, x: 105.0, y: 526.3, width: 73.9, height: 71.4),
        MF34Key(id: "down", defaultCode: "down_arrow", displayLabel: "↓", isGrayKeycap: false, x: 178.1, y: 526.3, width: 72.2, height: 71.4),
        MF34Key(id: "right", defaultCode: "right_arrow", displayLabel: "→", isGrayKeycap: false, x: 250.7, y: 526.3, width: 73.1, height: 71.4),
        
        MF34Key(id: "kp_0", defaultCode: "keypad_0", displayLabel: "0", isGrayKeycap: false, x: 382.0, y: 526.3, width: 145.3, height: 71.4),
        MF34Key(id: "kp_dot", defaultCode: "keypad_period", displayLabel: ".", isGrayKeycap: false, x: 491.0, y: 526.3, width: 73.1, height: 71.4)
    ]
    
    init() {
        loadPersistedProfiles()
    }
    
    func defaultMappings() -> [String: KeyMapping] {
        var map: [String: KeyMapping] = [:]
        for k in keys {
            map[k.id] = KeyMapping(keyId: k.id, toKeyCode: k.defaultCode, modifiers: [], isModified: false)
        }
        return map
    }
    
    func loadPersistedProfiles() {
        let savedIndex = UserDefaults.standard.integer(forKey: "MF34_ActiveProfileIndex")
        activeProfileIndex = (savedIndex >= 1 && savedIndex <= 3) ? savedIndex : 1
        
        if let savedLang = UserDefaults.standard.string(forKey: "MF34_AppLanguage"),
           let lang = AppLanguage(rawValue: savedLang) {
            appLanguage = lang
        } else {
            appLanguage = .korean
        }
        
        let savedWiredVID = UserDefaults.standard.integer(forKey: "MF34_WiredVID")
        if savedWiredVID != 0 { wiredVendorId = savedWiredVID }
        
        let savedWiredPID = UserDefaults.standard.integer(forKey: "MF34_WiredPID")
        if savedWiredPID != 0 { wiredProductId = savedWiredPID }
        
        for idx in 1...3 {
            if let savedModeStr = UserDefaults.standard.string(forKey: "MF34_ProfileMode_\(idx)"),
               let mode = MF34ConnectionMode(rawValue: savedModeStr) {
                profileModes[idx] = mode
            }
            
            if let data = UserDefaults.standard.data(forKey: "MF34_Profile_\(idx)"),
               var decoded = try? JSONDecoder().decode([String: KeyMapping].self, from: data) {
                for (k, v) in decoded {
                    let sanitized = sanitizeKarabinerKeyCode(v.toKeyCode)
                    if sanitized != v.toKeyCode {
                        decoded[k]?.toKeyCode = sanitized
                    }
                }
                profiles[idx] = decoded
            } else {
                profiles[idx] = defaultMappings()
            }
        }
        
        connectionMode = profileModes[activeProfileIndex] ?? .wireless
        mappings = profiles[activeProfileIndex] ?? defaultMappings()
    }
    
    func saveCurrentProfile() {
        objectWillChange.send()
        
        for k in keys {
            if var m = mappings[k.id] {
                m.isModified = false
                m.toKeyCode = sanitizeKarabinerKeyCode(m.toKeyCode)
                mappings[k.id] = m
            }
        }
        selectedKey = nil
        stagingCode = ""
        stagingModifiers = []
        
        let isKor = appLanguage == .korean
        let modeName = connectionMode == .wireless ? (isKor ? "Wireless(파란색)" : "Wireless (Blue)") : (isKor ? "Wired(노란색)" : "Wired (Yellow)")
        
        lastModifiedMessage = isKor
            ? "레이아웃 \(activeProfileIndex)번에 [\(modeName)] 키맵이 저장되었습니다."
            : "Layout \(activeProfileIndex) saved with [\(modeName)] profile."
        
        profileModes[activeProfileIndex] = connectionMode
        UserDefaults.standard.set(connectionMode.rawValue, forKey: "MF34_ProfileMode_\(activeProfileIndex)")
        
        profiles[activeProfileIndex] = mappings
        if let data = try? JSONEncoder().encode(mappings) {
            UserDefaults.standard.set(data, forKey: "MF34_Profile_\(activeProfileIndex)")
        }
    }
    
    func resetCurrentProfileToDefault() {
        objectWillChange.send()
        mappings = defaultMappings()
        saveCurrentProfile()
        
        let isKor = appLanguage == .korean
        lastModifiedMessage = isKor
            ? "레이아웃 \(activeProfileIndex)번이 기본 공장 초기화 상태로 복원되었습니다."
            : "Layout \(activeProfileIndex) restored to default factory settings."
    }
    
    func resetSelectedKey() {
        guard let key = selectedKey else { return }
        stagingCode = ""
        stagingModifiers = []
        mappings[key.id] = KeyMapping(keyId: key.id, toKeyCode: key.defaultCode, modifiers: [], isModified: false)
    }
    
    func commitStagingMapping() {
        guard let key = selectedKey else { return }
        let rawFinalCode = stagingCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sanitizedCode = sanitizeKarabinerKeyCode(rawFinalCode.isEmpty ? key.defaultCode : rawFinalCode)
        let isCodeChanged = (sanitizedCode != key.defaultCode)
        let isModified = isCodeChanged || !stagingModifiers.isEmpty
        
        mappings[key.id] = KeyMapping(
            keyId: key.id,
            toKeyCode: sanitizedCode,
            modifiers: stagingModifiers,
            isModified: isModified
        )
        
        let syms = formatModifierSymbols(stagingModifiers)
        let displayTarget = formatDisplayKeyLabel(sanitizedCode)
        let fullDesc = syms.isEmpty ? displayTarget : "\(syms) \(displayTarget)"
        
        let isKor = appLanguage == .korean
        lastModifiedMessage = isKor
            ? "[\(key.displayLabel)] 키가 [\(fullDesc)] 로 설정되었습니다."
            : "[\(key.displayLabel)] key is now configured to [\(fullDesc)]."
        
        selectedKey = nil
        stagingCode = ""
        stagingModifiers = []
    }
    
    func exportToFile() {
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.plainText]
            savePanel.nameFieldStringValue = "keymochi_profile_\(self.activeProfileIndex).txt"
            savePanel.canCreateDirectories = true
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    let jsonStr = self.exportKarabinerJSON()
                    try? jsonStr.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        }
    }
    
    func importFromFile() {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.allowedContentTypes = [UTType.plainText, UTType.json]
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            
            openPanel.begin { response in
                if response == .OK, let url = openPanel.url,
                   let data = try? Data(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.parseKarabinerOrProfileJSON(data: data)
                    }
                }
            }
        }
    }
    
    private func parseKarabinerOrProfileJSON(data: Data) {
        objectWillChange.send()
        let isKor = appLanguage == .korean
        
        if let directMap = try? JSONDecoder().decode([String: KeyMapping].self, from: data) {
            var updated = directMap
            for (k, v) in updated {
                let sanitizedTo = sanitizeKarabinerKeyCode(v.toKeyCode)
                updated[k]?.toKeyCode = sanitizedTo
                if let orig = keys.first(where: { $0.id == k }) {
                    let isChanged = (sanitizedTo != orig.defaultCode) || !v.modifiers.isEmpty
                    updated[k]?.isModified = isChanged
                }
            }
            self.mappings = updated
            self.profiles[self.activeProfileIndex] = updated
            self.lastModifiedMessage = isKor ? "키맵 프로파일을 성공적으로 불러왔습니다." : "Keymap profile loaded successfully."
            return
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        var manipulatorsList: [[String: Any]] = []
        if let manipulators = json["manipulators"] as? [[String: Any]] {
            manipulatorsList = manipulators
        } else if let rules = json["rules"] as? [[String: Any]],
                  let firstRule = rules.first,
                  let manipulators = firstRule["manipulators"] as? [[String: Any]] {
            manipulatorsList = manipulators
        }
        
        guard !manipulatorsList.isEmpty else { return }
        
        if let firstManip = manipulatorsList.first,
           let conditions = firstManip["conditions"] as? [[String: Any]] {
            for cond in conditions {
                if let identifiers = cond["identifiers"] as? [[String: Any]],
                   let firstId = identifiers.first {
                    let vid = firstId["vendor_id"] as? Int ?? 0
                    let pid = firstId["product_id"] as? Int ?? 0
                    
                    if vid == wirelessVendorId && pid == wirelessProductId {
                        self.connectionMode = .wireless
                    } else {
                        self.connectionMode = .wired
                        if vid != 0 { self.wiredVendorId = vid }
                        if pid != 0 { self.wiredProductId = pid }
                    }
                    break
                }
            }
        }
        
        var newMap = defaultMappings()
        var modifiedCount = 0
        var availableKeys = self.keys
        
        for manip in manipulatorsList {
            guard let fromDict = manip["from"] as? [String: Any],
                  let fromCode = fromDict["key_code"] as? String,
                  let toArr = manip["to"] as? [[String: Any]],
                  let firstTo = toArr.first,
                  let rawToCode = firstTo["key_code"] as? String else { continue }
            
            let toCode = sanitizeKarabinerKeyCode(rawToCode)
            let mods = firstTo["modifiers"] as? [String] ?? []
            
            var matchedIndex = availableKeys.firstIndex(where: { $0.defaultCode == fromCode })
            if matchedIndex == nil {
                if fromCode == "equal_sign" || fromCode == "keypad_equal_sign" {
                    matchedIndex = availableKeys.firstIndex(where: { $0.id == "equal_top" })
                } else if fromCode == "spacebar" || fromCode == "space" {
                    matchedIndex = availableKeys.firstIndex(where: { $0.id == "space_top" })
                } else if fromCode == "f13" {
                    matchedIndex = availableKeys.firstIndex(where: { $0.id == "f13" })
                } else if fromCode == "f14" {
                    matchedIndex = availableKeys.firstIndex(where: { $0.id == "f14" })
                } else if fromCode == "f15" || fromCode == "al_calculator" {
                    matchedIndex = availableKeys.firstIndex(where: { $0.id == "calc" })
                }
            }
            
            if let idx = matchedIndex {
                let matchedKey = availableKeys.remove(at: idx)
                let isChanged = (toCode != matchedKey.defaultCode) || !mods.isEmpty
                newMap[matchedKey.id] = KeyMapping(
                    keyId: matchedKey.id,
                    toKeyCode: toCode,
                    modifiers: mods,
                    isModified: isChanged
                )
                if isChanged { modifiedCount += 1 }
            }
        }
        
        self.mappings = newMap
        self.profiles[self.activeProfileIndex] = newMap
        self.selectedKey = nil
        self.stagingCode = ""
        self.stagingModifiers = []
        
        let recognizedDevice = self.connectionMode == .wireless ? "Wireless" : "Wired"
        self.lastModifiedMessage = isKor
            ? "[\(recognizedDevice)] 감지 완료! 34개 중 \(modifiedCount)개 커스텀 키 적용."
            : "[\(recognizedDevice)] detected! Applied \(modifiedCount) custom keys out of 34."
    }
    
    func exportKarabinerJSON() -> String {
        var manipulators: [[String: Any]] = []
        
        for k in keys {
            let map = mappings[k.id] ?? KeyMapping(keyId: k.id, toKeyCode: k.defaultCode, modifiers: [], isModified: false)
            let safeToCode = sanitizeKarabinerKeyCode(map.toKeyCode)
            
            var toDict: [String: Any] = ["key_code": safeToCode]
            if !map.modifiers.isEmpty {
                toDict["modifiers"] = map.modifiers
            }
            
            let manipulator: [String: Any] = [
                "conditions": [
                    [
                        "identifiers": [
                            [
                                "product_id": currentProductId,
                                "vendor_id": currentVendorId
                            ]
                        ],
                        "type": "device_if"
                    ]
                ],
                "from": [
                    "key_code": k.defaultCode,
                    "modifiers": [
                        "optional": ["any"]
                    ]
                ],
                "to": [toDict],
                "type": "basic"
            ]
            manipulators.append(manipulator)
        }
        
        let rootRule: [String: Any] = [
            "description": "Magicforce MF34 (\(connectionMode.rawValue)) Profile \(activeProfileIndex) (Vendor: \(currentVendorId), Product: \(currentProductId))",
            "manipulators": manipulators
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: rootRule, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}

// MARK: - Key Capture Helper
struct KeyCaptureView: NSViewRepresentable {
    @Binding var capturedCode: String
    var onKeyCaptured: () -> Void
    
    class KeyView: NSView {
        var onCapture: ((String) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            let code = translateEventToKarabinerCode(event)
            onCapture?(code)
        }
        
        private func translateEventToKarabinerCode(_ event: NSEvent) -> String {
            switch event.keyCode {
            case 53: return "escape"
            case 48: return "tab"
            case 51: return "delete_or_backspace"
            case 36: return "return_or_enter"
            case 49: return "spacebar"
            case 126: return "up_arrow"
            case 125: return "down_arrow"
            case 123: return "left_arrow"
            case 124: return "right_arrow"
            case 115: return "home"
            case 119: return "end"
            case 116: return "page_up"
            case 121: return "page_down"
            case 117: return "delete_forward"
            
            case 122: return "f1"
            case 120: return "f2"
            case 99:  return "f3"
            case 118: return "f4"
            case 96:  return "f5"
            case 97:  return "f6"
            case 98:  return "f7"
            case 100: return "f8"
            case 101: return "f9"
            case 109: return "f10"
            case 103: return "f11"
            case 111: return "f12"
            case 105: return "f13"
            case 107: return "f14"
            case 113: return "f15"
            
            case 24: return "equal_sign"
            case 27: return "hyphen"
            case 33: return "open_bracket"
            case 30: return "close_bracket"
            case 42: return "backslash"
            case 41: return "semicolon"
            case 39: return "quote"
            case 43: return "comma"
            case 47: return "period"
            case 44: return "slash"
            case 50: return "grave_accent_and_tilde"
            
            case 82: return "keypad_0"
            case 83: return "keypad_1"
            case 84: return "keypad_2"
            case 85: return "keypad_3"
            case 86: return "keypad_4"
            case 87: return "keypad_5"
            case 88: return "keypad_6"
            case 89: return "keypad_7"
            case 91: return "keypad_8"
            case 92: return "keypad_9"
            case 65: return "keypad_period"
            case 67: return "keypad_asterisk"
            case 69: return "keypad_plus"
            case 75: return "keypad_slash"
            case 78: return "keypad_hyphen"
            case 76: return "keypad_enter"
            case 81: return "equal_sign"
            
            default:
                if let chars = event.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty {
                    let char = chars.first!
                    switch char {
                    case "=": return "equal_sign"
                    case "-": return "hyphen"
                    case "[": return "open_bracket"
                    case "]": return "close_bracket"
                    case "\\": return "backslash"
                    case ";": return "semicolon"
                    case "'": return "quote"
                    case ",": return "comma"
                    case ".": return "period"
                    case "/": return "slash"
                    case "`": return "grave_accent_and_tilde"
                    default:
                        if char.isLetter || char.isNumber {
                            return String(char)
                        }
                    }
                }
                return sanitizeKarabinerKeyCode("key_\(event.keyCode)")
            }
        }
    }
    
    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onCapture = { code in
            capturedCode = code
            onKeyCaptured()
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: KeyView, context: Context) {}
}

// MARK: - Main ContentView
struct ContentView: View {
    @StateObject private var vm = MF34ViewModel()
    @State private var showCopiedAlert: Bool = false
    @State private var showEditHardwareIdAlert: Bool = false
    @State private var inputVendorId: String = ""
    @State private var inputProductId: String = ""
    
    // [핵심 변경] 확실한 문자열 대조 ("AGREED_FINAL")
    // UserDefaults에 이 값이 정확히 들어있지 않으면 무조건 팝업을 띄웁니다!
    @State private var hasAgreed: Bool = (UserDefaults.standard.string(forKey: "KEYMOCHI_EULA_STATE") == "AGREED_FINAL")
    @State private var eulaLang: AppLanguage = .korean // 팝업 언어는 무조건 [한국어]로 시작!
    
    var isKor: Bool {
        vm.appLanguage == .korean
    }
    
    var body: some View {
        ZStack {
            // [LAYER 1] 메인 키패드 편집 화면
            HStack(spacing: 0) {
                // [LEFT AREA] 34키보드 시각화 캔버스 영역
                VStack(spacing: 16) {
                    // 상단 헤더: 타이틀 단독 행 + 초밀착된 VENDOR 라인
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("Magicforce MF34")
                                .font(.system(size: 19, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                            
                            Spacer()
                            
                            // LAYOUT 버튼군
                            HStack(spacing: 6) {
                                Text("LAYOUT")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.45))
                                    .padding(.trailing, 2)
                                
                                ForEach(1...3, id: \.self) { idx in
                                    let isSelected = vm.activeProfileIndex == idx
                                    let slotMode = vm.profileModes[idx] ?? .wireless
                                    let isSlotBlue = slotMode == .wireless
                                    
                                    Button(action: {
                                        vm.activeProfileIndex = idx
                                    }) {
                                        ZStack(alignment: .topTrailing) {
                                            Text("\(idx)")
                                                .font(.system(size: 12, weight: .heavy))
                                                .frame(width: 30, height: 26)
                                                .background(
                                                    isSelected
                                                    ? (isSlotBlue ? Color.modeBlue : Color.modeYellow)
                                                    : Color.buttonDarkGray
                                                )
                                                .foregroundColor(
                                                    isSelected
                                                    ? (isSlotBlue ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                                                    : .white.opacity(0.85)
                                                )
                                                .cornerRadius(4)
                                            
                                            if !isSelected {
                                                Circle()
                                                    .fill(isSlotBlue ? Color.modeBlue : Color.modeYellow)
                                                    .frame(width: 5, height: 5)
                                                    .padding(3)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.surfaceGray)
                            .cornerRadius(6)
                            
                            // 우측 액션 버튼들
                            Button(action: {
                                vm.saveCurrentProfile()
                            }) {
                                Text(isKor ? "키맵저장" : "Save Map")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 12)
                                    .frame(height: 36)
                                    .background(Color.buttonDarkGray)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                vm.resetCurrentProfileToDefault()
                            }) {
                                Text(isKor ? "키맵초기화" : "Reset")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 12)
                                    .frame(height: 36)
                                    .background(Color.buttonDarkGray)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // 타이틀 바로 아래에 바짝 밀착된 벤더 라인
                        HStack(spacing: 6) {
                            Text("VENDOR: \(vm.currentVendorId)   PRODUCT: \(vm.currentProductId)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.40))
                            
                            Button(action: {
                                inputVendorId = String(vm.currentVendorId)
                                inputProductId = String(vm.currentProductId)
                                showEditHardwareIdAlert = true
                            }) {
                                Text("EDIT")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.45))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.2)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(3)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.7)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, -5)
                    }
                    .padding(.horizontal, 30)
                    
                    // 키보드 그래픽 캔버스 (672 x 672)
                    ZStack {
                        Image(vm.currentKeyboardImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 672, height: 672)
                            .cornerRadius(14)
                        
                        // [상단 대칭 스위치] Wired / Wireless 알약 버튼
                        VStack {
                            HStack(spacing: 0) {
                                ForEach(MF34ConnectionMode.allCases) { mode in
                                    let isSelected = vm.connectionMode == mode
                                    Button(action: {
                                        vm.connectionMode = mode
                                    }) {
                                        Text(mode.rawValue)
                                            .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular, design: .rounded))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3.5)
                                            .background(isSelected ? Color.white.opacity(0.18) : Color.clear)
                                            .foregroundColor(isSelected ? .white.opacity(0.9) : .white.opacity(0.4))
                                            .cornerRadius(10)
                                            .contentShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2.5)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                            )
                            .padding(.top, 42)
                            
                            Spacer()
                            
                            // [하단 대칭 스위치] 한국어 / English 알약 버튼
                            HStack(spacing: 0) {
                                ForEach(AppLanguage.allCases) { lang in
                                    let isSelected = vm.appLanguage == lang
                                    Button(action: {
                                        vm.appLanguage = lang
                                    }) {
                                        Text(lang.rawValue)
                                            .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular, design: .rounded))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3.5)
                                            .background(isSelected ? Color.white.opacity(0.18) : Color.clear)
                                            .foregroundColor(isSelected ? .white.opacity(0.9) : .white.opacity(0.4))
                                            .cornerRadius(10)
                                            .contentShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2.5)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                            )
                            .padding(.bottom, 42)
                        }
                        .frame(width: 672, height: 672)
                        
                        // 34개 키 렌더링
                        ForEach(vm.keys) { k in
                            let isSelected = vm.selectedKey?.id == k.id
                            let mapping = vm.mappings[k.id]
                            let isModified = mapping?.isModified ?? false
                            
                            let currentMappedCode = sanitizeKarabinerKeyCode(mapping?.toKeyCode ?? k.defaultCode)
                            let currentMods = mapping?.modifiers ?? []
                            let hasCustomMapping = (currentMappedCode != k.defaultCode) || !currentMods.isEmpty
                            
                            let mainText = hasCustomMapping ? formatDisplayKeyLabel(currentMappedCode) : k.displayLabel
                            
                            let mainTextColor: Color = {
                                if isModified {
                                    return Color.accentRed
                                } else if isKeypadKeyCode(currentMappedCode) {
                                    return Color.deepCobaltBlue
                                } else {
                                    return Color.black
                                }
                            }()
                            
                            let modColor: Color = {
                                if isModified {
                                    return Color.accentRed.opacity(0.55)
                                } else if k.isGrayKeycap {
                                    return Color.white.opacity(0.42)
                                } else {
                                    return Color.black.opacity(0.48)
                                }
                            }()
                            
                            let modWeight: Font.Weight = k.isGrayKeycap ? .medium : .bold
                            let ctrlSize: CGFloat = k.isGrayKeycap ? 16 : 17
                            let otherModSize: CGFloat = k.isGrayKeycap ? 15 : 16
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(
                                        isSelected ? Color.accentRed : Color.clear,
                                        lineWidth: isSelected ? 3.5 : 0
                                    )
                                    .shadow(color: isSelected ? Color.accentRed.opacity(0.9) : Color.clear, radius: isSelected ? 6 : 0)
                                
                                ZStack {
                                    if currentMods.contains("left_control") {
                                        VStack {
                                            HStack {
                                                Text("⌃")
                                                    .font(.system(size: ctrlSize, weight: modWeight))
                                                    .foregroundColor(modColor)
                                                    .padding(.leading, 8)
                                                    .padding(.top, 5.5)
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                    }
                                    
                                    if currentMods.contains("left_shift") {
                                        VStack {
                                            HStack {
                                                Spacer()
                                                Text("⇧")
                                                    .font(.system(size: otherModSize, weight: modWeight))
                                                    .foregroundColor(modColor)
                                                    .padding(.trailing, 8)
                                                    .padding(.top, 5.5)
                                            }
                                            Spacer()
                                        }
                                    }
                                    
                                    if currentMods.contains("left_option") {
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Text("⌥")
                                                    .font(.system(size: otherModSize, weight: modWeight))
                                                    .foregroundColor(modColor)
                                                    .padding(.leading, 8)
                                                    .padding(.bottom, 5.5)
                                                Spacer()
                                            }
                                        }
                                    }
                                    
                                    if currentMods.contains("left_command") {
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                Text("⌘")
                                                    .font(.system(size: ctrlSize, weight: modWeight))
                                                    .foregroundColor(modColor)
                                                    .padding(.trailing, 8)
                                                    .padding(.bottom, 5.5)
                                            }
                                        }
                                    }
                                    
                                    Text(mainText)
                                        .font(.system(
                                            size: k.width > 90 ? 28 : (mainText.count > 2 ? 17 : 29),
                                            weight: .bold,
                                            design: .rounded
                                        ))
                                        .foregroundColor(mainTextColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.65)
                                }
                            }
                            .frame(width: k.width, height: k.height)
                            .contentShape(Rectangle())
                            .position(x: k.x, y: k.y)
                            .onTapGesture {
                                vm.selectedKey = k
                                vm.stagingCode = ""
                                vm.stagingModifiers = vm.mappings[k.id]?.modifiers ?? []
                                vm.lastModifiedMessage = nil
                            }
                        }
                    }
                    .frame(width: 672, height: 672)
                    
                    // 하단 3개 버튼
                    HStack(spacing: 14) {
                        PlainBottomButton(title: isKor ? "불러오기" : "Import") {
                            vm.importFromFile()
                        }
                        PlainBottomButton(title: isKor ? "내보내기" : "Export") {
                            vm.exportToFile()
                        }
                        PlainBottomButton(
                            title: showCopiedAlert ? (isKor ? "복사 완료!" : "Copied!") : (isKor ? "코드복사" : "Copy Code"),
                            isHighlight: true
                        ) {
                            let json = vm.exportKarabinerJSON()
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(json, forType: .string)
                            showCopiedAlert = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopiedAlert = false
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.vertical, 24)
                .frame(width: 732)
                
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
                
                // [RIGHT AREA] 사이드바 패널
                SidebarEditorView(vm: vm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            }
            .blur(radius: hasAgreed ? 0 : 5)
            .allowsHitTesting(hasAgreed)
            
            // [LAYER 2] 약관 동의 팝업 모달 (미동의 시 최상단 윈도우에 무조건 100% 렌더링)
            if !hasAgreed {
                ZStack {
                    Color.black.opacity(0.72)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 18) {
                        // 상단 헤더: 경고 아이콘 + 타이틀 + 실시간 [ 한국어 | English ] 언어 전환 토글
                        HStack(alignment: .center) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.modeYellow)
                                
                                Text(eulaLang == .korean ? "KeyMochi 사용 안내 및 면책 동의" : "Terms of Use & Disclaimer")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white.opacity(0.95))
                            }
                            
                            Spacer()
                            
                            // 팝업 내부 상단 언어 선택 알약 스위치
                            HStack(spacing: 0) {
                                ForEach(AppLanguage.allCases) { lang in
                                    let isSelected = eulaLang == lang
                                    Button(action: {
                                        eulaLang = lang
                                    }) {
                                        Text(lang.rawValue)
                                            .font(.system(size: 11, weight: isSelected ? .bold : .regular, design: .rounded))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3.5)
                                            .background(isSelected ? Color.white.opacity(0.22) : Color.clear)
                                            .foregroundColor(isSelected ? .white : .white.opacity(0.45))
                                            .cornerRadius(10)
                                            .contentShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2.5)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                        }
                        
                        // 본문 스크롤 영역 (디폴트: 한국어)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                if eulaLang == .korean {
                                    Text("본 소프트웨어(KeyMochi)를 사용하기 전에 아래의 안내 사항과 약관을 주의 깊게 읽어주시기 바랍니다.")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                    
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    Group {
                                        Text("1. 필수 요구사항 및 사용 방법")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color.modeYellow)
                                        
                                        Text("• Karabiner-Elements 연동 필수: 본 앱은 시스템 입력을 직접 가로채지 않는 보조 GUI 도구입니다. 앱에서 생성된 코드를 복사하여 Karabiner-Elements의 'Complex Modifications' 룰에 등록해야 실제 키 매핑이 동작합니다.")
                                        Text("• 프로파일 보관: [.txt] 및 [.json] 파일 형식의 내보내기/불러오기를 통해 안전하게 키맵을 백업 및 전환할 수 있습니다.")
                                        Text("• 시스템 요구사항: macOS 13.0 (Ventura) 이상, 최신 Karabiner-Elements (Python 등 부수적 런타임 설치 불필요).")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineSpacing(4)
                                    
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    Group {
                                        Text("2. 보증의 부인 및 면책 조항 (NO WARRANTY & AS-IS)")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color.accentRed)
                                        
                                        Text("• 있는 그대로의 제공 (AS-IS): 본 소프트웨어는 개인적 유용성을 목적으로 제작되었으며, 개발 및 배포 시점의 점검 사항 외에 발생할 수 있는 예상치 못한 버그, macOS 업데이트에 따른 호환성 문제, 기기 오동작 및 데이터 손실에 대해 개발자는 어떠한 법적 책임도 지지 않습니다.")
                                        Text("• 유지보수 의무의 부존재: 향후 업데이트는 개발자의 필요에 따라 비정기적으로 이루어질 수 있으며, 사후 지원에 대한 의무는 일절 존재하지 않습니다.")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineSpacing(4)
                                    
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    Group {
                                        Text("3. 사용권 및 재배포 규정")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white.opacity(0.9))
                                        
                                        Text("• 누구나 비상업적 목적으로 자유롭게 공유, 수정 및 재배포할 수 있습니다.")
                                        Text("• 수정 및 재배포 시 원개발자와 수정한 자를 명시해야 하며, 앱 고유의 디자인과 본래의 정체성을 훼손하지 않아야 합니다.")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineSpacing(4)
                                    
                                } else {
                                    Text("Please review the following instructions and terms carefully before using KeyMochi.")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                    
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    Group {
                                        Text("1. Requirements & Usage")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color.modeBlue)
                                        
                                        Text("• Karabiner-Elements Required: KeyMochi does not hook system keys directly. It is a companion GUI tool that generates precision JSON rules for Karabiner-Elements. Copy and register the generated rules into Karabiner-Elements Complex Modifications.")
                                        Text("• Profile Management: Export and import [.txt] or [.json] files across 3 independent hardware-linked slots.")
                                        Text("• System Requirements: macOS 13.0 (Ventura) or later, latest stable Karabiner-Elements (No Python or secondary runtimes needed).")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineSpacing(4)
                                    
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    Group {
                                        Text("2. Disclaimer of Warranty & Liability (AS-IS)")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color.accentRed)
                                        
                                        Text("• Provided AS-IS: THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND. The author assumes no legal liability for unforeseen bugs, macOS incompatibilities, device malfunctions, or data loss.")
                                        Text("• No Maintenance Obligation: Future maintenance and updates occur solely at the author's discretion without ongoing support obligations.")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineSpacing(4)
                                    
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    Group {
                                        Text("3. License & Redistribution")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white.opacity(0.9))
                                        
                                        Text("• Freely shareable and modifiable for non-commercial purposes.")
                                        Text("• Redistribution requires proper attribution (Original Author & Contributors) and must preserve the visual design and core brand identity.")
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineSpacing(4)
                                }
                            }
                            .padding(16)
                        }
                        .frame(height: 290)
                        .background(Color.deepGrayBg)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        
                        // 하단 액션 버튼들: [거절 (종료)] 및 [동의]
                        HStack(spacing: 12) {
                            Button(action: {
                                NSApplication.shared.terminate(nil)
                            }) {
                                Text(eulaLang == .korean ? "거절 (종료)" : "Disagree (Quit)")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 140)
                                    .frame(height: 42)
                                    .background(Color.buttonDarkGray)
                                    .cornerRadius(7)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                // 팝업에서 고른 언어를 메인 앱에도 계승
                                vm.appLanguage = eulaLang
                                // 동의 완료 문자열 영구 저장
                                UserDefaults.standard.set("AGREED_FINAL", forKey: "KEYMOCHI_EULA_STATE")
                                hasAgreed = true
                            }) {
                                Text(eulaLang == .korean ? "동의하고 계속하기" : "Agree & Continue")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(Color.accentRed)
                                    .cornerRadius(7)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                    .frame(width: 580, height: 460)
                    .background(Color.surfaceGray)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 25, x: 0, y: 10)
                }
            }
        }
        .background(Color.deepGrayBg.ignoresSafeArea())
        .frame(width: 1250, height: 864)
        .sheet(isPresented: $showEditHardwareIdAlert) {
            VStack(spacing: 16) {
                Text(isKor ? "[\(vm.connectionMode.rawValue)] 하드웨어 ID 설정" : "[\(vm.connectionMode.rawValue)] Hardware ID Settings")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
                
                Text(isKor ? "기기의 Vendor ID 및 Product ID를 직접 입력할 수 있습니다." : "Configure custom Vendor ID and Product ID for this device.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vendor ID:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    TextField("Vendor ID", text: $inputVendorId)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Product ID:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    TextField("Product ID", text: $inputProductId)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(width: 240)
                
                HStack(spacing: 12) {
                    Button(isKor ? "취소" : "Cancel") {
                        showEditHardwareIdAlert = false
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button(isKor ? "저장" : "Save") {
                        if let v = Int(inputVendorId.trimmingCharacters(in: .whitespaces)),
                           let p = Int(inputProductId.trimmingCharacters(in: .whitespaces)) {
                            if vm.connectionMode == .wired {
                                vm.wiredVendorId = v
                                vm.wiredProductId = p
                            }
                        }
                        showEditHardwareIdAlert = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentRed)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color.surfaceGray)
        }
    }
}

// MARK: - Sidebar Editor Panel
struct SidebarEditorView: View {
    @ObservedObject var vm: MF34ViewModel
    @State private var isListening: Bool = false
    
    var isKor: Bool {
        vm.appLanguage == .korean
    }
    
    var hasPendingChanges: Bool {
        guard let targetKey = vm.selectedKey else { return false }
        let currentMapping = vm.mappings[targetKey.id]
        let originalMods = currentMapping?.modifiers ?? []
        
        let hasNewCode = !vm.stagingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasModifiedMods = (vm.stagingModifiers != originalMods)
        
        return hasNewCode || hasModifiedMods
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let targetKey = vm.selectedKey {
                VStack(alignment: .leading, spacing: 5) {
                    Text("KEY CONFIGURATION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                    
                    HStack(alignment: .center) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(targetKey.displayLabel)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                            
                            Text("(Original: \(targetKey.defaultCode))")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            vm.resetSelectedKey()
                            isListening = false
                        }) {
                            Text(isKor ? "이 키 초기화" : "Reset Key")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.88))
                                .frame(width: 100, height: 38)
                                .background(Color.buttonDarkGray)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
                
                Divider().background(Color.white.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(isKor ? "키 입력 감지창" : "DETECTED TARGET KEY")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                        
                        Spacer()
                        
                        if isListening {
                            Text(isKor ? "키를 누르세요..." : "Press any key...")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.accentRed)
                        }
                    }
                    
                    HStack(spacing: 10) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.buttonDarkGray)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isListening ? Color.accentRed : Color.white.opacity(0.12), lineWidth: isListening ? 2 : 1)
                                )
                            
                            Text(vm.stagingCode.isEmpty ? (isListening ? (isKor ? "입력 대기 중..." : "Waiting...") : "") : formatDisplayKeyLabel(vm.stagingCode))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(vm.stagingCode.isEmpty ? .white.opacity(0.4) : .white.opacity(0.92))
                                .padding(.horizontal, 14)
                        }
                        .frame(height: 40)
                        
                        Button(action: {
                            isListening.toggle()
                        }) {
                            Text(isListening ? (isKor ? "취소" : "Cancel") : (isKor ? "키 입력 감지" : "Record Key"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.88))
                                .frame(width: 100, height: 40)
                                .background(isListening ? Color.gray.opacity(0.6) : Color.buttonDarkGray)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if isListening {
                        KeyCaptureView(capturedCode: $vm.stagingCode) {
                            isListening = false
                        }
                        .frame(width: 0, height: 0)
                        .opacity(0)
                    }
                }
                
                VStack(alignment: .leading, spacing: 9) {
                    Text(isKor ? "조합키 (MODIFIERS)" : "COMBINATION MODIFIERS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                    
                    HStack(spacing: 10) {
                        ModifierCard(symbol: "⌘", title: "CMD", modifierKey: "left_command", currentMods: $vm.stagingModifiers)
                        ModifierCard(symbol: "⌥", title: "OPT", modifierKey: "left_option", currentMods: $vm.stagingModifiers)
                        ModifierCard(symbol: "⇧", title: "SHIFT", modifierKey: "left_shift", currentMods: $vm.stagingModifiers)
                        ModifierCard(symbol: "⌃", title: "CTRL", modifierKey: "left_control", currentMods: $vm.stagingModifiers)
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack(spacing: 14) {
                    Button(action: {
                        isListening = false
                        vm.stagingCode = ""
                        vm.stagingModifiers = vm.mappings[targetKey.id]?.modifiers ?? []
                    }) {
                        Text(isKor ? "취소" : "Cancel")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(hasPendingChanges ? .white.opacity(0.88) : .white.opacity(0.35))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.buttonDarkGray)
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(height: 42)
                    .disabled(!hasPendingChanges)
                    
                    Button(action: {
                        isListening = false
                        vm.commitStagingMapping()
                    }) {
                        Text(isKor ? "적용" : "Apply")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white.opacity(0.95))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(hasPendingChanges ? Color.accentRed : Color.buttonDarkGray)
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(height: 42)
                    .disabled(!hasPendingChanges)
                }
                
                Spacer()
                
            } else {
                VStack(spacing: 18) {
                    Spacer()
                    
                    if let message = vm.lastModifiedMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 42))
                                .foregroundColor(Color.accentRed)
                            
                            Text(message)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 18)
                            
                            Text(isKor ? "계속해서 편집하려면 왼쪽에서 키를 선택하세요." : "Select a key on the left to continue mapping.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.45))
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 28)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(Color.surfaceGray)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    } else {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color.white.opacity(0.18))
                        
                        Text(isKor ? "왼쪽 키패드에서 매핑할 키를 선택해주세요." : "Select a key on the left keypad to map.")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 30)
        .onChange(of: vm.selectedKey, initial: false) { _, _ in
            isListening = false
        }
    }
}

// MARK: - Subcomponents
struct PlainBottomButton: View {
    let title: String
    var isHighlight: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(isHighlight ? Color.accentRed : Color.buttonDarkGray)
                .foregroundColor(.white.opacity(0.92))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ModifierCard: View {
    let symbol: String
    let title: String
    let modifierKey: String
    @Binding var currentMods: [String]
    
    var isOn: Bool {
        currentMods.contains(modifierKey)
    }
    
    var body: some View {
        Button(action: {
            if isOn {
                currentMods.removeAll { $0 == modifierKey }
            } else {
                currentMods.append(modifierKey)
            }
        }) {
            VStack(spacing: 3) {
                Text(symbol)
                    .font(.system(size: 17, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isOn ? Color.accentRed : Color.buttonDarkGray)
            .foregroundColor(.white.opacity(0.92))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isOn ? Color.accentRed : Color.white.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
