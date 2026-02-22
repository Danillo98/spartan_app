import os

def fix_imports():
    for root, _, files in os.walk('lib'):
        for f in files:
            if f.endswith('.dart'):
                filepath = os.path.join(root, f)
                try:
                    with open(filepath, 'r', encoding='utf-8') as file:
                        content = file.read()
                    
                    if "import 'dart:html' as html;" in content:
                        modified = content.replace("import 'dart:html' as html;", "import 'package:universal_html/html.dart' as html;")
                        with open(filepath, 'w', encoding='utf-8') as file:
                            file.write(modified)
                        print(f"Fixed {filepath}")
                except Exception as e:
                    print(f"Error processing {filepath}: {e}")

if __name__ == '__main__':
    fix_imports()
