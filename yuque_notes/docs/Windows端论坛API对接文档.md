# NoteYourNeed（Windows 端）论坛 API 对接文档

> **用途**：与论坛服务端对齐联调。  
> **依据**：Windows 与 Android 共用同一套 Flutter 代码；HTTP 调用集中在  
> `lib/services/forum/`、`lib/services/community_sync_service.dart`。  
> **生成日期**：2026-07-17（以当前仓库客户端实现为准）。

---

## 1. 全局约定

| 项 | 客户端实现 |
|----|------------|
| **API 基址** | `https://forum.mahoer.space`（`ForumApiClient.defaultBaseUrl`） |
| **完整 URL** | `{baseUrl}{path}`，例如 `https://forum.mahoer.space/api/auth/login` |
| **协议** | HTTPS |
| **Content-Type** | `application/json` |
| **Accept** | `application/json` |
| **JSON 字段命名** | **camelCase**（禁止 snake_case） |
| **认证头** | `Authorization: Bearer <accessToken>`（需登录的接口） |
| **密码** | 客户端传 **明文**；论坛端自行哈希存储（与本地 SHA-256 规则对齐由服务端负责） |
| **错误体（服务端）** | 推荐 FastAPI 风格：`{ "detail": "中文错误信息" }` |
| **客户端读错误** | 优先 `detail`（string 或 validation list 的 `msg`），其次 `message`；空 body 时按 HTTP 状态码生成提示 |

### 1.1 客户端调用清单（仅 HTTP）

| # | 方法 | 路径 | 鉴权 | 触发场景 |
|---|------|------|------|----------|
| 1 | `POST` | `/api/auth/login` | 否 | 登录 |
| 2 | `POST` | `/api/auth/register` | 否 | 注册 |
| 3 | `POST` | `/api/auth/send-verification-code` | 否 | 发送邮箱验证码 |
| 4 | `POST` | `/api/auth/refresh` | 否（body 带 refreshToken） | Token 刷新 |
| 5 | `PATCH` | `/api/users/me/avatar` | Bearer | 更新头像 |
| 6 | `POST` | `/api/posts/sync` | Bearer | 文档上传云端/同步社区 |
| 7 | `DELETE` | `/api/posts/{postId}` | Bearer | 删除社区帖（客户端已实现，UI 可能未暴露） |

### 1.2 非 HTTP（不在本文对接范围）

| 能力 | 说明 |
|------|------|
| 本地 SQLite | 文件夹/文档/用户均本地存储 |
| 导入/导出 `.nnb` | 本地文件 JSON，不访问论坛 |
| 联系我们 | 本地文案 + 静态资源 |

---

## 2. 认证相关 API

### 2.1 登录

| 项 | 值 |
|----|-----|
| **Method** | `POST` |
| **Path** | `/api/auth/login` |
| **完整地址** | `https://forum.mahoer.space/api/auth/login` |
| **鉴权** | 无 |
| **客户端期望成功状态码** | **仅 `200`** |

#### 请求头

```http
Content-Type: application/json
Accept: application/json
```

#### 请求体（JSON）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `username` | string | 是 | 用户名（客户端会 `trim`） |
| `password` | string | 是 | 明文密码 |

#### 示例请求

```http
POST /api/auth/login HTTP/1.1
Host: forum.mahoer.space
Content-Type: application/json
Accept: application/json

{
  "username": "alice",
  "password": "secret123"
}
```

#### 客户端期望成功响应（HTTP 200）

