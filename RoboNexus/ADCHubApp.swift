//
//  ADCHubApp.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//

import os
import SwiftUI

let API = ADCHubAPI()
let activities = ADCHubActivityController()

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

struct CustomCenter: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context[HorizontalAlignment.center]
    }
}

extension HorizontalAlignment {
    static let customCenter: HorizontalAlignment = .init(CustomCenter.self)
}

/// Detect a Shake gesture in SwiftUI
/// Based on https://stackoverflow.com/a/60085784/128083
struct ShakableViewRepresentable: UIViewControllerRepresentable {
    let onShake: () -> ()
    
    class ShakeableViewController: UIViewController {
        var onShake: (() -> ())?
        
        override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake {
                onShake?()
            }
        }
    }
    
    func makeUIViewController(context: Context) -> ShakeableViewController {
        let controller = ShakeableViewController()
        controller.onShake = onShake
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ShakeableViewController, context: Context) {}
}

extension View {
    func onShake(_ block: @escaping () -> Void) -> some View {
        overlay(
            ShakableViewRepresentable(onShake: block).allowsHitTesting(false)
        )
    }
}

extension UIApplication {
    static var appVersion: String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
    static var appBuildNumber: String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}

extension Collection where Indices.Iterator.Element == Index {
    public subscript(safe index: Index) -> Iterator.Element? {
        return (startIndex <= index && index < endIndex) ? self[index] : nil
    }
}

struct LazyView<Content: View>: View {
    private let build: () -> Content
    
    init(_ build: @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

struct BulletList: View {
    var listItems: [String]
    var listItemSpacing: CGFloat? = nil
    var bullet: String = "•"
    var bulletWidth: CGFloat? = nil
    var bulletAlignment: Alignment = .leading
    
    var body: some View {
        VStack(alignment: .leading, spacing: listItemSpacing) {
            ForEach(listItems, id: \.self) { data in
                HStack(alignment: .top) {
                    Text(bullet)
                        .frame(width: bulletWidth, alignment: bulletAlignment)
                    Text(data)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .font(.body) // Adjust font size as needed
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct NoData: View {
    var body: some View {
        VStack {
            Image(systemName: "xmark.bin.fill")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            Spacer().frame(height: 5)
            Text("No data")
                .foregroundColor(.secondary)
        }
    }
}

struct ImportingData: View {
    var body: some View {
        ProgressView()
            .font(.system(size: 30))
            .tint(.secondary)
        Spacer().frame(height: 5)
        Text("Importing Data")
            .foregroundColor(.secondary)
    }
}

@main
struct ADCHub: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var favorites = FavoriteStorage()
    @StateObject var settings = UserSettings()
    @StateObject var dataController = ADCHubDataController()
    // NEW: Create a ConfigManager instance and inject it into the environment.
    @StateObject var configManager = ConfigManager()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(favorites)
                .environmentObject(settings)
                .environmentObject(dataController)
                .environmentObject(EventSearch())
                .environmentObject(configManager)  // Inject the ConfigManager
                .tint(settings.buttonColor())
                .onAppear {
                    #if DEBUG
                    print("Debug configuration")
                    #else
                    print("Release configuration")
                    #endif
                    if Bundle.main.path(forResource: "Config", ofType: "plist") == nil {
                        let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Production")
                        logger.warning("Production API keys inaccessible!")
                    }
                    let activeSeason = API.get_current_season_id()
                    settings.setSelectedSeasonID(id: activeSeason)
                                        settings.updateUserDefaults()
                    
                    DispatchQueue.global(qos: .userInteractive).async {
                        API.generate_season_id_map()
                        API.populate_all_world_skills_caches()
                        
                    }
                }
        }
    }
}
