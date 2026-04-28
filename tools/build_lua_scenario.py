#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Build Lua Scenario - Combined Script for Processing and Merging Lua Files
Combines the functionality of clean_lua_scripts.py and merge_lua_scripts.py
into a unified build system with dependency-aware ordering.
"""

import argparse
import fnmatch
import os
import re
import shutil
from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Dict, List, Set, Tuple

LUA_BLOCK_COMMENT_PATTERN = re.compile(r"--\[\[.*?\]\]", flags=re.DOTALL)
LUA_RETURN_TABLE_PATTERN = re.compile(
    r"\s*return\s*\{\s*(?:[^}]*?)\s*\}\s*$", flags=re.DOTALL
)
LUA_RETURN_MODULE_PATTERN = re.compile(r"^return\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*$")
LUA_LOCAL_TABLE_PATTERN = re.compile(r"local\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*\{")
INIT_ACTION_NAME_PATTERN = re.compile(r'["\']([^"\']+)["\']')
INIT_SPECIAL_ACTION_PATTERN = re.compile(
    r'\{\s*path\s*=\s*["\']([^"\']+)["\']\s*,\s*actionName\s*=\s*["\']([^"\']+)["\']\s*\}\s*,?'
)


@dataclass(frozen=True)
class SpecialActionEntry:
    """Parsed init.lua special action definition."""

    path: str
    action_name: str


@dataclass(frozen=True)
class HtmlInjectionSpec:
    """HTML template injection target definition."""

    html_filename: str
    function_name: str
    placeholders: Tuple[str, ...] = ()


HTML_INJECTION_SPECS: Tuple[HtmlInjectionSpec, ...] = (
    HtmlInjectionSpec(
        html_filename="unit-status.html",
        function_name="getHTMLTemplate",
        placeholders=(
            "__INJECT_SIGNALS__",
            "__INJECT_LAUNCHERS__",
            "__INJECT_C2__",
            "__INJECT_BASE_WEAPONS__",
            "__INJECT_LANDING_UNITS__",
        ),
    ),
    HtmlInjectionSpec(
        html_filename="setup-menu.html",
        function_name="getSetupMenuTemplate",
        placeholders=(
            "__INJECT_JAMMERS__",
            "__INJECT_AIRBASES__",
            "__INJECT_MISSILE_SYSTEMS__",
            "__INJECT_SIDE_NAME__",
        ),
    ),
    HtmlInjectionSpec(
        html_filename="emcon-setting.html",
        function_name="getWCSSettingTemplate",
    ),
)

MERGE_INCLUDE_DIRS: Tuple[str, ...] = ("core", "utils", "modules")
PRIORITY_FILES: Dict[str, int] = {
    "core/gKH_State_Standalone.lua": 0,
    "core/constants.lua": 1,
    "core/config.lua": 2,
    "core/saveData.lua": 3,
}


def read_text_file(file_path: str) -> str:
    """Read and return UTF-8 text content from a file."""
    with open(file_path, "r", encoding="utf-8") as file:
        return file.read()


def write_text_file(file_path: str, content: str) -> None:
    """Write UTF-8 text content to a file."""
    with open(file_path, "w", encoding="utf-8") as file:
        file.write(content)


def ensure_directory(path: str) -> None:
    """Create a directory if it does not already exist."""
    os.makedirs(path, exist_ok=True)


def collapse_extra_blank_lines(content: str) -> str:
    """Collapse runs of blank lines to at most two lines."""
    return re.sub(r"\n\s*\n\s*\n", "\n\n", content)


def trim_leading_blank_lines(content: str) -> str:
    """Remove blank lines at the start of content."""
    return re.sub(r"^\s*\n", "", content)


def trim_trailing_blank_lines(content: str) -> str:
    """Reduce trailing blank lines to a single newline."""
    return re.sub(r"(\n\s*){3,}$", "\n", content)


def remove_lua_block_comments(content: str) -> str:
    """Remove Lua block comments from content."""
    return LUA_BLOCK_COMMENT_PATTERN.sub("", content)


def strip_require_and_comments(lines: List[str]) -> List[str]:
    """Remove comment lines, require lines, and inline comments."""
    filtered_lines: List[str] = []

    for line in lines:
        stripped_line = line.strip()

        if stripped_line.startswith("--"):
            continue

        if not stripped_line:
            filtered_lines.append(line)
            continue

        line_without_comments = stripped_line.split("--")[0].strip()
        is_require_line = "require(" in line_without_comments

        if is_require_line:
            continue

        if "--" in line:
            code_part = line.split("--")[0].rstrip()
            if code_part:
                filtered_lines.append(code_part)
        else:
            filtered_lines.append(line)

    return filtered_lines


def normalize_processed_content(content: str) -> str:
    """Normalize blank lines after content transformations."""
    content = collapse_extra_blank_lines(content)
    content = trim_leading_blank_lines(content)
    return content.strip()


def remove_module_return_table(content: str) -> str:
    """Remove a trailing module-level return table statement."""
    return LUA_RETURN_TABLE_PATTERN.sub("", content)


def remove_trailing_module_return(lines: List[str]) -> Tuple[List[str], str | None]:
    """Remove trailing return ModuleName and return the module name if found."""
    updated_lines = list(lines)
    module_name = None

    i = len(updated_lines) - 1
    while i >= 0:
        line = updated_lines[i].strip()
        if not line or line.startswith("--"):
            i -= 1
            continue

        match = LUA_RETURN_MODULE_PATTERN.match(line)
        if match and "{" not in line:
            module_name = match.group(1)
            updated_lines[i] = ""

            j = i + 1
            while j < len(updated_lines):
                next_line = updated_lines[j].strip()
                if not next_line or next_line.startswith("--"):
                    updated_lines[j] = ""
                else:
                    break
                j += 1
        break

    return updated_lines, module_name


def find_local_table_declarations(lines: List[str]) -> List[str]:
    """Find local table declarations in Lua content."""
    local_tables: List[str] = []
    for line in lines:
        match = LUA_LOCAL_TABLE_PATTERN.search(line)
        if match:
            local_tables.append(match.group(1))
    return local_tables


def count_table_functions(lines: List[str], table_name: str) -> int:
    """Count function declarations attached to a table."""
    pattern = re.compile(r"^function\s+" + re.escape(table_name) + r"\.")
    return sum(1 for line in lines if pattern.match(line.strip()))


def detect_main_module_table(lines: List[str], local_tables: List[str]) -> str | None:
    """Find the most likely primary module table based on method count."""
    main_module_table = None
    max_functions = 0

    for table_name in local_tables:
        count = count_table_functions(lines, table_name)
        if count > max_functions and count > 0:
            max_functions = count
            main_module_table = table_name

    return main_module_table


def promote_local_table_to_global(lines: List[str], table_name: str) -> List[str]:
    """Remove local from a table initialization so merged output can access it globally."""
    updated_lines = list(lines)

    try:
        pattern = re.compile(r"^(\s*)local(\s+" + re.escape(table_name) + r".*)$")
        for index, line in enumerate(updated_lines):
            match_local_decl = pattern.match(line)
            if match_local_decl and re.search(r"=\s*\{", line):
                updated_lines[index] = match_local_decl.group(
                    1
                ) + match_local_decl.group(2)
                break
    except re.error as error:
        print(f"Skipping module rename for '{table_name}' due to regex error: {error}")

    return updated_lines


# =============================================================================
# CLEANING FUNCTIONS (from clean_lua_scripts.py)
# =============================================================================


def process_lua_content(content: str) -> str:
    """
    Process Lua content:
    1. Remove require statements.
    2. Remove ALL comments (including LuaLS annotations and block comments).
    3. Remove module-level return {} or return ModuleName.
    4. If return ModuleName is removed, change 'local ModuleName = {}' to 'ModuleName = {}'.
    """
    content = remove_lua_block_comments(content)
    content = "\n".join(strip_require_and_comments(content.splitlines()))
    content = normalize_processed_content(content)
    content = remove_module_return_table(content)

    lines, module_name = remove_trailing_module_return(content.splitlines())
    local_tables = find_local_table_declarations(lines)
    main_module_table = detect_main_module_table(lines, local_tables)

    if main_module_table and len(local_tables) > 1:
        lines = promote_local_table_to_global(lines, main_module_table)

    if module_name:
        lines = promote_local_table_to_global(lines, module_name)

    content = "\n".join(lines)
    content = collapse_extra_blank_lines(content)
    content = trim_trailing_blank_lines(content)

    return content.strip()


def clean_lua_files(src_dir: str, slim_dir: str) -> Tuple[int, int]:
    """
    Clean Lua files from src directory to slim directory.
    Returns (processed_count, error_count)
    """
    ensure_directory(slim_dir)

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
                ensure_directory(output_dir)

                try:
                    content = read_text_file(input_file_path)

                    # Count require statements before processing
                    require_count_before = len(
                        [
                            line
                            for line in content.splitlines()
                            if "require" in line and not line.strip().startswith("--")
                        ]
                    )

                    processed_content = process_lua_content(content)

                    # Special handling for unitStatusUI.lua to inject HTML templates
                    if file_name == "unitStatusUI.lua":
                        processed_content = inject_html_templates(
                            processed_content, src_dir
                        )

                    # Count require statements after processing
                    require_count_after = len(
                        [
                            line
                            for line in processed_content.splitlines()
                            if "require" in line and not line.strip().startswith("--")
                        ]
                    )

                    write_text_file(output_file_path, processed_content)

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

            # Step 1: Load all processed event scripts
            scripts_mapping = load_scripts_mapping(slim_dir)

            # Read current init.lua content
            init_content = read_text_file(init_lua_path)

            # Step 2: Inject event scripts into initEventActions
            modified_init_content = inject_scripts_into_init(
                init_content, scripts_mapping
            )

            # Step 3: Load all processed special action scripts
            special_actions_mapping = load_special_actions_mapping(slim_dir)

            # Step 4: Inject special action scripts into initSpecialActions
            modified_init_content = inject_special_actions_into_init(
                modified_init_content, special_actions_mapping
            )

            # Write back to init.lua
            write_text_file(init_lua_path, modified_init_content)

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

    # Helper to inject local JS files into HTML
    def inject_local_js_into_html(html_content: str, html_dir: str) -> str:
        """
        Find and inject local JS file contents into HTML.
        Replaces <script src="localfile.js"></script> with <script>content</script>
        Removes JS comments to avoid Lua parsing conflicts.
        """
        # Pattern to match <script src="..."></script> tags
        script_pattern = r'<script\s+src="([^"]+)"\s*></script>'

        def remove_js_comments(js_code: str) -> str:
            """
            Remove JavaScript comments to avoid Lua parsing conflicts.
            Keeps code structure intact by preserving newlines.
            """
            result = []
            i = 0
            length = len(js_code)
            in_string = False
            string_char = None

            while i < length:
                # Handle escape sequences in strings
                if in_string and js_code[i] == "\\" and i + 1 < length:
                    result.append(js_code[i])  # backslash
                    result.append(js_code[i + 1])  # escaped character
                    i += 2
                    continue

                # Handle strings
                if not in_string and js_code[i] in ('"', "'", "`"):
                    in_string = True
                    string_char = js_code[i]
                    result.append(js_code[i])
                    i += 1
                    continue
                elif in_string and js_code[i] == string_char:
                    result.append(js_code[i])
                    in_string = False
                    string_char = None
                    i += 1
                    continue
                elif in_string:
                    result.append(js_code[i])
                    i += 1
                    continue

                # Handle multi-line comments /* ... */
                if i < length - 1 and js_code[i : i + 2] == "/*":
                    # Find the end of comment
                    j = i + 2
                    while j < length - 1:
                        if js_code[j : j + 2] == "*/":
                            # Count newlines in comment to preserve line numbers
                            comment_text = js_code[i : j + 2]
                            newline_count = comment_text.count("\n")
                            result.append("\n" * newline_count)
                            i = j + 2
                            break
                        j += 1
                    else:
                        # Unclosed comment, skip to end
                        i = length
                    continue

                # Handle single-line comments //
                if i < length - 1 and js_code[i : i + 2] == "//":
                    # Skip until end of line
                    while i < length and js_code[i] != "\n":
                        i += 1
                    # Keep the newline
                    if i < length:
                        result.append("\n")
                        i += 1
                    continue

                # Normal character
                result.append(js_code[i])
                i += 1

            return "".join(result)

        def replace_script(match):
            src = match.group(1)

            # Skip external URLs (http://, https://, //)
            if src.startswith(("http://", "https://", "//")):
                return match.group(0)  # Keep original tag

            # Try to find the local JS file
            js_path = os.path.join(html_dir, src)
            if os.path.exists(js_path):
                try:
                    js_content = read_text_file(js_path)

                    # Remove JS comments to avoid Lua parsing issues
                    js_content = remove_js_comments(js_content)

                    print(f"    ✓ Injected {src} into HTML (comments removed)")
                    return f"<script>\n{js_content}\n  </script>"
                except Exception as e:
                    print(f"    ✗ Error reading {src}: {e}")
                    return match.group(0)
            else:
                print(f"    ⚠️ Local JS file not found: {js_path}")
                return match.group(0)

        return re.sub(script_pattern, replace_script, html_content)

    # Helper to process and inject
    def process_and_inject(spec: HtmlInjectionSpec, lua_content: str):
        html_path = os.path.join(html_dir, spec.html_filename)
        if os.path.exists(html_path):
            try:
                html_content = read_text_file(html_path)

                # Inject local JS files into HTML before processing
                html_content = inject_local_js_into_html(html_content, html_dir)

                # Escape % to %% but keep %s as %s
                # 1. Replace all % with %%
                html_content = html_content.replace("%", "%%")
                # 2. Replace %%s back to %s (restore placeholders)
                html_content = html_content.replace("%%s", "%s")

                html_content = replace_html_placeholders(
                    html_content, spec.placeholders
                )

                # Determine the required long string level to avoid conflicts
                opening_bracket, closing_bracket, level = build_lua_long_string(
                    html_content
                )

                # Regex to find and replace the function's return statement
                # Match: local function functionName() return [=*[ ... ]=*]
                pattern = (
                    r"(local function "
                    + re.escape(spec.function_name)
                    + r"\(\)\s*return )\[=*\[.*?\]=*\]"
                )

                new_content = re.sub(
                    pattern,
                    lambda m: (
                        m.group(1)
                        + opening_bracket
                        + "\n"
                        + html_content
                        + "\n"
                        + closing_bracket
                    ),
                    lua_content,
                    flags=re.DOTALL,
                )

                if new_content != lua_content:
                    print(
                        f"    ✓ Injected {spec.html_filename} into {spec.function_name} (long string level: {level})"
                    )
                    return new_content
                else:
                    print(
                        f"    ⚠️ Could not find function {spec.function_name} to inject {spec.html_filename}"
                    )
                    return lua_content

            except Exception as e:
                print(f"    ✗ Error injecting {spec.html_filename}: {e}")
                return lua_content
        else:
            print(f"    ⚠️ HTML file not found: {html_path}")
            return lua_content

    for spec in HTML_INJECTION_SPECS:
        content = process_and_inject(spec, content)

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
                    content = read_text_file(script_path)
                    scripts_mapping[action_name] = content
                    print(f"  ✓ Loaded {action_name}")
                except Exception as e:
                    print(f"  ✗ Error loading {action_name}: {e}")

    print(f"📊 Total scripts loaded: {len(scripts_mapping)}")
    return scripts_mapping


def load_special_actions_mapping(slim_dir: str) -> Dict[str, str]:
    """
    Load all processed special action script files from slim/scripts/*/specialActions directories.
    Returns a mapping of {relative_path -> script_content}
    Example: {"scripts\\china\\specialActions\\addACs.lua" -> "actual code"}
    """
    special_actions_mapping = {}

    # Define the special actions directories to scan
    special_actions_dirs = [
        os.path.join(slim_dir, "scripts", "china", "specialActions"),
        os.path.join(slim_dir, "scripts", "taiwan", "specialActions"),
    ]

    print("📜 Loading special action script files...")

    for special_dir in special_actions_dirs:
        if not os.path.exists(special_dir):
            print(
                f"⚠️ Warning: Special actions directory '{special_dir}' does not exist"
            )
            continue

        for file_name in os.listdir(special_dir):
            if file_name.endswith(".lua"):
                script_path = os.path.join(special_dir, file_name)
                # Get relative path from slim_dir (e.g., "scripts/china/specialActions/addACs.lua")
                relative_path = os.path.relpath(script_path, slim_dir)
                # Normalize path separators to backslashes (Windows style) to match paths in init.lua
                action_path = relative_path.replace(os.sep, "\\")

                try:
                    content = read_text_file(script_path)
                    special_actions_mapping[action_path] = content
                    print(f"  ✓ Loaded {action_path}")
                except Exception as e:
                    print(f"  ✗ Error loading {action_path}: {e}")

    print(f"📊 Total special action scripts loaded: {len(special_actions_mapping)}")
    return special_actions_mapping


def get_long_string_level(content: str) -> int:
    """
    Determine the required level for Lua long string brackets.
    Returns the minimum number of '=' needed to avoid conflicts.
    Example: level 0 -> [[ ... ]], level 1 -> [=[ ... ]=], etc.
    """
    level = 0
    while level <= 10:  # Safety limit
        # Check if the current level's closing bracket exists in content
        closing = "]" + ("=" * level) + "]"
        if closing not in content:
            return level
        level += 1
    return 10  # Fallback to level 10


def strip_script_for_injection(script_content: str) -> str:
    """Remove empty lines and comment lines before injecting Lua script content."""
    processed_lines: List[str] = []

    for script_line in script_content.splitlines():
        stripped = script_line.rstrip()
        stripped_left = stripped.lstrip()

        if not stripped or stripped_left.startswith("--"):
            continue

        processed_lines.append(script_line + " ")

    return "\n".join(processed_lines)


def comment_out_expanded_loop(
    lines: List[str], start_index: int, indent_str: str
) -> Tuple[List[str], int]:
    """Comment out the original loop body and return the next index after the loop."""
    result_lines: List[str] = []
    index = start_index
    loop_depth = 1

    while index < len(lines) and loop_depth > 0:
        curr_line = lines[index].strip()
        if (
            curr_line.startswith("for ")
            or curr_line.startswith("if ")
            or curr_line.startswith("function ")
        ):
            loop_depth += 1
        elif curr_line == "end" or curr_line.startswith("end "):
            loop_depth -= 1
            if loop_depth == 0:
                result_lines.append(
                    indent_str + "-- " + curr_line + " -- End of expanded loop"
                )
                index += 1
                break

        if lines[index].strip() and not lines[index].strip().startswith("--"):
            result_lines.append(indent_str + "-- " + lines[index].strip())
        else:
            result_lines.append(lines[index])
        index += 1

    return result_lines, index


def build_lua_long_string(content: str) -> Tuple[str, str, int]:
    """Build Lua long string delimiters that do not conflict with content."""
    level = get_long_string_level(content)
    equals = "=" * level
    return f"[{equals}[", f"]{equals}]", level


def parse_init_action_names(init_content: str) -> List[str]:
    """Parse actionNames entries from init.lua."""
    action_names: List[str] = []
    in_action_names = False

    for line in init_content.split("\n"):
        if "local actionNames = {" in line:
            in_action_names = True
            continue
        if in_action_names:
            if "}" in line and not line.strip().startswith("--"):
                break
            match = INIT_ACTION_NAME_PATTERN.search(line)
            if match:
                action_name = match.group(1).replace("\\\\", "\\")
                action_names.append(action_name)

    return action_names


def parse_init_special_actions(init_content: str) -> List[SpecialActionEntry]:
    """Parse special action entries from init.lua."""
    actions: List[SpecialActionEntry] = []
    in_actions_table = False

    for line in init_content.split("\n"):
        if "local actions = {" in line:
            in_actions_table = True
            continue
        if in_actions_table:
            if "}" in line and not line.strip().startswith("--") and "{" not in line:
                break
            match = INIT_SPECIAL_ACTION_PATTERN.search(line)
            if match:
                actions.append(
                    SpecialActionEntry(
                        path=match.group(1).replace("\\\\", "\\"),
                        action_name=match.group(2),
                    )
                )

    return actions


def render_event_action_update(
    indent_str: str, action_name: str, script_content: str | None
) -> str:
    """Render a ScenEdit_SetAction update statement."""
    escaped_action_name = action_name.replace("\\", "\\\\")
    if script_content is None:
        return (
            f"{indent_str}GameApi.ScenEdit_SetAction({{ mode = 'update', type = 'LuaScript', "
            f'name = "{escaped_action_name}", ScriptText = [[]] }})'
        )

    processed_content = strip_script_for_injection(script_content)
    opening_bracket, closing_bracket, _ = build_lua_long_string(processed_content)
    return (
        f"{indent_str}GameApi.ScenEdit_SetAction({{ mode = 'update', type = 'LuaScript', "
        f'name = "{escaped_action_name}", ScriptText = {opening_bracket}\n'
        f"{processed_content}\n"
        f"{closing_bracket} }})"
    )


def normalize_special_action_script_path(path: str) -> str:
    """Normalize special action source path to the processed slim/scripts layout."""
    if path.startswith("src\\"):
        return path[4:]
    return path


def extract_side_name(script_path: str) -> str:
    """Extract side name from scripts\\<side>\\... path."""
    match = re.search(r"scripts\\([^\\]+)\\", script_path)
    if match:
        return match.group(1)
    return "Unknown"


def render_special_action_update(
    indent_str: str, action: SpecialActionEntry, script_content: str | None
) -> List[str]:
    """Render add/update code for a special action entry."""
    script_path = normalize_special_action_script_path(action.path)
    side_name = extract_side_name(script_path)
    escaped_action_name = action.action_name.replace('"', '\\"')

    lines = [
        f'{indent_str}local actionEntry = GameApi.ScenEdit_GetSpecialAction({{ side = "{side_name}", ActionNameOrID = "{escaped_action_name}" }})',
        f"{indent_str}if not actionEntry then",
    ]

    if script_content is None:
        lines.append(
            f'{indent_str}  GameApi.ScenEdit_AddSpecialAction({{ ActionNameOrID = "{escaped_action_name}", side = "{side_name}", ScriptText = [[]] }})'
        )
        lines.append(f"{indent_str}else")
        lines.append(
            f'{indent_str}  GameApi.ScenEdit_SetSpecialAction({{ mode = \'update\', ActionNameOrID = "{escaped_action_name}", side = "{side_name}", ScriptText = [[]] }})'
        )
        lines.append(f"{indent_str}end")
        return lines

    processed_content = strip_script_for_injection(script_content)
    opening_bracket, closing_bracket, _ = build_lua_long_string(processed_content)
    lines.append(
        f'{indent_str}  GameApi.ScenEdit_AddSpecialAction({{IsRepeatable = true, ActionNameOrID = "{escaped_action_name}", side = "{side_name}", ScriptText = {opening_bracket}\n{processed_content}\n{closing_bracket} }})'
    )
    lines.append(f"{indent_str}else")
    lines.append(
        f'{indent_str}  GameApi.ScenEdit_SetSpecialAction({{ mode = \'update\', ActionNameOrID = "{escaped_action_name}", side = "{side_name}", ScriptText = {opening_bracket}\n{processed_content}\n{closing_bracket} }})'
    )
    lines.append(f"{indent_str}end")
    return lines


def replace_html_placeholders(
    html_content: str, placeholder_names: Tuple[str, ...]
) -> str:
    """Replace injected HTML data payloads with %s placeholders."""
    for placeholder_name in placeholder_names:
        pattern = r"window\." + re.escape(placeholder_name) + r"\s*=\s*`[^`]*`;"
        replacement = f"window.{placeholder_name} = `%s`;"
        html_content = re.sub(pattern, replacement, html_content, flags=re.DOTALL)
    return html_content


def normalize_rel_path(path: str) -> str:
    """Normalize relative paths to forward-slash style."""
    return path.replace("\\", "/")


def iter_lua_files(root_dir: str) -> List[str]:
    """Collect all Lua file paths under a directory."""
    lua_files: List[str] = []
    for root, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith(".lua"):
                lua_files.append(os.path.join(root, filename))
    return lua_files


def is_schema_file(filename: str) -> bool:
    """Return whether a filename is schema.lua."""
    return filename == "schema.lua"


def group_files_by_priority(file_paths: List[str]) -> Dict[int, List[str]]:
    """Group file paths by merge priority while preserving input order."""
    priority_groups: Dict[int, List[str]] = defaultdict(list)
    for file_path in file_paths:
        priority, _ = get_file_priority(file_path)
        priority_groups[priority].append(file_path)
    return priority_groups


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
    action_names = parse_init_action_names(init_content)
    lines = init_content.split("\n")

    print(f"📋 Found {len(action_names)} action names in init.lua")

    # Now replace the entire for loop with expanded ScenEdit_SetAction calls
    result_lines = []
    i = 0
    injected_count = 0

    while i < len(lines):
        line = lines[i]

        # Detect start of for loop
        if "for _, name in ipairs(actionNames) do" in line:
            # Get the indentation of the for loop
            indent = len(line) - len(line.lstrip())
            indent_str = " " * indent

            # Skip the for loop and its content until 'end'
            result_lines.append(line)  # Keep the for loop line commented out
            result_lines[-1] = indent_str + "-- " + line.strip() + " -- Expanded below"
            i += 1

            commented_loop_lines, i = comment_out_expanded_loop(lines, i, indent_str)
            result_lines.extend(commented_loop_lines)

            # Now inject the expanded code
            for action_name in action_names:
                if action_name in scripts_mapping:
                    script_content = scripts_mapping[action_name]
                    result_lines.append(
                        render_event_action_update(
                            indent_str, action_name, script_content
                        )
                    )
                    injected_count += 1
                    _, _, level = build_lua_long_string(
                        strip_script_for_injection(script_content)
                    )
                    print(f"  ✓ Injected {action_name} (long string level: {level})")
                else:
                    result_lines.append(
                        render_event_action_update(indent_str, action_name, None)
                    )
                    print(f"  ⚠️ Script not found for action: {action_name}")

            # After injecting scripts, i now points to the line after 'for loop's end'
            # which is initEventActions' end. We need to continue processing from there.
            # Decrement i so that the outer loop's i += 1 will process the current line
            i -= 1

        else:
            result_lines.append(line)

        i += 1

    print(f"📊 Total scripts injected: {injected_count}/{len(action_names)}")

    return "\n".join(result_lines)


def inject_special_actions_into_init(
    init_content: str, special_actions_mapping: Dict[str, str]
) -> str:
    """
    Inject special action script contents into init.lua's initSpecialActions function.
    Expands the for loop and replaces each ScriptText = [[]] with actual content
    """
    if not special_actions_mapping:
        print("⚠️ No special action scripts to inject")
        return init_content

    print("💉 Injecting special action scripts into init.lua...")

    # Parse actions table and extract all action entries
    actions = parse_init_special_actions(init_content)
    lines = init_content.split("\n")

    print(f"📋 Found {len(actions)} special actions in init.lua")

    # Now replace the entire for loop with expanded ScenEdit_SetSpecialAction calls
    result_lines = []
    i = 0
    injected_count = 0

    while i < len(lines):
        line = lines[i]

        # Detect start of for loop for special actions
        if "for _, action in ipairs(actions) do" in line:
            # Get the indentation of the for loop
            indent = len(line) - len(line.lstrip())
            indent_str = " " * indent

            # Skip the for loop and its content until 'end'
            result_lines.append(line)  # Keep the for loop line commented out
            result_lines[-1] = indent_str + "-- " + line.strip() + " -- Expanded below"
            i += 1

            commented_loop_lines, i = comment_out_expanded_loop(lines, i, indent_str)
            result_lines.extend(commented_loop_lines)

            # Now inject the expanded code
            for action_entry in actions:
                script_path = normalize_special_action_script_path(action_entry.path)
                if script_path in special_actions_mapping:
                    script_content = special_actions_mapping[script_path]
                    result_lines.extend(
                        render_special_action_update(
                            indent_str, action_entry, script_content
                        )
                    )
                    injected_count += 1
                    _, _, level = build_lua_long_string(
                        strip_script_for_injection(script_content)
                    )
                    print(
                        f"  ✓ Injected {script_path} (side: {extract_side_name(script_path)}, action: {action_entry.action_name}, level: {level})"
                    )
                else:
                    result_lines.extend(
                        render_special_action_update(indent_str, action_entry, None)
                    )
                    print(f"  ⚠️ Script not found for special action: {script_path}")

            # After injecting scripts, i now points to the line after 'for loop's end'
            # Decrement i so that the outer loop's i += 1 will process the current line
            i -= 1

        else:
            result_lines.append(line)

        i += 1

    print(f"📊 Total special action scripts injected: {injected_count}/{len(actions)}")

    return "\n".join(result_lines)


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
        content = read_text_file(file_path).strip()
        return content
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
        return ""


def analyze_file_dependencies(
    file_path: str, slim_dir: str, src_dir: str = "src"
) -> Set[str]:
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
        content = read_text_file(src_file_path)

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
        print(f"Warning: Could not analyze dependencies for {src_file_path}: {e}")

    return dependencies


def normalize_require_path(require_path: str, slim_dir: str) -> str | None:
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


def collect_all_lua_files(slim_dir: str, skip_schema: bool = True) -> Dict[str, str]:
    """
    Collect all Lua files from slim directory (excluding scripts and optionally schema).
    Returns dict of {relative_path: full_path}
    """
    files = {}

    for dir_name in MERGE_INCLUDE_DIRS:
        dir_path = os.path.join(slim_dir, dir_name)
        if os.path.exists(dir_path):
            for full_path in iter_lua_files(dir_path):
                filename = os.path.basename(full_path)
                if skip_schema and is_schema_file(filename):
                    continue

                rel_path = normalize_rel_path(os.path.relpath(full_path, slim_dir))
                files[rel_path] = full_path

    return files


def should_exclude_file(rel_path: str, exclude_patterns: List[str]) -> bool:
    """Return whether a relative file path should be excluded from merge."""
    if not exclude_patterns:
        return False

    normalized_path = normalize_rel_path(rel_path)
    return any(fnmatch.fnmatch(normalized_path, pattern) for pattern in exclude_patterns)


def normalize_exclude_pattern(pattern: str) -> str:
    """Normalize exclude pattern to merge-relative path style."""
    normalized = normalize_rel_path(pattern).lstrip("./")
    if normalized.startswith("src/"):
        normalized = normalized[4:]
    elif normalized.startswith("slim/"):
        normalized = normalized[5:]
    return normalized


def build_dependency_graph(
    files: Dict[str, str], slim_dir: str, src_dir: str = "src"
) -> Dict[str, Set[str]]:
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
            print(f"  {rel_path} depends on: {', '.join(sorted(valid_dependencies))}")
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
    if file_path in PRIORITY_FILES:
        return (PRIORITY_FILES[file_path], file_path)

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


def sort_files_with_dependencies(
    files: Dict[str, str], slim_dir: str, src_dir: str = "src"
) -> List[str]:
    """
    Sort files considering both fixed priorities and dynamic dependencies.
    """
    # Build dependency graph
    dependency_graph = build_dependency_graph(files, slim_dir, src_dir)

    # Get topological order
    topo_order = topological_sort(dependency_graph)
    existing_topo_order = [file_path for file_path in topo_order if file_path in files]
    priority_groups = group_files_by_priority(existing_topo_order)

    # Combine groups in priority order
    result = []
    for priority in sorted(priority_groups.keys()):
        result.extend(priority_groups[priority])

    return result


def merge_lua_files(
    slim_dir: str,
    output_file: str,
    src_dir: str = "src",
    skip_schema: bool = True,
    exclude_patterns: List[str] | None = None,
) -> Tuple[bool, int]:
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

    normalized_patterns = [
        normalize_exclude_pattern(pattern) for pattern in (exclude_patterns or [])
    ]
    excluded_paths = [
        rel_path
        for rel_path in sorted(files.keys())
        if should_exclude_file(rel_path, normalized_patterns)
    ]
    for rel_path in excluded_paths:
        del files[rel_path]

    if normalized_patterns:
        print(
            "🚫 Exclude patterns: "
            + ", ".join(normalized_patterns)
        )
        print(f"🚫 Excluded files: {len(excluded_paths)}")
        for rel_path in excluded_paths:
            print(f"  - {rel_path}")

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
        file_path = files[file_rel_path]
        content = read_file_content(file_path)
        if content:
            merged_content.append(get_file_section_comment(file_path, slim_dir))
            # Wrap each module in do...end to scope local variables,
            # avoiding the Lua 200 local variable limit per chunk.
            # Global module tables (e.g., GameApi = {}) remain accessible
            # across modules since they are assigned to global scope.
            merged_content.append("do")
            merged_content.append(content)
            merged_content.append("end")
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

            write_text_file(output_file, final_content)

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

        print("\n📊 Cleaning Results:")
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
        merge_success, merged_count = merge_lua_files(
            slim_dir,
            output_file,
            src_dir,
            not args.include_schema,
            args.exclude,
        )

        print("\n📊 Merging Results:")
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
        description="Build Lua Scenario - Clean and merge Lua files with dependency analysis",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python build_lua_scenario.py                    # Full build (clean + merge)
  python build_lua_scenario.py --clean-only       # Only clean files
  python build_lua_scenario.py --merge-only       # Only merge files
  python build_lua_scenario.py --output custom.lua # Custom output filename
  python build_lua_scenario.py --exclude "modules/debug.lua"
  python build_lua_scenario.py --exclude "modules/test/*.lua" --exclude "utils/tmp.lua"
        """,
    )

    # Mode selection (mutually exclusive)
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--clean-only",
        dest="clean",
        action="store_true",
        help="Only perform cleaning step (src -> slim)",
    )
    mode_group.add_argument(
        "--merge-only",
        dest="merge",
        action="store_true",
        help="Only perform merging step (slim -> merged file)",
    )

    # Default is full build
    parser.set_defaults(build=True)

    # Directory options
    parser.add_argument(
        "--src-dir", default="src", help="Source directory (default: src)"
    )
    parser.add_argument(
        "--slim-dir", default="slim", help="Slim directory (default: slim)"
    )

    # Output options
    parser.add_argument(
        "--output", default=None, help="Output filename (default: slim/main.lua)"
    )
    parser.add_argument(
        "--include-schema",
        action="store_true",
        help="Include schema.lua in merge (default: skip schema)",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help=(
            "Exclude Lua files from merge by relative path or glob pattern. "
            "Example: --exclude 'modules/debug.lua' --exclude 'modules/test/*.lua'"
        ),
    )

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
