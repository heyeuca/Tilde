//
//  SettingsView.swift
//  Tilde
//

import SwiftUI

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
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 380, height: 384)
        .onChange(of: appearance) { _, newValue in
            newValue.apply()
        }
    }
}
