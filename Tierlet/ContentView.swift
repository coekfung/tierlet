//
//  ContentView.swift
//  Tierlet
//
//  Created by Zhuofeng on 2026/8/8.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var daemon = DaemonClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tierlet")
                .font(.largeTitle)

            Text(daemon.status)
                .foregroundStyle(.secondary)

            HStack {
                Button("Install Helper") {
                    daemon.install()
                }

                Button("Ping Helper") {
                    daemon.ping()
                }
            }
        }
        .frame(minWidth: 420, minHeight: 220, alignment: .topLeading)
        .padding(24)
        .task {
            daemon.refreshStatus()
        }
    }
}
