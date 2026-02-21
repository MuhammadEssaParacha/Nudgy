//
//  NudgyTaskExtractor.swift
//  Nudge
//
//  Phase 9: Extract actionable tasks from natural conversation.
//  Uses OpenAI to parse free-form text into structured task data.
//  Falls back to simple pattern matching when AI is unavailable.
//

import Foundation
import os

// MARK: - Extracted Task

/// A task extracted from natural language with rich metadata.
struct ExtractedTask: Codable {
    let content: String
    let emoji: String
    let actionType: String  // CALL, TEXT, EMAIL, or empty
    let contactName: String // or empty
    let actionTarget: String // phone/email/url or empty
    let isActionable: Bool
    let priority: String     // high, medium, low
    let dueDateString: String // ISO 8601 date or relative like "tomorrow", or empty
    
    /// Map to ActionType enum.
    var mappedActionType: ActionType? {
        switch actionType.uppercased() {
        case "CALL": return .call
        case "TEXT": return .text
        case "EMAIL": return .email
        case "ALARM": return .setAlarm
        default: return nil
        }
    }
    
    /// Map to TaskPriority enum.
    var mappedPriority: TaskPriority {
        switch priority.lowercased() {
        case "high": return .high
        case "low": return .low
        default: return .medium
        }
    }
    
    /// Parse the dueDateString into a Date, handling both ISO 8601 and relative expressions.
    var parsedDueDate: Date? {
        let raw = dueDateString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !raw.isEmpty else { return nil }
        
        // Try ISO 8601 first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        if let date = isoFormatter.date(from: dueDateString) {
            // ISO dates are midnight UTC — set to 9am local using the date components
            let utcComps = Calendar.current.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
            var localComps = DateComponents()
            localComps.year = utcComps.year
            localComps.month = utcComps.month
            localComps.day = utcComps.day
            localComps.hour = 9
            localComps.minute = 0
            localComps.second = 0
            return Calendar.current.date(from: localComps)
        }
        
        // Try standard date format "yyyy-MM-dd"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        if let date = df.date(from: dueDateString) {
            let utcComps = Calendar.current.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
            var localComps = DateComponents()
            localComps.year = utcComps.year
            localComps.month = utcComps.month
            localComps.day = utcComps.day
            localComps.hour = 9
            localComps.minute = 0
            localComps.second = 0
            return Calendar.current.date(from: localComps)
        }
        
        // Parse relative expressions
        let cal = Calendar.current
        let now = Date()
        
        if raw.contains("today") || raw.contains("tonight") {
            return cal.date(bySettingHour: raw.contains("tonight") ? 20 : 17, minute: 0, second: 0, of: now)
        }
        if raw.contains("tomorrow") {
            let tom = cal.date(byAdding: .day, value: 1, to: now)!
            // Check for time hints
            if raw.contains("morning") {
                return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tom)
            } else if raw.contains("afternoon") {
                return cal.date(bySettingHour: 14, minute: 0, second: 0, of: tom)
            } else if raw.contains("evening") || raw.contains("night") {
                return cal.date(bySettingHour: 19, minute: 0, second: 0, of: tom)
            }
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tom)
        }
        
        // "this week", "this weekend"
        if raw.contains("this weekend") {
            let weekday = cal.component(.weekday, from: now)
            let daysUntilSat = (7 - weekday) % 7
            let sat = cal.date(byAdding: .day, value: max(daysUntilSat, 1), to: now)!
            return cal.date(bySettingHour: 10, minute: 0, second: 0, of: sat)
        }
        
        // "next week", "next monday", etc.
        if raw.contains("next week") {
            let nextMon = cal.date(byAdding: .day, value: (9 - cal.component(.weekday, from: now)) % 7 + 1, to: now)!
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: nextMon)
        }
        
        // Try parsing a time like "2pm", "at 3", "14:00"
        // Extract hour from dueDateString for today
        let hourPattern = /(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/
        if let match = raw.firstMatch(of: hourPattern) {
            guard var hour = Int(match.1) else { return nil }
            if let ampm = match.3 {
                if ampm == "pm" && hour < 12 { hour += 12 }
                if ampm == "am" && hour == 12 { hour = 0 }
            }
            return cal.date(bySettingHour: hour, minute: Int(match.2 ?? "0") ?? 0, second: 0, of: now)
        }
        
        return nil
    }
    
    /// Backward compatibility: decode gracefully when priority/dueDateString are missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        emoji = try container.decode(String.self, forKey: .emoji)
        actionType = try container.decode(String.self, forKey: .actionType)
        contactName = try container.decode(String.self, forKey: .contactName)
        actionTarget = try container.decode(String.self, forKey: .actionTarget)
        isActionable = try container.decodeIfPresent(Bool.self, forKey: .isActionable) ?? true
        priority = try container.decodeIfPresent(String.self, forKey: .priority) ?? "medium"
        dueDateString = try container.decodeIfPresent(String.self, forKey: .dueDateString) ?? ""
    }
    
    init(content: String, emoji: String, actionType: String, contactName: String, actionTarget: String, isActionable: Bool, priority: String = "medium", dueDateString: String = "") {
        self.content = content
        self.emoji = emoji
        self.actionType = actionType
        self.contactName = contactName
        self.actionTarget = actionTarget
        self.isActionable = isActionable
        self.priority = priority
        self.dueDateString = dueDateString
    }
}

