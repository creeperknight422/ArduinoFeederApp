import SwiftUI

struct DiagnosticsView: View {
    @AppStorage("ipAddress") private var ipAddress: String = ""
    @AppStorage("name") private var name: String = "-"
    @AppStorage("storage") private var storage: String = "-"
    @AppStorage("feededWeight") private var feededWeight: String = "-"
    @State private var statusMessage: String = ""
    @State private var connectionStatus = "Disconnected"
    @AppStorage("DarkModeEnabled") private var isEnabled = false
    
    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        return URLSession(configuration: config)
    }()
    
    var body: some View {
        Form {
            Section(){
                Button(action: {
                    sendCommand("/getName")
                })
                {
                    DeviceDataControlRow2(title: "Get Name Command")
                        .foregroundColor(.primary)
                }
                Button(action: {
                    sendCommand("/getFeededWeight")
                })
                {
                    DeviceDataControlRow2(title: "Get Weight and WiFi Status Command")
                        .foregroundColor(.primary)
                }
                Button(action: {
                    sendCommand("/getFeedLog")
                })
                {
                    DeviceDataControlRow2(title: "Get Feed Log Command")
                        .foregroundColor(.primary)
                }
            }
            .listRowBackground(Color(.secondarySystemBackground))
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            if !statusMessage.isEmpty {
                DeviceDataControlRow2(title: statusMessage)
                    .foregroundColor(connectionStatus == "Disconnected" ? .red : .green)
                    .listRowBackground(Color(.secondarySystemBackground))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

        }
        .navigationTitle("Troubleshooting")
        .preferredColorScheme(isEnabled ? .dark : .light)
        .scrollContentBackground(.hidden)

    }

    func sendCommand(_ path: String) {
        guard let url = URL(string: ipAddress + path) else {
            statusMessage = "Invalid URL"
            return
        }

        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    switch error.code {
                    case NSURLErrorTimedOut:
                        statusMessage = "Request timed out, please reset feeder or phone"
                        connectionStatus = "Disconnected"
                    case NSURLErrorNotConnectedToInternet:
                        statusMessage = "No internet connection. Please check your Phone's internet"
                        connectionStatus = "Disconnected"
                    case NSURLErrorNetworkConnectionLost:
                        statusMessage = "Feeder has lost internet, please reconnect"
                        connectionStatus = "Disconnected"
                    default:
                        statusMessage = "Send failed: \(error.localizedDescription)"
                        connectionStatus = "Disconnected"
                    }
                } else {
                    statusMessage = "Command \(path) sent successfully"
                    connectionStatus = "Connected"
                }
            }
        }.resume()
    }

}
