//
//  ADCHubAPI.swift
//
//  ADC Hub
//
//  Based on
//  VRC RoboScout by William Castro
//
//  Created by Skyler Clagg on 9/26/24.
//


import Foundation
import OrderedCollections
#if canImport(EventKit)
import EventKit
#endif
import Matft

enum ADCHubAPIError: Error {
    case missing_data(String)
}

// MARK: - World Skills Response Models
public struct WorldSkillsResponse: Decodable {
    
    public struct WorldSkillsResponseTeam: Decodable {
        var id: Int
        var program: String
        var team: String
        var teamName: String
        var organization: String
        var city: String
        var region: String?
        var country: String
        var eventRegion: String
        var eventRegionId: Int
    }
    
    public struct WorldSkillsResponseEvent: Decodable {
        var sku: String
    }
    
    public struct WorldSkillsResponseScores: Decodable {
        var score: Int
        var programming: Int
        var driver: Int
        var maxProgramming: Int
        var maxDriver: Int
    }
    
    var rank: Int
    var team: WorldSkillsResponseTeam
    var event: WorldSkillsResponseEvent
    var scores: WorldSkillsResponseScores
}

// MARK: - World Skills Cache
public struct WorldSkillsCache {
    var teams: [WorldSkills]
    
    public init() {
        self.teams = [WorldSkills]()
    }
    
    public init(responses: [WorldSkillsResponse]) {
        self.teams = responses.map {
            WorldSkills(
                team: Team(id: $0.team.id, number: $0.team.team, fetch: false),
                ranking: $0.rank,
                event: Event(sku: $0.event.sku, fetch: false),
                driver: $0.scores.driver,
                programming: $0.scores.programming,
                highest_driver: $0.scores.maxDriver,
                highest_programming: $0.scores.maxProgramming,
                combined: $0.scores.score,
                event_region: $0.team.eventRegion,
                event_region_id: $0.team.eventRegionId
            )
        }
    }
}


// MARK: - ADCHubAPI Class
public class ADCHubAPI {
    
    // Remove old global caches.
    // New, separate caches for each program/grade combination:
    public var adc_middle_school_skills_cache: WorldSkillsCache = WorldSkillsCache()
    public var adc_high_school_skills_cache: WorldSkillsCache = WorldSkillsCache()
    
    public var viqrc_elementary_school_skills_cache: WorldSkillsCache = WorldSkillsCache()
    public var viqrc_middle_school_skills_cache: WorldSkillsCache = WorldSkillsCache()
    
    public var v5rc_middle_school_skills_cache: WorldSkillsCache = WorldSkillsCache()
    public var v5rc_high_school_skills_cache: WorldSkillsCache = WorldSkillsCache()
    
    public var vurc_skills_cache: WorldSkillsCache = WorldSkillsCache()
    public var vairc_high_school_skills_cache: WorldSkillsCache = WorldSkillsCache()
    public var vairc_college_skills_cache: WorldSkillsCache = WorldSkillsCache()
    
    public var imported_skills: Bool
    public var regions_map: [String: Int]
    public var imported_trueskill: Bool
    public var season_id_map: [OrderedDictionary<Int, String>] // [ADC]
    
    public var level_map: [OrderedDictionary<Int, String>] = [
        OrderedDictionary(uniqueKeysWithValues: [
            (0, "All"),
            (1, "Event Region Championship"),
            (2, "National Championship"),
            (3, "World Championship"),
            (4, "Signature Event"),
            (5, "JROTC Brigade Championship"),
            (6, "JROTC National Championship"),
            (7, "Showcase Event")
        ])
    ]
    
    public var grade_map: [OrderedDictionary<Int, String>] = [
        OrderedDictionary(uniqueKeysWithValues: [
            (0, "All"),
            (1, "Middle School"),
            (2, "High School"),
            (3, "College")
        ])
    ]
    
    public var current_skills_season_id: Int
    
    public init() {
        self.adc_middle_school_skills_cache = WorldSkillsCache()
        self.adc_high_school_skills_cache = WorldSkillsCache()
        self.viqrc_elementary_school_skills_cache = WorldSkillsCache()
        self.viqrc_middle_school_skills_cache = WorldSkillsCache()
        self.v5rc_middle_school_skills_cache = WorldSkillsCache()
        self.v5rc_high_school_skills_cache = WorldSkillsCache()
        self.vurc_skills_cache = WorldSkillsCache()
        self.vairc_college_skills_cache = WorldSkillsCache()
        self.vairc_high_school_skills_cache = WorldSkillsCache()
        
        self.imported_skills = false
        self.regions_map = [String: Int]()
        self.imported_trueskill = false
        self.season_id_map = [OrderedDictionary<Int, String>]()
        self.current_skills_season_id = 0
    }
    
    // MARK: - Dynamic Program ID Support
    public static func selected_program_id() -> Int {
        // Expecting UserSettings.getSelectedProgram() to return "ADC", "VIQRC", "VURC", or "V5RC"
        let programStr = UserSettings.getSelectedProgram() ?? ProgramType.v5rc.rawValue
        let mapping: [String: Int] = [
            "Aerial Drone Competition": 44,
            "VEX IQ Robotics Competition": 41,
            "VEX U Robotics Competition": 4,
            "VEX V5 Robotics Competition": 1,
            "VEX AI Robotics Competition" : 57
        ]
        return mapping[programStr] ?? 1
    }
    
    public static func robotevents_date(date: String, localize: Bool) -> Date? {
        let formatter = DateFormatter()
        if localize {
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            return formatter.date(from: date) ?? nil
        } else {
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            var split = date.split(separator: "-")
            if !split.isEmpty { split.removeLast() }
            return formatter.date(from: split.joined(separator: "-")) ?? nil
        }
    }
    
    public static func robotevents_url() -> String {
        return "https://www.robotevents.com/api/v2"
    }
    