/// Multiple tasks extracted from a brain dump.
struct ExtractedTaskList: Codable {
    let tasks: [ExtractedTask]
}

// MARK: - NudgyTaskExtractor

/// Extracts actionable tasks from natural language using OpenAI.
@MainActor
final class NudgyTaskExtractor {
    
    static let shared = NudgyTaskExtractor()
    private init() {}
    
    // MARK: - Single Task Extraction
    
    /// Extract a task from a single natural language input.
    func extractTask(from input: String) async -> ExtractedTask {
        guard NudgyConfig.isAvailable else {
            return fallbackExtraction(input)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd, EEEE"
        let todayString = dateFormatter.string(from: Date())
        
        do {
            let response = try await NudgyLLMService.shared.generate(
                systemPrompt: """
                You extract actionable tasks from natural language. Today is \(todayString).
                Respond with ONLY valid JSON, no markdown.
                Format: {"content": "short task (max 8 words)", "emoji": "SF Symbol name like phone.fill or envelope.fill", "actionType": "CALL/TEXT/EMAIL or empty", "contactName": "name or empty", "actionTarget": "phone/email/url or empty", "isActionable": true/false, "priority": "high/medium/low", "dueDateString": "YYYY-MM-DD or relative expression or empty"}
                If input is just chat/nonsense, set isActionable to false.
                Infer priority from urgency cues (urgent/ASAP/deadline → high, maybe/someday → low, otherwise medium).
                Extract time references: "tomorrow" → "tomorrow", "by Friday" → the date of this Friday as YYYY-MM-DD.
                """,
                userPrompt: "Extract task from: \"\(input)\"",
                model: NudgyConfig.OpenAI.extractionModel,
                temperature: NudgyConfig.OpenAI.extractionTemperature
            )
            
            // Parse JSON response
            let cleaned = response
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let data = cleaned.data(using: .utf8),
               let task = try? JSONDecoder().decode(ExtractedTask.self, from: data) {
                return task
            }
            
            return fallbackExtraction(input)
        } catch {
            Log.ai.warning("[TaskExtractor] extractTask failed, using fallback: \(error, privacy: .public)")
            return fallbackExtraction(input)
        }
    }
    
    // MARK: - Brain Dump Splitting
    
    /// Split a brain dump transcript into individual tasks.
    func splitBrainDump(transcript: String) async -> [ExtractedTask] {
        let wordCount = transcript.split(separator: " ").count
        
        // Very short input — skip AI
        if wordCount <= 4 {
            return [ExtractedTask(
                content: transcript, emoji: "doc.text.fill", actionType: "",
                contactName: "", actionTarget: "", isActionable: true,
                priority: "medium", dueDateString: ""
            )]
        }
        
        guard NudgyConfig.isAvailable else {
            // Try Apple FM fallback before dumb pattern matching
            return await appleFMSplitFallback(transcript: transcript)
        }
        
        // Get current date context for relative date resolution
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd, EEEE"
        let todayString = dateFormatter.string(from: Date())
        
        do {
            let response = try await NudgyLLMService.shared.generate(
                systemPrompt: """
                You are an expert task extractor for an ADHD-friendly app. The user spoke a messy, unstructured brain dump.
                Your job: parse it into clean, actionable task cards with rich metadata.
                
                Today's date: \(todayString)
                
                Respond with ONLY valid JSON (no markdown, no backticks). Format:
                {"tasks": [{"content": "...", "emoji": "...", "actionType": "...", "contactName": "...", "actionTarget": "", "isActionable": true, "priority": "...", "dueDateString": "..."}]}
                
                FIELD RULES:
                • content: Short, clear, actionable task (max 8 words). Start with a verb. Strip filler.
                • emoji: An Apple SF Symbol name that represents this task. Use context: phone.fill for calls, envelope.fill for email, cross.case.fill for medical, dollarsign.circle.fill for money, cart.fill for shopping, pawprint.fill for pets, book.fill for reading, checklist for generic tasks, etc.
                • actionType: "CALL" / "TEXT" / "EMAIL" or "" — detect from verbs like call, ring, text, message, email, send.
                • contactName: Person or business name if mentioned, "" otherwise.
                • actionTarget: Only if an explicit phone/email/URL was spoken. Usually "".
                • priority: Infer from urgency cues:
                  - "high": urgent, overdue, deadline, ASAP, critical, "really need to", "have to before", "can't forget"
                  - "medium": normal tasks, no urgency signals
                  - "low": "maybe", "when I get a chance", "at some point", "not urgent"
                • dueDateString: Extract time references as YYYY-MM-DD when possible. Use relative words verbatim otherwise:
                  - "call dentist tomorrow" → "tomorrow"
                  - "pay rent by the 5th" → YYYY-MM-05 (current or next month)
                  - "this weekend" → "this weekend"
                  - "before Friday" → YYYY-MM-DD of this Friday
                  - No time mentioned → ""
                
                EXTRACTION RULES:
                1. Ignore filler: um, uh, like, you know, I mean, so yeah, anyway
                2. Skip non-actionable venting: "I'm so tired", "this sucks" → not tasks
                3. Split compound tasks: "call mom and pick up groceries" → TWO separate tasks
                4. Preserve specificity: "buy milk" not "go shopping"
                5. Cap at 10 tasks. Merge duplicates.
                6. Order by priority (high first, low last)
                
                EXAMPLE INPUT: "ok so I really need to call the dentist tomorrow, um and I should probably pay rent before the 5th, oh and I need to text Sarah about dinner tonight, and maybe at some point I should look into getting my car washed"
                
                EXAMPLE OUTPUT:
                {"tasks": [
                  {"content": "Pay rent before the 5th", "emoji": "dollarsign.circle.fill", "actionType": "", "contactName": "", "actionTarget": "", "isActionable": true, "priority": "high", "dueDateString": "\(Self.nextDateForDay(5))"},
                  {"content": "Call the dentist", "emoji": "phone.fill", "actionType": "CALL", "contactName": "dentist", "actionTarget": "", "isActionable": true, "priority": "medium", "dueDateString": "tomorrow"},
                  {"content": "Text Sarah about dinner", "emoji": "message.fill", "actionType": "TEXT", "contactName": "Sarah", "actionTarget": "", "isActionable": true, "priority": "medium", "dueDateString": "today"},
                  {"content": "Get car washed", "emoji": "car.fill", "actionType": "", "contactName": "", "actionTarget": "", "isActionable": true, "priority": "low", "dueDateString": ""}
                ]}
                """,
                userPrompt: "Extract tasks from this brain dump:\n\"\(transcript)\"",
                model: NudgyConfig.OpenAI.extractionModel,
                temperature: NudgyConfig.OpenAI.extractionTemperature
            )
            
            let cleaned = response
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let data = cleaned.data(using: .utf8),
               let taskList = try? JSONDecoder().decode(ExtractedTaskList.self, from: data) {
                Log.ai.debug("[TaskExtractor] Extracted \(taskList.tasks.count) tasks from brain dump")
                for (i, task) in taskList.tasks.enumerated() {
                    Log.ai.debug("  [\(i+1)] \(task.priority.uppercased()) | \(task.emoji) \(task.content) | due: \(task.dueDateString.isEmpty ? "—" : task.dueDateString) | action: \(task.actionType.isEmpty ? "—" : task.actionType) \(task.contactName)")
                }
                return taskList.tasks.isEmpty ? [fallbackExtraction(transcript)] : taskList.tasks
            }
            
            Log.ai.warning("[TaskExtractor] Failed to decode JSON, raw response: \(cleaned)")
            return [fallbackExtraction(transcript)]
        } catch {
            // OpenAI failed — try Apple FM before giving up
            Log.ai.error("[TaskExtractor] OpenAI failed: \(error, privacy: .public). Trying Apple FM fallback...")
            return await appleFMSplitFallback(transcript: transcript)
        }
    }
    
    // MARK: - Apple FM Fallback
    
    /// Try Apple Foundation Models when OpenAI is unavailable.
    private func appleFMSplitFallback(transcript: String) async -> [ExtractedTask] {
        #if canImport(FoundationModels)
        guard AIService.shared.isAvailable else {
            return [fallbackExtraction(transcript)]
        }
        do {
            let splitTasks = try await AIService.shared.splitBrainDump(transcript: transcript)
            return splitTasks.map { task in
                ExtractedTask(
                    content: task.task,
                    emoji: task.emoji,
                    actionType: task.action,
                    contactName: task.contact,
                    actionTarget: task.actionTarget,
                    isActionable: true,
                    priority: "medium",
                    dueDateString: ""
                )
            }
        } catch {
            Log.ai.warning("[TaskExtractor] splitBrainDump failed, using fallback: \(error, privacy: .public)")
            return [fallbackExtraction(transcript)]
        }
        #else
        return [fallbackExtraction(transcript)]
        #endif
    }
    
    // MARK: - Date Helper
    
    /// Get the next occurrence of a given day-of-month as YYYY-MM-DD.
    static func nextDateForDay(_ day: Int) -> String {
        let cal = Calendar.current
        let now = Date()
        let currentDay = cal.component(.day, from: now)
        var comps = cal.dateComponents([.year, .month], from: now)
        comps.day = day
        
        if currentDay >= day {
            // The day has passed this month, use next month
            let nextMonth = (comps.month ?? 1) + 1
            comps.month = nextMonth
            if nextMonth > 12 {
                comps.month = 1
                comps.year = (comps.year ?? 2026) + 1
            }
        }
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        if let date = cal.date(from: comps) {
            return df.string(from: date)
        }
        return ""
    }
    
    // MARK: - Draft Generation
    
    /// Generate a message draft for a task.
    func generateDraft(
        taskContent: String,
        actionType: String,
        contactName: String?,
        senderName: String?,
        categoryLabel: String? = nil
    ) async -> (draft: String, subject: String)? {
        guard NudgyConfig.isAvailable else { return nil }
        
        do {
            let senderLine = senderName.flatMap { $0.isEmpty ? nil : $0 }
                .map { "\nSender name: \"\($0)\"" } ?? ""
            let categoryLine = categoryLabel.flatMap { $0.isEmpty ? nil : $0 }
                .map { "\nCategory: \($0) (adapt tone to match this life area)" } ?? ""
            
            let response = try await NudgyLLMService.shared.generate(
                systemPrompt: """
                Write a short, ready-to-send message. Respond with ONLY valid JSON.
                Format: {"draft": "message body", "subject": "email subject or empty"}
                Texts: 1-3 sentences. Emails: 3-5 sentences. Natural and human, not robotic.
                """,
                userPrompt: """
                Write a \(actionType.lowercased()) for:
                Task: "\(taskContent)"
                Recipient: "\(contactName ?? "the person mentioned")"\(senderLine)\(categoryLine)
                """,
                model: NudgyConfig.OpenAI.extractionModel,
                temperature: 0.7
            )
            
            let cleaned = response
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let draft = json["draft"] as? String ?? ""
                let subject = json["subject"] as? String ?? ""
                return (draft, subject)
            }
            
            return nil
        } catch {
            Log.ai.warning("[TaskExtractor] draftMessage failed: \(error, privacy: .public)")
            return nil
        }
    }

