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

import { deserializeGameStateLog } from "@gi-tcg/core";
import getData from "@gi-tcg/data";
import { ReplayFolderPlayer, type ReplayFile } from "./ReplayFolderPlayer";

export type { ReplayFile };

/**
 * 弹系统文件夹选择框，解析其中全部 JSON 对局日志。
 * 从 App.tsx 抽出，避免该功能在上游合并时产生冲突。
 */
async function pickReplayFolder(): Promise<ReplayFile[]> {
  const files: ReplayFile[] = [];
  const errors: string[] = [];

  return new Promise<ReplayFile[]>((resolve, reject) => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "application/json";
    input.multiple = true;
    // webkitdirectory enables folder selection in Chromium-based browsers
    (input as HTMLInputElement & { webkitdirectory?: boolean }).webkitdirectory = true;

    input.onchange = async (e) => {
      const fileList = (e.target as HTMLInputElement)?.files;
      if (!fileList || fileList.length === 0) {
        reject("No files selected");
        return;
      }

      // Sort files by name for consistent ordering
      const sorted = Array.from(fileList).sort((a, b) =>
        a.name.localeCompare(b.name),
      );

      for (const file of sorted) {
        try {
          const contents = await file.text();
          const logs = JSON.parse(contents);
          const gv = logs.gv;
          const parsed = deserializeGameStateLog(getData(gv), logs);
          files.push({ name: file.name, logs: parsed });
        } catch (error) {
          errors.push(
            `${file.name}: ${error instanceof Error ? error.message : String(error)}`,
          );
        }
      }

      if (files.length === 0) {
        reject(
          `No valid log files found. Errors:\n${errors.join("\n")}`,
        );
      } else {
        if (errors.length > 0) {
          console.warn("Some files failed to parse:", errors);
        }
        resolve(files);
      }
    };

    input.oncancel = () => {
      reject("Folder selection canceled");
    };

    input.click();
  });
}

export interface ReplayFolderButtonProps {
  onPicked: (files: ReplayFile[]) => void;
}

/** 首页的「导入文件夹」按钮。 */
export function ReplayFolderButton(props: ReplayFolderButtonProps) {
  return (
    <button
      onClick={async () => {
        const files = await pickReplayFolder().catch(alert);
        if (files && files.length > 0) {
          props.onPicked(files);
        }
      }}
    >
      导入文件夹
    </button>
  );
}

export interface ReplayFolderPageProps {
  files: ReplayFile[];
  onBack: () => void;
}

/** 文件夹回放页：播放列表 + 返回首页。 */
export function ReplayFolderPage(props: ReplayFolderPageProps) {
  return (
    <>
      <ReplayFolderPlayer files={props.files} />
      <button
        onClick={() => props.onBack()}
        style={{ margin: "1rem auto", display: "block" }}
      >
        返回首页
      </button>
    </>
  );
}
