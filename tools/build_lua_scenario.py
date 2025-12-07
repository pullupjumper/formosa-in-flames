#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Build Lua Scenario - Combined Script for Processing and Merging Lua Files
Combines the functionality of clean_lua_scripts.py and merge_lua_scripts.py
into a unified build system with dependency-aware ordering.
"""

import os
import re
import argparse
import shutil
from typing import List, Dict, Set, Tuple
from collections import defaultdict, deque

# =============================================================================
# CLEANING FUNCTIONS (from clean_lua_scripts.py)
# =============================================================================


def process_lua_content(content):
    """
    Process Lua content:
    1. Remove require statements.
    2. Remove ALL comments (including LuaLS annotations and block comments).
    3. Remove module-level return {} or return ModuleName.
    4. If return ModuleName is removed, change 'local ModuleName = {}' to 'ModuleName = {}'.
    """
    # First, remove block comments --[[ ... ]]
    # Use non-greedy matching to handle multiple block comments
    content = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)

    # 1. Remove require statements and comments - comprehensive approach
    # Split content into lines for line-by-line processing
    lines = content.splitlines()
    filtered_lines = []

    for line in lines:
        # Check if line contains a require statement
        stripped_line = line.strip()

        # Skip ALL comment lines (including LuaLS annotations like ---@type, ---@param, etc.)
        if stripped_line.startswith('--'):
            continue  # Remove this line entirely

        # Skip empty lines for now (we'll clean them up later)
        if not stripped_line:
            filtered_lines.append(line)
            continue

        # Check if this line contains a require statement
        is_require_line = False

        # Use the most aggressive and simple approach possible
        if 'require(' in stripped_line:
            # Remove comments from the line for analysis
            line_without_comments = stripped_line.split('--')[0].strip()

            if 'require(' in line_without_comments:
                # If a line contains 'require(' and is not a comment, remove it
                is_require_line = True

        # If it's not a require line, keep it (but remove inline comments)
        if not is_require_line:
            # Remove inline comments (e.g., "local x = 5 -- comment")
            if '--' in line:
                code_part = line.split('--')[0].rstrip()
                if code_part:  # Only keep if there's actual code
                    filtered_lines.append(code_part)
            else:
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
            pattern = re.compile(r"^(\s*)local(\s+" +
                                 re.escape(main_module_table) + r"\s*.*)$")
            for j, line in enumerate(lines):
                match_local_decl = pattern.match(line)
                if match_local_decl:
                    # Further check if the line contains '={}' to ensure it's table initialization
                    if re.search(r"=\s*\{", line):
                        # If match successful and is table initialization, remove 'local'
                        new_line = match_local_decl.group(
                            1) + match_local_decl.group(2)
                        lines[j] = new_line
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

    content = "\n".join(lines)
    # Clean up extra empty lines
    content = re.sub(r"\n\s*\n\s*\n", "\n\n", content)
    content = re.sub(r"(\n\s*){3,}$", "\n", content)
    content = content.strip()

    return content


def clean_lua_files(src_dir: str, slim_dir: str) -> Tuple[int, int]:
    """
    Clean Lua files from src directory to slim directory.
    Returns (processed_count, error_count)
    """
    if not os.path.exists(slim_dir):
        os.makedirs(slim_dir)

    processed_count = 0
    error_count = 0

    print(f"🧹 Cleaning Lua files from '{src_dir}' to '{slim_dir}'...")

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

                    # Special handling for unitStatusUI.lua to inject HTML templates
                    if file_name == "unitStatusUI.lua":
                        processed_content = inject_html_templates(
                            processed_content, src_dir)

                    # Count require statements after processing
                    require_count_after = len([
                        line for line in processed_content.splitlines() if
                        'require' in line and not line.strip().startswith('--')
                    ])

                    with open(output_file_path, "w", encoding="utf-8") as f:
                        f.write(processed_content)

                    if require_count_before > 0:
                        print(
                            f"  ✓ {relative_path} (removed {require_count_before - require_count_after}/{require_count_before} require statements)"
                        )
                    else:
                        print(f"  ✓ {relative_path}")
                    processed_count += 1

                except Exception as e:
                    print(f"  ✗ Error processing file {input_file_path}: {e}")
                    error_count += 1

    # Special post-processing: inject scripts into init.lua
    print("\n" + "=" * 70)
    init_lua_path = os.path.join(slim_dir, "core", "init.lua")
    if os.path.exists(init_lua_path):
        try:
            print("🔧 Post-processing init.lua with script injection...")

            # Load all processed scripts
            scripts_mapping = load_scripts_mapping(slim_dir)

            # Read current init.lua content
            with open(init_lua_path, "r", encoding="utf-8") as f:
                init_content = f.read()

            # Inject scripts
            modified_init_content = inject_scripts_into_init(init_content, scripts_mapping)

            # Write back to init.lua
            with open(init_lua_path, "w", encoding="utf-8") as f:
                f.write(modified_init_content)

            print("✅ init.lua post-processing completed")
        except Exception as e:
            print(f"❌ Error post-processing init.lua: {e}")
            error_count += 1
    else:
        print(f"⚠️ Warning: init.lua not found at {init_lua_path}")

    return processed_count, error_count


def inject_html_templates(content: str, src_dir: str) -> str:
    """
    Inject HTML templates into unitStatusUI.lua
    """
    # Assuming references/html is parallel to src directory
    # src_dir is likely "src"
    # We need to go up one level and then to references/html
    # But src_dir might be absolute or relative.
    # If src_dir is "src", os.path.dirname("src") is "".

    # Let's try to find the project root based on src_dir
    if os.path.isabs(src_dir):
        project_root = os.path.dirname(src_dir)
    else:
        # If src_dir is relative, e.g. "src", we assume we are running from project root
        project_root = "."

    html_dir = os.path.join(project_root, "src", "htmls")

    # Helper to process and inject
    def process_and_inject(html_filename: str, function_name: str,
                           lua_content: str):
        html_path = os.path.join(html_dir, html_filename)
        if os.path.exists(html_path):
            try:
                with open(html_path, 'r', encoding='utf-8') as f:
                    html_content = f.read()

                # Escape % to %% but keep %s as %s
                # 1. Replace all % with %%
                html_content = html_content.replace('%', '%%')
                # 2. Replace %%s back to %s (restore placeholders)
                html_content = html_content.replace('%%s', '%s')

                # Replace data assignments with placeholders
                # 1. units object -> unitsString
                html_content = re.sub(
                    r'const\s+units\s*=\s*\{.*?\};',
                    'const unitsString = `%s`;\n    const units = JSON.parse(unitsString);',
                    html_content,
                    flags=re.DOTALL)

                # 2. signals array -> signalsString
                html_content = re.sub(
                    r'const\s+signals\s*=\s*\[.*?\];',
                    'const signalsString = `%s`;\n    const signals = JSON.parse(signalsString);',
                    html_content,
                    flags=re.DOTALL)

                # 3. dataString (C2 nodes) - use greedy matching to handle multi-line JSON
                html_content = re.sub(r'const\s+dataString\s*=\s*`[^`]*`;',
                                      'const dataString = `%s`;',
                                      html_content,
                                      flags=re.DOTALL)

                # 4. baseWeaponsString - use greedy matching to handle multi-line JSON
                html_content = re.sub(
                    r'const\s+baseWeaponsString\s*=\s*`[^`]*`;',
                    'const baseWeaponsString = `%s`;',
                    html_content,
                    flags=re.DOTALL)

                # 5. landingUnitsString - use greedy matching to handle multi-line JSON
                html_content = re.sub(
                    r'const\s+landingUnitsString\s*=\s*`[^`]*`;',
                    'const landingUnitsString = `%s`;',
                    html_content,
                    flags=re.DOTALL)

                # 6. ewUnitString
                html_content = re.sub(r'const\s+ewUnitString\s*=\s*`.*?`;',
                                      'const ewUnitString = `%s`;',
                                      html_content,
                                      flags=re.DOTALL)

                # 7. baseString
                html_content = re.sub(r'const\s+baseString\s*=\s*`.*?`;',
                                      'const baseString = `%s`;',
                                      html_content,
                                      flags=re.DOTALL)

                # Regex to replace content inside [[ ... ]]
                # We use a lambda to safely insert the content
                pattern = r'(local function ' + re.escape(
                    function_name) + r'\(\)\s*return \[\[).*?(\]\])'

                new_content = re.sub(pattern,
                                     lambda m: m.group(1) + '\n' + html_content
                                     + '\n' + m.group(2),
                                     lua_content,
                                     flags=re.DOTALL)

                if new_content != lua_content:
                    print(
                        f"    ✓ Injected {html_filename} into {function_name}")
                    return new_content
                else:
                    print(
                        f"    ⚠️ Could not find function {function_name} to inject {html_filename}"
                    )
                    return lua_content

            except Exception as e:
                print(f"    ✗ Error injecting {html_filename}: {e}")
                return lua_content
        else:
            print(f"    ⚠️ HTML file not found: {html_path}")
            return lua_content

    # 1. Inject unit-status-table.html into getHTMLTemplate
    content = process_and_inject("unit-status-table.html", "getHTMLTemplate",
                                 content)

    # 2. Inject setup-menu.html into getSetupMenuTemplate
    content = process_and_inject("setup-menu.html", "getSetupMenuTemplate",
                                 content)

    content = process_and_inject("EMCON-setting-menu.html",
                                 "getWCSSettingTemplate", content)

    return content


def load_scripts_mapping(slim_dir: str) -> Dict[str, str]:
    """
    Load all processed script files from slim/scripts directory.
    Returns a mapping of {action_name -> script_content}
    Example: {"scripts\\china\\CSGEnterArea.lua" -> "actual code"}
    """
    scripts_mapping = {}
    scripts_dir = os.path.join(slim_dir, "scripts")

    if not os.path.exists(scripts_dir):
        print(f"⚠️ Warning: Scripts directory '{scripts_dir}' does not exist")
        return scripts_mapping

    print(f"📜 Loading script files from '{scripts_dir}'...")

    for root, _, files in os.walk(scripts_dir):
        for file_name in files:
            if file_name.endswith(".lua"):
                script_path = os.path.join(root, file_name)
                # Get relative path from slim_dir (e.g., "scripts/china/CSGEnterArea.lua")
                relative_path = os.path.relpath(script_path, slim_dir)
                # Normalize path separators to backslashes (Windows style) to match action names in init.lua
                # Use replace to ensure consistency regardless of OS
                action_name = relative_path.replace(os.sep, "\\")

                try:
                    with open(script_path, "r", encoding="utf-8") as f:
                        content = f.read()
                    scripts_mapping[action_name] = content
                    print(f"  ✓ Loaded {action_name}")
                except Exception as e:
                    print(f"  ✗ Error loading {action_name}: {e}")

    print(f"📊 Total scripts loaded: {len(scripts_mapping)}")
    return scripts_mapping


def get_long_string_level(content: str) -> int:
    """
    Determine the required level for Lua long string brackets.
    Returns the minimum number of '=' needed to avoid conflicts.
    Example: level 0 -> [[ ... ]], level 1 -> [=[ ... ]=], etc.
    """
    level = 0
    while level <= 10:  # Safety limit
        # Check if the current level's closing bracket exists in content
        closing = ']' + ('=' * level) + ']'
        if closing not in content:
            return level
        level += 1
    return 10  # Fallback to level 10


def inject_scripts_into_init(init_content: str, scripts_mapping: Dict[str, str]) -> str:
    """
    Inject script contents into init.lua's initEventActions function.
    Expands the for loop and replaces each ScriptText = [[]] with actual content
    """
    if not scripts_mapping:
        print("⚠️ No scripts to inject")
        return init_content

    print("💉 Injecting scripts into init.lua...")

    # Parse actionNames table and extract all action names
    action_names = []
    in_action_names = False
    lines = init_content.split('\n')

    for line in lines:
        if 'local actionNames = {' in line:
            in_action_names = True
            continue
        if in_action_names:
            if '}' in line and not line.strip().startswith('--'):
                break
            # Extract string from line like: "scripts\\china\\CSGEnterArea.lua",
            match = re.search(r'["\']([^"\']+)["\']', line)
            if match:
                # Convert Lua escaped backslashes (\\) to single backslash (\)
                action_name = match.group(1).replace('\\\\', '\\')
                action_names.append(action_name)

    print(f"📋 Found {len(action_names)} action names in init.lua")

    # Now replace the entire for loop with expanded ScenEdit_SetAction calls
    result_lines = []
    i = 0
    injected_count = 0

    while i < len(lines):
        line = lines[i]

        # Detect start of for loop
        if 'for _, name in ipairs(actionNames) do' in line:

            # Get the indentation of the for loop
            indent = len(line) - len(line.lstrip())
            indent_str = ' ' * indent

            # Skip the for loop and its content until 'end'
            result_lines.append(line)  # Keep the for loop line commented out
            result_lines[-1] = indent_str + '-- ' + line.strip() + ' -- Expanded below'
            i += 1

            # Skip lines until we find the 'end' of the for loop
            loop_depth = 1
            while i < len(lines) and loop_depth > 0:
                curr_line = lines[i].strip()
                if curr_line.startswith('for ') or curr_line.startswith('if ') or curr_line.startswith('function '):
                    loop_depth += 1
                elif curr_line == 'end' or curr_line.startswith('end '):
                    loop_depth -= 1
                    if loop_depth == 0:
                        result_lines.append(indent_str + '-- ' + curr_line + ' -- End of expanded loop')
                        i += 1  # Move past the for loop's end
                        break
                # Comment out the original loop content
                if lines[i].strip() and not lines[i].strip().startswith('--'):
                    result_lines.append(indent_str + '-- ' + lines[i].strip())
                else:
                    result_lines.append(lines[i])
                i += 1

            # Now inject the expanded code
            for action_name in action_names:
                # Escape backslashes for Lua string literal (only for the action name)
                escaped_action_name = action_name.replace('\\', '\\\\')

                if action_name in scripts_mapping:
                    script_content = scripts_mapping[action_name]

                    # Process each line: remove comments and add space (NO semicolons for now)
                    # This simplifies debugging
                    processed_lines = []

                    script_lines = script_content.splitlines()
                    for script_i, script_line in enumerate(script_lines):
                        stripped = script_line.rstrip()
                        stripped_left = stripped.lstrip()

                        # Skip empty lines and ALL comment lines (including LuaLS annotations)
                        if not stripped or stripped_left.startswith('--'):
                            continue  # Skip this line entirely

                        # Just add space at the end, no semicolons
                        processed_lines.append(script_line + ' ')

                    processed_content = '\n'.join(processed_lines)

                    # Determine the required long string level to avoid conflicts
                    level = get_long_string_level(processed_content)
                    equals = '=' * level
                    opening_bracket = f'[{equals}['
                    closing_bracket = f']{equals}]'

                    # Use Lua long string syntax to preserve newlines and avoid escaping
                    result_lines.append(f'{indent_str}GameApi.ScenEdit_SetAction({{ mode = \'update\', type = \'LuaScript\', name = "{escaped_action_name}", ScriptText = {opening_bracket}\n{processed_content}\n{closing_bracket} }})')
                    injected_count += 1
                    print(f"  ✓ Injected {action_name} (long string level: {level})")
                else:
                    # Keep the original call with empty ScriptText if script not found
                    result_lines.append(f'{indent_str}GameApi.ScenEdit_SetAction({{ mode = \'update\', type = \'LuaScript\', name = "{escaped_action_name}", ScriptText = [[]] }})')
                    print(f"  ⚠️ Script not found for action: {action_name}")

            # After injecting scripts, i now points to the line after 'for loop's end'
            # which is initEventActions' end. We need to continue processing from there.
            # Decrement i so that the outer loop's i += 1 will process the current line
            i -= 1

        else:
            result_lines.append(line)

        i += 1

    print(f"📊 Total scripts injected: {injected_count}/{len(action_names)}")

    return '\n'.join(result_lines)


# =============================================================================
# MERGING FUNCTIONS (from merge_lua_scripts.py)
# =============================================================================


def get_file_section_comment(file_path: str, base_dir: str) -> str:
    """Generate a section comment for the file."""
    relative_path = os.path.relpath(file_path, base_dir)
    return f"-- ===== {relative_path} ===== --"


def read_file_content(file_path: str) -> str:
    """Read and return file content with error handling."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read().strip()
        return content
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
        return ""


