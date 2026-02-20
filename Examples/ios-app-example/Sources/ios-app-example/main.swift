
import SwiftUI
import ConfigReader

@main
struct iOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var message = "Loading..."

    var body: some View {
        Text(message)
            .onAppear(perform: loadConfig)
    }

    func loadConfig() {
        do {
            let config = try ConfigReader.shared.read(from: "config.json")
            message = config.get("message", as: String.self) ?? "Default Message"
        } catch {
            message = "Error loading config: \(error)"
        }
    }
}
