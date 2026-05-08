# Repository Skills

This directory contains GitHub Copilot skills that are **local to this repository** and tracked in version control.

## Why Local Skills?

Skills in this `.agents/skills/` directory are:
- ✅ **Version controlled** - Tracked in git with the codebase
- ✅ **Team shared** - Everyone working on this repo has access
- ✅ **Project specific** - Tailored to this Terraform scaffolding project
- ✅ **Portable** - Moves with the repository

## Available Skills

### terraform-scaffold-consistency

**Location**: [.agents/skills/terraform-scaffold-consistency/SKILL.md](.agents/skills/terraform-scaffold-consistency/SKILL.md)

**Purpose**: Maintains consistency between Terraform templates, modules, and the tf-scaffold.sh script.

**Auto-triggers on**:
- Adding new Azure service modules
- Modifying templates or module structure
- Adding Private Endpoint support
- Updating scaffold script logic
- Keywords: "scaffold", "template", "module consistency", "private endpoint"

**What it does**:
- Guides you through the 4-location rule for PE-enabled modules
- Explains DNS auto-detection from `.env` file
- Provides testing checklists
- Shows common issues and solutions
- Ensures scaffold stays in sync with templates

## Usage

GitHub Copilot will automatically invoke these skills when:
1. You mention trigger phrases (e.g., "add module", "scaffold not generating")
2. You're editing relevant files (templates, modules, tf-scaffold.sh)
3. You explicitly ask to use the skill

**Example prompts**:
- "Use terraform-scaffold-consistency skill to add azure-storage with PE support"
- "Why isn't my new module appearing in the scaffold menu?"
- "Add Private Endpoint support to azure-redis"

## Adding New Skills

To add a new skill to this repository:

1. **Create skill directory**:
   ```bash
   mkdir -p .agents/skills/{skill-name}
   ```

2. **Create SKILL.md** with YAML frontmatter:
   ```yaml
   ---
   description: >
     Brief description of what the skill does.
     Trigger phrases: "keyword1", "keyword2"
   ---

   # Skill Name

   ## Purpose
   ...
   ```

3. **Commit to git**:
   ```bash
   git add .agents/skills/{skill-name}/
   git commit -m "Add {skill-name} skill"
   ```

4. **Update this README** to list the new skill

## Best Practices

1. **Keep skills focused** - One skill, one responsibility
2. **Use clear trigger phrases** - Make it obvious when to use the skill
3. **Include examples** - Show expected input/output
4. **Test thoroughly** - Verify skill provides accurate guidance
5. **Document location** - Skills are in `.agents/skills/`, not `~/.agents/skills/`

## References

- [SCAFFOLD_CONSISTENCY_SETUP.md](../SCAFFOLD_CONSISTENCY_SETUP.md) - Setup documentation
- [.github/copilot-instructions.md](../.github/copilot-instructions.md) - Copilot context instructions
- [GitHub Copilot Skills Documentation](https://docs.github.com/en/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
