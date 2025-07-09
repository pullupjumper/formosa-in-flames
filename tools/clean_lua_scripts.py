import os
import re


def process_lua_content(content):
    """
    Process Lua content:
    1. Remove require statements.
    2. Remove module-level return {} or return ModuleName.
    3. If return ModuleName is removed, change 'local ModuleName = {}' to 'ModuleName = {}'.
    """
    # 1. Remove require statements - comprehensive approach
    # Split content into lines for line-by-line processing
    lines = content.splitlines()
    filtered_lines = []

    for line in lines:
        # Check if line contains a require statement
        # Patterns to match:
        # - local VarName = require("module")
        # - local VarName = require('module')
        # - VarName = require("module")
        # - VarName = require('module')
        # - require("module") (standalone)
        # - require('module') (standalone)

        stripped_line = line.strip()

        # Skip empty lines and comments (we'll add them back)
        if not stripped_line or stripped_line.startswith('--'):
            filtered_lines.append(line)
            continue

        # Check if this line contains a require statement
        # This is more robust than complex regex patterns
        is_require_line = False

        # Use the most aggressive and simple approach possible
        if 'require(' in stripped_line:
            # Remove comments from the line for analysis
            line_without_comments = stripped_line.split('--')[0].strip()

            if 'require(' in line_without_comments:
                # If a line contains 'require(' and is not a comment, remove it
                # This is the most reliable approach
                is_require_line = True

        # If it's not a require line, keep it
        if not is_require_line:
            filtered_lines.append(line)

    # Rejoin the lines
    content = '\n'.join(filtered_lines)

    # Remove extra empty lines
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    content = re.sub(r'^\s*\n', '', content)
    content = content.strip()

    # 2. Remove module-level return { ... } statements
    content = re.sub(r"\s*return\s*\{\s*(?:[^}]*?)\s*\}\s*$",
                     "",
                     content,
                     flags=re.DOTALL)

    # 3. Handle 'return module_name' and 'local module_name = {}'
    lines = content.splitlines()
    module_name = None

    # Traverse from back to front, find and remove 'return module_name'
    i = len(lines) - 1
    while i >= 0:
        line = lines[i].strip()
        if not line or line.startswith("--"):
            i -= 1
            continue

        match = re.match(r"^return\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*$", line)
        if match and not re.search(r"\{", line):
            module_name = match.group(1)
            lines[i] = ""  # Remove return line

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

    # 4. Special handling for proxy pattern - detect and process module main table BEFORE processing the proxy
    # Find all local table declarations
    local_tables = []
    for line in lines:
        match = re.search(r'local\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*\{', line)
        if match:
            local_tables.append(match.group(1))
    
    # Count function definitions for each table to identify the main module table
    table_function_counts = {}
    for table_name in local_tables:
        count = 0
        pattern = re.compile(r'^function\s+' + re.escape(table_name) + r'\.')
        for line in lines:
            if pattern.match(line.strip()):
                count += 1
        table_function_counts[table_name] = count
    
    # Find the table with the most functions (likely the main module table)
    main_module_table = None
    max_functions = 0
    for table_name, count in table_function_counts.items():
        if count > max_functions and count > 0:  # Must have at least 1 function
            max_functions = count
            main_module_table = table_name
    
    # If we found a main module table and there are multiple tables, remove 'local' from main table
    if main_module_table and len(local_tables) > 1:
        try:
            pattern = re.compile(r"^(\s*)local(\s+" + re.escape(main_module_table) + r"\s*.*)$")
            for j, line in enumerate(lines):
                match_local_decl = pattern.match(line)
                if match_local_decl:
                    # Further check if the line contains '={}' to ensure it's table initialization
                    if re.search(r"=\s*\{", line):
                        # If match successful and is table initialization, remove 'local'
                        new_line = match_local_decl.group(1) + match_local_decl.group(2)
                        lines[j] = new_line
                        print(f"Removed 'local' from main module table '{main_module_table}' (has {max_functions} functions)")
                        break
        except re.error as e:
            print(f"Skipping main module table rename due to regex error: {e}")

    # 5. If module_name is found, remove 'local' from its definition
    if module_name:
        try:
            # Use flexible pattern to match 'local ModuleName' and check if it's table initialization
            # Capture leading whitespace and content after 'local'
            pattern = re.compile(r"^(\s*)local(\s+" + re.escape(module_name) +
                                 r".*)$")
            for j, line in enumerate(lines):
                match_local_decl = pattern.match(line)
                if match_local_decl:
                    # Further check if the line contains '={}' to ensure it's module table initialization
                    if re.search(r"=\s*\{", line):
                        # If match successful and is table initialization, remove 'local'
                        new_line = match_local_decl.group(
                            1) + match_local_decl.group(2)
                        lines[j] = new_line
                        break  # Assume only one module table definition per file
        except re.error as e:
            print(
                f"Skipping module rename for '{module_name}' due to regex error: {e}"
            )
    
    # Debug: Print detection results
    if main_module_table and len(local_tables) > 1:
        print(f"Proxy pattern detected: main_module='{main_module_table}' ({max_functions} functions), all_tables={local_tables}")

    content = "\n".join(lines)
    # Clean up extra empty lines
    content = re.sub(r"\n\s*\n\s*\n", "\n\n", content)
    content = re.sub(r"(\n\s*){3,}$", "\n", content)
    content = content.strip()

    return content


def main():
    src_dir = "src"
    slim_dir = "slim"

    if not os.path.exists(slim_dir):
        os.makedirs(slim_dir)

    processed_count = 0
    error_count = 0

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

                    # Count require statements before processing
                    require_count_before = len([
                        line for line in content.splitlines() if
                        'require' in line and not line.strip().startswith('--')
                    ])

                    processed_content = process_lua_content(content)

                    # Count require statements after processing
                    require_count_after = len([
                        line for line in processed_content.splitlines() if
                        'require' in line and not line.strip().startswith('--')
                    ])

                    with open(output_file_path, "w", encoding="utf-8") as f:
                        f.write(processed_content)

                    if require_count_before > 0:
                        print(
                            f"Processed: {relative_path} (removed {require_count_before - require_count_after}/{require_count_before} require statements)"
                        )
                    else:
                        print(f"Processed: {relative_path}")
                    processed_count += 1

                except Exception as e:
                    print(f"Error processing file {input_file_path}: {e}")
                    error_count += 1

    print(
        f"\nProcessing complete! Success: {processed_count} files, Errors: {error_count} files"
    )


if __name__ == "__main__":
    print("Starting Lua script processing...")
    main()
    print("Lua script processing completed.")
