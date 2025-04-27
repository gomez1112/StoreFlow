# StoreFlow 📦

A **pure-Swift** StoreKit 2 + SwiftData engine that gives you:

| Feature | Description |
|---------|-------------|
| 🚀 **Drop-in Store** | A `@MainActor` `Store<ID>` type that handles product lookup, transaction updates, entitlements, consumables, and subscription-renewal status. |
| 🗄 **SwiftData persistence** | Entitlements, consumable balances, and renewal info are stored locally with zero boilerplate. |
| 🧪 **Swift Testing-powered test-suite** | Modern `#expect`-style tests, ready for continuous integration. |
| 🎨 **Tiny SwiftUI demo** | Shows balance updates and access-level gating in <50 lines. |

> **Minimum SDKs:** iOS 17.4 · macOS 14.4 · visionOS 1.2  
> **Tool-chain:** Xcode 17.4 · Swift 6

---

## Installation

<details>
<summary>Swift Package Manager</summary>

```swift
dependencies: [
    .package(url: "https://github.com/<you>/StoreFlow.git", from: "1.0.0")
]