    public static func robotevents_access_key() -> String {
        return UserSettings.getRobotEventsAPIKey() ?? ""
    }
    
    public static func robotevents_request(request_url: String, params: [String: Any] = [:]) -> [[String: Any]] {
        var data = [[String: Any]]()
        var request_url = self.robotevents_url() + request_url
        var page = 1
        var cont = true
        var params = params
        
        while cont {
            params["page"] = page
            let semaphore = DispatchSemaphore(value: 0)
            if params["per_page"] == nil { params["per_page"] = 250 }
            
            var components = URLComponents(string: request_url)!
            components.queryItems = params.map { (key, value) in
                URLQueryItem(name: key, value: String(describing: value))
            }
            request_url = components.url?.description ?? request_url
            
            for (key, value) in params {
                if value is [CustomStringConvertible] {
                    for (index, elem) in (value as! [CustomStringConvertible]).enumerated() {
                        request_url += String(format: "&%@[%d]=%@", key, index, elem.description)
                    }
                }
            }
            
            let request = NSMutableURLRequest(url: URL(string: request_url)!)
            request.setValue(String(format: "Bearer %@", self.robotevents_access_key()), forHTTPHeaderField: "Authorization")
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request as URLRequest) { (response_data, response, error) in
                if response_data != nil {
                    do {
                        print(String(format: "RobotEvents API request (page %d): %@", page, components.url?.description ?? request_url))
                        let json = try JSONSerialization.jsonObject(with: response_data!) as? [String: Any]
                        if json == nil || (response as? HTTPURLResponse)?.statusCode != 200 {
                            return
                        }
                        for elem in json!["data"] as! [Any] {
                            data.append(elem as! [String: Any])
                        }
                        page += 1
                        if ((json!["meta"] as! [String: Any])["last_page"] as! Int == (json!["meta"] as! [String: Any])["current_page"] as! Int) {
                            cont = false
                        }
                        semaphore.signal()
                    } catch let error as NSError {
                        print("NSERROR " + error.description)
                        cont = false
                        semaphore.signal()
                    }
                } else if let error = error {
                    print("ERROR " + error.localizedDescription)
                    cont = false
                    semaphore.signal()
                }
            }
            task.resume()
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        }
        return data
    }
    
    public static func teamMatchesForSeason(teamID: Int, season: Int) -> [[String: Any]] {
        // Build the endpoint URL using teamID.
        let endpoint = "/teams/\(teamID)/matches"
        
        // Set up the parameters using the required key.
        let params: [String: Any] = ["season[]": season]
        
        // Use the existing robotevents_request helper to perform the request (handles pagination).
        let matchesData = robotevents_request(request_url: endpoint, params: params)
        
        return matchesData
    }
    
    
    public static func robotevents_competition_scraper(params: [String: Any] = [:]) -> [String] {
        var request_url = "https://www.robotevents.com/robot-competitions/ADC"
        var params = params
        
        if params["page"] == nil { params["page"] = 1 }
        if params["country_id"] == nil { params["country_id"] = "*" }
        if params["level_class_id"] as? Int == 4 { params["level_class_id"] = 9 }
        if params["level_class_id"] as? Int == 5 { params["level_class_id"] = 12 }
        if params["level_class_id"] as? Int == 6 { params["level_class_id"] = 13 }
        if params["grade_level_id"] as? Int == 1 { params["grade_level_id"] = 2 }
        else if params["grade_level_id"] as? Int == 2 { params["grade_level_id"] = 3 }
        
        let semaphore = DispatchSemaphore(value: 0)
        var components = URLComponents(string: request_url)!
        components.queryItems = params.map { (key, value) in
            URLQueryItem(name: key, value: String(describing: value))
        }
        request_url = components.url?.description ?? request_url
        
        for (key, value) in params {
            if value is [CustomStringConvertible] {
                for (index, elem) in (value as! [CustomStringConvertible]).enumerated() {
                    request_url += String(format: "&%@[%d]=%@", key, index, elem.description)
                }
            }
        }
        var sku_array = [String]()
        let request = NSMutableURLRequest(url: URL(string: request_url)!)
        request.setValue(String(format: "Bearer %@", self.robotevents_access_key()), forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) { (response_data, response, error) in
            if response_data != nil {
                print(String(format: "RobotEvents Scraper (page %d): %@", params["page"] as? Int ?? 0, components.url?.description ?? request_url))
                let html = String(data: response_data!, encoding: .utf8)!
                let regex = try! NSRegularExpression(pattern: "https://www\\.robotevents\\.com/robot-competitions/ADC/[A-Z0-9_-]+\\.html", options: [.caseInsensitive])
                let range = NSRange(location: 0, length: html.count)
                let matches = regex.matches(in: html, options: [], range: range)
                for match in matches {
                    sku_array.append(String(html[Range(match.range, in: html)!])
                        .replacingOccurrences(of: "https://www.robotevents.com/robot-competitions/ADC/", with: "")
                        .replacingOccurrences(of: ".html", with: ""))
                }
                semaphore.signal()
            } else if let error = error {
                print("ERROR " + error.localizedDescription)
                semaphore.signal()
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return sku_array
    }
    
    // MARK: - Program/Grade–Specific World Skills Caches Population
    /// Populates the appropriate world skills caches based on the selected program.
    public func populate_all_world_skills_caches(completion: @escaping () -> Void = {}) {
        print("Populating caches for the new season...")
        let seasonID = self.selected_season_id()
        let dispatchGroup = DispatchGroup()
        
        let programStr = UserSettings.getSelectedProgram() ?? ProgramType.v5rc.rawValue
        switch programStr {
        case "Aerial Drone Competition":
            dispatchGroup.enter()
            fetch_world_skills(forGrade: "Middle School", season: seasonID) { responses in
                self.adc_middle_school_skills_cache = WorldSkillsCache(responses: responses)
                print("ADC Middle School Cache populated with \(self.adc_middle_school_skills_cache.teams.count) teams.")
                dispatchGroup.leave()
            }
            dispatchGroup.enter()
            fetch_world_skills(forGrade: "High School", season: seasonID) { responses in
                self.adc_high_school_skills_cache = WorldSkillsCache(responses: responses)
                print("ADC High School Cache populated with \(self.adc_high_school_skills_cache.teams.count) teams.")
                dispatchGroup.leave()
            }
        case "VEX IQ Robotics Competition":
            dispatchGroup.enter()
            fetch_world_skills(forGrade: "Elementary", season: seasonID) { responses in
                self.viqrc_elementary_school_skills_cache = WorldSkillsCache(responses: responses)
                print("VIQRC Elementary Cache populated with \(self.viqrc_elementary_school_skills_cache.teams.count) teams.")
                dispatchGroup.leave()
            }
            dispatchGroup.enter()
            fetch_world_skills(forGrade: "Middle School", season: seasonID) { responses in
                self.viqrc_middle_school_skills_cache = WorldSkillsCache(responses: responses)
                print("VIQRC Middle School Cache populated with \(self.viqrc_middle_school_skills_cache.teams.count) teams.")
                dispatchGroup.leave()
            }
        case "VEX V5 Robotics Competition":
            dispatchGroup.enter()
            fetch_world_skills(forGrade: "Middle School", season: seasonID) { responses in
                self.v5rc_middle_school_skills_cache = WorldSkillsCache(responses: responses)
                print("V5RC Middle School Cache populated with \(self.v5rc_middle_school_skills_cache.teams.count) teams.")
                dispatchGroup.leave()
            }
            dispatchGroup.enter()
            fetch_world_skills(forGrade: "High School", season: seasonID) { responses in
                self.v5rc_high_school_skills_cache = WorldSkillsCache(responses: responses)
                print("V5RC High School Cache populated with \(self.v5rc_high_school_skills_cache.teams.count) teams.")
                dispatchGroup.leave()
            }
        case "VEX U Robotics Competition":
            dispatchGroup.enter()
            fetch_world_skills(forGrade: "College", season: seasonID) { responses in
                self.vurc_skills_cache = WorldSkillsCache(responses: responses)
                print("VURC Cache populated with \(self.vurc_skills_cache.teams.count) teams.")
                dispatchGroup.leave()
            }
        case "VEX AI Robotics Competition":
            dispatchGroup.enter()
            fetch_world_skills(forGrade: "High School", season: seasonID) { responses in
                self.vairc_high_school_skills_cache = WorldSkillsCache(responses: responses)
                print("VAIRC High School Cache populated with \(self.vairc_high_school_skills_cache.teams.count) teams.")
                dispatchGroup.leave()
            }
            dispatchGroup.enter()
            fetch_world_skills(forGrade: "College", season: seasonID) { responses in
                self.vairc_college_skills_cache = WorldSkillsCache(responses: responses)
                print("VAIRC College Cache populated with \(self.vairc_college_skills_cache.teams.count) teams.")
                dispatchGroup.leave()
            }
        default:
            print("Unknown program: no caches updated.")
        }
        
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }
    /// Returns the WorldSkills object for a given team by checking the appropriate cache
    /// based on the selected program and the team's grade.
    public func world_skills_for(team: Team) -> WorldSkills? {
        let prog = UserSettings.getSelectedProgram() ?? ProgramType.v5rc.rawValue
        var cache: WorldSkillsCache
        if prog == "Aerial Drone Competition" {
            if team.grade == "Middle School" {
                cache = self.adc_middle_school_skills_cache
            } else {
                cache = self.adc_high_school_skills_cache
            }
        } else if prog == "VEX IQ Robotics Competition" {
            if team.grade == "Elementary" {
                cache = self.viqrc_elementary_school_skills_cache
            } else {
                cache = self.viqrc_middle_school_skills_cache
            }
        } else if prog == "VEX V5 Robotics Competition" {
            if team.grade == "Middle School" {
                cache = self.v5rc_middle_school_skills_cache
            } else {
                cache = self.v5rc_high_school_skills_cache
            }
        } else if prog == "VEX U Robotics Competion" {
            cache = self.vurc_skills_cache
        }else if prog == "VEX AI Robotics Competition" {
            if team.grade == "High School"{
                cache = self.vairc_high_school_skills_cache
            }else{
                cache = self.vairc_college_skills_cache
            }
        }
        else {
            // Fallback to ADC high school cache if something unexpected occurs.
            cache = self.adc_high_school_skills_cache
        }
        return cache.teams.first(where: { $0.team.id == team.id })
    }

    
    func fetch_world_skills(forGrade grade: String, season: Int, completion: @escaping ([WorldSkillsResponse]) -> Void) {
        var components = URLComponents(string: String(format: "https://www.robotevents.com/api/seasons/%d/skills", season))!
        components.queryItems = [URLQueryItem(name: "grade_level", value: grade)]
        
        // Print the full URL being used
        if let urlString = components.url?.absoluteString {
            print("Fetching world skills for grade \(grade) for season \(season) using URL: \(urlString)")
        } else {
            print("Failed to construct URL for grade \(grade) and season \(season)")
        }
        
        let request = NSMutableURLRequest(url: components.url! as URL)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) { (response_data, response, error) in
            if let response_data = response_data {
                do {
                    let data = try JSONDecoder().decode([WorldSkillsResponse].self, from: response_data)
                    print("Fetched \(grade) teams for season \(season): \(data.count) teams.")
                    completion(data)
                } catch {
                    print("Error decoding \(grade) data: \(error.localizedDescription)")
                    completion([])
                }
            } else if let error = error {
                print("Error fetching \(grade) data: \(error.localizedDescription)")
                completion([])
            }
        }
        task.resume()
    }
    
    // MARK: - Season and Misc Methods
    public func generate_season_id_map() {
        self.season_id_map = [[:]]
        let seasons_data = ADCHubAPI.robotevents_request(request_url: "/seasons/")
        for season_data in seasons_data {
            if let program = season_data["program"] as? [String: Any],
               let program_id = program["id"] as? Int,
               program_id == ADCHubAPI.selected_program_id() {
                let season_id = season_data["id"] as! Int
                let season_name = season_data["name"] as? String ?? ""
                self.season_id_map[0][season_id] = season_name
            }
        }
        print("Season ID map generated")
    }
    
    public func selected_season_id() -> Int {
        return UserDefaults.standard.object(forKey: "selected_season_id") as? Int ?? self.active_season_id()
    }
    public func setSelectedSeasonID(id: Int) {
        // Write the new season ID to UserDefaults under the key "selected_season_id"
        UserDefaults.standard.set(id, forKey: "selected_season_id")
    }

    
    public func active_season_id() -> Int {
        return !self.season_id_map.isEmpty ? self.season_id_map[0].keys.first ?? 190 : 190
    }
    
    public func get_current_season_id() -> Int {
        let seasons_data = ADCHubAPI.robotevents_request(request_url: "/seasons", params: ["program": [ADCHubAPI.selected_program_id()], "active": true])
        if let current_season = seasons_data.first,
           let season_id = current_season["id"] as? Int {
            return season_id
        }
        return self.active_season_id()
    }
    
}


