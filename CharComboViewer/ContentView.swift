import SwiftUI
import Carbon
import Combine

// MARK: - Keyboard State Model

/// An observable object that tracks the current keyboard layout, modifier key states,
/// and the characters they produce.
@MainActor
class KeyboardState: ObservableObject {
    
    /// The localized name of the current keyboard layout (e.g., "U.S.").
    @Published var layoutName: String = "Unknown"
    
    /// A dictionary mapping virtual key codes to their corresponding character strings.
    @Published var keys: [UInt16: String] = [:]
    
    // MARK: Keyboard Row Definitions
    // These arrays define the virtual key codes for each row of a standard US keyboard.
    
    @Published var row1: [UInt16] = [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 51] // ~, 1-9, 0, -, =, delete
    @Published var row2: [UInt16] = [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30]    // tab, Q-P, [, ]
    @Published var row3: [UInt16] = [57, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 42]          // caps, A-L, ;, ', \
    @Published var row4: [UInt16] = [56, 10, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 60]       // L-shift, ISO-§, Z-M, ,, ., /, R-shift
    @Published var row5: [UInt16] = [63, 59, 58, 55, 49, 54, 61]                         // fn, ctrl, L-opt, L-cmd, space, R-cmd, R-opt
    
    private var layoutData: Data?
    private var flagsMonitor: Any?

    init() {
        // Initialize the keyboard layout and keys.
        updateKeyboardLayout()
        updateAllKeys(modifiers: 0)
        
        // Listen for changes in the keyboard layout (e.g., switching from US to French).
        NotificationCenter.default.addObserver(
            forName: .init(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateKeyboardLayout()
                self?.updateAllKeys(modifiers: 0)
            }
        }
        
        // Listen for modifier key presses (e.g., Shift, Option, Command).
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.updateModifiers(event.modifierFlags)
            return event
        }
    }
    
    deinit {
        // Clean up the notification observer and event monitor.
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    /// Translates Cocoa modifier flags (NSEvent.ModifierFlags) into the older Carbon format.
    /// - Parameter flags: The modern Cocoa modifier flags.
    public func updateModifiers(_ flags: NSEvent.ModifierFlags) {
        var carbonModifiers: UInt32 = 0
        
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.capsLock) { carbonModifiers |= UInt32(alphaLock) }

        self.updateAllKeys(modifiers: carbonModifiers)
    }

    /// Fetches the current keyboard layout's name and raw data from the system.
    private func updateKeyboardLayout() {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeUnretainedValue() else {
            return
        }
        // Get the human-readable name of the layout.
        if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
            let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue()
            self.layoutName = name as String
        }
        // Get the raw layout data needed for character translation.
        if let dataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue()
            self.layoutData = data as Data
        }
    }
    
    /// Iterates through all defined key codes and updates their character representations
    /// based on the current modifier keys.
    private func updateAllKeys(modifiers: UInt32) {
        guard self.layoutData != nil else { return }
        
        let keyCodesToUpdate: [UInt16] = self.row1 + self.row2 + self.row3 + self.row4 + self.row5
        
        var newKeys: [UInt16: String] = [:]
        for virtualKeyCode in keyCodesToUpdate {
            newKeys[virtualKeyCode] = getCharacter(
                for: virtualKeyCode,
                with: modifiers
            )
        }
        self.keys = newKeys
    }
    
    /// Translates a single virtual key code into a character string, correctly handling "dead keys"
    /// (like Option-E, which waits for the next key to apply an accent).
    /// - Parameters:
    ///   - virtualKeyCode: The key code to translate.
    ///   - modifiers: The active Carbon-style modifier flags.
    /// - Returns: The resulting character, or a special representation for dead keys.
    private func getCharacter(for virtualKeyCode: UInt16, with modifiers: UInt32) -> String {
        guard let layoutData = self.layoutData else { return "?" }
        
        let result = layoutData.withUnsafeBytes { layoutPtr in
            let keyboardLayout = layoutPtr.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self)
            
            var deadKeyState: UInt32 = 0
            var outputChars = [UniChar](repeating: 0, count: 4)
            var actualCharCount = 0
            
            // First Pass: Try to translate the key normally.
            var status = UCKeyTranslate(
                keyboardLayout,
                virtualKeyCode,
                UInt16(kUCKeyActionDown),
                (modifiers >> 8) & 0xFF,
                UInt32(LMGetKbdType()),
                0, // options: 0 means handle dead keys
                &deadKeyState,
                outputChars.count,
                &actualCharCount,
                &outputChars
            )

            // If a character is produced, return it.
            if status == noErr && actualCharCount > 0 {
                return String(utf16CodeUnits: outputChars, count: actualCharCount)
            }

            // Second Pass: If the first pass indicated a dead key was pressed (deadKeyState is non-zero),
            // we need to "flush" it to get the standalone character.
            if status == noErr && actualCharCount == 0 && deadKeyState != 0 {
                
                // We simulate pressing the spacebar to get the standalone diacritic (e.g., "¨" from Option-U).
                let kVK_Space: UInt16 = 49

                status = UCKeyTranslate(
                    keyboardLayout,
                    kVK_Space,
                    UInt16(kUCKeyActionDown),
                    0, // No modifiers for the flushing spacebar press
                    UInt32(LMGetKbdType()),
                    0,
                    &deadKeyState,
                    outputChars.count,
                    &actualCharCount,
                    &outputChars
                )
                
                // If we get the standalone diacritic, we format it specially for rendering.
                if status == noErr && actualCharCount > 0 {
                    let resultString = String(utf16CodeUnits: outputChars, count: actualCharCount)
                    if let firstChar = resultString.first {
                        // We return the diacritic followed by a special marker "|_"
                        // to tell the KeyView how to render it.
                        return "\(firstChar)|_"
                    }
                }
            }

            // If translation fails, return an empty string.
            return ""
        }
        return result
    }
}

