# Dynamic Resume PDF Generator

Generate multiple versions of your resume from a single markdown template. Perfect for tailoring resumes for different roles, industries, or audiences.

## Features

- **Single Source, Multiple Outputs**: One template file generates multiple targeted versions
- **Version Markers**: Use simple HTML comments to mark version-specific content
- **Flexible Styling**: Configure fonts, margins, and layout globally or per-version
- **Command-Line Control**: Generate all versions or filter by template/version

## Installation

### Requirements

- **bash**: For running generate.sh
- **pandoc**: For PDF generation
- **xelatex** or **pdflatex**: LaTeX engine for PDF rendering
- **yq**: For parsing YAML config (required for anything other than default config)

### Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get install pandoc texlive-xetex texlive-fonts-recommended
```

**macOS:**
```bash
brew install pandoc basictex
sudo tlmgr update --self
sudo tlmgr install collection-fontsrecommended
```

**Install yq (required):**
```bash
# macOS
brew install yq

# Linux
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq
```

## Quick Start

1. **Edit a template** in `templates/` (or create your own)
2. **Run the generator:**
   ```bash
   ./generate.sh
   ```
3. **Check output:** Generated PDFs and markdown files in `output/`

That's it! The included example templates will generate multiple resume versions.

## Usage

### Generate Everything
```bash
./generate.sh
```

### Generate Specific Templates
```bash
./generate.sh templates=1              # Just template 1
./generate.sh templates=1,2            # Templates 1 and 2
```

### Generate Specific Versions
```bash
./generate.sh versions=technical       # Only "technical" versions
./generate.sh versions=technical,management
```

### Combine Filters
```bash
./generate.sh templates=1 versions=technical
```

### Custom Output Name
```bash
./generate.sh templates=1 versions=technical output=my_resume.pdf
```

## Template Format

Templates are markdown files named `*.TEMPLATE.md` in the `templates/` directory.

### Version Markers

Mark version-specific content with HTML comments:

**Shorthand syntax:**
```markdown
<!--v:technical-->
Content only for the "technical" version
<!--/v-->
```

**Full syntax:**
```markdown
<!--VERSION:management-->
Content only for the "management" version
<!--/VERSION-->
```

**Shared content** (no markers) appears in all versions.

### Example Template

```markdown
# Jane Smith
jane@email.com | (555) 123-4567

## Summary

<!--v:technical-->
Software engineer with 5+ years building scalable applications.
<!--/v-->

<!--v:management-->
Engineering leader with experience building high-performing teams.
<!--/v-->

## Experience

**TechCorp** | Senior Engineer | 2021-Present
- Led architecture of microservices platform
- Mentored junior developers

<!--v:management-->
- Managed team of 8 engineers
- Established hiring processes
<!--/v-->
```

This generates two versions: `jane.technical.pdf` and `jane.management.pdf`

## Project Structure

```
resume-template/
├── templates/          # Your .TEMPLATE.md files
│   ├── Example_1.TEMPLATE.md
│   └── Example_2.TEMPLATE.md
├── output/             # Generated .md and .pdf files
├── config.yaml         # Configuration
├── generate.sh              # Generator script
└── README.md
```

## Configuration

Edit `config.yaml` to customize styling. Settings cascade with priority:

**Priority order:** `global` → `templates` → `versions` → `template_versions` → command-line args

### Global Settings

Apply to all generated PDFs:

```yaml
global:
  pdf_engine: "xelatex"    # xelatex (recommended) or pdflatex
  font: "Arial"            # Any system font with xelatex
  fontsize: "11pt"         # Standard: 10pt, 11pt, 12pt
                           # Extended: 8pt, 9pt, 14pt, 17pt, 20pt
  margin: "0.5in"
  pagestyle: "empty"       # No headers/footers
  linestretch: "1.0"       # Line spacing (1.0 = single)
```

### Custom Geometry

For individual margin control:

```yaml
global:
  geometry_options:
    - top=0.5in
    - bottom=0.5in
    - left=0.75in
    - right=0.75in
```

### Per-Template Overrides

Customize specific templates:

```yaml
templates:
  Example_1.TEMPLATE.md:
    font: "Helvetica"
    fontsize: "12pt"
    output_name: "jane_smith_resume"  # Custom filename
```

### Per-Version Overrides

Apply styling to all instances of a version:

```yaml
versions:
  technical:
    font: "Courier New"
    fontsize: "10pt"
```

### Per-Template-Per-Version Overrides

Highest specificity (except CLI args):

```yaml
template_versions:
  Example_1.TEMPLATE.md:
    technical:
      output_name: "jane_technical"
      fontsize: "10pt"
    management:
      output_name: "jane_management"
      fontsize: "11pt"
```

### Directories

Change input/output directories:

```yaml
directories:
  templates: "templates"
  output: "output"
```

## Troubleshooting

**"pandoc: command not found"**
- Install pandoc and LaTeX (see Installation)

**"Font not found" errors**
- Use xelatex for system fonts, or stick to standard fonts (Arial, Helvetica, Times, Courier) with pdflatex

**Font size not changing**
- Standard sizes: 10pt, 11pt, 12pt
- Extended sizes: 8pt, 9pt, 14pt, 17pt, 20pt (uses extarticle automatically)
- Sizes beyond 20pt not supported

**Version markers not working**
- Syntax: `<!--v:name-->` or `<!--VERSION:name-->`
- Closing tags: `<!--/v-->` or `<!--/VERSION-->`
- Markers are case-sensitive

**"yq not found" warning**
- Install yq (required for full config support)
- Without yq, only basic directory settings work

## Examples

See `templates/Example_1.TEMPLATE.md` and `templates/Example_2.TEMPLATE.md` for working examples.

## License

MIT License - use freely for your resumes!

This software is provided "as is", without warranty of any kind, express or implied. The author is not responsible for any issues, errors, or consequences arising from the use of this software. Use at your own risk.
