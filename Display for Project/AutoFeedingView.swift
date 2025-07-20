import SwiftUI

struct AutoFeedingView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isFeeding: Bool = false
    @State private var amountToFeed: Double = 0
    
    @AppStorage("ipAddress") private var ipAddress: String = ""
    @AppStorage("weight") private var weight: String = ""
    @AppStorage("name") private var name: String = "-"
    @AppStorage("storage") private var storage: String = "-"
    @AppStorage("feededWeight") private var feededWeight: String = "-"
    @AppStorage("statusMessage") private var statusMessage: String = ""
    @AppStorage("animal_weight") private var animalWeight: Double = 0.0
    @AppStorage("DarkModeEnabled") private var isDarkModeEnabled = false

    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Select Amount\nto feed:")
                .font(.title)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            VStack {
                if !isFeeding {
                    Slider(value: $amountToFeed, in: 0...15, step: 0.1)
                        .padding()
                    Text(String(format: "%.1f lbs", amountToFeed))
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.primary)
                } else {
                    Text("\(feededWeight) lbs")
                        .font(.largeTitle)
                        .bold()
                        .padding()
                        .foregroundColor(.primary)
                }
            }

            Button(action: {
                if isFeeding {
                    sendCommand("/H")
                    isFeeding = false
                    print("Stopped feeding manually")
                    presentationMode.wrappedValue.dismiss()
                } else {
                    sendCommand("/L")
                    isFeeding = true
                    print("Feeding \(amountToFeed) lbs")
                }
            }) {
                Text(isFeeding ? "Stop" : "Feed")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isFeeding ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }

            Text(isFeeding
                 ? "Target: \(String(format: "%.1f", amountToFeed)) lbs"
                 : "Amount Already Fed: \(feededWeight) lbs")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .navigationTitle("Feed Control")
        .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        .onAppear {
            amountToFeed = animalWeight * 0.02
            isFeeding = true
            sendCommand("/L")
        }
        .onChange(of: feededWeight) { newValue in
            if let fed = Double(newValue),
               isFeeding,
               fed >= amountToFeed - 0.01 {
                sendCommand("/H")
                isFeeding = false
                print("Auto-stopped feeding at \(fed) lbs (target: \(amountToFeed) lbs)")
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    func sendCommand(_ path: String) {
        guard let url = URL(string: ipAddress + path) else {
            statusMessage = "Invalid URL"
            return
        }
        
        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    statusMessage = "Send failed: \(error.localizedDescription)"
                } else {
                    statusMessage = "Command \(path) sent successfully"
                }
            }
        }.resume()
    }
}