| 字段 | 类型 | 必填（客户端解析） | 说明 |
|------|------|-------------------|------|
| `accessToken` | string | **是** | 访问令牌 |
| `refreshToken` | string \| null | 否 | 刷新令牌 |
| `userId` | number | **是** | 论坛用户 ID |
| `username` | string | **是** | 用户名 |
| `avatar` | string \| null | 否 | **R2 公网 URL** 或 `null`（不是 Base64） |

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "userId": 7,
  "username": "alice",
  "avatar": "https://pub-xxxx.r2.dev/avatars/7/xxx.jpg"
}
```

无头像时 `"avatar": null`。

Token 有效期（服务端默认，以 JWT `exp` 为准）：

| Token | 默认有效期 |
|-------|-----------|
| accessToken | 24 小时 |
| refreshToken | 7 天 |

#### 失败响应（示例）

客户端期望可读 `detail`：

```json
{
  "detail": "用户名或密码错误"
}
```

常见状态：`401` / `400` / `502`（网关无 body 时客户端提示 502）。

#### 客户端代码位置

- `ForumCloudAuthApi.login` → `POST /api/auth/login`
- 解析：`_parseAuthResult`

---

### 2.2 注册

| 项 | 值 |
|----|-----|
| **Method** | `POST` |
| **Path** | `/api/auth/register` |
| **完整地址** | `https://forum.mahoer.space/api/auth/register` |
| **鉴权** | 无 |
| **客户端期望成功状态码** | **仅 `200`** |

#### 请求体（JSON）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `username` | string | 是 | 用户名 |
| `password` | string | 是 | 明文密码 |
| `email` | string | 是 | 邮箱 |
| `verificationCode` | string | 是 | 邮箱验证码 |

#### 示例请求

```http
POST /api/auth/register HTTP/1.1
Host: forum.mahoer.space
Content-Type: application/json
Accept: application/json

{
  "username": "alice",
  "password": "secret123",
  "email": "alice@example.com",
  "verificationCode": "123456"
}
```

#### 客户端期望成功响应（HTTP 200）

与 **登录成功响应相同**（`accessToken` / `refreshToken` / `userId` / `username` / `avatar`）。

```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "userId": 7,
  "username": "alice",
  "avatar": null
}
```

#### 失败响应（示例）

```json
{
  "detail": "验证码错误或已过期"
}
```

#### 客户端代码位置

- `ForumCloudAuthApi.register` → `POST /api/auth/register`

---

### 2.3 发送邮箱验证码

| 项 | 值 |
|----|-----|
| **Method** | `POST` |
| **Path** | `/api/auth/send-verification-code` |
| **完整地址** | `https://forum.mahoer.space/api/auth/send-verification-code` |
| **鉴权** | 无 |
| **客户端期望成功状态码** | **仅 `200`** |

#### 请求体（JSON）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `email` | string | 是 | 邮箱（`trim`） |

#### 示例请求

```http
POST /api/auth/send-verification-code HTTP/1.1
Host: forum.mahoer.space
Content-Type: application/json
Accept: application/json

{
  "email": "alice@example.com"
}
```

#### 客户端期望成功响应（HTTP 200）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `message` | string | 建议 | 如 `"验证码已发送"` |
| `retryAfterSeconds` | number | 是（云端当前始终返回数字） | 再次发送等待秒数 |

```json
{
  "message": "验证码已发送",
  "retryAfterSeconds": 60
}
```

#### 客户端解析规则

- `retryAfterSeconds` 为 `number` → `toInt()` 用于倒计时
- 兼容缺失/`null` → 返回 `null`
- 其它类型 → `Unexpected verification response`

#### 失败响应（示例）

```json
{
  "detail": "发送过于频繁，请稍后再试"
}
```

#### 客户端代码位置

- `ForumCloudAuthApi.sendVerificationCode`

---

### 2.4 刷新 Token

| 项 | 值 |
|----|-----|
| **Method** | `POST` |
| **Path** | `/api/auth/refresh` |
| **完整地址** | `https://forum.mahoer.space/api/auth/refresh` |
| **鉴权** | 无 Bearer 头；**body 携带 refreshToken** |
| **客户端期望成功状态码** | **仅 `200`** |

#### 请求体（JSON）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `refreshToken` | string | 是 | 刷新令牌 |

#### 示例请求

