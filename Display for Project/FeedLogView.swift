import SwiftUI

struct FeedLogEntry: Codable, Identifiable {
    var id = UUID()
    let time: String
    let targetWeight: Float
}

struct FeedLogView: View {
    let device: DetectedDevice
    @State private var feedLog: [FeedLogEntry] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading) {
            if isLoading {
                ProgressView("Loading Feed Log...")
                    .padding()
            } else if feedLog.isEmpty {
                Text("No feed log entries.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(feedLog) { entry in
                    HStack {
                        Text(entry.time)
                        Spacer()
                        Text(String(format: "%.2f oz", entry.targetWeight))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Feed Log")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchFeedLog()
        }
    }

    func fetchFeedLog() {
        guard let url = URL(string: "http://\(device.ipAddress)/getFeedLog") else {
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data else { return }
                if let decoded = try? JSONDecoder().decode([FeedLogEntry].self, from: data) {
                    feedLog = decoded
                print(feedLog)
                } else {
                    print("Failed to decode feed log.")
                }
            }
        }.resume()
    }
}
