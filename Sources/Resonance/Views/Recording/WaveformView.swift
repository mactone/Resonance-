import SwiftUI

struct WaveformView: View {
    let level: Float        // 0.0 – 1.0
    var barCount: Int = Constants.UI.waveformBarCount
    var color: Color = .accentColor

    @State private var phases: [Double] = []

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(
                            width: (geo.size.width - CGFloat(barCount - 1) * 3) / CGFloat(barCount),
                            height: barHeight(for: i, in: geo.size.height)
                        )
                        .animation(.easeInOut(duration: 0.12), value: level)
                }
            }
        }
        .onAppear {
            phases = (0..<barCount).map { _ in Double.random(in: 0..<Double.pi * 2) }
        }
    }

    private func barHeight(for index: Int, in maxHeight: CGFloat) -> CGFloat {
        guard !phases.isEmpty else { return 4 }
        let phase = phases[index]
        let noise = sin(phase + Double(index) * 0.4) * 0.3
        let base = Double(level)
        let height = max(0.05, min(1.0, base + noise * base))
        return CGFloat(height) * maxHeight
    }
}
