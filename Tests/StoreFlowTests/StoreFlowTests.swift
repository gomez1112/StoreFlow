
import Testing
import SwiftData
@_spi(Testing) @testable import StoreFlow

@MainActor
struct StoreFlowTests {
    // MARK: – Sample Product-ID enum -------------------------------------
    enum DummyID: String, StoreProductID, AccessLevelMappable {
        case consumable100
        case pro
        case lifetime
        
        var accessLevel: AccessLevel {
            switch self {
                case .consumable100: .free
                case .pro:           .pro
                case .lifetime:      .lifetime
            }
        }
    }
    // MARK: – Helpers -----------------------------------------------------
    // 1️⃣ Hold the container for the whole test run
    static let container: ModelContainer = {
        try! ModelContainer(
            for: EntitlementRecord.self,
            ConsumableRecord.self,
            RenewalRecord.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
    }()
    
    // 2️⃣ Return a Store that uses that container’s context
    @MainActor
    static func makeStore() -> Store<DummyID> {
        Store<DummyID>(context: container.mainContext)
    }
    @MainActor
    @Test("Granting and revoking entitlements updates access level")
    func GrantAndRevoke() async throws {
        let store = Self.makeStore()
        
        // Initially only free
        #expect(store.accessLevel == .free)
    
        // Pretend we granted “pro”
        store.grant(.pro)
        
        #expect(store.owns(.pro))
        #expect(store.accessLevel == .pro)
        
        // Revoke and confirm we’re back to free
        store.revoke(.pro)
        #expect(store.owns(.pro) == false)
        #expect(store.accessLevel == .free)
    }
    @Test("Adding and consuming consumables decreases balance")
    func consumingConsumables() async throws {
        let store = Self.makeStore()
        
        // Pretend the user bought 100 credits
        try store.addUnits(.consumable100, qty: 100)
        #expect(store.balance(of: .consumable100) == 100)
        
        // Consume 25
        try store.consume(.consumable100, qty: 25)
        #expect(store.balance(of: .consumable100) == 75)
        
        // Over-consume should throw
        #expect(throws: StoreError.insufficientBalance) {
            try store.consume(.consumable100, qty: 200)
        }

    }
}
