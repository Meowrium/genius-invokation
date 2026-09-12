// Copyright (C) 2024-2025 Guyutongxue
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import { Show, createSignal } from "solid-js";

export interface McpModeTabProps {
  /**
   * 玩家点击「开始对局」时触发。双方均为 user 时由调用方回退到普通本地模拟。
   */
  onStart: (player0Type: "user" | "ai", player1Type: "user" | "ai") => void;
}

// 模块级 signal：首页 tab 条只在 NotStarted 时挂载，玩家选择需在开始对局、
// 再返回首页时仍然保留（此前由 App.tsx 持有的同名状态保证）。
const [player0Type, setPlayer0Type] = createSignal<"user" | "ai">("ai");
const [player1Type, setPlayer1Type] = createSignal<"user" | "ai">("user");

/**
 * 首页 tab 条中的「MCP模式」入口（radio + 标题 + 配置面板三连）。
 * 独立成文件，避免 MCP 相关 UI 侵入 App.tsx，减少上游合并冲突。
 */
export function McpModeTab(props: McpModeTabProps) {
  return (
    <>
      <input
        class="tab__input"
        type="radio"
        name="gameModeTab"
        id="mcpInput"
      />
      <label class="tab__header" for="mcpInput">
        MCP模式
      </label>
      <div class="tab__content config-panel">
        <div class="config-panel__title">MCP AI 对局配置</div>
        <div class="config-panel__description">
          牌组配置请在「本地模拟」标签页中设置。
          <br />
          设置各玩家由用户还是 AI 控制。双方均为用户时将自动使用普通本地模拟模式。
        </div>
        <div class="config-panel__deck">
          <label>先手 (Player 0)</label>
          <select
            value={player0Type()}
            onChange={(e) => setPlayer0Type(e.target.value as "user" | "ai")}
          >
            <option value="ai">AI</option>
            <option value="user">用户</option>
          </select>
        </div>
        <div class="config-panel__deck">
          <label>后手 (Player 1)</label>
          <select
            value={player1Type()}
            onChange={(e) => setPlayer1Type(e.target.value as "user" | "ai")}
          >
            <option value="ai">AI</option>
            <option value="user">用户</option>
          </select>
        </div>
        <Show
          when={player0Type() === "user" && player1Type() === "user"}
        >
          <div class="config-panel__description text-danger">
            ⚠ 双方均为用户，将使用普通本地模拟模式。
          </div>
        </Show>
        <div class="config-panel__button-group">
          <button
            onClick={() => {
                props.onStart(player0Type(), player1Type());
            }}
          >
            开始对局
            {player0Type() === "ai" || player1Type() === "ai"
              ? " (MCP)"
              : ""}
          </button>
        </div>
      </div>
    </>
  );
}
