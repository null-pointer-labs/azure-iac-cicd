# Skill Relocation: Global to Repository-Local

**Date**: 2026-05-08  
**Change Type**: Configuration Update  
**Status**: ✅ Complete

## Overview

Moved the `terraform-scaffold-consistency` skill from the global user location (`~/.agents/skills/`) to the repository-local location (`.agents/skills/`) to ensure it's version controlled and shared with the team.

## Why This Change?

**Before** (Global Skills):
- ❌ Skills in `~/.agents/skills/` are user-specific
- ❌ Not tracked in version control
- ❌ Not shared with other team members
- ❌ Not portable with the repository

**After** (Repository-Local Skills):
- ✅ Skills in `.agents/skills/` are repository-specific
- ✅ Tracked in git with the codebase
- ✅ Shared with all team members
- ✅ Portable - moves with the repository
- ✅ Versioned - can track skill changes over time

## Files Changed

### New Files
- [.agents/README.md](.agents/README.md) - Documentation for repository skills
- [.agents/skills/terraform-scaffold-consistency/SKILL.md](.agents/skills/terraform-scaffold-consistency/SKILL.md) - Skill definition (relocated)

### Updated Files
- [BUGFIX_MODULE_REFERENCES.md](BUGFIX_MODULE_REFERENCES.md)
  - Line 84: Updated reference from `~/.agents/skills/` to `.agents/skills/`
  - Line 218: Updated reference from `~/.agents/skills/` to `.agents/skills/`

- [SCAFFOLD_CONSISTENCY_SETUP.md](SCAFFOLD_CONSISTENCY_SETUP.md)
  - Line 26: Updated skill file location
  - Line 123: Updated key files listing
  - Line 224: Updated skill documentation structure

## Skill Content

The skill file contains 799 lines of comprehensive documentation:

1. **Purpose & When to Use** - Clear trigger conditions
2. **Project Structure Context** - Visual directory layout
3. **Critical Rules** - 4-location rule for PE modules
4. **Workflows**:
   - Adding a new module
   - Adding Private Endpoint support
   - Adding conditional infrastructure
5. **DNS Auto-Detection** - How `.env` file determines DNS mode
6. **Common Issues** - 7 documented issues with solutions
7. **Testing Checklist** - Pre and post change verification
8. **Quick Reference** - Common commands
9. **TL;DR** - The essential 4-location rule summary

## Git Status

```bash
$ git status .agents/
Changes to be committed:
  new file:   .agents/README.md
  new file:   .agents/skills/terraform-scaffold-consistency/SKILL.md
```

The `.agents/` directory is:
- ✅ Not excluded by `.gitignore`
- ✅ Added to git staging area
- ✅ Ready to commit

## How GitHub Copilot Finds Skills

GitHub Copilot looks for skills in:
1. **Repository-local**: `.agents/skills/` (✅ **Now using this**)
2. **Global user**: `~/.agents/skills/`
3. **VS Code extensions**: `~/.vscode/extensions/.../skills/`

Repository-local skills take precedence, so the skill will be found and used automatically.

## Verification

To verify the skill is working:

```bash
# Check skill is in repo
ls -la .agents/skills/terraform-scaffold-consistency/SKILL.md

# Verify not excluded by .gitignore
git check-ignore .agents/skills/terraform-scaffold-consistency/SKILL.md
# Should output nothing (not ignored)

# Check git tracking
git ls-files .agents/
# Should show both README.md and SKILL.md
```

## Team Usage

After this change is committed and pushed, team members will:

1. **Pull the repository** - Gets the `.agents/` directory automatically
2. **Copilot auto-discovers** - No manual setup required
3. **Same experience for everyone** - Consistent skill behavior across the team

## Next Steps

1. ✅ Files staged for commit
2. ⏳ Commit changes: `git commit -m "Relocate terraform-scaffold-consistency skill to repository"`
3. ⏳ Push to remote: `git push origin main`
4. ⏳ Team pulls latest changes

## References

- [.agents/README.md](.agents/README.md) - How to use and add repository skills
- [SCAFFOLD_CONSISTENCY_SETUP.md](SCAFFOLD_CONSISTENCY_SETUP.md) - Original skill setup documentation
- [GitHub Copilot Skills Documentation](https://docs.github.com/en/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)

## Summary

The `terraform-scaffold-consistency` skill is now:
- 📍 Located in `.agents/skills/terraform-scaffold-consistency/SKILL.md`
- 📝 Version controlled with git
- 👥 Shared with the team
- 🎯 Automatically discovered by Copilot
- 📖 Documented in `.agents/README.md`

All documentation references have been updated to reflect the new location.