// Additional classes and structs remain unchanged below...

public class Division: Hashable, Identifiable {
    public var id: Int
    public var name: String
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(0)
    }
    
    public init(data: [String: Any] = [:]) {
        self.id = data["id"] as? Int ?? 0
        self.name = data["name"] as? String ?? ""
    }
    
    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
    
    public static func ==(lhs: Division, rhs: Division) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

public enum Alliance {
    case red, blue
}

public enum Round: Int {
    case none, practice, qualification, r128, r64, r32, r16, quarterfinals, semifinals, finals
}

private let round_map = [
    0: Round.none,
    1: Round.practice,
    2: Round.qualification,
    3: Round.quarterfinals,
    4: Round.semifinals,
    5: Round.finals,
    6: Round.r16,
    7: Round.r32,
    8: Round.r64,
    9: Round.r128
]

public class Match: Identifiable {
    
    public var id: Int
    public var event: Event
    public var division: Division
    public var field: String
    public var scheduled: Date?
    public var started: Date?
    public var round: Round
    public var instance: Int
    public var matchnum: Int
    public var name: String
    public var blue_alliance: [Team]
    public var red_alliance: [Team]
    public var blue_score: Int
    public var red_score: Int

    public init(data: [String: Any] = [:], fetch: Bool = false) {
        self.id = (data["id"] != nil) ? data["id"] as? Int ?? 0 : 0
        self.event = (data["event"] != nil) ? Event(id: ((data["event"] as! [String: Any])["id"] as! Int), fetch: fetch) : Event()
        self.division = (data["division"] != nil) ? Division(data: data["division"] as! [String : Any]) : Division()
        self.field = (data["field"] != nil) ? data["field"] as? String ?? "" : ""
        self.scheduled = (data["scheduled"] != nil) ? ADCHubAPI.robotevents_date(date: data["scheduled"] as? String ?? "", localize: true) : nil
        self.started = (data["started"] != nil) ? ADCHubAPI.robotevents_date(date: data["started"] as? String ?? "", localize: true) : nil
        
        let round = (data["round"] != nil) ? data["round"] as? Int ?? 0 : 0
        self.round = round_map[round] ?? Round.none
        
        self.instance = (data["instance"] != nil) ? data["instance"] as? Int ?? 0 : 0
        self.matchnum = (data["matchnum"] != nil) ? data["matchnum"] as? Int ?? 0 : 0
        self.name = (data["name"] != nil) ? data["name"] as? String ?? "" : ""
        self.blue_alliance = [Team]()
        self.red_alliance = [Team]()
        self.blue_score = 0
        self.red_score = 0
        
        for alliance in (data["alliances"] != nil) ? data["alliances"] as! [[String: Any]] : [[String: Any]]() {
            if alliance["color"] as! String == "blue" {
                self.blue_score = alliance["score"] as? Int ?? -1
                for team in (alliance["teams"] != nil) ? alliance["teams"] as! [[String: Any]] : [[String: Any]]() {
                    self.blue_alliance.append(Team(id:(team["team"] as! [String: Any])["id"] as! Int, fetch: false))
                }
            }
            else {
                self.red_score = alliance["score"] as? Int ?? -1
                for team in (alliance["teams"] != nil) ? alliance["teams"] as! [[String: Any]] : [[String: Any]]() {
                    self.red_alliance.append(Team(id:(team["team"] as! [String: Any])["id"] as! Int, fetch: false))
                }
            }
        }
        while self.red_alliance.count < 2 {
            self.red_alliance.append(Team())
        }
        while self.blue_alliance.count < 2 {
            self.blue_alliance.append(Team())
        }
    }
    
