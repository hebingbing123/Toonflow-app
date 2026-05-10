# 搜索结果缓存实现

## 概述

本模块实现了搜索结果的内存缓存功能，使用 Moka 库提供 5 分钟 TTL 的缓存机制，以提升搜索性能并减少数据库负载。

## 技术选型

- **缓存库**: Moka (Rust 高性能内存缓存库)
- **TTL**: 5 分钟（300 秒）
- **最大容量**: 1000 条记录
- **缓存策略**: LRU (Least Recently Used)

### 为什么选择 Moka 而不是 Redis？

1. **简单性**: Moka 是纯 Rust 库，无需额外的 Redis 服务器部署和维护
2. **性能**: 内存访问比网络访问（Redis）更快
3. **开发效率**: 无需配置 Redis 连接、序列化/反序列化等
4. **适用场景**: 对于搜索结果缓存，5 分钟 TTL 足够，不需要跨实例共享缓存

**注意**: 如果未来需要跨多个后端实例共享缓存，可以考虑迁移到 Redis。

## 缓存键设计

缓存键格式：`search:{workspace_id}:{query_hash}`

其中 `query_hash` 是基于以下参数计算的 MD5 哈希：
- 搜索关键词（标准化：去除前后空格，转小写）
- 结果类型过滤（result_type）
- 分页参数（page, page_size）
- 时间范围过滤（time_from, time_to）
- workspace_id

### 缓存键标准化

为了提高缓存命中率，缓存键生成时会进行以下标准化：
- 去除搜索关键词前后空格
- 将搜索关键词转为小写（"Test" 和 "test" 生成相同缓存键）

## 使用方式

### 在 SearchService 中使用

```rust
use crate::search::{SearchService, SearchCache};

// 创建搜索服务（自动创建缓存）
let service = SearchService::new(pool);

// 或者使用自定义缓存
let cache = SearchCache::new();
let service = SearchService::with_cache(pool, cache);

// 执行搜索（自动使用缓存）
let response = service.search(user_id, workspace_id, query).await?;
```

### 缓存操作

```rust
// 获取缓存统计信息
let stats = service.cache_stats();
println!("缓存条目数: {}", stats.entry_count);

// 清除指定 workspace 的缓存
service.invalidate_workspace_cache(workspace_id).await;

// 清除所有缓存
service.clear_cache().await;
```

## 缓存行为

### 缓存命中

当相同的搜索查询（包括所有参数）在 5 分钟内再次执行时：
1. 从缓存中直接返回结果
2. 不执行数据库查询
3. 记录 debug 日志：`Search cache hit`

### 缓存未命中

当搜索查询不在缓存中或已过期时：
1. 执行数据库查询
2. 将结果存入缓存（5 分钟 TTL）
3. 记录 debug 日志：`Search cache miss, executing database query`

### 缓存过期

- **自动过期**: 缓存条目在 5 分钟后自动过期
- **容量限制**: 当缓存条目超过 1000 条时，使用 LRU 策略淘汰最少使用的条目

## 性能影响

### 预期性能提升

- **缓存命中时**: 响应时间从 ~100-500ms 降低到 ~1-5ms（约 100 倍提升）
- **数据库负载**: 相同查询的重复请求不会触发数据库查询
- **并发能力**: 缓存命中时可支持更高的并发请求

### 内存占用

- **单条缓存**: 约 1-5 KB（取决于结果数量）
- **最大内存**: 约 1000 * 5 KB = 5 MB（最大容量时）

## 监控和调试

### 日志

缓存操作会记录以下 debug 级别日志：

```
// 缓存命中
Search cache hit, cache_key=search:xxx:yyy

// 缓存未命中
Search cache miss, executing database query, cache_key=search:xxx:yyy

// 缓存写入
Search result cached, cache_key=search:xxx:yyy
```

### 统计信息

```rust
let stats = service.cache_stats();
println!("缓存条目数: {}", stats.entry_count);
println!("缓存占用大小: {}", stats.weighted_size);
```

## 测试

### 单元测试

缓存模块包含以下单元测试：
- 缓存键生成一致性
- 缓存键标准化（大小写、空格）
- 不同查询生成不同缓存键
- 缓存 get/set 操作
- 缓存清除操作
- 缓存统计信息

运行测试：
```bash
cargo test --lib search::cache
```

### 集成测试

搜索服务集成测试验证：
- 缓存命中和未命中行为
- 缓存过期机制
- 并发访问缓存的正确性

## 未来优化

### 可能的改进方向

1. **Redis 支持**: 如果需要跨实例共享缓存，可以添加 Redis 后端
2. **缓存预热**: 在系统启动时预加载热门搜索查询
3. **智能失效**: 当项目/剧本/资产更新时，主动失效相关缓存
4. **缓存分层**: 热门查询使用更长的 TTL
5. **压缩**: 对大结果集进行压缩以减少内存占用

### Redis 迁移指南

如果未来需要迁移到 Redis：

1. 添加 Redis 依赖：
```toml
redis = { version = "0.24", features = ["tokio-comp", "connection-manager"] }
```

2. 实现 Redis 缓存后端：
```rust
pub struct RedisSearchCache {
    client: redis::Client,
}

impl RedisSearchCache {
    pub async fn get(&self, key: &str) -> Option<SearchResponse> {
        // 从 Redis 获取并反序列化
    }
    
    pub async fn set(&self, key: &str, value: &SearchResponse, ttl: u64) {
        // 序列化并存入 Redis，设置 TTL
    }
}
```

3. 更新 SearchService 使用 Redis 缓存

## 相关文件

- `backend/src/search/cache.rs` - 缓存实现
- `backend/src/search/service.rs` - 搜索服务（集成缓存）
- `backend/src/search/models.rs` - 数据模型
- `backend/Cargo.toml` - 依赖配置（moka, md5）

## 参考资料

- [Moka 文档](https://docs.rs/moka/)
- [Requirements 9.2](../../.kiro/specs/global-search/requirements.md#requirement-9-性能与可扩展性)
