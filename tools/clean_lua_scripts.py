import os
import re


def process_lua_content(content):
    """
    處理Lua內容：
    1. 移除 require 語句。
    2. 移除模組層級的 return {} 或 return ModuleName。
    3. 如果移除了 return ModuleName，則將 'local ModuleName = {}' 修改為 'ModuleName = {}'。
    """
    # 1. 移除完整的 require 語句
    content = re.sub(
        r'^\s*(?:local\s+)?\w*\s*=?\s*require\([^)]+\)(?:\.\w+)?\s*$',
        '',
        content,
        flags=re.MULTILINE)
    content = re.sub(r'\n+', '\n', content).strip()

    # 2. 移除模組層級的 return { ... } 語句
    content = re.sub(r"\s*return\s*\{\s*(?:[^}]*?)\s*\}\s*$",
                     "",
                     content,
                     flags=re.DOTALL)

    # 3. 處理 'return module_name' 和 'local module_name = {}'
    lines = content.splitlines()
    module_name = None

    # 從後往前遍歷，找到並移除 'return module_name'
    i = len(lines) - 1
    while i >= 0:
        line = lines[i].strip()
        if not line or line.startswith("--"):
            i -= 1
            continue

        match = re.match(r"^return\s+([\w_.]+)\s*$", line)
        if match and not re.search(r"\{", line):
            module_name = match.group(1)
            lines[i] = ""  # 移除 return 行

            j = i + 1
            while j < len(lines):
                if not lines[j].strip() or lines[j].strip().startswith("--"):
                    lines[j] = ""
                else:
                    break
                j += 1
            break
        else:
            break
        i -= 1

    # 4. 如果找到了 module_name，就移除其定義中的 'local'
    if module_name:
        try:
            # 使用更靈活的模式來匹配 'local ModuleName'，並在後續檢查是否為 table 初始化
            # 捕獲開頭的空白和 'local' 之後的內容
            pattern = re.compile(r"^(\s*)local(\s+" + re.escape(module_name) + r".*)$")
            for j, line in enumerate(lines):
                match_local_decl = pattern.match(line)
                if match_local_decl:
                    # 進一步檢查該行是否包含 '={}'，確保它是模組 table 的初始化
                    if re.search(r"=\s*\{", line):
                        # 如果匹配成功且是 table 初始化，則移除 'local'
                        new_line = match_local_decl.group(1) + match_local_decl.group(2)
                        lines[j] = new_line
                        break  # 假設一個檔案只會定義一次模組 table，找到就停止
        except re.error as e:
            print(f"Skipping module rename for '{module_name}' due to regex error: {e}")

    content = "\n".join(lines)
    content = re.sub(r"(\n\s*){2,}$", "\n", content)
    content = content.strip()

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
                relative_path = os.path.relpath(input_file_path, src_dir)
                output_file_path = os.path.join(slim_dir, relative_path)

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