    func fetch_full_info() {
        var blue_full = [Team]()
        var red_full = [Team]()
        
        for team in self.blue_alliance {
            blue_full.append(Team(id: team.id))
        }
        
        for team in self.red_alliance {
            red_full.append(Team(id: team.id))
        }
        
        self.blue_alliance = blue_full
        self.red_alliance = red_full
    }
    
    func alliance_for(team: Team) -> Alliance? {
        for alliance_team in self.red_alliance {
            if alliance_team.id == team.id {
                return Alliance.red
            }
        }
        for alliance_team in self.blue_alliance {
            if alliance_team.id == team.id {
                return Alliance.blue
            }
        }
        return nil
    }
    
    func winning_alliance() -> Alliance? {
        if self.red_score > self.blue_score {
            return Alliance.red
        }
        else if self.blue_score > self.red_score {
            return Alliance.blue
        }
        else {
            return nil
        }
    }
    
    func completed() -> Bool {
        if (self.started == nil || self.started?.timeIntervalSinceNow ?? 0 > -300 ) && self.red_score == 0 && self.blue_score == 0 {
            return false
        }
        return true
    }
    
    func toString() -> String {
        return "\(self.name) - \(self.red_score) to \(self.blue_score)"
    }
}

public struct TeamAwardWinner {
    public var division: Division
    public var team: Team
}

