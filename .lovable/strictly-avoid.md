# Strictly Avoid

> Violating ANY of these is a critical failure. No exceptions.

## Code & Scripts

1. **Never mutate config.json with runtime data.** Config files are declarative input only. Runtime state goes to `.resolved/`.
2. **Never use Unicode box-drawing or em dashes in terminal banners.** Use plain ASCII only: `+`, `-`, `|`.
3. **Never omit `-Confirm:$false -Force`** on `New-Item`, `Set-ItemProperty`, or similar cmdlets that can prompt.
4. **Never swallow file/path errors.** Every file or path error MUST log the exact file path and failure reason using `Write-FileError`. (CODE RED)
5. **Never use bare `-not` checks.** Use `$isInstalled -eq $false` or `-not $isInstalled` with `is/has` prefix booleans.
6. **Never use PascalCase or camelCase for file/folder names.** All file and folder names use kebab-case: `log-messages.json`, `01-install-vscode/`.
7. **Never touch the `.gitmap/release/` folder.** Release artifacts are managed externally.

## Architecture

8. **Never add backend code to the React project.** The sandbox is client-side only. Use Lovable Cloud for backend needs.
9. **Never store roles on the profile or users table.** Roles must be in a separate table to prevent privilege escalation.
10. **Never check admin status via client-side storage** (localStorage, sessionStorage) or hardcoded credentials.

## Communication

11. **Never append boilerplate** like "Let me know if you have questions!" or "Hope this helps!" or the "If you have any question and confusion..." block.
12. **Never append the "Do you understand? Always add this part..." code block.**

## Version Control

13. **Any code change must bump at least the minor version.** No silent changes.
