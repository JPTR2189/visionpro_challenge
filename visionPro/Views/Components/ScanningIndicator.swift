import SwiftUI

struct ScanningIndicator: View {

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(.indigo.opacity(0.3 - Double(index) * 0.08), lineWidth: 1.5)
                    .frame(width: CGFloat(44 + index * 22), height: CGFloat(44 + index * 22))
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.18),
                        value: isPulsing
                    )
            }

            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.indigo)
                .symbolEffect(.variableColor.iterative, options: .repeating)
        }
        .onAppear { isPulsing = true }
    }
}

#Preview {
    ScanningIndicator()
        .frame(width: 120, height: 120)
        .background(.black)
}
