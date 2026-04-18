---
name: Interactive menu behavior
description: Script 12 interactive menu: all unchecked by default, lettered group shortcuts from config, CSV/space number input, loop-back after install, Q to quit
type: feature
---
- All items unchecked by default (checkedByDefault: false in all groups)
- Lettered group shortcuts (a, b, c...) defined in config.json groups[].letter
- Input accepts: numbers (CSV "1,2,5" or space "1 2 5"), group letters, A=all, N=none, Q=quit
- After install + summary, menu loops back with all items unchecked again
- User can press Q to exit the loop