//
//  AgendaView.swift
//
//  ADC Hub
//
//  Created by Skyler Clagg on 9/26/24.
//

import SwiftUI
import SwiftSoup

struct AgendaView: View {
    let event: Event
    @EnvironmentObject var settings: UserSettings
    // Adjustable text size.
    var textSize: CGFloat = 17.0
    
    @State private var agendaLines: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Build the URL from the event's SKU.
    var agendaURL: URL? {
        URL(string: "https://www.robotevents.com/robot-competitions/adc/\(event.sku).html#agenda")
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading Agenda…")
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if !agendaLines.isEmpty {
                    ScrollView {
                        VStack(alignment: .center, spacing: 8) {
                            ForEach(agendaLines, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: textSize))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("No agenda available.")
                        .padding()
                }
            }
            .navigationBarTitle("Event Agenda", displayMode: .inline)
            .onAppear {
                fetchAgenda()
            }
        }
    }
    
    func fetchAgenda() {
        guard let url = agendaURL else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL."
                self.isLoading = false
            }
            return
        }
        
        print("DEBUG: Fetching agenda from URL: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("DEBUG: Error fetching data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                return
            }
            
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                print("DEBUG: Data is nil or unable to decode HTML.")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load data."
                    self.isLoading = false
                }
                return
            }
            
            print("DEBUG: Full HTML length: \(html.count)")
            
            do {
                let document = try SwiftSoup.parse(html)
                // Use the selector that previously worked.
                if let agendaElement = try document.select("tab[name='Agenda']").first() {
                    // Attempt to extract paragraphs.
                    let paragraphElements = try agendaElement.select("p").array()
                    var lines: [String] = []
                    if paragraphElements.isEmpty {
                        // Fallback: split the raw text by newlines.
                        let rawText = try agendaElement.text()
                        lines = rawText.components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    } else {
                        for paragraph in paragraphElements {
                            let text = try paragraph.text()
                            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                                lines.append(text)
                            }
                        }
                    }
                    print("DEBUG: Joined agenda text:\n\(lines.joined(separator: "\n\n"))")
                    DispatchQueue.main.async {
                        self.agendaLines = lines
                        self.isLoading = false
                    }
                } else {
                    print("DEBUG: No agenda element found with selector \"tab[name='Agenda']\".")
                    DispatchQueue.main.async {
                        self.agendaLines = ["No agenda found."]
                        self.isLoading = false
                    }
                }
            } catch {
                print("DEBUG: Error parsing HTML: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }.resume()
    }
}

struct AgendaView_Previews: PreviewProvider {
    static var previews: some View {
        // Replace Event() with an appropriate test event that has a valid sku.
        AgendaView(event: Event(), textSize: 18)
            .environmentObject(UserSettings())
    }
}
