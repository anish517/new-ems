import os

files = {
    r'frontend\lib\features\attendance\screens\attendance_screen.dart': [
        ("        appBar: AppBar(", "        appBar: AppBar(actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll)], "),
        ("      appBar: AppBar(", "      appBar: AppBar(actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll)], ")
    ],
    r'frontend\lib\features\feedback\screens\feedback_screen.dart': [
        ("      appBar: AppBar(title: const Text('Feedback & Complaints')),", 
         "      appBar: AppBar(title: const Text('Feedback & Complaints'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadComplaints)]), ")
    ],
    r'frontend\lib\features\leave\screens\leave_screen.dart': [
        ("      appBar: AppBar(", "      appBar: AppBar(actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLeaves)], ")
    ],
    r'frontend\lib\features\noticeboard\screens\noticeboard_screen.dart': [
        ("      appBar: AppBar(title: const Text('Noticeboard')),", 
         "      appBar: AppBar(title: const Text('Noticeboard'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadNotices)]), ")
    ],
    r'frontend\lib\features\performance\screens\performance_screen.dart': [
        ("      appBar: AppBar(title: const Text('Performance Reviews')),", 
         "      appBar: AppBar(title: const Text('Performance Reviews'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll)]), ")
    ],
    r'frontend\lib\features\salary\screens\salary_screen.dart': [
        ("        appBar: AppBar(", "        appBar: AppBar(actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)], "),
        ("      appBar: AppBar(", "      appBar: AppBar(actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)], ")
    ],
    r'frontend\lib\features\tasks\screens\tasks_screen.dart': [
        ("      appBar: AppBar(", "      appBar: AppBar(actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTasks)], ")
    ]
}

for path, replacements in files.items():
    full_path = os.path.join(r'f:\emp\ems-full-stack', path)
    with open(full_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for old, new in replacements:
        if old in content and new not in content:
            content = content.replace(old, new, 1)
            
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'Updated {path}')
