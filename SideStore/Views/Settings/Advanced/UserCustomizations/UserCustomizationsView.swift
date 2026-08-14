//
//  UserCustomizationsView.swift
//  SideStore
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI

private extension Color {
    static let settingsDivider = Color.miniStoreSeparator
}

struct UserCustomizationsView: View {
    @State private var customizeAppId: Bool = UserDefaults.standard.customizeAppId
    @State private var customizeAppExtensions: Bool = UserDefaults.standard.customizeAppExtensions
    @State private var autoFixAppGroupIDs: Bool = UserDefaults.standard.autoFixAppGroupIDs
    @State private var isExportResignedAppEnabled: Bool = UserDefaults.standard.isExportResignedAppEnabled
    @State private var enableEMPforWireguard: Bool = UserDefaults.standard.enableEMPforWireguard
    @State private var skipNonCopyableFiles: Bool = UserDefaults.standard.skipNonCopyableBackupFiles
    @State private var isOLEDModeEnabled: Bool = MiniStore.isOLEDModeEnabled

    private var isFreeAccount: Bool {
        DatabaseManager.shared.activeTeam()?.type == .free
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section 0: APPEARANCE & THEMES
                VStack(alignment: .leading, spacing: 8) {
                    Text("APPEARANCE & THEMES")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.75))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        NavigationLink(destination: ThemePickerView()) {
                            HStack {
                                Text("Theme Manager")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(uiColor: ThemeManager.shared.primaryColor))
                                        .frame(width: 14, height: 14)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color.white.opacity(0.4))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }

                        divider

                        NavigationLink(destination: TabVisibilityView()) {
                            HStack {
                                Text("Tab Bar")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }

                        divider

                        toggleRow(title: "OLED Dark Mode",
                                  subtitle: "Pure black backgrounds in dark mode.",
                                  isOn: Binding(
                            get: { isOLEDModeEnabled },
                            set: { newValue in
                                isOLEDModeEnabled = newValue
                                MiniStore.isOLEDModeEnabled = newValue
                            }
                        ))
                    }
                    .background(Color.miniStoreCard)
                    .cornerRadius(16)
                }

                // Section 1: APP & EXTENSIONS CUSTOMIZATION
                VStack(alignment: .leading, spacing: 8) {
                    Text("CUSTOMIZATION OPTIONS")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.75))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        toggleRow(title: "Customize AppID", isOn: Binding(
                            get: { customizeAppId },
                            set: { newValue in
                                customizeAppId = newValue
                                UserDefaults.standard.customizeAppId = newValue
                            }
                        ))
                        
                        divider
                        
                        toggleRow(title: "Customize App Extensions", isOn: Binding(
                            get: { customizeAppExtensions },
                            set: { newValue in
                                customizeAppExtensions = newValue
                                UserDefaults.standard.customizeAppExtensions = newValue
                            }
                        ))
                        
                        divider
                        
                        toggleRow(
                            title: "Auto-Fix AppGroup IDs",
                            subtitle: isFreeAccount ? "Required for free developer accounts" : "Automatically fix App Group casing mismatches",
                            isOn: Binding(
                                get: { isFreeAccount ? true : autoFixAppGroupIDs },
                                set: { newValue in
                                    guard !isFreeAccount else { return }
                                    autoFixAppGroupIDs = newValue
                                    UserDefaults.standard.autoFixAppGroupIDs = newValue
                                }
                            )
                        )
                        .disabled(isFreeAccount)
                        
                        divider
                        
                        toggleRow(title: "Export Resigned Apps", isOn: Binding(
                            get: { isExportResignedAppEnabled },
                            set: { newValue in
                                isExportResignedAppEnabled = newValue
                                UserDefaults.standard.isExportResignedAppEnabled = newValue
                            }
                        ))
                        
                        divider
                        
                        toggleRow(title: "EMProxy (WireGuard) Server", isOn: Binding(
                            get: { enableEMPforWireguard },
                            set: { newValue in
                                enableEMPforWireguard = newValue
                                UserDefaults.standard.enableEMPforWireguard = newValue
                            }
                        ))
                        
                        divider
                        
                        toggleRow(title: "Skip Uncopyable Backup Files", isOn: Binding(
                            get: { skipNonCopyableFiles },
                            set: { newValue in
                                skipNonCopyableFiles = newValue
                                UserDefaults.standard.skipNonCopyableBackupFiles = newValue
                            }
                        ))
                    }
                    .background(Color.miniStoreCard)
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .miniStoreBackground()
        .navigationTitle("User Customizations")
        .navigationBarTitleDisplayMode(.large)
    }

    private func toggleRow(title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.settingsDivider)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
}
