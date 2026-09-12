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

import type { DiceType, ReadonlyDiceRequirement } from "@gi-tcg/typings";

// 索引式选骰：返回布尔数组，被选中的骰子下标为 true。
// 上游 @gi-tcg/utils 已不再提供 chooseDice（改为 chooseDiceValue），
// 而本包需要"按下标选中"的语义，故在此本地实现，避免 fork utils。
const VOID = 0;
const OMNI: typeof DiceType.Omni = 8;
const ALIGNED: typeof DiceType.Aligned = 8;
const ENERGY = 9;

/**
 * "智能"选骰算法（不检查能量）
 * @param required 卡牌或技能需要的骰子类型
 * @param dice 当前持有的骰子
 * @returns 布尔数组，被选择的骰子的下标对应元素设置为 `true`；如果无法选择则返回全 `false`。
 */
export function chooseDice(
  required: ReadonlyDiceRequirement,
  dice: readonly DiceType[],
): boolean[] {
  const OMNI_COUNT = dice.filter((d) => d === OMNI).length;
  const FAIL_RESULT = Array<boolean>(dice.length).fill(false);
  const result = [...FAIL_RESULT];
  // 需要同色骰子
  if (required.has(ALIGNED)) {
    const requiredCount = required.get(ALIGNED)!;
    // 杂色骰子+万能骰子，凑够同色
    for (let i = dice.length - 1; i >= 0; i--) {
      if (dice[i] === OMNI) continue;
      const thisCount = dice.filter((d) => d === dice[i]).length;
      if (thisCount + OMNI_COUNT < requiredCount) continue;
      for (
        let j = dice.length - 1, count = 0;
        count < requiredCount && j >= 0;
        j--
      ) {
        if (dice[j] === OMNI || dice[j] === dice[i]) {
          result[j] = true;
          count++;
        }
      }
      return result;
    }
    // ……或者只用万能骰子凑
    if (OMNI_COUNT >= requiredCount) {
      for (let i = dice.length - 1, count = 0; count < requiredCount; i--) {
        if (dice[i] === OMNI) {
          result[i] = true;
          count++;
        }
      }
      return result;
    }
    return FAIL_RESULT;
  }
  const requiredArray = required
    .entries()
    .toArray()
    .flatMap(([k, v]) => Array.from({ length: v }, () => k));
  // 无色或者杂色
  next: for (const r of requiredArray) {
    if (r === ENERGY) continue;
    if (r === VOID) {
      // 无色：任何骰子都可以
      for (let j = dice.length - 1; j >= 0; j--) {
        if (!result[j]) {
          result[j] = true;
          continue next;
        }
      }
    } else {
      // 对应颜色或者万能骰子
      for (let j = 0; j < dice.length; j++) {
        if (!result[j] && dice[j] === r) {
          result[j] = true;
          continue next;
        }
      }
      for (let j = 0; j < dice.length; j++) {
        if (!result[j] && dice[j] === OMNI) {
          result[j] = true;
          continue next;
        }
      }
    }
    return FAIL_RESULT;
  }
  return result;
}

