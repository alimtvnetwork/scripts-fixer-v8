# Spec: Script 41 -- Install Python Libraries

## Purpose

Install common Python/ML libraries via `pip` into the configured
`PYTHONUSERBASE` directory. Packages are organized into groups that can
be installed individually or all at once.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install all configured libraries (default) |
| `group <name>` | Install a specific library group |
| `add <pkg ...>` | Install specific packages by name |
| `list` | List available groups and their packages |
| `installed` | Show currently installed pip packages |
| `uninstall` | Uninstall all tracked libraries |
| `uninstall <pkg>` | Uninstall specific packages |
| `-Help` | Show usage information |

## Library Groups

| Group | Label | Packages |
|-------|-------|----------|
| `ml` | Machine Learning | numpy, scipy, scikit-learn, torch, tensorflow, keras |
| `data` | Data & Analytics | pandas, polars |
| `viz` | Visualization | matplotlib, seaborn, plotly |
| `web` | Web Frameworks | django, flask, fastapi, uvicorn |
| `scraping` | Scraping & HTTP | requests, beautifulsoup4 |
| `cv` | Computer Vision | opencv-python |
| `db` | Database | sqlalchemy |
| `jupyter` | Jupyter Notebook | jupyterlab, notebook, ipykernel, ipywidgets |

## Parameters

| Parameter | Position | Description |
|-----------|----------|-------------|
| `-Path` | N/A | Not used directly; relies on `PYTHONUSERBASE` set by script 05 |

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `requiresPython` | bool | Asserts Python is installed before proceeding |
| `installToUserSite` | bool | Use `--user` flag with pip (installs to PYTHONUSERBASE) |
| `groups` | object | Named groups of packages |
| `allPackages` | array | Full list of all packages for `all` command |

## Flow

1. Assert Python and pip are available
2. Check `PYTHONUSERBASE` -- if set, install with `--user` flag
3. Install requested packages (all, group, or custom)
4. Save resolved state with installed package list
5. Save installed record

## Install Keywords

**Single-script keywords** (script 41 only):

| Keyword | Description |
|---------|-------------|
| `python-libs` | Install all pip libraries |
| `pip-libs` | Install all pip libraries |
| `ml-libs` | ML/Data libraries |
| `ml-full` | ML libraries |
| `python-packages` | Install all pip libraries |
| `jupyter+libs` | Jupyter group only (mode: `group jupyter`) |

**Combo keywords** (installs Python 05 + libraries 41):

| Keyword | Scripts | Description |
|---------|---------|-------------|
| `pylibs` | 05, 41 | Python + all libraries in one go |
| `python+libs` | 05, 41 | Python + all libraries |
| `ml-dev` | 05, 41 | Python + all libraries |
| `python+jupyter` | 05, 41 | Python + all libraries |
| `pip+jupyter+libs` | 05, 41 | Python + all libraries |
| `data-science` | 05, 41 | Python + data/viz libs (mode: `group data`) |
| `datascience` | 05, 41 | Python + data/viz libs (mode: `group data`) |
| `ai-dev` | 05, 41 | Python + ML libs (mode: `group ml`) |
| `aidev` | 05, 41 | Python + ML libs (mode: `group ml`) |
| `deep-learning` | 05, 41 | Python + ML libs (mode: `group ml`) |

## Usage Examples

```powershell
# Via root dispatcher
.\run.ps1 install python-libs       # Install all libraries
.\run.ps1 install python+libs       # Install Python + all libraries
.\run.ps1 install jupyter+libs      # Install Jupyter group only
.\run.ps1 install data-science      # Python + data/viz group
.\run.ps1 install ai-dev            # Python + ML group
.\run.ps1 install python+jupyter    # Python + all libraries

# Via script directly
.\run.ps1 -I 41                     # Install all libraries
.\run.ps1 -I 41 -- group ml         # Install ML group only
.\run.ps1 -I 41 -- group jupyter    # Install Jupyter group
.\run.ps1 -I 41 -- group viz        # Install visualization only
.\run.ps1 -I 41 -- add jupyterlab streamlit  # Install custom packages
.\run.ps1 -I 41 -- list             # Show available groups
.\run.ps1 -I 41 -- installed        # Show pip packages
.\run.ps1 -I 41 -- uninstall        # Remove all tracked libraries
.\run.ps1 -I 41 -- uninstall numpy pandas  # Remove specific packages
```
