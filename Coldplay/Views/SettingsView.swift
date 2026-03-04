import SwiftUI

struct SettingsView: View {
    @Environment(LocalizationManager.self) private var loc
    @Environment(AttendanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var loc = loc
        NavigationStack {
            List {
                Section(loc.languageLabel) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Button {
                            loc.language = lang
                        } label: {
                            HStack {
                                Text(lang.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if loc.language == lang {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                Section(loc.dataLabel) {
                    if let url = store.exportCSV() {
                        ShareLink(item: url) {
                            Label(loc.exportCSV, systemImage: "square.and.arrow.up")
                        }
                    }

                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(loc.autoBackupHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(loc.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
