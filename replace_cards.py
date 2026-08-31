import re
import glob

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Pattern to match Card(color: AppColors.cardBackground
    pattern = r'Card\(\s*color:\s*AppColors\.cardBackground,\s*margin:\s*([^,]+),\s*child:'
    
    def repl(m):
        margin_str = m.group(1)
        # For GlassCard we can just wrap it in a padding if margin was used, or just pass it to GlassCard if it supports margin.
        # But GlassCard doesn't have a margin parameter. We can wrap it in Padding.
        return f'Padding(\n      padding: {margin_str},\n      child: GlassCard(\n        child:'
    
    new_content = re.sub(pattern, repl, content)
    
    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for f in glob.glob('frontend-web/lib/marketing_hub/screens/*.dart'):
    process_file(f)
