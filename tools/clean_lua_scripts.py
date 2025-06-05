import os
import re


def process_lua_content(content):
    """
    處理Lua內容：移除require語句、模組層級的return {}。
    """
    # 1. 移除完整的 require 語句
    # 匹配 'local var = require("module")' 或 'require("module")'
    # 考慮到 require 可能在行首或有縮排
    content = re.sub(
        r"^\s*local\s+[\w_]+\s*=\s*require\s*([\"'])(?:(?!\1).)*\1(?:\s*\.[\w_]+)*\s*(--.*)?[\n\r]*",
        "",
        content,
        flags=re.MULTILINE)
    content = re.sub(
        r"^\s*require\s*([\"'])(?:(?!\1).)*\1(?:\s*\.[\w_]+)*\s*(--.*)?[\n\r]*",
        "",
        content,
        flags=re.MULTILINE)

    # 2. 僅移除模組層級的 return {} 或 return { ... } 語句
    # 這裡使用一個更精確的模式，嘗試匹配檔案末尾的 return { ... } 結構
    # 避免匹配函數內部的 return
    # 匹配從 'return' 開始，到文件結束的任何內容，只要它看起來像一個模組返回表
    # 考慮到可能有多行，並且可能包含註釋或空白行
    content = re.sub(r"\s*return\s*\{\s*(?:[^}]*?)\s*\}\s*$",
                     "",
                     content,
                     flags=re.DOTALL)

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
