import Foundation
import Domain

// MARK: - Catalog
//
// 工具目录解析、搜索、分类。阶段 2 由子代理 A 实现。
// 数据契约（Tool / CatalogSnapshot）见 Domain 模块。

public protocol CatalogLoading: Sendable {
    func loadCatalog() async throws -> CatalogSnapshot
}

public enum CatalogError: Error, Sendable, Equatable {
    case network(String)
    case decoding(String)
    case schemaMismatch(expected: String, got: String)
    case signatureInvalid
    case expired
    case revoked(toolID: String)
}
