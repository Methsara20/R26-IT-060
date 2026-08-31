import re
import glob

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    if 'GlassCard' not in content:
        content = "import '../core/widgets/glass_card.dart';\n" + content
    
    # Simple regex to replace Card() and basic Containers with GlassCard
    content = re.sub(r'Card\(\s*color:\s*AppColors\.cardBackground,', r'GlassCard(', content)
    content = re.sub(r'Container\(\s*margin:.*?\s*decoration:\s*BoxDecoration\(\s*color:\s*AppColors\.cardBackground,.*?borderRadius.*?,\s*\),', r'GlassCard(', content, flags=re.DOTALL)
    
    with open(filepath, 'w') as f:
        f.write(content)

for f in glob.glob('frontend-web/lib/marketing_hub/screens/*.dart'):
    process_file(f)