```http
POST /api/auth/refresh HTTP/1.1
Host: forum.mahoer.space
Content-Type: application/json
Accept: application/json

{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### 客户端期望成功响应（HTTP 200）

与登录相同结构：

```json
{
  "accessToken": "eyJ...新access...",
  "refreshToken": "eyJ...新refresh或沿用...",
  "userId": 7,
  "username": "alice",
  "avatar": null
}
```

**必填解析字段**：`accessToken`、`userId`、`username`。

#### 失败响应（示例）

```json
{
  "detail": "refreshToken 无效或已过期"
}
```

#### 客户端代码位置

- `ForumCloudAuthApi.refresh`
- `SessionService.refreshCloudSession`（会话层调用）

---

## 3. 用户相关 API

### 3.1 更新当前用户头像

| 项 | 值 |
|----|-----|
| **Method** | `PATCH` |
| **Path** | `/api/users/me/avatar` |
| **完整地址** | `https://forum.mahoer.space/api/users/me/avatar` |
| **鉴权** | **是** `Authorization: Bearer <accessToken>` |
| **客户端期望成功状态码** | **仅 `200`** |

#### 请求头

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <accessToken>
```

#### 请求体（JSON）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `avatar` | string \| null | 是（可 null） | 客户端常见为 `data:image/...;base64,...` 或 URL；传 `null` 表示清空（若服务端支持） |

#### 示例请求

```http
PATCH /api/users/me/avatar HTTP/1.1
Host: forum.mahoer.space
Content-Type: application/json
Accept: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

{
  "avatar": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z5BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
}
```

#### 请求约束（与云端一致）

- 非空 `avatar` 必须是 Data URI：
  - `data:image/jpeg;base64,...`
  - `data:image/png;base64,...`
  - `data:image/gif;base64,...`
  - `data:image/webp;base64,...`
- **不接受**普通图片 URL 作为上传内容
- 文件最大 **5 MB**
- 客户端上传后**禁止**把本地 Base64 当头像缓存；必须使用响应里的 URL

#### 客户端期望成功响应（HTTP 200）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `avatar` | string \| null | 是（允许 null） | **R2 公网 URL** 或 `null`（清空） |

```json
{
  "avatar": "https://pub-xxxx.r2.dev/avatars/81/0f6c....jpg"
}
```

清空：

```json
{
  "avatar": null
}
```

#### 失败响应（示例）

| 状态码 | 含义 |
|-------:|------|
| 400 | Data URI/Base64 无效、类型不支持或超过 5MB |
| 401 | accessToken 无效或过期 |
| 502 | R2 上传失败 |
| 503 | 后端 R2 未配置 |

```json
{
  "detail": "未登录或 token 无效"
}
```

#### 客户端代码位置

- `ForumCloudAuthApi.updateAvatar`
- UI：工作区点击头像换图（保存会话时只用响应 `avatar`）

---

## 4. 文档 / 帖子同步 API

### 4.1 同步文档到社区（上传云端）

| 项 | 值 |
|----|-----|
| **Method** | `POST` |
| **Path** | `/api/posts/sync` |
| **完整地址** | `https://forum.mahoer.space/api/posts/sync` |
| **鉴权** | **是** `Authorization: Bearer <accessToken>` |
| **客户端期望成功状态码** | **`200` 或 `201`**（任一即可） |

#### 请求头

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <accessToken>
```

#### 请求体（JSON）

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `bssUserId` | number | 是 | 本地 SQLite `users.id`（非论坛 users.id） |
| `bssDocumentId` | number | 是 | 本地 `documents.id` |
| `bssFolderId` | number | 是 | 本地文档所属 `folders.id` |
| `bssFolderName` | string | 否 | 直接父文件夹名称；有父文件夹时发送 |
| `bssFolderPath` | string | 否 | 根到父的路径，用 ` / ` 拼接，如 `"工作 / 子目录"` |
| `bssFolderChain` | array | 否 | 从根到当前文件夹的链路数组（见下表） |
| `title` | string | 是 | 文档标题 |
| `content` | string | 是 | 文档正文（Markdown 字符串；可含图片 data URI、`<nn-snippet ...>` 等） |
| `bssDocumentUpdatedAt` | string | 是 | 本地文档更新时间 ISO-8601 |

##### `bssFolderChain[]` 元素

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | number | 本地文件夹 id |
| `parentId` | number \| null | 父文件夹 id，根为 `null` |
| `name` | string | 文件夹名 |
| `depth` | number | 从 0 开始的深度（根 = 0） |

#### 示例请求

```http
POST /api/posts/sync HTTP/1.1
Host: forum.mahoer.space
Content-Type: application/json
Accept: application/json
Authorization: Bearer eyJ...

