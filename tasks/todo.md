# Lordon AI Insights

- [ ] Inspect existing Lordon dashboard structure and data files
- [ ] Implement `lordon/scripts/build-lordon-ai-insights.js`
- [ ] Update `lordon/index.html` to load AI insights and wire key AI boxes with fallbacks
- [ ] Run the script locally and confirm `data/ai-insights.json` is written
- [ ] Review diffs for correctness
- [ ] Commit and push changes

## Risks
- Data shapes may differ from assumptions across the three JSON files
- Anthropic responses may include code fences or extra text around JSON
- Existing AI copy may be inline in multiple render functions, requiring targeted updates

## Verification
- Run the script with available env / fallback mode and confirm output file is created
- Run a syntax check on the Node script
- Review rendered text wiring in `index.html` by inspecting the updated code paths
- Check `git diff` before commit
