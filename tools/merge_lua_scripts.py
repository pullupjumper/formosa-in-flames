#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Merge Lua Scripts with Dynamic Dependency-Aware Ordering
Based on clean_lua_scripts.py, this script merges processed Lua files from the slim directory
into a single deployment-ready Lua file, dynamically analyzing require() statements to determine order.
"""

import os
import re
from typing import List, Dict, Set, Tuple
from collections import defaultdict, deque

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

def analyze_file_dependencies(file_path: str, slim_dir: str, src_dir: str = "src") -> Set[str]:
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
        print(f"Warning: Could not analyze dependencies for {src_file_path}: {e}")
    
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

def collect_all_lua_files(slim_dir: str) -> Dict[str, str]:
    """
    Collect all Lua files from slim directory (excluding scripts and schema).
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
                        # Skip schema.lua
                        if filename == 'schema.lua':
                            continue
                        
                        full_path = os.path.join(root, filename)
                        rel_path = os.path.relpath(full_path, slim_dir)
                        rel_path = rel_path.replace('\\', '/')  # Normalize separators
                        files[rel_path] = full_path
    
    return files

def build_dependency_graph(files: Dict[str, str], slim_dir: str, src_dir: str = "src") -> Dict[str, Set[str]]:
    """
    Build dependency graph by analyzing require statements in src files.
    Returns dict of {file_path: set_of_dependencies}
    """
    dependency_graph = {}
    
    print("Analyzing file dependencies...")
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
        print(f"Warning: Circular dependencies detected in: {remaining}")
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

def sort_files_with_dependencies(files: Dict[str, str], slim_dir: str, src_dir: str = "src") -> List[str]:
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


def merge_lua_files(slim_dir: str, output_file: str = "merged_scenario.lua", src_dir: str = "src") -> bool:
    """
    Merge all Lua files from slim directory in dependency order.
    Uses dynamic dependency analysis from src directory to determine optimal ordering.
    """
    
    if not os.path.exists(slim_dir):
        print(f"Error: Slim directory '{slim_dir}' does not exist")
        return False
    
    if not os.path.exists(src_dir):
        print(f"Warning: Source directory '{src_dir}' does not exist - dependency analysis may be limited")
    
    # Collect all Lua files
    print("Collecting Lua files...")
    files = collect_all_lua_files(slim_dir)
    print(f"Found {len(files)} Lua files")
    
    # Sort files with dependency analysis
    print("\nSorting files by dependencies...")
    sorted_files = sort_files_with_dependencies(files, slim_dir, src_dir)
    
    # Merge files
    merged_content = []
    processed_files = []
    
    print(f"\nMerging {len(sorted_files)} files...")
    for file_rel_path in sorted_files:
        if file_rel_path in files:
            file_path = files[file_rel_path]
            content = read_file_content(file_path)
            if content:
                merged_content.append(get_file_section_comment(file_path, slim_dir))
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
-- Generated by merge_lua_scripts.py with dynamic dependency analysis
-- Total files merged: {len(processed_files)}
-- ================================================================

"""
            final_content = header + final_content
            
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(final_content)
            
            print(f"\n✅ Successfully merged {len(processed_files)} files into '{output_file}'")
            print(f"📄 Output file size: {len(final_content):,} characters")
            
            # Print final order for verification
            print(f"\n📋 Final merge order:")
            for i, file_path in enumerate(processed_files, 1):
                print(f"  {i:2d}. {file_path}")
            
            return True
            
        except Exception as e:
            print(f"❌ Error writing output file: {e}")
            return False
    else:
        print("❌ No content to merge")
        return False

def main():
    """Main execution function."""
    slim_dir = "slim"
    output_file = os.path.join(slim_dir, "merged_scenario.lua")
    
    print("🚀 Starting Lua script merging with dynamic dependency analysis...")
    print(f"📂 Source directory: {slim_dir}")
    print(f"📄 Output file: {output_file}")
    print("="*70)
    
    success = merge_lua_files(slim_dir, output_file)
    
    print("="*70)
    if success:
        print("🎉 Lua script merging completed successfully!")
        print("📝 Dependencies were analyzed dynamically - no manual updates needed for new files!")
    else:
        print("💥 Lua script merging failed!")
    
    return success

if __name__ == "__main__":
    main()