{
  "bssUserId": 3,
  "bssDocumentId": 12,
  "bssFolderId": 5,
  "bssFolderName": "工作笔记",
  "bssFolderPath": "工作笔记",
  "bssFolderChain": [
    {
      "id": 5,
      "parentId": null,
      "name": "工作笔记",
      "depth": 0
    }
  ],
  "title": "今日开发日志",
  "content": "# 标题\n\n正文\n\n<nn-snippet data=\"...\"></nn-snippet>",
  "bssDocumentUpdatedAt": "2026-07-02T16:00:00.000"
}
```

嵌套文件夹示例（`bssFolderPath` / `bssFolderChain`）：

```json
{
  "bssFolderId": 9,
  "bssFolderName": "周报",
  "bssFolderPath": "工作笔记 / 周报",
  "bssFolderChain": [
    { "id": 5, "parentId": null, "name": "工作笔记", "depth": 0 },
    { "id": 9, "parentId": 5, "name": "周报", "depth": 1 }
  ]
}
```

#### 客户端期望成功响应（HTTP 200 或 201）

客户端**当前不强制解析字段**（只要状态码在 200/201 即视为成功，然后本地 `synced_to_community = 1`）。  
为便于对齐，服务端建议返回完整帖子对象，例如：

```json
{
  "id": 1,
  "authorId": 1,
  "authorUsername": "alice",
  "title": "今日开发日志",
  "content": "# 标题\n\n正文",
  "bssUserId": 3,
  "bssDocumentId": 12,
  "bssFolderId": 5,
  "bssFolderName": "工作笔记",
  "bssFolderPath": "工作笔记",
  "bssDocumentUpdatedAt": "2026-07-02T16:00:00.000",
  "createdAt": "2026-07-02T16:00:00.000",
  "updatedAt": "2026-07-02T16:00:00.000"
}
```

| 字段 | 类型 | 建议 | 说明 |
|------|------|------|------|
| `id` | number | 建议 | 论坛帖子 ID |
| `authorId` | number | 建议 | 论坛作者 ID |
| `authorUsername` | string | 建议 | 作者用户名 |
| `title` / `content` | string | 建议 | 与请求一致或规范化后的内容 |
| `bssUserId` / `bssDocumentId` / `bssFolderId` | number | 建议 | 回显映射 |
| `createdAt` / `updatedAt` | string | 建议 | ISO-8601 |

#### 客户端业务前置（不会发 HTTP）

| 条件 | 结果 |
|------|------|
| 本地用户为游客 `__local__` | 本地抛错，不请求接口 |
| 未登录（无 session） | UI 先拉登录 |
| 同步返回 `401` | 尝试 `refresh` 后重试一次；仍失败则清会话 |

#### 失败响应（示例）

```json
{
  "detail": "文档不存在或无权同步"
}
```

#### 客户端代码位置

- `CommunitySyncService.syncDocumentToCommunity`
- UI：文档编辑器「上传云端」

---

### 4.2 删除社区帖子

| 项 | 值 |
|----|-----|
| **Method** | `DELETE` |
| **Path** | `/api/posts/{postId}` |
| **完整地址** | `https://forum.mahoer.space/api/posts/{postId}` |
| **鉴权** | **是** `Authorization: Bearer <accessToken>` |
| **客户端期望成功状态码** | **仅 `204`**（无 body 或空 body） |

#### 路径参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `postId` | number | 论坛帖子 ID（非本地 document id） |

#### 示例请求

```http
DELETE /api/posts/42 HTTP/1.1
Host: forum.mahoer.space
Accept: application/json
Authorization: Bearer eyJ...
```

#### 客户端期望成功响应

- HTTP **204**
- Body 可为空

#### 失败响应（示例）

```json
{
  "detail": "帖子不存在"
}
```

#### 客户端代码位置

