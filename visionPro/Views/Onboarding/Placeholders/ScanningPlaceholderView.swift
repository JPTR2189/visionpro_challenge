import SwiftUI

struct ScanningPlaceholderView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                RoomWireframeShape(w: w, h: h)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)

                Image("TutorialScanning")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: w * 0.96)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct RoomWireframeShape: Shape {
    let w: CGFloat
    let h: CGFloat

    func path(in rect: CGRect) -> Path {
        let backTL = CGPoint(x: w * 0.305, y: h * 0.240)
        let backTR = CGPoint(x: w * 0.695, y: h * 0.240)
        let backBL = CGPoint(x: w * 0.305, y: h * 0.800)
        let backBR = CGPoint(x: w * 0.695, y: h * 0.800)

        let frontTL = CGPoint(x: w * 0.015, y: h * 0.060)
        let frontTR = CGPoint(x: w * 0.985, y: h * 0.060)
        let frontBL = CGPoint(x: 0,          y: h * 1.000)
        let frontBR = CGPoint(x: w,          y: h * 1.000)

        var p = Path()

        p.move(to: backTL)
        p.addLine(to: backTR)
        p.addLine(to: backBR)
        p.addLine(to: backBL)
        p.closeSubpath()

        p.move(to: frontTL); p.addLine(to: backTL)
        p.move(to: frontTR); p.addLine(to: backTR)
        p.move(to: frontTL); p.addLine(to: frontTR)

        p.move(to: frontBL); p.addLine(to: backBL)
        p.move(to: frontBR); p.addLine(to: backBR)
        p.move(to: frontBL); p.addLine(to: frontBR)

        return p
    }
}
