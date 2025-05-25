# StoreFlow

[![Swift 6.0+](https://img.shields.io/badge/swift-6.0+-orange.svg)](https://swift.org/download/)
[![Platforms: iOS 18 / macOS 15 / visionOS 2](https://img.shields.io/badge/platforms-iOS%2018%20|%20macOS%2015%20|%20visionOS%202-blue)]()

A drop-in, generic StoreKit 2 package with SwiftData-powered consumable tracking—designed for beautiful SwiftUI paywalls, robust product logic, and fully reusable (no singletons!) in any modern Swift app.

- Supports subscriptions, non-consumables, and consumables
- Tracks consumable credits using [SwiftData](https://developer.apple.com/xcode/swiftdata/)
- No singleton, no static shared—fully instance-based and testable
- Easy to customize and extend for your own business logic
- Includes a beautiful animated paywall view with a mesh gradient
- Full error handling via `StoreError`, surfaced to your UI

---

## ✨ Features

- Generic, app-agnostic StoreKit 2 manager
- Consumable credit management via SwiftData
- Beautiful SwiftUI paywall UI (ready to drop in)
- Access level mapping for feature gating (`not subscribed`, `individual`, `family`, `premium`)
- Full error handling (`StoreError` enum)
- Easy integration—just plug in your product IDs and go!

---

## 📦 Installation

**Swift Package Manager:**

```
https://github.com/gomez1112/StoreFlow.git
```

Or copy `StoreFlow.swift` into your project.

---

## 🛠️ Usage

### 1. Set Up Your Configuration

```swift
import StoreFlow

let config = DefaultStoreConfiguration(
    groupID: "com.myapp.subscriptions",
    productIDs: [
        "com.myapp.tip.small", "com.myapp.lifetime", "com.myapp.yearly.individual"
    ],
    productAccess: [
        "com.myapp.lifetime": .premium,
        "com.myapp.yearly.individual": .premium,
        "com.myapp.tip.small": .individual
    ],
    consumableIDs: ["com.myapp.tip.small"]
)
```

### 2. Create a SwiftData ModelContainer

```swift
let modelContainer = try! ModelContainer(for: ConsumableCredit.self)
let modelContext = modelContainer.mainContext
```

### 3. Instantiate Your Store Manager

```swift
@StateObject var store = StoreFlow(configuration: config, modelContext: modelContext)
```

---

## 🍬 Consumable Credits

```swift
// Use a consumable
try? store.useConsumable(id: "com.myapp.tip.small", amount: 1)

// Get available credits
let credits = store.consumableQuantity(for: "com.myapp.tip.small")
```

---

## ⚠️ Error Handling

All StoreKit and SwiftData errors are reported via the `StoreError` enum:

- `var error: StoreError?` on your `StoreFlow` instance.
- Methods like `purchase(_:)`, `useConsumable(id:amount:)` can `throw` StoreError.
- Surface errors in your SwiftUI UI with `.alert(item: $store.error)`.

### Example

```swift
@StateObject var store = StoreFlow(...)
@State private var selectedProduct: Product?

Button("Buy") {
    Task {
        do {
            try await store.purchase(selectedProduct)
        } catch {
            // Error is also set on store.error for your alert!
        }
    }
}

.alert(item: $store.error) { err in
    Alert(title: Text("Error"), message: Text(err.localizedDescription))
}
```

StoreError covers:

- StoreKit verification, sync, fetch errors
- SwiftData save/fetch errors
- Insufficient consumable credits
- User-friendly, localized messages for every case

---

## 🎨 Screenshots

<!-- Add screenshots to your repo and link here, for example: -->
<!-- ![Paywall example](./screenshots/paywall.png) -->

---

## 🙌 Credits

Created by [Your Name](https://transfinite.us)  
Inspired by the best of Apple's design and developer community.

---

## 📄 License

MIT

---

## Questions or Feature Requests?

File an issue or open a PR!
