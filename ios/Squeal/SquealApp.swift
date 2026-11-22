import SwiftUI

@main
struct SquealApp: App {
    var body: some Scene {
        WindowGroup { Text("Squeal").font(.largeTitle).foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(red: 0.16, green: 0.13, blue: 0.24)) }
    }
}
