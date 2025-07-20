import SwiftUI
import UserNotifications

struct ContentView: View {
    // AppStorage
    @AppStorage("savedFeedingTime") private var savedTime: Double = 0

    // Timer & scheduling
    @State private var currentTime = Date()
    @State private var lastTriggerMinute: Int? = nil
    @State private var timer: Timer?
    @State private var feededWeightTimer: Timer?
    @State private var hasEverConnected = false
    var connectionStatus: String {
        hasEverConnected ? "Connected" : statusMessage
    }


    
    // Arduino controller
    @AppStorage("ipAddress") private var ipAddress: String = "http://192.168.1.50"
    @AppStorage("weight") private var weight: String = ""
    @AppStorage("name") private var name: String = "-"
    @AppStorage("storage") private var storage: String = "-"
    @AppStorage("feededWeight") private var feededWeight: String = "-"
    @AppStorage("statusMessage") private var statusMessage: String = ""
    @AppStorage("animal_weight") private var animalWeight: Double = 450.0

    @State private var showAutoFeed = false
    @State private var isScanning = false


    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        return URLSession(configuration: config)
    }()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Spacer()
                    Image("IMG_0124")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 350, height: 250)
                        .cornerRadius(30)
                        .ignoresSafeArea()
                }
                .padding()

                // Status message
                if !connectionStatus.isEmpty {
                    Text(connectionStatus)
                        .font(.footnote)
                        .foregroundColor(connectionStatus == "Disconnected" ? .red : .green)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    NavigationLink(destination: SetFeedingTime()) {
                        HStack {
                            Text("Scheduled feeding time:")
                            Spacer()
                            Text(formattedTime(from: savedTime))
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }

                    NavigationLink(destination: ManualFeed()) {
                        HStack {
                            Text("Manually feed")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }

                    NavigationLink(destination: DeviceData()) {
                        HStack {
                            Text("View device data")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }

                    NavigationLink(destination: AnimalData()) {
                        HStack {
                            Text("View animal data")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                scanForArduino()

                feededWeightTimer?.invalidate()
                feededWeightTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    fetchFeededWeight()
                }
            }
            .sheet(isPresented: $showAutoFeed) {
                AutoFeedingView()
            }
        }
    }

    // MARK: - Time Formatting

    func formattedTime(from timeInterval: Double) -> String {
        let date = Date(timeIntervalSince1970: timeInterval)
        return formattedTime(date: date)
    }

    func formattedTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func targetTimeFormatted(from timeInterval: Double) -> String {
        let date = Date(timeIntervalSince1970: timeInterval)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Networking

    func sendCommand(_ path: String) {
        guard let url = URL(string: ipAddress + path) else {
            statusMessage = "Invalid URL"
            return
        }

        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if (error as NSError).code == NSURLErrorTimedOut {
                        statusMessage = "Disconnected (Timeout)"
                    } else {
                        statusMessage = "Send failed: \(error.localizedDescription)"
                    }
                } else {
                    statusMessage = "Command \(path) sent successfully"
                }
            }
        }.resume()
    }

    func fetchFeededWeight() {
        guard let url = URL(string: ipAddress + "/getFeededWeight") else {
            statusMessage = "Invalid feed URL"
            return
        }

        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    if error.code == NSURLErrorTimedOut && !hasEverConnected {
                        statusMessage = "Disconnected"
                    }
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let fw = json["FeededWeight"] as? String else {
                    if !hasEverConnected {
                        statusMessage = "Disconnected"
                    }
                    return
                }

                feededWeight = fw

                if !hasEverConnected {
                    hasEverConnected = true
                    statusMessage = "Connected"
                }
            }
        }.resume()
    }



    func setTargetTime(_ value: String) {
        sendCommand("/setTargetTime?value=\(value)")
    }

    func setAnimalWeight(_ value: String) {
        sendCommand("/setAnimalWeight?value=\(value)")
    }

    func fetchAllData() {
        fetchValue(from: "/getName") { json in
            if let n = json["name"] as? String {
                name = n
            }
        }

        fetchValue(from: "/getStorage") { json in
            if let s = json["Storage"] as? String {
                storage = s
            }
        }

        fetchFeededWeight()
    }

    func fetchValue(from endpoint: String, completion: @escaping ([String: Any]) -> Void) {
        guard let url = URL(string: ipAddress + endpoint) else {
            DispatchQueue.main.async {
                statusMessage = "Invalid URL for \(endpoint)"
            }
            return
        }

        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if (error as NSError).code == NSURLErrorTimedOut {
                        statusMessage = "Disconnected (Timeout)"
                    } else {
                        statusMessage = "Fetch \(endpoint) failed: \(error.localizedDescription)"
                    }
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    statusMessage = "Failed to parse response from \(endpoint)"
                    return
                }

                completion(json)
            }
        }.resume()
    }
    
    func scanForArduino() {
        guard !isScanning else { return }
        isScanning = true

        DispatchQueue.global(qos: .background).async {
            let group = DispatchGroup()
            for i in 1...250 {
                let testIP = "http://192.168.1.\(i)"
                guard let url = URL(string: testIP + "/getName") else { continue }

                group.enter()
                var request = URLRequest(url: url)
                request.timeoutInterval = 1.5

                let task = session.dataTask(with: request) { data, response, error in
                    defer { group.leave() }

                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let name = json["name"] as? String {
                        DispatchQueue.main.async {
                            ipAddress = testIP
                            statusMessage = "Connected to \(name)"
                            hasEverConnected = true
                        }
                        // Stop further scanning
                        group.notify(queue: .main) {
                            isScanning = false
                        }
                        return
                    }
                }
                task.resume()
            }

            group.notify(queue: .main) {
                if !hasEverConnected {
                    statusMessage = "No Arduino found"
                }
                isScanning = false
            }
        }
    }

    
}
