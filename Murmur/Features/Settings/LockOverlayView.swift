//
//  LockOverlayView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI

struct LockOverlayView: View {
    @EnvironmentObject private var appLock: AppLockController

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                Text("Unlock Murmur")
                    .font(.headline)
                if !appLock.isLockEnabled {
                    Text("Set up app lock in Settings to keep Murmur secure.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
        }
    }

}

#Preview {
    let controller = AppLockController()
    controller.setLockEnabled(true)
    controller.appDidEnterBackground()
    return LockOverlayView()
        .environmentObject(controller)
}
