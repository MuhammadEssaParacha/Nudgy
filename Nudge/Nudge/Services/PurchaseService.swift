//
//  PurchaseService.swift
//  Nudge
//
//  StoreKit 2 subscription management — Pro monthly + yearly.
//  No server-side receipt validation (uses StoreKit 2 JWS verification).
//

import StoreKit
import SwiftUI
import os

/// Manages Pro subscription state via StoreKit 2.
@MainActor @Observable
final class PurchaseService {
    
    static let shared = PurchaseService()
    
    // MARK: - State
    
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    
    /// Whether the user has an active Pro subscription
    var isPro: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    /// Monthly product
    var monthlyProduct: Product? {
        products.first { $0.id == StoreKitProducts.proMonthly }
    }
    
    /// Yearly product
    var yearlyProduct: Product? {
        products.first { $0.id == StoreKitProducts.proYearly }
    }
    
    /// Yearly savings description
    var yearlySavingsText: String {
        guard let monthly = monthlyProduct, let yearly = yearlyProduct else {
            return String(localized: "Save 50%")
        }
        let monthlyAnnual = monthly.price * Decimal(12)
        let savings = monthlyAnnual - yearly.price
        let pct = Int(truncating: (savings / monthlyAnnual * Decimal(100)) as NSDecimalNumber)
        return String(localized: "Save \(pct)%")
    }
    
    // MARK: - Transaction Listener
    
    private var transactionListener: Task<Void, Never>?
    
    // MARK: - Init
    
    init() {
        // Delay transaction listener setup to avoid nonisolated init issues
    }
    
    /// Call once after init to start listening for transactions
    func startListening() {
        guard transactionListener == nil else { return }
        transactionListener = listenForTransactions()
    }
    

    
    // MARK: - Load Products
    
    /// Fetch available products from App Store.
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            products = try await Product.products(for: StoreKitProducts.allProducts)
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = error.localizedDescription
            Log.purchase.error("Failed to load products: \(error, privacy: .public)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    
    /// Purchase a product. Returns true if successful.
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Update purchased status
            purchasedProductIDs.insert(transaction.productID)
            
            // Finish the transaction
            await transaction.finish()
            
            HapticService.shared.shareSaved() // Success haptic
            return true
            
        case .pending:
            // Transaction pending (e.g., Ask to Buy)
            return false
            
        case .userCancelled:
            return false
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore purchases — checks all current entitlements.
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        var activeIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                activeIDs.insert(transaction.productID)
            }
        }
        
        purchasedProductIDs = activeIDs
        isLoading = false
    }
    
    // MARK: - Check Entitlements
    
    /// Check current subscription status. Call on app launch.
    func checkEntitlements() async {
        var activeIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                activeIDs.insert(transaction.productID)
            }
        }
        
        purchasedProductIDs = activeIDs
    }
    
    // MARK: - Transaction Listener
    
    /// Listen for transaction updates (renewals, revocations, etc.)
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await self?.checkEntitlements()
                    await transaction.finish()
                }
            }
        }
    }
    
    // MARK: - Verification
    
    /// Verify transaction using StoreKit 2 JWS verification.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Sync with AppSettings

extension PurchaseService {
    
    /// Sync Pro status to AppSettings (call after entitlement changes).
    func syncToSettings(_ settings: AppSettings) {
        settings.isPro = isPro
    }
}