- `CommunitySyncService.deleteCommunityPost`（已实现；当前主 UI 未必暴露入口）

---

## 5. 通用错误格式（对齐要求）

### 5.1 推荐错误体

```json
{
  "detail": "中文人类可读错误"
}
```

### 5.2 校验错误列表（FastAPI 风格，客户端可解析）

```json
{
  "detail": [
    {
      "loc": ["body", "username"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

客户端会尽量取 `detail[0].msg`。

### 5.3 客户端对状态码的兜底文案（body 无法解析时）

| HTTP | 客户端兜底提示（摘要） |
|------|------------------------|
| 400 | 请求参数错误 |
| 401 | 用户名或密码错误，或未授权 |
| 403 | 无权限访问 |
| 404 | 接口不存在 |
| 502 | 网关错误：论坛服务未响应 |
| 503 | 服务暂时不可用 |
| 504 | 网关超时 |
| 其它 | 请求失败（HTTP xxx） |

---

## 6. ID 映射约定（同步对齐关键）

| 客户端本地（SQLite） | 请求字段 | 论坛侧建议 |
|----------------------|----------|------------|
| `users.id` | `bssUserId` | 绑定/关联 `users.bss_user_id` |
| `documents.id` | `bssDocumentId` | 帖子唯一键之一，防重复同步 |
| `folders.id` | `bssFolderId` | 帖子文件夹元数据 |
| 论坛 `users.id` | 响应 `userId` / `authorId` | 与 bss id **不是**同一序列 |

---

## 7. 内容字段 `content` 说明（同步时）

客户端同步的 `content` 为 **Markdown 文本**，可能包含：

| 内容类型 | 形式 |
|----------|------|
| 普通正文 | Markdown |
| 图片 | 如 `<img src="data:image/..." width="300" />` 或 data URI |
| 可复制块组件 | `<nn-snippet data="<base64url(JSON)>"></nn-snippet>` |

`nn-snippet` 的 JSON 解码后结构示例：

```json
{
  "id": "1730000000000_12345",
  "title": "小标题",
  "content": "可复制正文"
}
```

服务端可原样存字符串，无需解析组件，除非要做论坛渲染。

---

## 8. 快速对照表（联调 Checklist）

| API | Method | 成功码 | 鉴权 | 请求要点 | 响应要点 |
|-----|--------|--------|------|----------|----------|
| `/api/auth/login` | POST | 200 | 否 | username, password | accessToken, userId, username |
| `/api/auth/register` | POST | 200 | 否 | + email, verificationCode | 同登录 |
| `/api/auth/send-verification-code` | POST | 200 | 否 | email | retryAfterSeconds? |
| `/api/auth/refresh` | POST | 200 | 否 | refreshToken | 同登录结构 |
| `/api/users/me/avatar` | PATCH | 200 | Bearer | avatar | avatar |
| `/api/posts/sync` | POST | 200/201 | Bearer | bss* + title + content | 任意 JSON Map 即可 |
| `/api/posts/{id}` | DELETE | 204 | Bearer | path id | 空 body |

---

## 9. 源码索引

| 模块 | 路径 |
|------|------|
| HTTP 客户端 | `lib/services/forum/forum_api_client.dart` |
| 认证实现 | `lib/services/forum/forum_cloud_auth_api.dart` |
| 认证抽象 | `lib/services/cloud_auth_api.dart` |
| 文档同步 | `lib/services/community_sync_service.dart` |
| 登录 UI | `lib/screens/auth/auth_dialog.dart` |
| 上传云端 UI | `lib/widgets/document_editor_panel.dart` + `workspace_screen.dart` |
| 基址常量 | `ForumApiClient.defaultBaseUrl` |

---

## 10. 变更说明

- 本文档描述的是 **客户端实际发出的请求与解析期望**，用于与服务端契约对齐。  
- 若服务端路径/字段/状态码与上表不一致，Windows 登录/同步会出现解析失败或「请求失败 / 502」类提示。  
- 修改对接时请同步更新：本文档 + `forum_cloud_auth_api.dart` / `community_sync_service.dart` / 服务端实现。
