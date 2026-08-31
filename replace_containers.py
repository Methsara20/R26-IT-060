import re
import glob

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Pattern to match Container with BoxDecoration(color: AppColors.cardBackground)
    # We want to replace it with GlassCard
    # Example:
    # Container(
    #   padding: const EdgeInsets.all(16),
    #   decoration: BoxDecoration(
    #     color: AppColors.cardBackground,
    #     borderRadius: BorderRadius.circular(12),
    #     border: Border.all(color: AppColors.divider),
    #   ),
    #   child:
    
    # regex for this specific block:
    pattern = r'Container\(\s*(padding:\s*[^,]+,)?\s*decoration:\s*BoxDecoration\(\s*color:\s*AppColors\.cardBackground,\s*borderRadius:\s*BorderRadius\.circular\([^)]+\),\s*(?:border:\s*Border\.all\([^)]+\),\s*)?\),\s*child:'
    
    def repl(m):
        padding_str = m.group(1) if m.group(1) else ''
        return f'GlassCard(\n      {padding_str}\n      child:'
    
    new_content = re.sub(pattern, repl, content)
    
    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for f in glob.glob('frontend-web/lib/marketing_hub/screens/*.dart'):
    process_file(f)
