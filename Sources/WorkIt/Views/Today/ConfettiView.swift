import SwiftUI

/// A one-shot confetti burst covering the full screen. Fires whenever `trigger`
/// changes value -- callers just increment a counter to replay it.
struct ConfettiView: View {
    let trigger: Int

    @State private var pieces: [Piece] = []

    private static let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    private static let pieceCount = 70
    private static let fallDuration: Double = 1.8

    struct Piece: Identifiable {
        let id = UUID()
        let color: Color
        let startX: CGFloat // fraction of screen width, 0...1
        let drift: CGFloat // horizontal wander in points
        let fallDistance: CGFloat
        let rotation: Double
        let delay: Double
        let size: CGFloat
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPieceView(piece: piece, containerSize: proxy.size, duration: Self.fallDuration)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onChange(of: trigger) { _, _ in
            burst()
        }
    }

    private func burst() {
        pieces = (0..<Self.pieceCount).map { _ in
            Piece(
                color: Self.colors.randomElement() ?? .orange,
                startX: CGFloat.random(in: 0...1),
                drift: CGFloat.random(in: -60...60),
                fallDistance: CGFloat.random(in: 500...900),
                rotation: Double.random(in: 180...900),
                delay: Double.random(in: 0...0.25),
                size: CGFloat.random(in: 6...12)
            )
        }
        let clearDelay = Self.fallDuration + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + clearDelay) {
            pieces = []
        }
    }
}

private struct ConfettiPieceView: View {
    let piece: ConfettiView.Piece
    let containerSize: CGSize
    let duration: Double

    @State private var fallen = false

    var body: some View {
        Rectangle()
            .fill(piece.color)
            .frame(width: piece.size, height: piece.size * 0.4)
            .position(
                x: piece.startX * containerSize.width + (fallen ? piece.drift : 0),
                y: (fallen ? piece.fallDistance : -20)
            )
            .rotationEffect(.degrees(fallen ? piece.rotation : 0))
            .opacity(fallen ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(piece.delay)) {
                    fallen = true
                }
            }
    }
}
