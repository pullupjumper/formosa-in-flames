import os
import re


def process_lua_content(content):
    """
    處理Lua內容：移除require語句、模組層級的return {}。
    """
    # 1. 移除完整的 require 語句
    # 匹配 'local var = require("module")' 或 'require("module")'
    # 考慮到 require 可能在行首或有縮排
    # 1. 移除完整的 require 語句
    # 匹配 'local var = require("module")', 'var = require("module")' 或 'require("module")'
    # 考慮到 require 可能在行首或有縮排
    # 1. 移除完整的 require 語句
    # 匹配 'local var = require("module")', 'var = require("module")' 或 'require("module")'
    # 考慮到 require 可能在行首或有縮排，以及可能帶有 .submodule
    # 這裡嘗試匹配整個 require 語句的行
    # 1. 移除完整的 require 語句
    # 匹配 'local var = require("module")', 'var = require("module")' 或 'require("module")'
    # 考慮到 require 可能在行首或有縮排，以及可能帶有 .submodule
    # 這裡嘗試匹配整個 require 語句的行
    content = re.sub(
        # r"^\s*(?:local\s+)?(?:[\w_]+\s*=\s*)?require\s*([\"'])(?:(?!\1).)*\1(?:\s*\.[\w_]+)*\s*(--.*)?[\n\r]*",
        # "",
        r'^\s*(local\s+)?\w*\s*=?\s*require\([^)]+\)(\.\w+)?\s*$',
        '',
        content,
        flags=re.MULTILINE)
    content = re.sub(r'\n+', '\n', content).strip()

    # 2. 僅移除模組層級的 return {} 或 return { ... } 語句
    # 這裡使用一個更精確的模式，嘗試匹配檔案末尾的 return { ... } 結構
    # 避免匹配函數內部的 return
    # 匹配從 'return' 開始，到文件結束的任何內容，只要它看起來像一個模組返回表
    # 考慮到可能有多行，並且可能包含註釋或空白行
    content = re.sub(r"\s*return\s*\{\s*(?:[^}]*?)\s*\}\s*$",
                     "",
                     content,
                     flags=re.DOTALL)

    # 3. 移除模組層級的 return module 語句 (不帶括號)
    # 為了避免誤刪函數內部的 return，我們將從檔案末尾開始處理。
    lines = content.splitlines()

    # 從後往前遍歷，找到第一個非空且非註釋的行
    i = len(lines) - 1
    while i >= 0:
        line = lines[i].strip()
        # 忽略空行和註釋行
        if not line or line.startswith("--"):
            i -= 1
            continue

        # 檢查是否為模組層級的 return module
        # 匹配 'return module_name' 形式，且不是 'return {}'
        if re.match(r"^return\s+[\w_.]+\s*$", line) and not re.match(
                r"^return\s*\{\s*(?:[^}]*?)\s*\}\s*$", line):
            # 找到模組層級的 return，將其移除
            lines[i] = ""  # 將該行設置為空字串，相當於移除
            # 移除該 return 語句後，其後面的所有空白行和註釋行也應該被移除
            j = i + 1
            while j < len(lines):
                if not lines[j].strip() or lines[j].strip().startswith("--"):
                    lines[j] = ""
                else:
                    break  # 遇到非空非註釋行，停止移除
                j += 1
            break  # 找到並處理完畢，退出循環
        else:
            break  # 遇到其他有效程式碼，停止向上查找
        i -= 1

    content = "\n".join(lines)
    # 清理多餘的空行，特別是檔案末尾
    content = re.sub(r"(\n\s*){2,}$", "\n", content)  # 移除多餘的空行
    content = content.strip()  # 移除首尾空白

    return content

    return content


def main():
    src_dir = "src"
    slim_dir = "slim"

    if not os.path.exists(slim_dir):
        os.makedirs(slim_dir)

    for root, _, files in os.walk(src_dir):
        for file_name in files:
            if file_name.endswith(".lua"):
                input_file_path = os.path.join(root, file_name)

                # 構建輸出檔案路徑
                relative_path = os.path.relpath(input_file_path, src_dir)
                output_file_path = os.path.join(slim_dir, relative_path)

                # 確保輸出目錄存在
                output_dir = os.path.dirname(output_file_path)
                if not os.path.exists(output_dir):
                    os.makedirs(output_dir)

                try:
                    with open(input_file_path, "r", encoding="utf-8") as f:
                        content = f.read()

                    processed_content = process_lua_content(content)

                    with open(output_file_path, "w", encoding="utf-8") as f:
                        f.write(processed_content)
                    print(f"已處理並輸出: {output_file_path}")
                except Exception as e:
                    print(f"處理檔案 {input_file_path} 時發生錯誤: {e}")


if __name__ == "__main__":
    print("開始處理 Lua 腳本...")
    main()
    print("Lua 腳本處理完成。")
