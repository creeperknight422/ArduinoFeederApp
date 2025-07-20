import SwiftUI

struct ManualFeed: View {
    @State private var amountToFeed: Double = 2.5
    @State private var isFeeding: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    @AppStorage("ipAddress") private var ipAddress: String = ""
    @AppStorage("weight") private var weight: String = ""
    @AppStorage("name") private var name: String = "-"
    @AppStorage("storage") private var storage: String = "-"
    @AppStorage("feededWeight") private var feededWeight: String = "-"
    @AppStorage("statusMessage") private var statusMessage: String = ""
    
    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
    
    @State private var feededWeightTimer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Select Amount\nto feed:")
                .font(.title)
                .multilineTextAlignment(.center)
            
            VStack {
                if !isFeeding {
                    Slider(value: $amountToFeed, in: 0...15, step: 0.1)
                        .padding()
                    Text(String(format: "%.1f lbs", amountToFeed))
                        .font(.largeTitle)
                        .bold()
                } else {
                    Text("\(feededWeight) lbs")
                        .font(.largeTitle)
                        .bold()
                        .padding()
                }
            }
            
            Button(action: {
                if isFeeding {
                    sendCommand("/H")
                    isFeeding = false
                    print("Stopped feeding manually")
                } else {
                    setWeight(String(format: "%.1f", amountToFeed))
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
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Feed Control")
        .onAppear {
            startFeededWeightTimer()
        }
        .onDisappear {
            feededWeightTimer?.invalidate()
                 feededWeightTimer = nil
        }
        .onChange(of: feededWeight) { newValue in
            if let fed = Double(newValue),
               isFeeding,
               fed >= amountToFeed - 0.01 {
                sendCommand("/H")
                isFeeding = false
                print("Auto-stopped feeding at \(fed) lbs (target: \(amountToFeed) lbs)")
            }
        }
        .alert("Feeding Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    func startFeededWeightTimer() {
        feededWeightTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            fetchFeededWeight()
        }
    }

    func fetchFeededWeight() {
        guard let url = URL(string: ipAddress + "/getFeededWeight") else {
            statusMessage = "Invalid feed URL"
            return
        }
        
        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    if error.code == NSURLErrorTimedOut {
                        statusMessage = "Disconnected"
                    } else {
                        statusMessage = "Fetch failed: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let fw = json["FeededWeight"] as? String else {
                    statusMessage = "Disconnected"
                    return
                }
                
                feededWeight = fw
            }
        }.resume()
    }
    
    func sendCommand(_ path: String) {
        guard let url = URL(string: ipAddress + path) else {
            handleError("Invalid IP address or URL.")
            return
        }
        
        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    handleError("Network error: \(error.localizedDescription)")
                    if isFeeding {
                        sendCommand("/H")
                        isFeeding = false
                        print("Feeding stopped due to error: \(error.localizedDescription)")
                    }
                    return
                }
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    handleError("Server responded with status code \(httpResponse.statusCode)")
                    if isFeeding {
                        sendCommand("/H")
                        isFeeding = false
                        print("Feeding stopped due to HTTP error: \(httpResponse.statusCode)")
                    }
                    return
                }
                if data == nil || data?.isEmpty == true {
                    handleError("No response from feeder device.")
                    if isFeeding {
                        sendCommand("/H")
                        isFeeding = false
                        print("Feeding stopped due to empty response.")
                    }
                    return
                }
                statusMessage = "Command \(path) sent successfully"
            }
        }.resume()
    }
    
    func handleError(_ message: String) {
/*        statusMessage = message
        errorMessage = message

        showErrorAlert = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            showErrorAlert = true
        }*/
    }
    
    func setWeight(_ value: String) {
        let sanitized = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "0"
        sendCommand("/setWeight?value=\(sanitized)")
    }
}
