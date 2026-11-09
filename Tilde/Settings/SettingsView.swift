//
//  SettingsView.swift
//  Tilde
//

import SwiftUI
#if canImport(KeyboardShortcuts)
import KeyboardShortcuts
#endif

/// Tilde's entire settings, on one screen (PRODUCT.md §22).
struct SettingsView: View {
    @AppStorage(AppSettings.appearanceKey) private var appearance = AppearanceSetting.system
    @AppStorage(AppSettings.fontSizeKey) private var fontSize = AppSettings.defaultFontSize
    @AppStorage(AppSettings.wordWrapKey) private var wordWrap = AppSettings.defaultWordWrap
    @AppStorage(AppSettings.lineNumbersKey) private var lineNumbers = AppSettings.defaultLineNumbers
    @AppStorage(AppSettings.markdownStylingKey) private var markdownStyling = AppSettings.defaultMarkdownStyling

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearanceSetting.allCases) { setting in
                        Text(setting.label).tag(setting)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Editor") {
                Stepper(
                    "Font Size: \(Int(fontSize)) pt",
                    value: $fontSize,
                    in: AppSettings.fontSizeRange,
                    step: 1
                )
                Toggle("Word Wrap", isOn: $wordWrap)
                Toggle("Line Numbers", isOn: $lineNumbers)
            }

            Section("Markdown") {
                Toggle("Markdown Styling", isOn: $markdownStyling)
            }

            #if canImport(KeyboardShortcuts)
            // Global shortcut for a blank window (#62); empty until recorded.
            Section {
                KeyboardShortcuts.Recorder(for: .openBlankWindow) {
                    Text("Blank Window Shortcut")
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 380, height: 428)
        .onChange(of: appearance) { _, newValue in
            newValue.apply()
        }
    }
}
