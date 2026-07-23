# Windows 端论坛 API 对接修正

本文档用于修正《Windows端论坛API对接文档.md》中与当前论坛后端实现不一致的部分。

原文档中的 API 基址和大部分路径不需要修改：

```text
https://forum.mahoer.space
```

本文档只列出必须调整或需要特别注意的内容。

## 1. 头像接口：请求格式基本不变，响应格式已经改变

### 1.1 请求地址不变

```http
PATCH /api/users/me/avatar
Authorization: Bearer <accessToken>
Content-Type: application/json
```

Windows 端仍然可以提交当前使用的 Base64 Data URI：

```json
{
  "avatar": "data:image/jpeg;base64,/9j/4AAQ..."
}
```

也可以传 `null` 清空头像：

```json
{
  "avatar": null
}
```

### 1.2 服务端不再接受普通 URL 作为上传内容

当前接口接收的非空 `avatar` 必须是以下格式之一：

- `data:image/jpeg;base64,...`
- `data:image/png;base64,...`
- `data:image/gif;base64,...`
- `data:image/webp;base64,...`

服务端会在内存中将 Data URI 解码后上传到 Cloudflare R2，但不会把 Base64 保存到数据库。

限制：头像文件最大 5 MB，图片内容必须与声明的 MIME 类型一致。

### 1.3 成功响应不再是 Base64，而是 R2 URL

成功状态码：`200`

```json
{
  "avatar": "https://pub-74455fe21d224f73a370fd8443fe8a3c.r2.dev/avatars/81/0f6c....jpg"
}
```

清空头像时：

```json
{
  "avatar": null
}
```

Windows 端必须读取响应中的 `avatar`，并用它更新本地会话和头像缓存。不要继续把提交的 Base64 字符串作为头像保存。

Flutter/Dart 处理逻辑示意：

```dart
final response = await api.patch(
  '/api/users/me/avatar',
  data: {'avatar': dataUri},
);

final String? avatarUrl = response.data['avatar'] as String?;
session.avatar = avatarUrl;
await saveSession(session);
```

如果用户清空头像，`avatarUrl` 会是 `null`，客户端应同时删除本地头像缓存。

## 2. 登录、注册、刷新 Token 的响应格式

登录、注册和刷新接口都返回同一结构，字段名必须使用 camelCase：

```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "userId": 81,
  "username": "alice",
  "avatar": "https://pub-74455fe21d224f73a370fd8443fe8a3c.r2.dev/avatars/81/xxx.jpg"
}
```

没有头像时：

```json
{
  "avatar": null
}
```

客户端不能假设 `avatar` 一定是 Base64；它现在是 R2 公网 URL 或 `null`。

## 3. Token 有效期

当前默认配置：

| Token | 有效期 | 用途 |
|---|---:|---|
| `accessToken` | 24 小时 | 请求需要登录的接口 |
| `refreshToken` | 7 天 | 获取新 Token |

Token 内部包含 JWT `exp` 字段。有效期由后端环境变量控制：

```env
ACCESS_TOKEN_EXPIRE_HOURS=24
REFRESH_TOKEN_EXPIRE_DAYS=7
```

如果部署环境修改了这两个值，应以实际 JWT 的 `exp` 为准。

## 4. Token 过期和刷新流程

刷新接口：

```http
POST /api/auth/refresh
Content-Type: application/json
```

请求体：

```json
{
  "refreshToken": "eyJ..."
}
```

这个请求不需要 `Authorization: Bearer` 头。

刷新成功后会返回新的一组：

```json
{
  "accessToken": "eyJ...new-access...",
  "refreshToken": "eyJ...new-refresh...",
  "userId": 81,
  "username": "alice",
  "avatar": "https://pub-74455fe21d224f73a370fd8443fe8a3c.r2.dev/avatars/81/xxx.jpg"
}
```

推荐客户端逻辑：

1. 登录、注册或刷新成功后保存完整响应。
2. 每次请求需要登录的 API 都携带当前 `accessToken`。
3. 可以读取 JWT 的 `exp`，在过期前约 60 秒调用刷新接口。
4. 如果任意受保护接口返回 `401`，调用刷新接口并重试原请求一次。
5. 刷新也返回 `401` 时，删除本地 Token 和用户会话，要求重新登录。

客户端可以解码 JWT 的 `exp` 作为提前刷新提示，但不能把客户端解码结果当作安全校验；最终以服务端请求返回的 `401` 为准。

服务端没有单独的“检查 Token 是否过期”接口。

## 5. 错误响应处理

服务端错误通常返回：

```json
{
  "detail": "错误说明"
}
```

头像接口相关状态码：

| 状态码 | 含义 |
|---:|---|
| `400` | Data URI 无效、Base64 无效、图片类型不支持或超过 5 MB |
| `401` | accessToken 无效或已过期 |
| `502` | R2 上传失败 |
| `503` | 后端 R2 配置未完成 |

客户端不能把所有空响应都当作成功。非 `2xx` 响应应先读取状态码，再读取 `detail`；如果网关确实没有响应体，则使用状态码生成兜底提示。

## 6. 发送邮箱验证码的字段修正

接口：

```http
POST /api/auth/send-verification-code
```

成功响应实际为：

```json
{
  "message": "验证码已发送",
  "retryAfterSeconds": 60
}
```

当前后端会始终返回数字类型的 `retryAfterSeconds`，不是 `null`，客户端可以直接转换为倒计时秒数。

## 7. 帖子同步的字段和状态码修正

`POST /api/posts/sync` 的成功状态码当前固定为：
