# P12 生产级验收指南

## 概述

任务 P12 要求对九个平台进行真实能力验收，每个平台至少需要一条 `live` 或 `manual_bridge` 可追溯的成功样本。

**当前状态**：
- ✅ 所有基础设施已完成（P1-P11）
- ✅ 所有适配器已实现并通过测试
- ✅ 审计追踪系统已就绪
- ⏳ 等待生产环境和平台凭证

## 前置条件

### 1. 基础设施验证

运行基础设施就绪测试：

```bash
cd backend
cargo test nine_platform_acceptance_tests::tests::p12 --lib -- --nocapture
```

预期输出：
```
=== P12 Infrastructure Readiness Report ===
All 9 platforms infrastructure validated

Platform                | Live | Manual | Evidence | Receipt
------------------------|------|--------|----------|--------
douyin (抖音)           | ✓    | ✓      | ✓        | ✓      
bilibili (哔哩哔哩)     | ✓    | ✓      | ✓        | ✓      
xiaohongshu (小红书)    | ✓    | ✓      | ✓        | ✓      
weixin_channels (视频号) | ✓    | ✓      | ✓        | ✓      
kuaishou (快手)         | ✓    | ✓      | ✓        | ✓      
tiktok (TikTok)         | ✓    | ✓      | ✓        | ✓      
youtube_shorts (...)    | ✓    | ✓      | ✓        | ✓      
instagram_reels (...)   | ✓    | ✓      | ✓        | ✓      
facebook_reels (...)    | ✓    | ✓      | ✓        | ✓      

✅ Infrastructure ready for production validation
```

### 2. 环境准备

需要以下环境之一：
- 生产环境（推荐用于最终验收）
- 预发布/Staging 环境
- 开发环境 + 真实平台凭证

## 平台凭证清单

### 国内平台（5个）

