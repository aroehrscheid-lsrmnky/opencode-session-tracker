# Dev Setup

1. Clone a built-in:
```bash
omarchy plugin clone omarchy.clock --edit
```
2. Rename folder to your id
3. Edit manifest.json
4. Validate:
```bash
omarchy plugin validate ~/.config/omarchy/plugins/your.id
qmllint -I "$OMARCHY_PATH/shell" your.id/BarWidget.qml
```
5. Test:
```bash
omarchy-shell shell summon "your.id" '{}'
```

Git:
```bash
git init
git add .
git commit -m "Initial scaffold"
```
