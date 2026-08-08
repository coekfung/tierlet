//
//  ContentView.swift
//  Tierlet
//
//  Created by Zhuofeng on 2026/8/8.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var service = TierletServiceClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tierlet")
                .font(.largeTitle)

            Text(service.status)
                .foregroundStyle(.secondary)

            if let serviceStatus = service.serviceStatus {
                Text("EasyTier \(serviceStatus.easyTierVersion) — \(serviceStatus.coreReady ? "core ready" : "core not ready")")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Install Helper") {
                    service.install()
                }

                Button("Uninstall Helper") {
                    service.uninstall()
                }

                Button("Ping Helper") {
                    service.ping()
                }
            }
        }
        .frame(minWidth: 420, minHeight: 220, alignment: .topLeading)
        .padding(24)
        .task {
            service.refreshStatus()
        }
    }
}
