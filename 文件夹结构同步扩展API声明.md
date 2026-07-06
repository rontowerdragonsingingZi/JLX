# 文件夹结构同步扩展 API 声明

本文档是针对“本地 BSS 有多层文件夹结构”这一需求的扩展协议声明。

当前云端论坛正式已接收的字段只有：

- `bssFolderId`
- `bssFolderName`

这只能表达“当前文档所在叶子文件夹”，不能表达完整的父子层级路径。

如果本地希望把文件夹树结构一并同步到云端，请按本文档扩展 `POST /api/posts/sync` 的请求体。

## 1. 目标

扩展后的同步协议需要让云端至少能识别：

- 当前文档属于哪个叶子文件夹
- 该叶子文件夹从根节点到当前节点的完整路径
- 每一级父文件夹的 `id / parentId / name`

## 2. 扩展字段

在保留原有字段不变的前提下，新增下面两个字段。

### 2.1 `bssFolderPath`

类型：`string | null`

含义：

- 从根文件夹到当前叶子文件夹的完整路径字符串
- 用于云端展示、筛选、搜索、快速识别结构

推荐格式：

```text
工作 / 项目A / 周报
```

约定：

- 使用从根到叶子的顺序
- 分隔符统一为 ` / `
- 不要在开头或结尾添加分隔符
- 若文档就在根文件夹下，则直接传根文件夹名

### 2.2 `bssFolderChain`

类型：`array<object> | null`

含义：

- 用结构化数组表达完整文件夹链
- 用于后端精确识别层级关系

数组顺序：

- 必须从根节点到叶子节点排序

每个节点对象结构：

```json
{
  "id": 1,
  "parentId": null,
  "name": "工作",
  "depth": 0
}
```

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `int` | 本地 `folders.id` |
| `parentId` | `int | null` | 本地 `folders.parent_id`，根节点为 `null` |
| `name` | `string` | 文件夹名称 |
| `depth` | `int` | 根节点为 `0`，向下递增 |

## 3. 完整请求示例

扩展后的 `POST /api/posts/sync` 请求示例：

```json
{
  "bssUserId": 3,
  "bssDocumentId": 42,
  "bssFolderId": 7,
  "bssFolderName": "周报",
  "bssFolderPath": "工作 / 项目A / 周报",
  "bssFolderChain": [
    {
      "id": 1,
      "parentId": null,
      "name": "工作",
      "depth": 0
    },
    {
      "id": 5,
      "parentId": 1,
      "name": "项目A",
      "depth": 1
    },
    {
      "id": 7,
      "parentId": 5,
      "name": "周报",
      "depth": 2
    }
  ],
  "title": "今日开发日志",
  "content": "# 标题\n\nMarkdown 正文...",
  "bssDocumentUpdatedAt": "2026-07-02T15:30:00.000"
}
```

## 4. 兼容规则

为了兼容旧版同步端，协议按下面规则处理：

1. `bssFolderId` 仍然保留，不能删除
2. `bssFolderName` 仍然保留，不能删除
3. `bssFolderPath` 为新增展示字段
4. `bssFolderChain` 为新增结构化字段
5. 若旧端未传 `bssFolderPath` / `bssFolderChain`，云端仍可按旧逻辑仅识别叶子文件夹
6. 若新端传了扩展字段，云端应优先使用扩展字段识别完整结构

## 5. 本地构造规则

本地 Agent 需要这样组装：

1. 从 `documents.folder_id` 找到当前叶子文件夹
2. 根据 `folders.parent_id` 一路向上追溯到根节点
3. 反转为“根 -> 叶子”的顺序
4. 叶子节点 `id` 写入 `bssFolderId`
5. 叶子节点 `name` 写入 `bssFolderName`
6. 全路径拼成 `bssFolderPath`
7. 全链路对象数组写入 `bssFolderChain`

## 6. 云端建议处理规则

云端接收扩展字段后，建议这样处理：

1. `bssFolderId` 继续作为叶子文件夹唯一标识
2. `bssFolderName` 继续作为叶子文件夹展示名
3. `bssFolderPath` 用于帖子详情、列表标签、搜索与筛选
4. `bssFolderChain` 用于保留完整结构，避免同名文件夹歧义
5. 若 `bssFolderChain` 的最后一个节点与 `bssFolderId / bssFolderName` 不一致，应拒绝请求或记日志后返回参数错误

## 7. 这个扩展解决什么问题

接入后可以解决：

- 只看到叶子文件夹名，看不出父级路径
- 不同父目录下存在同名文件夹时无法区分
- 云端帖子无法展示本地真正的文件夹层级

## 8. 图片问题与本扩展的关系

这个扩展只解决“文件夹树结构同步”，不解决图片资源上传。

图片同步仍然需要单独处理资源可访问地址，不能仅靠 `content` 正文同步完成。
