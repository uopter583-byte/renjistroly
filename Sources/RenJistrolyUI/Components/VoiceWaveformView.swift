import SwiftUI
import RenJistrolyModels

struct VoiceWaveformView: View {
    let isActive: Bool
    let voiceState: VoiceInputState

    private let barCount = 7

    var body: some View {
        if isActive {
            TimelineView(.animation) { context in
                HStack(spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor)
                            .frame(width: 2.5)
                            .scaleEffect(y: scale(for: index, at: context.date), anchor: .center)
                    }
                }
                .frame(height: 20)
            }
        } else {
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: 2.5)
                        .scaleEffect(y: 0.15, anchor: .center)
                }
            }
            .frame(height: 20)
        }
    }

    private var barColor: Color {
        switch voiceState {
        case .listening: return .blue
        case .lockedListening: return .purple
        case .transcribing: return .orange
        case .speaking: return .green
        case .failed: return .red
        default: return .secondary.opacity(0.4)
        }
    }

    private func scale(for index: Int, at date: Date) -> CGFloat {
        guard isActive else { return 0.15 }
        let t = date.timeIntervalSinceReferenceDate
        let phase = sin(Double(index) * 0.8 + t * 2.5)
        return max(0.15, abs(phase) * 0.9 + 0.1)
    }
}

struct VoiceWaveformView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            VoiceWaveformView(isActive: false, voiceState: .idle)
            VoiceWaveformView(isActive: true, voiceState: .listening)
            VoiceWaveformView(isActive: true, voiceState: .speaking)
            VoiceWaveformView(isActive: true, voiceState: .transcribing)
        }
        .padding()
    }
}
