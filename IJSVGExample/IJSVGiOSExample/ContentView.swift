import IJSVG
import SwiftUI

struct ContentView: View {
    @Environment(\.displayScale) private var displayScale
    @State private var image: CGImage?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("IJSVG")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.black)
            VStack(spacing: 24) {
                if let image {
                    Image(image, scale: displayScale, label: Text("Car"))
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                        .frame(maxWidth: 600, maxHeight: 600)
                        .background(.white, in: RoundedRectangle(cornerRadius: 24))
                } else if let errorMessage {
                    ContentUnavailableView("Unable to load SVG",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text(errorMessage))
                } else {
                    ProgressView("Loading SVG")
                }

                Text("car.svg")
                    .font(.caption)
                    .foregroundStyle(Color.black.opacity(0.65))
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: displayScale) {
                loadSVG()
            }
        }
        .padding(.top, 24)
        .background(Color(white: 0.95))
        .preferredColorScheme(.light)
    }

    @MainActor
    private func loadSVG() {
        do {
            guard let url = Bundle.main.url(forResource: "car", withExtension: "svg") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let svg = try IJSVG(contentsOf: url)
            let scale = displayScale
            svg.renderingBackingScaleHelper = { scale }

            // Fit the SVG into a square without changing its intrinsic aspect ratio.
            let size = svg.size
            guard size.width > 0, size.height > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let factor = 600 / max(size.width, size.height)
            let outputSize = CGSize(width: max(1, size.width * factor),
                                    height: max(1, size.height * factor))
            image = try svg.renderCGImage(size: outputSize, flipped: true)
            errorMessage = nil
        } catch {
            image = nil
            errorMessage = error.localizedDescription
        }
    }
}
