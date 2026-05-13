import Foundation

enum UserDefaultsStore {
    private static let defaults = UserDefaults.standard

    static var hookServerPort: UInt16 {
        get { UInt16(defaults.integer(forKey: "hookServerPort")).nonZero ?? 31415 }
        set { defaults.set(Int(newValue), forKey: "hookServerPort") }
    }

    static var isFirstLaunch: Bool {
        get { !defaults.bool(forKey: "hasLaunchedBefore") }
        set { defaults.set(!newValue, forKey: "hasLaunchedBefore") }
    }

    static var autoConfigureHooks: Bool {
        get { defaults.bool(forKey: "autoConfigureHooks") }
        set { defaults.set(newValue, forKey: "autoConfigureHooks") }
    }
}

private extension UInt16 {
    var nonZero: UInt16? {
        self == 0 ? nil : self
    }
}