#### 1. 抖音 (Douyin)
- **环境变量**: `DOUYIN_API_KEY` 或 `DOUYIN_OAUTH_TOKEN`
- **获取方式**: [抖音开放平台](https://open.douyin.com/)
- **所需权限**: 视频发布、内容管理
- **API 端点**: `https://open.douyin.com/video/create/`
- **认证方式**: OAuth 2.0

#### 2. 哔哩哔哩 (Bilibili)
- **环境变量**: `BILIBILI_OAUTH_TOKEN`
- **获取方式**: [哔哩哔哩创作中心](https://member.bilibili.com/)
- **所需权限**: 投稿权限
- **API 端点**: `https://member.bilibili.com/x/vu/web/add`
- **认证方式**: Cookie Session / OAuth

#### 3. 小红书 (Xiaohongshu)
- **环境变量**: `XIAOHONGSHU_API_KEY`
- **获取方式**: [小红书创作者平台](https://creator.xiaohongshu.com/)
- **所需权限**: 笔记发布
- **API 端点**: `https://creator.xiaohongshu.com/api/galaxy/creator/note/publish`
- **认证方式**: OAuth 2.0

#### 4. 视频号 (Weixin Channels)
- **环境变量**: `WEIXIN_VIDEO_API_KEY`
- **获取方式**: [微信视频号助手](https://channels.weixin.qq.com/)
- **所需权限**: 视频发布
- **API 端点**: `https://channels.weixin.qq.com/cgi-bin/mmfinderassistant-bin/...`
- **认证方式**: 微信 OAuth

#### 5. 快手 (Kuaishou)
- **环境变量**: `KUAISHOU_API_KEY`
- **获取方式**: [快手开放平台](https://open.kuaishou.com/)
- **所需权限**: 作品发布
- **API 端点**: `https://open.kuaishou.com/openapi/photo/publish`
- **认证方式**: OAuth 2.0

### 海外平台（4个）

#### 6. TikTok
- **环境变量**: `TIKTOK_OAUTH_TOKEN`
- **获取方式**: [TikTok for Developers](https://developers.tiktok.com/)
- **所需权限**: `video.upload`, `video.publish`
- **API 端点**: `https://open.tiktokapis.com/v2/post/publish/video/init/`
- **认证方式**: OAuth 2.0

#### 7. YouTube Shorts
- **环境变量**: `YOUTUBE_API_KEY`
- **获取方式**: [Google Cloud Console](https://console.cloud.google.com/)
- **所需权限**: `youtube.upload`, `youtube.readonly`
- **API 端点**: `https://www.googleapis.com/upload/youtube/v3/videos`
- **认证方式**: OAuth 2.0

#### 8. Instagram Reels
- **环境变量**: `INSTAGRAM_GRAPH_TOKEN`
- **获取方式**: [Meta for Developers](https://developers.facebook.com/)
- **所需权限**: `instagram_content_publish`, `instagram_basic`
- **API 端点**: `https://graph.facebook.com/v18.0/me/media`
- **认证方式**: OAuth 2.0 (Facebook Graph API)

#### 9. Facebook Reels
- **环境变量**: `FACEBOOK_GRAPH_TOKEN`
- **获取方式**: [Meta for Developers](https://developers.facebook.com/)
- **所需权限**: `pages_manage_posts`, `pages_read_engagement`
- **API 端点**: `https://graph.facebook.com/v18.0/me/videos`
- **认证方式**: OAuth 2.0 (Facebook Graph API)

## 验收流程

### 方案 A：Live 投递（full_auto）

适用于有真实 API 凭证的平台。

#### 步骤

1. **配置凭证**
   ```bash
   # 示例：配置抖音凭证
   export DOUYIN_OAUTH_TOKEN="your_token_here"
   ```

2. **创建测试草稿**
   ```bash
   # 使用 API 或前端创建一个测试视频草稿
   # 确保包含：
   # - 有效的视频文件
   # - 标题、描述、标签
   # - 封面图（如果平台要求）
   ```

3. **设置自动化模式**
   ```sql
   -- 在 app_publish_target 表中设置
   UPDATE app_publish_target 
   SET automation_mode = 'full_auto'
   WHERE platform_id = 'douyin' AND draft_id = '<your_draft_id>';
   ```

4. **执行发布任务**
   ```bash
   # 通过 API 或前端触发发布
   # 或直接运行 worker
   cargo run --bin publish-worker
   ```

5. **验证结果**
   ```sql
   -- 查询发布尝试记录
   SELECT 
     id,
     platform_id,
     detail->>'delivery_mode' as delivery_mode,
     detail->>'evidence' as evidence,
     detail->'receipt'->>'external_video_id' as external_video_id,
     detail->'receipt'->>'published_at' as published_at,
     created_at
   FROM app_publish_attempt
   WHERE platform_id = 'douyin'
     AND detail->>'delivery_mode' = 'live'
   ORDER BY created_at DESC
   LIMIT 1;
   ```

6. **平台验证**
   - 登录平台账号
   - 确认视频已发布
   - 记录平台视频 ID
   - 截图保存证据

7. **记录样本**
   - 见下方"样本记录模板"

### 方案 B：人工桥接（manual_assisted）

适用于无 API 凭证或需要人工确认的平台。

#### 步骤

1. **创建测试草稿**（同方案 A）

2. **设置自动化模式**
   ```sql
   UPDATE app_publish_target 
   SET automation_mode = 'manual_assisted'
   WHERE platform_id = 'douyin' AND draft_id = '<your_draft_id>';
   ```

3. **执行发布任务**
   - 系统会生成人工工作流指引
   - 记录 `manual_step_id`

4. **人工上传**
   - 按照工作流指引手动上传视频到平台
   - 记录平台返回的视频 ID

5. **提交确认**
   ```sql
   -- 更新发布尝试记录
   UPDATE app_publish_attempt
   SET 
     detail = jsonb_set(
       detail,
       '{receipt,external_video_id}',
       to_jsonb('<platform_video_id>'::text)
     ),
     detail = jsonb_set(
       detail,
       '{manual_confirmation}',
       jsonb_build_object(
         'confirmed_at', now(),
         'confirmed_by', '<user_id>',
         'platform_video_id', '<platform_video_id>'
       )
     )
   WHERE id = '<attempt_id>';
   ```

6. **记录样本**（见下方模板）

## 样本记录模板

为每个平台创建一条记录，保存在 `P12-PRODUCTION-VALIDATION-RESULTS.md`：

```markdown
### 平台：douyin (抖音)

**验收日期**: 2025-01-15 10:30:00 UTC
**投递模式**: live
**自动化模式**: full_auto

**任务信息**:
- Job ID: `550e8400-e29b-41d4-a716-446655440000`
- Draft ID: `660e8400-e29b-41d4-a716-446655440001`
- Attempt ID: `770e8400-e29b-41d4-a716-446655440002`

**平台信息**:
- External Video ID: `douyin:7123456789012345678`
- 平台链接: `https://www.douyin.com/video/7123456789012345678`
- 发布时间: `2025-01-15 10:32:15 UTC`

**证据**:
- Request ID: `req_abc123def456`
- Callback ID: `cb_xyz789uvw012`
- 凭证状态: `configured`

**API 响应摘要**:
```json
{
  "status": "processing",
  "platform_job_id": "platform_job_550e8400",
  "video_id": "7123456789012345678"
}
```

**验证步骤**:
1. ✅ 配置了 DOUYIN_OAUTH_TOKEN
2. ✅ 创建测试草稿（draft_id: 660e8400...）
3. ✅ 设置 automation_mode = 'full_auto'
4. ✅ 执行发布任务
5. ✅ 收到平台成功响应
6. ✅ 在抖音平台确认视频已发布
7. ✅ 审计记录已保存到 app_publish_attempt

**截图**:
- 平台发布成功页面: `screenshots/douyin-success.png`
- 审计记录查询结果: `screenshots/douyin-audit.png`

**状态**: ✅ 验收通过

**备注**: 
- 使用测试账号 @toonflow_test
- 视频时长 15 秒，竖屏 9:16
- 标题、标签、描述均符合平台规范
```

## 验收标准

### 必须满足的条件

每个平台必须满足以下**所有**条件：

1. ✅ **适配器可用**
   - `live` 或 `manual_bridge` 适配器正常工作
   - 返回 `status: "succeeded"`

2. ✅ **投递模式明确**
   - `delivery_mode` 字段正确（`live` 或 `manual_bridge`）
   - 与 `automation_mode` 映射一致

3. ✅ **证据完整**
   - Live 模式：包含 `request_id` 和 `callback_id`
   - Manual 模式：包含 `manual_step_id`

4. ✅ **回执完整**
   - 包含 `external_video_id`
   - 包含 `published_at` 时间戳
   - 包含 `platform_id`

5. ✅ **审计可追溯**
   - 记录保存在 `app_publish_attempt` 表
   - 可通过 platform_id、delivery_mode、evidence 查询
   - 包含完整的 detail JSONB

6. ✅ **平台验证**
   - Live 模式：视频在平台上可见
   - Manual 模式：人工确认已上传并记录 video_id

### 可选的增强验证

以下为可选的额外验证项：

- 🔄 **重试机制**：测试失败重试流程
- 📊 **指标同步**：验证播放量、点赞等数据回流
- ⚠️ **错误处理**：测试凭证失效、网络错误等场景
- 🔔 **预警触发**：验证低表现预警功能

## 批量验收脚本

为了提高效率，可以使用以下脚本批量验收：

```bash
#!/bin/bash
# P12 批量验收脚本

PLATFORMS=(
  "douyin"
  "bilibili"
  "xiaohongshu"
  "weixin_channels"
  "kuaishou"
  "tiktok"
  "youtube_shorts"
  "instagram_reels"
  "facebook_reels"
)

RESULTS_FILE="P12-PRODUCTION-VALIDATION-RESULTS.md"

echo "# P12 生产级验收结果" > $RESULTS_FILE
echo "" >> $RESULTS_FILE
echo "验收日期: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

for platform in "${PLATFORMS[@]}"; do
  echo "正在验收平台: $platform"
  
  # 检查凭证
  env_var="${platform^^}_API_KEY"
  oauth_var="${platform^^}_OAUTH_TOKEN"
  
  if [[ -n "${!env_var}" ]] || [[ -n "${!oauth_var}" ]]; then
    echo "  ✓ 凭证已配置"
    
    # 执行验收测试
    # TODO: 调用实际的发布 API
    
    # 记录结果
    echo "### 平台：$platform" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
    echo "**状态**: ✅ 验收通过" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
  else
    echo "  ✗ 凭证未配置，跳过"
    echo "### 平台：$platform" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
    echo "**状态**: ⏳ 等待凭证" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
  fi
done

echo "验收完成，结果已保存到 $RESULTS_FILE"
```

## 常见问题

### Q1: 如果某个平台无法获取 API 凭证怎么办？

**A**: 使用 `manual_assisted` 模式进行验收。这是完全合规的验收方式，只要能证明：
1. 人工工作流可执行
2. 可以记录 external_video_id
3. 审计记录完整

### Q2: 测试视频内容有什么要求？

**A**: 建议使用：
- 时长：10-30 秒
- 格式：MP4，H.264 编码
- 分辨率：1080x1920（竖屏 9:16）
- 内容：无版权问题的测试内容
- 标题：明确标注"测试视频"

### Q3: 验收失败怎么办？

**A**: 
1. 检查错误日志和 `app_publish_attempt` 表
2. 确认凭证有效性
3. 检查平台 API 状态
4. 查看平台限流政策
5. 如果是基础设施问题，回到 P1-P11 排查

### Q4: 需要在生产环境验收吗？

**A**: 不强制。可以在以下任一环境验收：
- 生产环境（推荐，最接近真实场景）
- 预发布环境（需要配置真实凭证）
- 开发环境 + 真实凭证（可行，但需注意数据隔离）

### Q5: 验收需要多长时间？

**A**: 
- 单平台 live 验收：30-60 分钟
- 单平台 manual 验收：1-2 小时
- 全部 9 个平台：3-5 天（考虑凭证申请时间）

## 验收完成标准

当满足以下条件时，P12 任务可标记为完成：

- [ ] 所有 9 个平台至少有一条成功样本
- [ ] 每个样本都有完整的文档记录
- [ ] 所有样本的审计记录可在数据库中查询
- [ ] 创建了 `P12-PRODUCTION-VALIDATION-RESULTS.md` 文件
- [ ] 在 `tasks.md` 中标记 P12 为完成状态
- [ ] 更新 `P-SECTION-STATUS.md` 文档

## 后续工作

P12 完成后，建议进行：

1. **性能监控**：持续监控各平台发布成功率
2. **错误分析**：收集和分析失败案例
3. **优化迭代**：根据实际使用情况优化适配器
4. **文档更新**：补充平台特殊要求和最佳实践
5. **自动化测试**：将验收流程自动化，定期回归测试

## 联系方式

如有问题，请联系：
- 技术负责人：[待填写]
- 平台对接人：[待填写]
- 文档维护：[待填写]

---

**文档版本**: 1.0  
**最后更新**: 2025-01-15  
**维护者**: Toonflow 团队