// MARK: - Main Content View
struct ContentView: View {
    
    @StateObject private var keyboard = KeyboardState()

    var body: some View {
        VStack(spacing: 10) {
            Text("Current Layout: \(keyboard.layoutName)")
                .font(.headline)
            
            // The main keyboard view, arranged in a vertical stack of rows.
            VStack(alignment: .leading, spacing: 5) {
                KeyRowView(keys: keyboard.row1, keyData: keyboard.keys)
                KeyRowView(keys: keyboard.row2, keyData: keyboard.keys)
                KeyRowView(keys: keyboard.row3, keyData: keyboard.keys)
                KeyRowView(keys: keyboard.row4, keyData: keyboard.keys)
                KeyRowView(keys: keyboard.row5, keyData: keyboard.keys)
            }
            
            Text("Hold 'Option', 'Shift', or 'Shift + Option' to see character combinations.")
                .font(.caption)
                .padding(.top)
        }
        .padding()
        .frame(minWidth: 700, minHeight: 320)
    }
}

// MARK: - Key Row View
/// A view that renders a single horizontal row of keys.
struct KeyRowView: View {
    let keys: [UInt16]
    let keyData: [UInt16: String]
    
    var body: some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { keyCode in
                // Use a switch to handle special keys that need a label instead of a character.
                switch keyCode {
                // Row 1
                case 51: LabelKeyView(label: "⌫", width: 60) // delete
                
                // Row 2
                case 48: LabelKeyView(label: "⇥", width: 60) // tab
                
                // Row 3
                case 57: LabelKeyView(label: "⇪", width: 95) // caps lock
                
                // Row 4
                case 56: LabelKeyView(label: "⇧", width: 75) // Left Shift
                case 60: LabelKeyView(label: "⇧", width: 95) // Right Shift
                
                // Row 5
                case 63: LabelKeyView(label: "fn", width: 40)
                case 59: LabelKeyView(label: "⌃", width: 45) // Control
                case 58: LabelKeyView(label: "⌥", width: 50) // Left Option
                case 55: LabelKeyView(label: "⌘", width: 70) // Left Command
                case 49: KeyView(character: keyData[keyCode] ?? " ", width: 205) // Space
                case 54: LabelKeyView(label: "⌘", width: 70) // Right Command
                case 61: LabelKeyView(label: "⌥", width: 50) // Right Option
                
                // Default case for all other (character) keys.
                default: KeyView(character: keyData[keyCode] ?? "")
                }
            }
        }
    }
}


// MARK: - Single Key View
/// A view that represents a single physical key on the keyboard.
struct KeyView: View {
    let character: String
    var width: CGFloat = 40 // Default width for a standard 1U key.
    
    var body: some View {
        // The rendering logic for dead keys uses a special format: "diacritic|_".
        // We split the string by "|" to detect this.
        let parts = character.split(separator: "|")
        
        let viewContent: AnyView
        
        if parts.count == 2 {
            // This is a dead key. We render the diacritic and an underline character
            // in a ZStack to overlay them.
            let diacritic = String(parts[0])
            let underline = String(parts[1])
            
            viewContent = AnyView(
                ZStack(alignment: .center) {
                    Text(diacritic)
                    
                    Text(underline)
                        .fontWeight(.heavy)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 4)
                }
                .font(.system(size: 24, design: .monospaced))
            )
        } else {
            // This is a normal character key.
            viewContent = AnyView(
                Text(character.isEmpty ? " " : character)
                    .font(.system(size: 24, design: .monospaced))
            )
        }
        
        // Common styling for all keys.
        return viewContent
            .frame(width: width, height: 40)
            .background(Color(white: 0.9))
            .cornerRadius(5)
            .shadow(radius: 1)
    }
}

// MARK: - Label Key View
/// A view for keys that have a static label instead of a dynamic character (e.g., "Shift", "Caps Lock").
struct LabelKeyView: View {
    let label: String
    var width: CGFloat
    var height: CGFloat = 40
    var alignment: Alignment = .center

    var body: some View {
        Text(label)
            .font(.system(size: 14))
            .textCase(.uppercase)
            .frame(width: width, height: height, alignment: alignment)
            .background(Color(white: 0.8)) // Use a slightly darker background for label keys.
            .cornerRadius(5)
            .shadow(radius: 1)
    }
}
