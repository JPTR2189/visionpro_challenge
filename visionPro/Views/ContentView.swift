//
//  ContentView.swift
//  visionPro
//
//  Created by Jean Pierre on 23/06/26.
//

import SwiftUI

struct ContentView: View {

    var body: some View {
        VStack(spacing: 18) {
            Text("Portal Runes")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Entre no espaco imersivo para testar o portal com runas interativas.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ToggleImmersiveSpaceButton()
        }
        .frame(width: 420)
        .padding(32)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