public class Award: Identifiable {
    
    public var id: Int
    public var event: Event
    public var order: Int
    public var title: String
    public var qualifications: [String]
    public var team_winners: [TeamAwardWinner]
    public var individual_winners: [String]
    
    init(event: Event? = nil, data: [String: Any] = [:]) {
        self.id = data["id"] as? Int ?? 0
        let event = event ?? Event(fetch: false, data: data["event"] as? [String: Any] ?? [String: Any]())
        self.event = event
        self.order = data["order"] as? Int ?? 0
        self.title = data["title"] as? String ?? ""
        
        if !self.title.contains("(WC)") {
            self.title = self.title.replacingOccurrences(of: "\\([^()]*\\)", with: "", options: [.regularExpression])
        }
        
        self.qualifications = data["qualifications"] as? [String] ?? [String]()
        self.team_winners = (data["teamWinners"] as? [[String: [String: Any]]] ?? [[String: [String: Any]]]()).map{
            TeamAwardWinner(division: Division(data: $0["division"] ?? [String: Any]()), team: event.get_team(id: ($0["team"] ?? [String: Any]())["id"] as? Int ?? 0) ?? Team(id: ($0["team"] ?? [String: Any]())["id"] as? Int ?? 0, number: ($0["team"] ?? [String: Any]())["name"] as? String ?? "", fetch: false))
        }
        self.individual_winners = data["individualWinners"] as? [String] ?? [String]()
    }
}

public class DivisionalAward: Award {
    public var teams: [Team]
    public var division: Division
    
    init(event: Event, division: Division, data: [String: Any] = [:]) {
        self.teams = [Team]()
        self.division = division
        
        super.init(event: event, data: data)
        
        for team_award_winner in super.team_winners {
            if team_award_winner.division.id == division.id {
                self.teams.append(team_award_winner.team)
            }
        }
    }
}

public class TeamRanking: Identifiable {
    public var id: Int
    public var team: Team
    public var event: Event
    public var division: Division
    public var rank: Int
    public var wins: Int
    public var losses: Int
    public var ties: Int
    public var wp: Int
    public var ap: Int
    public var sp: Int
    public var high_score: Int
    public var average_points: Double
    public var total_points: Int
    
    public init(data: [String: Any] = [:]) {
        self.id = data["id"] as? Int ?? 0
        self.team = Team(id: (data["team"] as? [String: Any] ?? [:])["id"] as? Int ?? 0, fetch: false)
        self.event = Event(id: (data["event"] as? [String: Any] ?? [:])["id"] as? Int ?? 0, fetch: false)
        self.division = Division(data: data["division"] as? [String: Any] ?? [:])
        self.rank = data["rank"] as? Int ?? -1
        self.wins = data["wins"] as? Int ?? -1
        self.losses = data["losses"] as? Int ?? -1
        self.ties = data["ties"] as? Int ?? -1
        self.wp = data["wp"] as? Int ?? -1
        self.ap = data["ap"] as? Int ?? -1
        self.sp = data["sp"] as? Int ?? -1
        self.high_score = data["high_score"] as? Int ?? -1
        self.average_points = data["average_points"] as? Double ?? -1.0
        self.total_points = data["total_points"] as? Int ?? -1
    }
}

public class TeamSkillsRanking {
    public var driver_id: Int = 0
    public var programming_id: Int = 0
    public var team: Team
    public var event: Event
    public var rank: Int
    public var combined_score: Int = 0
    public var driver_score: Int = 0
    public var programming_score: Int = 0
    public var driver_attempts: Int = 0
    public var programming_attempts: Int = 0
    
    public init(data: [[String: Any]] = [[:]]) {
        self.team = Team(id: (data[0]["team"] as? [String: Any] ?? [:])["id"] as? Int ?? 0, fetch: false)
        self.event = Event(id: (data[0]["event"] as? [String: Any] ?? [:])["id"] as? Int ?? 0, fetch: false)
        self.rank = data[0]["rank"] as? Int ?? 0
        for skills_type in data {
            if (skills_type["type"] as? String ?? "") == "driver" {
                self.driver_id = skills_type["id"] as? Int ?? 0
                self.driver_score = skills_type["score"] as? Int ?? 0
                self.driver_attempts = skills_type["attempts"] as? Int ?? 0
            }
            else if (skills_type["type"] as? String ?? "") == "programming" {
                self.programming_id = skills_type["id"] as? Int ?? 0
                self.programming_score = skills_type["score"] as? Int ?? 0
                self.programming_attempts = skills_type["attempts"] as? Int ?? 0
            }
        }
        self.combined_score = self.driver_score + self.programming_score
    }
}

public class Event: Identifiable {
    
    public var id: Int
    public var sku: String
    public var name: String
    public var start: Date?
    public var end: Date?
    public var season: Int
    public var venue: String
    public var address: String
    public var city: String
    public var region: String
    public var postcode: Int
    public var country: String
    public var level: String
    public var matches: [Division: [Match]]
    public var teams: [Team]
    public var teams_map = [Int: Team]()
    public var divisions: [Division]
    public var rankings: [Division: [TeamRanking]]
    public var skills_rankings: [TeamSkillsRanking]
    public var awards: [Division: [DivisionalAward]]
    public var livestream_link: String?
    public var type: String
    public var type_id: Int
    