    // MARK: - Fallback
    
    private func fallbackExtraction(_ input: String) -> ExtractedTask {
        let trimmed = String(input.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Simple pattern matching for action types
        let lower = trimmed.lowercased()
        let actionType: String
        if lower.contains("call ") { actionType = "CALL" }
        else if lower.contains("text ") || lower.contains("message ") { actionType = "TEXT" }
        else if lower.contains("email ") { actionType = "EMAIL" }
        else { actionType = "" }
        
        // Extract contact name from "call/text/email/message <Name>" patterns
        let contactName = fallbackExtractContactName(from: lower, original: trimmed)
        
        // Simple urgency detection
        let priority: String
        if lower.contains("urgent") || lower.contains("asap") || lower.contains("important") || lower.contains("deadline") {
            priority = "high"
        } else if lower.contains("maybe") || lower.contains("someday") || lower.contains("whenever") {
            priority = "low"
        } else {
            priority = "medium"
        }
        
        // Simple due date detection
        let dueDateString = fallbackExtractDueDate(from: lower)
        
        return ExtractedTask(
            content: trimmed,
            emoji: "doc.text.fill",
            actionType: actionType,
            contactName: contactName,
            actionTarget: "",
            isActionable: true,
            priority: priority,
            dueDateString: dueDateString
        )
    }
    
    /// Regex-extract a contact name from patterns like "call mom", "text Dr. Smith about dinner",
    /// "email sarah the report". Returns empty string if no match.
    private func fallbackExtractContactName(from lower: String, original: String) -> String {
        // Match: (call|text|message|email) <name> [about|regarding|the|to|re|that|when|by|...]
        // Name = 1-3 capitalized words, or common relationship words
        let patterns = [
            // "call mom", "text dr. smith about dinner"
            #"(?:call|text|message|email)\s+([a-z]+(?:\.\s*)?(?:\s+[a-z]+){0,2})(?:\s+(?:about|regarding|the|to|re|that|when|by|for|and|tomorrow|today|asap|urgent)\b|$)"#,
        ]
        
        // Common relationship words that are valid contact names
        let relationshipWords: Set<String> = [
            "mom", "mum", "dad", "mother", "father", "sis", "bro", "brother", "sister",
            "grandma", "grandpa", "nana", "papa", "aunt", "uncle", "cousin",
            "wife", "husband", "partner", "babe", "honey",
            "boss", "manager", "landlord", "doctor", "dentist", "therapist"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(lower.startIndex..., in: lower)
            if let match = regex.firstMatch(in: lower, options: [], range: range),
               match.numberOfRanges > 1,
               let nameRange = Range(match.range(at: 1), in: lower) {
                let rawName = String(lower[nameRange]).trimmingCharacters(in: .whitespaces)
                
                // Validate: must be a known relationship word OR have at least 2 chars
                let words = rawName.split(separator: " ").map(String.init)
                guard let firstName = words.first, firstName.count >= 2 else { continue }
                
                // Skip obvious non-names (prepositions, articles, etc.)
                let stopWords: Set<String> = ["the", "a", "an", "my", "our", "his", "her", "their", "some", "this", "that", "it"]
                if stopWords.contains(firstName) { continue }
                
                // If it's a known relationship word, return as-is
                if relationshipWords.contains(firstName) {
                    return rawName
                }
                
                // Capitalize from original text if possible, else capitalize words
                let capitalizedName = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
                return capitalizedName
            }
        }
        
        return ""
    }
    
    /// Extract simple due date hints from text. Returns relative string or empty.
    private func fallbackExtractDueDate(from lower: String) -> String {
        if lower.contains("today") || lower.contains("tonight") { return "today" }
        if lower.contains("tomorrow") { return "tomorrow" }
        if lower.contains("next week") { return "next week" }
        if lower.contains("this week") { return "this week" }
        if lower.contains("monday") { return "monday" }
        if lower.contains("tuesday") { return "tuesday" }
        if lower.contains("wednesday") { return "wednesday" }
        if lower.contains("thursday") { return "thursday" }
        if lower.contains("friday") { return "friday" }
        if lower.contains("saturday") { return "saturday" }
        if lower.contains("sunday") { return "sunday" }
        return ""
    }
}
