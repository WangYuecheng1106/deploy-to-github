# deploy-to-github

一个 Cursor Agent Skill，用于将当前工作区部署到 GitHub Pages、Vercel、Netlify 或 Cloudflare Pages，并返回线上 URL。

---

## 这是什么？

`deploy-to-github` 是符合 [Agent Skills](https://cursor.com/cn/docs/skills) 标准的技能。它封装了完整的部署流程，让 Agent 可以自动完成项目上线。

技能采用官方推荐结构：

```
deploy-to-github/
├── SKILL.md       # 主要使用指令（简洁）
├── scripts/       # 可执行脚本
├── references/    # 按需加载的详细文档（渐进式披露）
└── assets/        # 模板和静态资源
```

---

## 何时使用

在以下场景中对 Agent 使用：

- “把这个项目部署上线”
- “部署到 Vercel / Netlify / Cloudflare Pages / GitHub Pages”
- “publish / ship / go live”
- “上线 / 部署 / 发布”

**不适用**：

- 仅询问如何编写配置文件或脚本
- 普通的 git 操作

---



## 安装



### 方式一：通过 Cursor 界面安装（官方推荐）

> 适用于已发布到 GitHub 的技能，便于多人共享和自动更新。

1. 打开侧边栏 **Customize → Rules**
2. 点击 **Add Rule**
3. 选择 **Remote Rule (GitHub)**
4. 输入技能仓库地址



### 方式二：本地安装（无需 GitHub）

> （需要先下载！！！）Cursor 会自动扫描以下两个目录，把技能文件夹放进去即可被识别。


| 作用域 | 路径                                       | 适用场景         |
| --- | ---------------------------------------- | ------------ |
| 用户级 | `~/.cursor/skills/deploy-to-github/`     | 个人常用，跨所有项目生效 |
| 项目级 | `<项目根>/.cursor/skills/deploy-to-github/` | 随项目分发，团队协作   |


**安装步骤（PowerShell）：**

```powershell
# 源目录（含 SKILL.md 的技能根目录）
$src = "C:\Users\XXX\.cursor\skills\deploy-to-github"

# 用户级安装（推荐）
Copy-Item -Recurse -Force $src "$HOME\.cursor\skills\"

# 或项目级安装
Copy-Item -Recurse -Force $src ".\.cursor\skills\"
```

**目录结构要求**：技能根目录下必须包含 `SKILL.md`，可选 `scripts/`、`references/`、`templates/`、`assets/` 等。

**方式对比：**


| 方式          | 需 GitHub | 跨项目 | 随项目分发 | 自动更新 |
| ----------- | -------- | --- | ----- | ---- |
| Remote Rule | 是        | 是   | 否     | 是    |
| 用户级本地       | 否        | 是   | 否     | 否    |
| 项目级本地       | 否        | 否   | 是     | 否    |




### 安装后验证环境

```bash
python ~/.cursor/skills/deploy-to-github/scripts/deploy_helper.py check
```

重启 Cursor 后，在对话框输入 `/` 应能看到 `deploy-to-github`。

---



## 如何使用



### 1. 直接对话（最推荐）

直接对 Agent 说需求即可：

- “把这个 Vite 项目部署到 GitHub Pages”
- “把这个 Next.js 项目上线”
- “重新部署”

Agent 会自动调用本技能。

### 2. 显式调用

输入 `/deploy-to-github`

### 3. 一键命令（手动执行）

```bash
python scripts/deploy_helper.py up
```

常用参数：

```bash
python scripts/deploy_helper.py up --target vercel --create-repo --spa
```

支持目标：`pages`、`vercel`、`netlify`、`cloudflare`

不指定目标时会自动选择合适平台。

---



## 重要说明



### 仓库创建

默认只绑定已有仓库。需要新建仓库时必须使用 `--create-repo`，创建前 Agent 会确认。

### 运行时文件

会在当前项目生成 `.deploy-skill/` 目录（状态、日志、备份）。

建议加入 `.gitignore`：

```gitignore
.deploy-skill/
```



### SSR 限制

GitHub Pages 仅支持静态站点。检测到 SSR 项目时会拒绝使用 `pages` 目标，并给出建议。

### 没装 GitHub CLI（`gh`）时：GitHub Desktop 方案

标准自动流程依赖 `gh` 来创建仓库、推送分支、监控 Actions。如果只缺 `gh`、`git` 和 `node` 都在，并且目标是 GitHub Pages，Agent 会询问你是否切换到 **GitHub Desktop** 手动方案；同意后走下面的流程，**不需要安装** `gh`。

前置：从 [https://desktop.github.com/](https://desktop.github.com/) 下载并登录 GitHub Desktop。

**actions 模式（默认，推荐）：**

1. Agent 自动跑 `detect` → `build` → `config --target pages`，生成 `.github/workflows/deploy-pages.yml` 和框架配置。
2. Agent 在本地 `git init` + 提交所有文件（含工作流文件）。
3. 你在 GitHub Desktop 手动操作：
  - **File → New Repository…**
  - **Local path** = 当前项目目录
  - **Name** = 仓库名，**Public**（Pages 免费版要求 public）
  - 点 **Publish repository**，自动创建远程仓库并推送 `main`。
4. 在 github.com 仓库 **Settings → Pages → Source: GitHub Actions**。
5. 预期 URL：`https://<user>.github.io/<repo>/`。Agent 用 `validate` 校验。

**branch 模式（需明确指定）：**

1. Agent 跑 `detect` → `build` → `config`，并本地生成 `gh-pages` 孤儿分支（内容为构建产物）。
2. 你在 GitHub Desktop：
  - **File → New Repository…** → **Publish**（创建远程 + 推 `main`）。
  - 切到 `gh-pages` 分支并推送；或在终端 `git push origin gh-pages --force`（孤儿分支允许 force）。
3. github.com → **Settings → Pages → Source = Deploy from a branch → Branch:** `gh-pages` **/ root**。
4. 预期 URL：`https://<user>.github.io/<repo>/`。

**fallback 的限制：**

- 仓库创建、推送、监控 Actions、设置 Pages 来源都需要你在 GUI / 网页上手动完成。
- 非 Pages 目标（Vercel / Netlify / Cloudflare）不需要 `gh`，照常走平台自己的 CLI 即可。
- 如果你不想走手动方案，安装 `gh` 即可恢复全自动流程：

```powershell
winget install --id GitHub.cli -e   # Windows
# brew install gh                   # macOS
# sudo apt install gh               # Linux
```

---



## 参考资料

详细内容放在 `references/` 目录中，按需加载：

- `references/troubleshooting.md`
- `references/platforms.md`
- `references/framework-detection.md`

---



## 部署前快速检查

- [ ] `git`、`node` 已安装（必需）
- [ ] `gh` 已安装并 `gh auth login --web`（**可选**，缺失时 Pages 走 GitHub Desktop 方案）
- [ ] 已运行 `python ~/.cursor/skills/deploy-to-github/scripts/deploy_helper.py check`
- [ ] SSR 项目不要选 GitHub Pages
- [ ] 需要新建仓库时加上 `--create-repo`

部署成功后 Agent 会返回线上 URL 和目标平台信息。