    public init(id: Int = 0, sku: String = "", fetch: Bool = true, data: [String: Any] = [:]) {
        self.id = (data["id"] != nil) ? data["id"] as! Int : id
        self.sku = (data["sku"] != nil) ? data["sku"] as! String : sku
        self.name = (data["name"] != nil) ? data["name"] as! String : ""
        self.start = (data["start"] != nil) ? ADCHubAPI.robotevents_date(date: data["start"] as! String, localize: false) : nil
        self.end = (data["end"] != nil) ? ADCHubAPI.robotevents_date(date: data["end"] as! String, localize: false) : nil
        self.season = (data["season"] != nil) ? (data["season"] as! [String: Any])["id"] as! Int : 0
        self.venue = (data["location"] != nil) ? ((data["location"] as! [String: Any])["venue"] as? String ?? "") : ""
        self.address = (data["location"] != nil) ? ((data["location"] as! [String: Any])["address_1"] as? String ?? "") : ""
        self.city = (data["location"] != nil) ? ((data["location"] as! [String: Any])["city"] as? String ?? "") : ""
        self.region = (data["location"] != nil) ? ((data["location"] as! [String: Any])["region"] as? String ?? "") : ""
        self.postcode = (data["location"] != nil) ? ((data["location"] as! [String: Any])["postcode"] as? Int ?? 0) : 0
        self.country = (data["location"] != nil) ? ((data["location"] as! [String: Any])["country"] as? String ?? "") : ""
        self.level = (data["level"] as? String) ?? "Unknown"
        self.matches = [Division: [Match]]()
        self.teams = [Team]()
        self.teams_map = [Int: Team]()
        self.divisions = [Division]()
        self.rankings = [Division: [TeamRanking]]()
        self.skills_rankings = [TeamSkillsRanking]()
        self.awards = [Division: [DivisionalAward]]()
        self.livestream_link = data["livestream_link"] as? String

        if let eventType = data["event_type"] as? [String: Any] {
            self.type = eventType["text"] as? String ?? ""
            self.type_id = eventType["id"] as? Int ?? -1
        } else {
            self.type = ""
            self.type_id = -1
        }
        
        if data["divisions"] != nil {
            for division in (data["divisions"] as! [[String: Any]]) {
                self.divisions.append(Division(data: division))
            }
        }
        
        if fetch {
            self.fetch_info()
        }
    }
    
    public func fetch_info() {
        if self.id == 0 && self.sku == "" { return }
        
        let data = ADCHubAPI.robotevents_request(request_url: "/events", params: self.id != 0 ? ["id": self.id] : ["sku": self.sku])
        
        if data.isEmpty { return }
        
        self.id = data[0]["id"] as? Int ?? 0
        self.sku = data[0]["sku"] as? String ?? ""
        self.name = data[0]["name"] as? String ?? ""
        self.start = ADCHubAPI.robotevents_date(date: data[0]["start"] as? String ?? "", localize: false)
        self.end = ADCHubAPI.robotevents_date(date: data[0]["end"] as? String ?? "", localize: false)
        self.season = (data[0]["season"] as! [String: Any])["id"] as? Int ?? 0
        self.city = (data[0]["location"] as! [String: Any])["city"] as? String ?? ""
        self.region = (data[0]["location"] as! [String: Any])["region"] as? String ?? ""
        self.country = (data[0]["location"] as! [String: Any])["country"] as? String ?? ""
        
        for division in (data[0]["divisions"] as! [[String: Any]]) {
            self.divisions.append(Division(data: division))
        }
    }
    
    public func fetch_teams() {
        self.teams = [Team]()
        let data = ADCHubAPI.robotevents_request(request_url: String(format: "/events/%d/teams", self.id))
        for team in data {
            let cached_team = Team(id: team["id"] as! Int, fetch: false, data: team)
            self.teams.append(cached_team)
            self.teams_map[cached_team.id] = cached_team
        }
    }
        
    public func get_team(id: Int) -> Team? {
        return self.teams_map[id]
    }
    
    public func fetch_rankings(division: Division) {
        let data = ADCHubAPI.robotevents_request(request_url: "/events/\(self.id)/divisions/\(division.id)/rankings")
        self.rankings[division] = [TeamRanking]()
        for ranking in data {
            var division_rankings = self.rankings[division] ?? [TeamRanking]()
            division_rankings.append(TeamRanking(data: ranking))
            self.rankings[division] = division_rankings
        }
    }
    
    public func fetch_skills_rankings() {
        let data = ADCHubAPI.robotevents_request(request_url: "/events/\(self.id)/skills")
        self.skills_rankings = [TeamSkillsRanking]()
        var index = 0
        while index < data.count {
            var bundle = [data[index]]
            if (((index + 1) < data.count) && (data[index + 1]["team"] as! [String: Any])["id"] as! Int == (data[index]["team"] as! [String: Any])["id"] as! Int) {
                bundle.append(data[index + 1])
                index += 1
            }
            self.skills_rankings.append(TeamSkillsRanking(data: bundle))
            index += 1
        }
        self.skills_rankings = self.skills_rankings.filter({ $0.rank != 0 })
    }
    
    public func fetch_awards(division: Division) {
        let data = ADCHubAPI.robotevents_request(request_url: "/events/\(self.id)/awards")
        if self.teams.isEmpty {
            self.fetch_teams()
        }
        var awards = [DivisionalAward]()
        for award in data {
            awards.append(DivisionalAward(event: self, division: division, data: award))
        }
        self.awards[division] = awards.sorted(by: { $0.order < $1.order })
    }
    
