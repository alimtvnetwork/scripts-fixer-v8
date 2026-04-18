---
name: Terminal banner and logging rules
description: Plain ASCII banners, logs/ subfolder per script, -Confirm:$false on all registry/file ops
type: constraint
---
1. Never use Unicode box-drawing characters or em dashes in banners. Use plain ASCII: +, -, |
2. Every script must write output to a logs/ subfolder via Start-Transcript
3. The root dispatcher cleans (delete+recreate) the logs/ folder before delegating
4. All New-Item / Set-ItemProperty calls must include -Confirm:$false -Force to prevent hangs
5. The logs folder is already covered by the project .gitignore entry