def analyze_file_dependencies(file_path: str,
                              slim_dir: str,
                              src_dir: str = "src") -> Set[str]:
    """
    Analyze a single file's require() statements and return normalized dependency paths.
    Since slim files have requires removed, we check the corresponding src file.
    """
    dependencies = set()

    # Convert slim path to src path
    rel_path = os.path.relpath(file_path, slim_dir)
    src_file_path = os.path.join(src_dir, rel_path)

    if not os.path.exists(src_file_path):
        return dependencies

    try:
        with open(src_file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Find all require statements
        require_patterns = [
            r'require\s*\(\s*["\']([^"\']+)["\']\s*\)',
            r'require\s*\(["\']([^"\']+)["\']\)',
        ]

        for pattern in require_patterns:
            matches = re.findall(pattern, content)
            for match in matches:
                # Convert require path to file path
                # e.g., "src.utils.gameApi" -> "utils/gameApi.lua"
                normalized_path = normalize_require_path(match, slim_dir)
                if normalized_path:
                    dependencies.add(normalized_path)

    except Exception as e:
        print(
            f"Warning: Could not analyze dependencies for {src_file_path}: {e}"
        )

    return dependencies


def normalize_require_path(require_path: str, slim_dir: str) -> str:
    """
    Convert a require path to a normalized file path within slim directory.
    e.g., "src.utils.gameApi" -> "utils/gameApi.lua"
    """
    # Remove "src." prefix if present
    if require_path.startswith("src."):
        require_path = require_path[4:]

    # Convert dots to path separators
    file_path = require_path.replace(".", "/") + ".lua"

    # Check if the file exists in slim directory
    full_path = os.path.join(slim_dir, file_path)
    if os.path.exists(full_path):
        return file_path

    return None


def collect_all_lua_files(slim_dir: str,
                          skip_schema: bool = True) -> Dict[str, str]:
    """
    Collect all Lua files from slim directory (excluding scripts and optionally schema).
    Returns dict of {relative_path: full_path}
    """
    files = {}

    # Define directories to include
    include_dirs = ["core", "utils", "modules"]

    for dir_name in include_dirs:
        dir_path = os.path.join(slim_dir, dir_name)
        if os.path.exists(dir_path):
            for root, _, filenames in os.walk(dir_path):
                for filename in filenames:
                    if filename.endswith('.lua'):
                        # Skip schema.lua if requested
                        if skip_schema and filename == 'schema.lua':
                            continue

                        full_path = os.path.join(root, filename)
                        rel_path = os.path.relpath(full_path, slim_dir)
                        rel_path = rel_path.replace(
                            '\\', '/')  # Normalize separators
                        files[rel_path] = full_path

    return files


def build_dependency_graph(files: Dict[str, str],
                           slim_dir: str,
                           src_dir: str = "src") -> Dict[str, Set[str]]:
    """
    Build dependency graph by analyzing require statements in src files.
    Returns dict of {file_path: set_of_dependencies}
    """
    dependency_graph = {}

    print("📊 Analyzing file dependencies...")
    for rel_path, full_path in files.items():
        dependencies = analyze_file_dependencies(full_path, slim_dir, src_dir)
        # Only keep dependencies that exist in our file list
        valid_dependencies = {dep for dep in dependencies if dep in files}
        dependency_graph[rel_path] = valid_dependencies

        if valid_dependencies:
            print(
                f"  {rel_path} depends on: {', '.join(sorted(valid_dependencies))}"
            )
        else:
            print(f"  {rel_path} has no dependencies")

    return dependency_graph


def topological_sort(dependency_graph: Dict[str, Set[str]]) -> List[str]:
    """
    Perform topological sort on dependency graph using Kahn's algorithm.
    Returns files in dependency order (dependencies first).
    """
    # Calculate in-degrees
    in_degree = defaultdict(int)
    all_files = set(dependency_graph.keys())

    # Add all files that are dependencies but might not be in the main list
    for deps in dependency_graph.values():
        all_files.update(deps)

    # Initialize in-degrees
    for file in all_files:
        in_degree[file] = 0

    # Calculate actual in-degrees
    for file, deps in dependency_graph.items():
        for dep in deps:
            in_degree[file] += 1

    # Start with files that have no dependencies
    queue = deque([file for file in all_files if in_degree[file] == 0])
    result = []

    while queue:
        current = queue.popleft()
        result.append(current)

        # Reduce in-degree for files that depend on current file
        for file, deps in dependency_graph.items():
            if current in deps:
                in_degree[file] -= 1
                if in_degree[file] == 0:
                    queue.append(file)

    # Check for circular dependencies
    if len(result) != len(all_files):
        remaining = all_files - set(result)
        print(f"⚠️ Warning: Circular dependencies detected in: {remaining}")
        # Add remaining files in arbitrary order
        result.extend(remaining)

    return result


def get_file_priority(file_path: str) -> Tuple[int, str]:
    """
    Get priority for file ordering. Lower numbers = higher priority.
    Returns (priority_level, file_path) for sorting.
    """
    # Define fixed priority files
    priority_files = {
        "core/gKH_State_Standalone.lua": 0,
        "core/constants.lua": 1,
        "core/saveData.lua": 2,
    }

    if file_path in priority_files:
        return (priority_files[file_path], file_path)

    # init.lua should be last
    if file_path == "core/init.lua":
        return (9999, file_path)

    # Default priority based on directory
    if file_path.startswith("utils/"):
        return (100, file_path)
    elif file_path.startswith("modules/"):
        return (200, file_path)
    else:
        return (500, file_path)


def sort_files_with_dependencies(files: Dict[str, str],
                                 slim_dir: str,
                                 src_dir: str = "src") -> List[str]:
    """
    Sort files considering both fixed priorities and dynamic dependencies.
    """
    # Build dependency graph
    dependency_graph = build_dependency_graph(files, slim_dir, src_dir)

    # Get topological order
    topo_order = topological_sort(dependency_graph)

    # Group files by priority, maintaining topological order within groups
    priority_groups = defaultdict(list)

    for file_path in topo_order:
        if file_path in files:  # Only include files that actually exist
            priority, _ = get_file_priority(file_path)
            priority_groups[priority].append(file_path)

    # Combine groups in priority order
    result = []
    for priority in sorted(priority_groups.keys()):
        result.extend(priority_groups[priority])

    return result


def merge_lua_files(slim_dir: str,
                    output_file: str,
                    src_dir: str = "src",
                    skip_schema: bool = True) -> Tuple[bool, int]:
    """
    Merge all Lua files from slim directory in dependency order.
    Uses dynamic dependency analysis from src directory to determine optimal ordering.
    Returns (success, file_count)
    """

    if not os.path.exists(slim_dir):
        print(f"❌ Error: Slim directory '{slim_dir}' does not exist")
        return False, 0

    if not os.path.exists(src_dir):
        print(
            f"⚠️ Warning: Source directory '{src_dir}' does not exist - dependency analysis may be limited"
        )

    # Collect all Lua files
    print("📁 Collecting Lua files...")
    files = collect_all_lua_files(slim_dir, skip_schema)
    print(f"Found {len(files)} Lua files")

    if not files:
        print("❌ No Lua files found to merge")
        return False, 0

    # Sort files with dependency analysis
    print("\n🔀 Sorting files by dependencies...")
    sorted_files = sort_files_with_dependencies(files, slim_dir, src_dir)

    # Merge files
    merged_content = []
    processed_files = []

    print(f"\n🔨 Merging {len(sorted_files)} files...")
    for file_rel_path in sorted_files:
        if file_rel_path in files:
            file_path = files[file_rel_path]
            content = read_file_content(file_path)
            if content:
                merged_content.append(
                    get_file_section_comment(file_path, slim_dir))
                merged_content.append(content)
                merged_content.append("")  # Add blank line
                processed_files.append(file_rel_path)
                print(f"  ✓ {file_rel_path}")
            else:
                print(f"  ✗ {file_rel_path} (empty or unreadable)")

    # Write merged content to output file
    if merged_content:
        try:
            final_content = "\n".join(merged_content)

            # Add header comment
            header = f"""-- ================================================================
-- Formosa in Flames - Merged Scenario Script
-- Generated by build_lua_scenario.py with dynamic dependency analysis
-- Total files merged: {len(processed_files)}
-- ================================================================

"""
            final_content = header + final_content

            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(final_content)

            print(
                f"\n✅ Successfully merged {len(processed_files)} files into '{output_file}'"
            )
            print(f"📄 Output file size: {len(final_content):,} characters")

            return True, len(processed_files)

        except Exception as e:
            print(f"❌ Error writing output file: {e}")
            return False, 0
    else:
        print("❌ No content to merge")
        return False, 0


# =============================================================================
# MAIN BUILD FUNCTIONS
# =============================================================================


def build_scenario(args) -> bool:
    """
    Main build function that orchestrates cleaning and merging.
    """
    src_dir = args.src_dir
    slim_dir = args.slim_dir
    output_file = args.output

    print("🚀 Starting Lua scenario build process...")
    print(f"📂 Source directory: {src_dir}")
    print(f"📂 Slim directory: {slim_dir}")
    print(f"📄 Output file: {output_file}")
    print("=" * 70)

    total_success = True

    # Step 1: Clean (if requested)
    if args.clean or args.build:
        if not os.path.exists(src_dir):
            print(f"❌ Error: Source directory '{src_dir}' does not exist")
            return False

        # Remove existing slim directory if doing full build
        if args.build and os.path.exists(slim_dir):
            print(f"🗑️ Removing existing slim directory: {slim_dir}")
            shutil.rmtree(slim_dir)

        processed_count, error_count = clean_lua_files(src_dir, slim_dir)

        print(f"\n📊 Cleaning Results:")
        print(f"  ✅ Successfully processed: {processed_count} files")
        print(f"  ❌ Errors: {error_count} files")

        if error_count > 0:
            print("⚠️ Some files had errors during cleaning")
            total_success = False

    # Step 2: Merge (if requested)
    if args.merge or args.build:
        if not os.path.exists(slim_dir):
            print(
                f"❌ Error: Slim directory '{slim_dir}' does not exist. Run with --clean first."
            )
            return False

        print("\n" + "=" * 70)
        merge_success, merged_count = merge_lua_files(slim_dir, output_file,
                                                      src_dir,
                                                      not args.include_schema)

        print(f"\n📊 Merging Results:")
        print(f"  ✅ Files merged: {merged_count}")
        print(f"  📄 Output: {output_file}")

        if not merge_success:
            total_success = False

    print("\n" + "=" * 70)
    if total_success:
        print("🎉 Build completed successfully!")
        if args.build:
            print("📝 Full build process (clean + merge) completed")
        elif args.clean:
            print("🧹 Cleaning process completed")
        elif args.merge:
            print("🔨 Merging process completed")
    else:
        print("💥 Build completed with errors!")

    return total_success


def main():
    """Main execution function with argument parsing."""
    parser = argparse.ArgumentParser(
        description=
        "Build Lua Scenario - Clean and merge Lua files with dependency analysis",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python build_lua_scenario.py                    # Full build (clean + merge)
  python build_lua_scenario.py --clean-only       # Only clean files
  python build_lua_scenario.py --merge-only       # Only merge files
  python build_lua_scenario.py --output custom.lua # Custom output filename
        """)

    # Mode selection (mutually exclusive)
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument("--clean-only",
                            dest="clean",
                            action="store_true",
                            help="Only perform cleaning step (src -> slim)")
    mode_group.add_argument(
        "--merge-only",
        dest="merge",
        action="store_true",
        help="Only perform merging step (slim -> merged file)")

    # Default is full build
    parser.set_defaults(build=True)

    # Directory options
    parser.add_argument("--src-dir",
                        default="src",
                        help="Source directory (default: src)")
    parser.add_argument("--slim-dir",
                        default="slim",
                        help="Slim directory (default: slim)")

    # Output options
    parser.add_argument(
        "--output",
        default=None,
        help="Output filename (default: slim/main.lua)")
    parser.add_argument(
        "--include-schema",
        action="store_true",
        help="Include schema.lua in merge (default: skip schema)")

    args = parser.parse_args()

    # Handle mode logic
    if args.clean:
        args.build = False
        args.merge = False
    elif args.merge:
        args.build = False
        args.clean = False
    else:
        # Default full build
        args.build = True
        args.clean = True
        args.merge = True

    # Set default output path
    if args.output is None:
        args.output = os.path.join(args.slim_dir, "main.lua")

    # Run build process
    success = build_scenario(args)

    return 0 if success else 1


if __name__ == "__main__":
    exit(main())
