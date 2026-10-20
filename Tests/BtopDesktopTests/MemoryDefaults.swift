import Foundation

final class MemoryDefaults: UserDefaults, @unchecked Sendable {
  private var values: [String: Any] = [:]
  override func register(defaults: [String: Any]) { values.merge(defaults) { old, _ in old } }
  override func set(_ value: Any?, forKey key: String) { values[key] = value }
  override func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
  override func double(forKey key: String) -> Double { (values[key] as? NSNumber)?.doubleValue ?? 0 }
  override func integer(forKey key: String) -> Int { (values[key] as? NSNumber)?.intValue ?? 0 }
  override func string(forKey key: String) -> String? { values[key] as? String }
}
