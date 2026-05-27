import re

with open('g:/NODEJS/koreanlearningapp/apps/admin-web/src/pages/TopikExamEditorPage.tsx', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for idx, line in enumerate(lines):
    if 'dirtyQuestions' in line or 'setDirtyQuestions' in line:
        print(f"{idx+1}: {line.strip()}")
