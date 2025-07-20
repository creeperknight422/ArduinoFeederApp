import SwiftUI

struct ScanningView: View {
    @AppStorage("DarkModeEnabled") private var isDarkModeEnabled = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(2)

                Text("Scanning for Feeders...")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text("This may take a few seconds.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        .navigationBarHidden(true)
    }
}
