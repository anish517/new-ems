import os
import re

files_info = [
    (r"lib\features\attendance\screens\attendance_screen.dart", "_loadAll()", "../../../core/providers/date_provider.dart"),
    (r"lib\features\leave\screens\leave_screen.dart", "_loadLeaves()", "../../../core/providers/date_provider.dart"),
    (r"lib\features\salary\screens\salary_screen.dart", "_loadData()", "../../../core/providers/date_provider.dart"),
    (r"lib\features\tasks\screens\tasks_screen.dart", "_loadTasks()", "../../../core/providers/date_provider.dart"),
    (r"lib\features\performance\screens\performance_screen.dart", "_loadData()", "../../../core/providers/date_provider.dart"),
    (r"lib\features\noticeboard\screens\noticeboard_screen.dart", "_loadNotices()", "../../../core/providers/date_provider.dart"),
    (r"lib\features\feedback\screens\feedback_screen.dart", "_loadFeedback()", "../../../core/providers/date_provider.dart"),
]

for file_path, load_func, import_path in files_info:
    full_path = os.path.join(r"f:\emp\ems-full-stack\frontend", file_path)
    if not os.path.exists(full_path):
        continue
    
    with open(full_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if import_path not in content:
        # Add import after the last import statement
        lines = content.split('\n')
        last_import = 0
        for i, line in enumerate(lines):
            if line.startswith('import '):
                last_import = i
        
        lines.insert(last_import + 1, f"import '{import_path}';")
        content = '\n'.join(lines)
    
    # Now find the build method of the MAIN screen (the first one if there are multiple, usually)
    # The first Widget build(BuildContext context) {
    if "ref.listen(nepaliDateProvider" not in content:
        build_match = re.search(r'Widget build\(BuildContext context\) \{', content)
        if build_match:
            insert_pos = build_match.end()
            content = content[:insert_pos] + f"\n    ref.listen(nepaliDateProvider, (_, __) => {load_func});" + content[insert_pos:]
            
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Updated {file_path}")
