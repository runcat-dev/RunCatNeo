@discardableResult
func waitUntil(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0 ..< 200 {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return false
}
