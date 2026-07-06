# 本地 BSS 接入云端论坛 API 说明

本文档是发给“本地 BSS 项目 Agent”的接入说明。

目标只有一个：让本地 BSS 通过 HTTP API 接入当前云端论坛项目，实现社区账号注册 / 登录，以及把本地 `documents` 同步到云端论坛。

## 1. 接入目标

本地 BSS 需要新增一套“云端论坛接入能力”，包含：

- 社区注册
- 社区登录
- Token 刷新
- 文档同步到社区
- 可选的社区帖子删除

本地 BSS 不需要做的事：

- 不要直连论坛 MySQL
- 不要操作论坛服务端代码
- 不要假设论坛账号和本地账号是同一套 ID
- 不要在论坛 Web 端发帖，发帖入口只在 BSS

## 2. 云端基址

- 生产 API 基址：`https://forum.mahoer.space`
- 健康检查：`GET https://forum.mahoer.space/api/health`

返回：

```json
{ "status": "ok" }
```

## 3. 接入总规则

- 所有请求 / 响应 JSON 一律使用 `camelCase`
- 需要登录态的接口统一使用：

```http
Authorization: Bearer <accessToken>
```

- `Content-Type` 统一为：

```http
application/json
```

- 云端错误格式统一按：

```json
{ "detail": "中文错误信息" }
```

## 4. 本地与云端的 ID 关系

这是最容易接错的地方。

- 本地 SQLite `users.id` 是本地用户 ID
- 云端论坛返回的 `userId` 是论坛用户 ID
- 这两个不是同一个值，不能混用

真正的绑定关系是：

- 本地 `users.id` 作为 `bssUserId`
- 第一次同步帖子时，云端会把当前论坛账号绑定到这个 `bssUserId`
- 云端绑定字段是 `users.bss_user_id`

所以：

- 本地发帖同步时，`bssUserId` 必须来自本地 `documents.user_id`
- 不能把论坛登录返回的 `userId` 填进 `bssUserId`

## 5. 哪些是本地要接的云端 API

本地至少要接下面这些接口。

### 5.1 发送注册验证码

`POST /api/auth/send-verification-code`

请求：

```json
{ "email": "alice@example.com" }
```

成功响应：

```json
{
  "message": "验证码已发送",
  "retryAfterSeconds": 60
}
```

说明：

- 本地注册页需要有邮箱输入框
- 本地需要有“发送验证码”按钮
- 本地需要根据 `retryAfterSeconds` 做倒计时

### 5.2 社区注册

`POST /api/auth/register`

请求：

```json
{
  "username": "alice",
  "password": "secret123",
  "email": "alice@example.com",
  "verificationCode": "123456"
}
```

成功响应：

```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "userId": 1,
  "username": "alice",
  "avatar": null
}
```

注意：

- 不是旧版的“只传用户名和密码”
- 现在注册必须带 `email` 和 `verificationCode`

### 5.3 社区登录

`POST /api/auth/login`

请求：

```json
{ "username": "alice", "password": "secret123" }
```

成功响应：

```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "userId": 1,
  "username": "alice",
  "avatar": null
}
```

### 5.4 刷新 Token

`POST /api/auth/refresh`

请求：

```json
{ "refreshToken": "eyJ..." }
```

成功响应格式与登录一致。

建议本地逻辑：

- 登录 / 注册成功后持久化 `accessToken`、`refreshToken`
- 调用受保护接口遇到 `401` 时先尝试 `refresh`
- `refresh` 失败后再让用户重新登录社区

### 5.5 同步本地文档到社区

`POST /api/posts/sync`

需要 Bearer Token。

请求：

```json
{
  "bssUserId": 3,
  "bssDocumentId": 42,
  "bssFolderId": 7,
  "bssFolderName": "工作笔记",
  "title": "今日开发日志",
  "content": "# 标题\n\nMarkdown 正文...",
  "bssDocumentUpdatedAt": "2026-07-02T15:30:00.000"
}
```

字段来源：

| 云端字段 | 本地来源 |
|---|---|
| `bssUserId` | `documents.user_id` |
| `bssDocumentId` | `documents.id` |
| `bssFolderId` | `documents.folder_id` |
| `bssFolderName` | `folders.name` |
| `title` | `documents.title` |
| `content` | `documents.content` |
| `bssDocumentUpdatedAt` | `documents.updated_at` |

说明：

- `content` 直接传本地 Markdown 正文
- `bssDocumentUpdatedAt` 强烈建议每次都传
- 云端会用 `bssDocumentId` 做幂等识别
- 云端会用 `bssDocumentUpdatedAt` 判断是否更新帖子

成功响应示例：

