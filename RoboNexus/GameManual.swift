//
//  GameManual.swift
//
//  ADC Hub
//
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI
import WebKit

// Main SwiftUI view for the Game Manual
struct GameManual: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var navigation_bar_manager: NavigationBarManager
    @State private var reloadWebView = false  // State to manage reload
    
    var body: some View {
        WebView(url: URL(string: "https://online.flippingbook.com/view/201482508/")!, reload: $reloadWebView)
            .onReceive(navigation_bar_manager.$shouldReload) { shouldReload in
                if shouldReload {
                    reloadWebView = true  // Trigger WebView reload
                    navigation_bar_manager.shouldReload = false  // Reset the reload signal
                }
            }
            .onAppear(){
                navigation_bar_manager.title = "Game Manual"
            }
            .toolbarBackground(settings.tabColor(), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

// SwiftUI wrapper for WKWebView to display web content in SwiftUI
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var reload: Bool  // Binding to trigger reload
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if reload {
            uiView.reload()
            DispatchQueue.main.async {
                self.reload = false  // Reset the reload state to prevent continuous reloads
            }
        }
    }
}

// Preview for SwiftUI (optional)
struct GameManual_Previews: PreviewProvider {
    static var previews: some View {
        GameManual()
    }
}
