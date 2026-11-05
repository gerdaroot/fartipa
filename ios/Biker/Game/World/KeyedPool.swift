import SceneKit

/// Something drawn for one road object, reused for another when it is gone.
@MainActor
protocol PooledItem: AnyObject {
    var root: SCNNode { get }
    /// Back to a fresh state before it is reused.
    func recycle()
}

/// Keeps exactly one item per object id while the object exists, so a stream or a car keeps its
/// own node (and its splash or smoke) for its whole life instead of hopping between pool slots.
@MainActor
final class KeyedPool<Item: PooledItem> {
    private let parent: SCNNode
    private let make: @MainActor () -> Item
    private var active: [Int: Item] = [:]
    private var spare: [Item] = []
    private var seen = Set<Int>()
    private var stale: [Int] = []

    init(parent: SCNNode, prewarm: Int, make: @escaping @MainActor () -> Item) {
        self.parent = parent
        self.make = make
        for _ in 0..<prewarm { spare.append(fresh()) }
    }

    private func fresh() -> Item {
        let item = make()
        item.root.isHidden = true
        parent.addChildNode(item.root)
        return item
    }

    func begin() {
        seen.removeAll(keepingCapacity: true)
    }

    /// The item for `id`, and whether it was just taken from the spares.
    func item(for id: Int) -> (item: Item, isNew: Bool) {
        seen.insert(id)
        if let existing = active[id] { return (existing, false) }
        let item = spare.popLast() ?? fresh()
        item.recycle()
        item.root.isHidden = false
        active[id] = item
        return (item, true)
    }

    /// Hides and frees every item whose object was not asked for since `begin`.
    func end() {
        stale.removeAll(keepingCapacity: true)
        for id in active.keys where !seen.contains(id) { stale.append(id) }
        for id in stale { release(id) }
    }

    func releaseAll() {
        stale.removeAll(keepingCapacity: true)
        stale.append(contentsOf: active.keys)
        for id in stale { release(id) }
    }

    func forEachActive(_ body: (Item) -> Void) {
        for item in active.values { body(item) }
    }

    private func release(_ id: Int) {
        guard let item = active.removeValue(forKey: id) else { return }
        item.root.isHidden = true
        spare.append(item)
    }
}

/// A pooled node with an optional spinning or bobbing child.
@MainActor
final class SimpleItem: PooledItem {
    let root: SCNNode
    let spinner: SCNNode?

    init(root: SCNNode, spinner: SCNNode? = nil) {
        self.root = root
        self.spinner = spinner
    }

    func recycle() {}
}