    public func fetch_matches(division: Division) {
        let data = ADCHubAPI.robotevents_request(request_url: "/events/\(self.id)/divisions/\(division.id)/matches")
        var matches = [Match]()
        for match_data in data {
            matches.append(Match(data: match_data))
        }
        matches.sort(by: { $0.instance < $1.instance })
        matches.sort(by: { $0.round.rawValue < $1.round.rawValue })
        self.matches[division] = matches
    }
    
    
    public func fetch_livestream_link() -> String? {
        if let livestream_link = self.livestream_link {
            return livestream_link
        }
        let request_url = "https://www.robotevents.com/robot-competitions/ADC/\(self.sku).html"
        let semaphore = DispatchSemaphore(value: 0)
        let request = NSMutableURLRequest(url: URL(string: request_url)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.dataTask(with: request as URLRequest) { (response_data, response, error) in
            if response_data != nil {
                let html = String(data: response_data!, encoding: .utf8)!
                if html.components(separatedBy: "Webcast").count > 3 {
                    self.livestream_link = request_url + "#webcast"
                }
                semaphore.signal()
            } else if let error = error {
                print("ERROR " + error.localizedDescription)
                semaphore.signal()
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return self.livestream_link
    }
    
    #if os(iOS)
    func add_to_calendar() {
        let eventStore = EKEventStore()
        if #available(iOS 17, *) {
            eventStore.requestWriteOnlyAccessToEvents() { (granted, error) in
                if (granted) && (error == nil) {
                    let event = EKEvent(eventStore: eventStore)
                    event.title = self.name
                    event.startDate = self.start
                    event.endDate = self.end
                    event.isAllDay = true
                    event.location = "\(self.address), \(self.city), \(self.region), \(self.country)"
                    event.calendar = eventStore.defaultCalendarForNewEvents
                    do {
                        try eventStore.save(event, span: .thisEvent)
                        print("Saved Event")
                    } catch let error as NSError {
                        print("Failed to save event with error : \(error)")
                    }
                } else {
                    print("Failed to save event with error : \(String(describing: error)) or access not granted")
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { (granted, error) in
                if (granted) && (error == nil) {
                    let event = EKEvent(eventStore: eventStore)
                    event.title = self.name
                    event.startDate = self.start
                    event.endDate = self.end
                    event.location = "\(self.address), \(self.city), \(self.region), \(self.postcode), \(self.country)"
                    event.calendar = eventStore.defaultCalendarForNewEvents
                    do {
                        try eventStore.save(event, span: .thisEvent)
                        print("Saved Event")
                    } catch let error as NSError {
                        print("Failed to save event with error : \(error)")
                    }
                } else {
                    print("Failed to save event with error : \(String(describing: error)) or access not granted")
                }
            }
        }
    }
    #endif
    
    public func toString() -> String {
        return String(format: "(%@) %@", self.sku, self.name)
    }
}

public class EventSkills {
    public var team: Team
    public var event: Event
    public var driver: Int
    public var programming: Int
    public var combined: Int
    
    public init(team: Team, event: Event, driver: Int = 0, programming: Int = 0) {
        self.team = team
        self.event = event
        self.driver = driver
        self.programming = programming
        self.combined = driver + programming
    }
    
    public func toString() -> String {
        return String(format:"%@ @ %@ - %d", self.team.toString(), self.event.toString(), self.combined)
    }
}

public class WorldSkills {
    public var team: Team
    public var ranking: Int
    public var event: Event
    public var driver: Int
    public var programming: Int
    public var highest_driver: Int
    public var highest_programming: Int
    public var combined: Int
    public var event_region: String
    public var event_region_id: Int
    
    public init(team: Team, ranking: Int, event: Event, driver: Int, programming: Int, highest_driver: Int, highest_programming: Int, combined: Int, event_region: String, event_region_id: Int) {
        self.team = team
        self.ranking = ranking
        self.event = event
        self.driver = driver
        self.programming = programming
        self.highest_driver = highest_driver
        self.highest_programming = highest_programming
        self.combined = combined
        self.event_region = event_region
        self.event_region_id = event_region_id
    }
    
    public init(team: Team, data: [String: Any] = [:]) {
        if data["scores"] == nil {
            self.team = team
            self.ranking = 0
            self.event = Event()
            self.driver = 0
            self.programming = 0
            self.highest_driver = 0
            self.highest_programming = 0
            self.combined = 0
            self.event_region = ""
            self.event_region_id = 0
            return
        }
        self.team = team
        self.ranking = (data["rank"] != nil) ? data["rank"] as! Int : 0
        self.event = (data["event"] != nil) ? Event(sku: (data["event"] as! [String: Any])["sku"] as! String, fetch: false) : Event()
        self.driver = ((data["scores"] as! [String: Any])["driver"] != nil) ? (data["scores"] as! [String: Any])["driver"] as! Int : 0
        self.programming = ((data["scores"] as! [String: Any])["programming"] != nil) ? (data["scores"] as! [String: Any])["programming"] as! Int : 0
        self.highest_driver = ((data["scores"] as! [String: Any])["maxDriver"] != nil) ? (data["scores"] as! [String: Any])["maxDriver"] as! Int : 0
        self.highest_programming = ((data["scores"] as! [String: Any])["maxProgramming"] != nil) ? (data["scores"] as! [String: Any])["maxProgramming"] as! Int : 0
        self.combined = ((data["scores"] as! [String: Any])["score"] != nil) ? (data["scores"] as! [String: Any])["score"] as! Int : 0
        self.event_region = ((data["team"] as! [String: Any])["eventRegion"] != nil) ? (data["team"] as! [String: Any])["eventRegion"] as! String : ""
        self.event_region_id = ((data["team"] as! [String: Any])["eventRegionId"] != nil) ? (data["team"] as! [String: Any])["eventRegionId"] as! Int : 0
    }
    
    public init() {
        self.team = Team()
        self.ranking = 0
        self.event = Event()
        self.driver = 0
        self.programming = 0
        self.highest_driver = 0
        self.highest_programming = 0
        self.combined = 0
        self.event_region = ""
        self.event_region_id = 0
    }
    
    public func toString() -> String {
        return String(format: "%@ #%d - %d", self.team.toString(), self.ranking, self.combined)
    }
}

public class Team: Identifiable {
    public var id: Int
    public var events: [Event]
    public var event_count: Int
    public var awards: [Award]
    public var name: String
    public var number: String
    public var organization: String
    public var robot_name: String
    public var city: String
    public var region: String
    public var country: String
    public var grade: String
    public var registered: Bool
    
    public init(id: Int = 0, number: String = "", fetch: Bool = true, data: [String: Any] = [:]) {
        self.id = (data["id"] != nil) ? data["id"] as? Int ?? id : id
        self.events = (data["events"] != nil) ? data["events"] as? [Event] ?? [] : []
        self.event_count = (data["event_count"] != nil) ? data["event_count"] as? Int ?? 0 : 0
        self.awards = (data["awards"] != nil) ? data["awards"] as? [Award] ?? [] : []
        self.name = (data["team_name"] != nil) ? data["team_name"] as? String ?? "" : ""
        self.number = (data["number"] != nil) ? data["number"] as? String ?? number : number
        self.organization = (data["organization"] != nil) ? data["organization"] as? String ?? "" : ""
        self.robot_name = (data["robot_name"] != nil) ? data["robot_name"] as? String ?? "" : ""
        self.city = (data["location"] != nil) ? ((data["location"] as! [String: Any])["city"] as? String ?? "") : ""
        self.region = (data["location"] != nil) ? ((data["location"] as! [String: Any])["region"] as? String ?? "") : ""
        self.country = (data["location"] != nil) ? ((data["location"] as! [String: Any])["country"] as? String ?? "") : ""
        self.grade = (data["grade"] != nil) ? data["grade"] as? String ?? "" : ""
        self.registered = (data["registered"] != nil) ? data["registered"] as? Bool ?? false : false
        
        if fetch {
            self.fetch_info()
        }
    }
    
    public func fetch_info() {
        if self.id == 0 && self.number == "" { return }
        
        let data = ADCHubAPI.robotevents_request(
            request_url: "/teams",
            params: self.id != 0 ? ["id": self.id, "program": ADCHubAPI.selected_program_id()] : ["number": self.number, "program": [ADCHubAPI.selected_program_id()]]
        )
        
        if data.isEmpty { return }
        
        self.id = data[0]["id"] as? Int ?? 0
        self.name = data[0]["team_name"] as? String ?? ""
        self.number = data[0]["number"] as? String ?? ""
        self.organization = data[0]["organization"] as? String ?? ""
        self.robot_name = data[0]["robot_name"] as? String ?? ""
        self.city = (data[0]["location"] as! [String: Any])["city"] as? String ?? ""
        self.country = (data[0]["location"] as! [String: Any])["country"] as? String ?? ""
        self.region = (data[0]["location"] as! [String: Any])["region"] as? String ?? self.country
        self.grade = data[0]["grade"] as? String ?? ""
        self.registered = data[0]["registered"] as? Bool ?? false
    }
    
    public func matches_at(event: Event) -> [Match] {
        let matches_data = ADCHubAPI.robotevents_request(request_url: "/teams/\(self.id)/matches", params: ["event": event.id])
        var matches = [Match]()
        for match_data in matches_data {
            matches.append(Match(data: match_data))
        }
        matches.sort(by: { $0.instance < $1.instance })
        matches.sort(by: { $0.round.rawValue < $1.round.rawValue })
        return matches
    }
    
    public func matches_for_season(season: Int) -> [Match] {
        let matches_data = ADCHubAPI.robotevents_request(request_url: "/teams/\(self.id)/matches", params: ["season": season])
        var matches = [Match]()
        for match_data in matches_data {
            matches.append(Match(data: match_data))
        }
        matches.sort(by: { $0.instance < $1.instance })
        matches.sort(by: { $0.round.rawValue < $1.round.rawValue })
        return matches
    }
    
    public func fetch_events(season: Int? = nil) {
        let season_id = UserSettings.getSelectedSeasonID()
        
        
        let data = ADCHubAPI.robotevents_request(request_url: "/events", params: ["team": self.id, "season": season ?? season_id])
        for event in data {
            self.events.append(Event(id: event["id"] as! Int, fetch: false, data: event))
        }
        self.event_count = self.events.count
    }
    
    public func fetch_awards(season: Int? = nil) {
        let data = ADCHubAPI.robotevents_request(request_url: "/teams/\(self.id)/awards", params: ["season": season ?? API.selected_season_id()])
        for award in data {
            self.awards.append(Award(data: award))
        }
        self.awards.sort(by: { $0.order < $1.order })
    }
    
    public func skills_at(event: Event) -> EventSkills {
        let data = ADCHubAPI.robotevents_request(request_url: "/events/\(event.id)/skills", params: ["team": self.id])
        var driver = 0
        var programming = 0
        for skills in data {
            if skills["type"] as! String == "driver" {
                driver = skills["score"] as! Int
            }
            else if skills["type"] as! String == "programming" {
                programming = skills["score"] as! Int
            }
        }
        return EventSkills(team: self, event: event, driver: driver, programming: programming)
    }
    
    public func average_ranking(season: Int? = nil) -> Double {
        let data = ADCHubAPI.robotevents_request(request_url: String(format: "/teams/%d/rankings/", self.id), params: ["season": season ?? API.selected_season_id()])
        var total = 0
        for comp in data {
            total += comp["rank"] as! Int
        }
        if data.count == 0 { return 0 }
        self.event_count = data.count
        return Double(total) / Double(data.count)
    }
    
    public func toString() -> String {
        return String(format: "%@ %@", self.name, self.number)
    }
}
