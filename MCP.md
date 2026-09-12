# 本分支：MCP 实现（mcp-v2）

本分支基于上游 [`piovium/genius-invokation`](https://github.com/piovium/genius-invokation) 的 `main`，叠加**七圣召唤 MCP（Model Context Protocol）实现**与两种对局模式：

| 模式 | 入口 | 说明 |
|---|---|---|
| 交互式对局 | `.opencode/start-p0.ps1` / `start-p1.ps1` / `start-both.ps1` + `packages/standalone` | 两个 agent（或人 + agent）通过 MCP 桥接驱动 standalone 客户端实时对局 |
| 无头批跑 | `.opencode/start-both-headless.ps1`、`.opencode/run-batch-llm.ps1`（配置 `.opencode/batch-llm-v2.json`） | 无 UI，批量跑 LLM 对局并落 LLM 交互日志 |

## 目录导览

- `packages/mcp/` — MCP 服务端：协议、工具、状态序列化/摘要、卡牌索引、评分、无头运行器
  - 入口文档：[README](./packages/mcp/README.md)（分层发布模型 core/adapter/patch）、[QUICKSTART](./packages/mcp/QUICKSTART.md)、[USAGE](./packages/mcp/USAGE.md)、`COMPATIBILITY.md`、`PATCHING.md`、`docs/`
- `packages/tactic-mcp/`、`packages/tactic-search/` — MCP 战术工具与搜索（`packages/mcp` 的依赖）
- `packages/llm-deck-analyzer/` — 卡组分析（MCP 工具链依赖；未发布到 npm，随本分支提供）
- `packages/standalone/` — 上游 standalone 客户端 + MCP 桥接插件（`src/StandaloneParentWithMCP.tsx`、`src/mcpBridgePlugin.ts`、`src/mcpState.ts`、`src/mcpActionEffects.ts`）
- `.opencode/` — 对局编排脚本、agent 配置（P0/P1）、prompts、plugins

## 构建与运行

```bash
pnpm install            # 上游要求 Node ^26.1.0；本仓库 packageManager 为 pnpm@12
# 依赖链需按序构建（.filter 是隐藏脚本，pnpm 11+ 下用 gnx 直调）：
pnpm exec gnx scripts/filter.ts build config,typings,utils,core,data,assets-manager
pnpm --filter @gi-tcg/card-data-viewer build
pnpm --filter @gi-tcg/detail-log-viewer build
pnpm --filter @gi-tcg/web-ui-core build && pnpm --filter @gi-tcg/deck-builder build
pnpm --filter @gi-tcg/llm-deck-analyzer build
pnpm --filter @gi-tcg/tactic-search build && pnpm --filter @gi-tcg/tactic-mcp build
pnpm --filter @gi-tcg/mcp build && pnpm --filter @gi-tcg/standalone build
```

跑测试与类型检查：

```bash
pnpm --filter @gi-tcg/mcp exec vitest run     # 13 文件 / 213 用例
pnpm --filter @gi-tcg/mcp check               # tsc --noEmit
```

对局前的前置条件见 [QUICKSTART](./packages/mcp/QUICKSTART.md)：本仓库不打包卡图，需自行下载到 `packages/standalone/public/card_images/`；LLM 相关脚本一律从环境变量取凭据（如 `OPENAI_API_KEY`），仓库内不存任何 key。

## 本分支相对上游的改动（透明清单）

叠加新包：`packages/mcp`、`packages/tactic-mcp`、`packages/tactic-search`、`packages/llm-deck-analyzer`，以及 `packages/standalone` 的 MCP 集成文件与 `.opencode/`。

为使这些包能在当前上游引擎上构建/检查，另做了如下**等价改写**（不改运行时行为）：

1. `packages/utils/src/dice.ts` — 采用含 `chooseDice` 的版本（上游只有 `chooseDiceValue`/`checkDice`；MCP 侧需要 `chooseDice`）。上游 `index.ts` 的导出保持不动（含 `toSortedBy`）。
2. `packages/assets-manager/src/index.ts` — 补导出 `getAllNamesSync`（该函数上游 `names.ts` 已有，仅未 re-export）。
3. `tsup` + TS 版本适配：`packages/mcp`、`packages/tactic-mcp`（用工作区 TS 6.x）加 `"ignoreDeprecations": "6.0"`——tsup 的 dts 流水线会注入 `baseUrl`，TS 6 起该选项报 TS5101；`packages/tactic-search`、`packages/llm-deck-analyzer` 自带 TS 5.9，不需要该选项。`packages/mcp` 补 `"types": ["node"]` 与 `"lib": ["ESNext","DOM"]`（其代码同时含 Node 与浏览器入口）。
4. `packages/standalone/package.json` — 显式声明 `@gi-tcg/mcp` 依赖（其 `StandaloneParentWithMCP.tsx` 一直在 import 它，此前依赖 pnpm 的隐式提升）。
5. `packages/standalone/src/mcpState.ts` — `export type Who`（`packages/mcp` 需要从外部引用该类型）。
6. MCP 侧代码适配上游 API：`getNameSync(language, id)` 补 language 参数（`HeadlessGameRunner`、`search-deck`）、`StateEvaluator.extractDelta` 去掉多余的第四个实参、`import.meta.dir` 改为 `fileURLToPath(new URL(...))`、`buildActionFeedback`/`buildCommandContext` 的类型补齐、`FragmentResolver.resolve()` 的 `debugNotes` 声明提前。
7. 测试从 `bun:test` 改为 `vitest`（本仓库禁用 bun，这些测试此前无法运行）；`packages/tactic-search` 的 `deploy/mine.ts`（Bun 专有脚本）移出编译范围。

## 验证状态（本机 Windows + Node 26.3 + pnpm 12）

- **构建**：`config` / `typings` / `utils` / `core` / `data` / `assets-manager` / `llm-deck-analyzer` / `tactic-search` / `tactic-mcp` / `mcp` / `card-data-viewer` / `detail-log-viewer` / `web-ui-core` / `deck-builder` / `standalone` 全部构建成功。
- **类型**：`mcp`、`tactic-mcp`、`tactic-search`、`llm-deck-analyzer` 的 `tsc --noEmit` 均为 0 错误（`mcp` 此前在该仓库中有 40+ 预存错误）。`standalone` 的 `check` 会报 3 条 TS6305（composite 构建产物未生成，与其 `build` 无关；`build` 通过）。
- **测试**：`packages/mcp` 13 文件 / 213 用例通过（17 跳过），vitest 类型检查无错误。
- ⚠️ 本机 `pnpm install` 有三个依赖的 postinstall 因 Windows DLL 初始化失败（`@swc/core`、`@vscode/vsce-sign`、`@bufbuild/buf`，疑与本机安全软件相关），用 `--ignore-scripts` 可完成安装；`buf generate`（`packages/typings` 的 `pnpm build:buf`）实测仍正常。

## 许可

沿用上游 **AGPL-3.0**（见 [LICENSE](./LICENSE)）。新增的 MCP 相关包同样以 AGPLv3 发布。