```json
{
  "id": 1,
  "authorId": 1,
  "authorUsername": "alice",
  "title": "今日开发日志",
  "content": "# 标题\n\nMarkdown 正文...",
  "bssUserId": 3,
  "bssDocumentId": 42,
  "bssFolderId": 7,
  "bssFolderName": "工作笔记",
  "bssDocumentUpdatedAt": "2026-07-02T15:30:00",
  "createdAt": "2026-07-02T16:00:00Z",
  "updatedAt": "2026-07-02T16:00:00Z"
}
```

### 5.6 可选：删除社区帖子

`DELETE /api/posts/{postId}`

需要 Bearer Token，且只能删除当前论坛账号自己创建的帖子。

成功：`204`

## 6. 本地必须新增或确认的字段 / 状态

本地 `documents` 表建议有同步状态字段：

```sql
ALTER TABLE documents ADD COLUMN synced_to_community INTEGER NOT NULL DEFAULT 0;
```

建议约定：

- `0` = 未同步
- `1` = 已同步

本地处理规则：

- `POST /api/posts/sync` 成功后设为 `1`
- 如果本地提供“删除社区帖子”并成功调通，则重置为 `0`
- 云端不会反向回写本地状态

## 7. 云端已实现的同步规则

本地 Agent 需要按这些规则写逻辑：

1. 某个论坛账号第一次同步帖子时，云端会自动绑定 `bssUserId`
2. 如果同一个论坛账号后来传了别的 `bssUserId`，云端会拒绝
3. 如果某个 `bssUserId` 已经绑定到别的论坛账号，云端会拒绝
4. 同一个 `bssDocumentId` 再次同步时，不会重复创建新帖子
5. 若 `bssDocumentUpdatedAt` 更晚，云端会更新原帖子
6. 发起同步的论坛账号不是该帖作者时，云端会拒绝更新

这意味着本地要做到：

- 同一篇文档重复同步时，继续传同一个 `bssDocumentId`
- 文档更新后继续传新的 `updated_at`
- 不要为同一篇文档随意生成新的“云端映射 ID”

## 8. 本地建议实现流程

### 8.1 社区注册流程

1. 用户输入 `username`、`password`、`email`
2. 点击发送验证码
3. 本地调用 `POST /api/auth/send-verification-code`
4. 用户输入验证码
5. 本地调用 `POST /api/auth/register`
6. 保存返回的 `accessToken`、`refreshToken`、`userId`、`username`、`avatar`

### 8.2 社区登录流程

1. 用户输入 `username`、`password`
2. 本地调用 `POST /api/auth/login`
3. 保存返回的社区登录态

### 8.3 文档同步流程

1. 用户在 BSS 中选择一篇 `documents`
2. 本地读取该文档的：
   `id`、`user_id`、`folder_id`、`title`、`content`、`updated_at`
3. 本地读取对应 `folders.name`
4. 组装 `POST /api/posts/sync` 请求
5. 成功后把本地 `synced_to_community` 设为 `1`

## 9. 本地 UI 至少要有的入口

建议最少包含：

- 社区注册页
- 社区登录页
- 发送验证码按钮
- 文档详情页或列表页的“同步到社区”按钮
- 已同步状态展示

可选再做：

- 删除社区帖子
- 社区头像同步

## 10. 错误处理要求

本地至少要正确处理这些云端错误：

### 认证相关

- `400`：用户名和密码不能为空
- `400`：邮箱格式不正确
- `400`：验证码不能为空
- `400`：验证码错误或已过期
- `401`：用户名或密码错误
- `401`：无效刷新令牌
- `409`：用户名已存在
- `409`：该邮箱已被注册
- `429`：请稍后再发送验证码

### 同步相关

- `401`：无效令牌
- `401`：用户不存在
- `403`：`bss用户ID与当前账号不匹配`
- `403`：`只能更新自己的帖子`
- `409`：`该bss用户ID已绑定其他社区账号`

## 11. 本地 Agent 的实现边界

本地 Agent 只需要围绕“接入云端 API”完成工作，不要扩展到：

- 改云端数据库结构
- 改论坛服务端发帖逻辑
- 改论坛前端页面
- 自建另一套社区协议

如果要联的是当前这套云端论坛，就必须按本文档的 API 与规则实现。

## 12. 最小落地清单

本地 Agent 可以按这个顺序直接施工：

1. 配置云端 API 基址
2. 新增社区注册 / 登录 API 客户端
3. 增加验证码发送接口接入
4. 增加 Token 持久化与刷新逻辑
5. 给 `documents` 增加 `synced_to_community`
6. 增加文档同步到社区接口
7. 在文档页挂接“同步到社区”按钮
8. 做基础错误提示

完成这 8 步后，本地 BSS 就已经具备接入当前云端论坛的最小能力。
