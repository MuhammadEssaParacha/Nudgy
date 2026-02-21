//
//  LocationService.swift
//  Nudge
//
//  CoreLocation integration for location-aware task surfacing.
//  Monitors geofences for tasks with location data and surfaces
//  "📍 nearby" badges on relevant task cards.
//
//  Privacy: Location access is opt-in (Settings toggle).
//  Uses When In Use permission — no background location tracking.
//

import CoreLocation
import SwiftUI
import SwiftData
import os

@MainActor @Observable
final class LocationService: NSObject {
    
    static let shared = LocationService()
    
    // MARK: - State
    
    /// Whether the user has granted location permission
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    /// Current user location (updated on significant change, not continuous)
    private(set) var currentLocation: CLLocation?
    
    /// Whether location features are enabled by the user (Settings toggle)
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "locationServiceEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "locationServiceEnabled")
            if newValue {
                requestPermissionIfNeeded()
            } else {
                stopMonitoring()
            }
        }
    }
    
    /// Whether we have sufficient permission to use location
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    /// Currently monitored geofence region identifiers (task IDs)
    private(set) var monitoredTaskIDs: Set<String> = []
    
    // MARK: - Private
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let log = Logger(subsystem: "com.tarsitgroup.nudge", category: "Location")
    
    /// Maximum geofences iOS allows per app (system limit is 20)
    private let maxGeofences = 20
    
    // MARK: - Init
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public API
    
    /// Request location permission (When In Use only — ADHD apps shouldn't track always).
    func requestPermissionIfNeeded() {
        guard authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Request a single location update (used for "near me" task surfacing).
    func requestCurrentLocation() {
        guard isAuthorized else {
            log.warning("requestCurrentLocation called without authorization")
            return
        }
        locationManager.requestLocation()
    }
    
    /// Start monitoring geofences for tasks that have location data.
    /// - Parameter tasks: Active tasks with latitude/longitude set.
    func monitorGeofences(for tasks: [NudgeItem]) {
        guard isAuthorized, isEnabled else { return }
        
        // Remove all existing regions first
        stopMonitoring()
        
        // Filter tasks with valid location data
        let locationTasks = tasks.filter { item in
            item.latitude != nil && item.longitude != nil
        }
        
        // Take the closest tasks up to the geofence limit
        let sorted: [NudgeItem]
        if let current = currentLocation {
            sorted = locationTasks.sorted { a, b in
                let locA = CLLocation(latitude: a.latitude!, longitude: a.longitude!)
                let locB = CLLocation(latitude: b.latitude!, longitude: b.longitude!)
                return locA.distance(from: current) < locB.distance(from: current)
            }
        } else {
            sorted = Array(locationTasks.prefix(maxGeofences))
        }
        
        for item in sorted.prefix(maxGeofences) {
            guard let lat = item.latitude, let lon = item.longitude else { continue }
            
            let radius = item.geofenceRadius ?? 200 // Default 200m
            let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let region = CLCircularRegion(
                center: center,
                radius: min(radius, locationManager.maximumRegionMonitoringDistance),
                identifier: item.id.uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            
            locationManager.startMonitoring(for: region)
            monitoredTaskIDs.insert(item.id.uuidString)
            log.debug("Monitoring geofence: \(item.content) at (\(lat), \(lon)) r=\(radius)m")
        }
    }
    
    /// Stop all geofence monitoring.
    func stopMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredTaskIDs.removeAll()
    }
    
    /// Check if a task is "nearby" (within 500m of current location).
    func isNearby(_ item: NudgeItem, threshold: CLLocationDistance = 500) -> Bool {
        guard let current = currentLocation,
              let lat = item.latitude,
              let lon = item.longitude else {
            return false
        }
        let taskLocation = CLLocation(latitude: lat, longitude: lon)
        return current.distance(from: taskLocation) <= threshold
    }
    
    /// Distance from current location to a task's location.
    func distance(to item: NudgeItem) -> CLLocationDistance? {
        guard let current = currentLocation,
              let lat = item.latitude,
              let lon = item.longitude else {
            return nil
        }
        return current.distance(from: CLLocation(latitude: lat, longitude: lon))
    }
    
    /// Formatted distance string (e.g. "0.3 mi" or "nearby").
    func formattedDistance(to item: NudgeItem) -> String? {
        guard let dist = distance(to: item) else { return nil }
        if dist < 100 { return String(localized: "nearby") }
        
        // Use miles for US locale, km otherwise
        let useMiles = Locale.current.measurementSystem == .us
        if useMiles {
            let miles = dist / 1609.34
            if miles < 0.1 { return String(localized: "nearby") }
            return String(format: "%.1f mi", miles)
        } else {
            let km = dist / 1000
            if km < 0.1 { return String(localized: "nearby") }
            return String(format: "%.1f km", km)
        }
    }
    
    // MARK: - Reverse Geocoding
    
    /// Reverse-geocode coordinates to a place name.
    func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            // Build a useful short name: "Store Name" or "Street, City"
            if let name = placemark.name, !name.isEmpty,
               name != placemark.thoroughfare {
                return name
            }
            var parts: [String] = []
            if let street = placemark.thoroughfare { parts.append(street) }
            if let city = placemark.locality { parts.append(city) }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        } catch {
            log.error("Reverse geocode failed: \(error)")
            return nil
        }
    }
    
    /// Forward geocode an address string to coordinates.
    func geocode(address: String) async -> CLLocationCoordinate2D? {
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            return placemarks.first?.location?.coordinate
        } catch {
            log.error("Forward geocode failed for '\(address)': \(error)")
            return nil
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            self.log.info("Location authorization changed: \(String(describing: status))")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.log.debug("Location updated: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.log.error("Location error: \(error)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        Task { @MainActor in
            self.log.info("Entered geofence: \(circularRegion.identifier)")
            // Post notification so views can show "📍 nearby" badge
            NotificationCenter.default.post(
                name: .nudgeGeofenceEntered,
                object: nil,
                userInfo: ["taskID": circularRegion.identifier]
            )
            // Schedule a local notification
            let content = UNMutableNotificationContent()
            content.title = String(localized: "📍 Nearby task")
            content.body = String(localized: "You're near a task location. Tap to view.")
            content.sound = .default
            content.userInfo = ["action": "view", "itemID": circularRegion.identifier]
            content.interruptionLevel = .active
            
            let request = UNNotificationRequest(
                identifier: "geofence_\(circularRegion.identifier)",
                content: content,
                trigger: nil // Immediate
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let nudgeGeofenceEntered = Notification.Name("nudgeGeofenceEntered")
}
