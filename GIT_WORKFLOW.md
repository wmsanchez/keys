# Git Workflow Guide

This document outlines the git workflow and best practices for this project.

## Overview

This project uses a feature branch workflow. Since it's a solo project with the goal of keeping all features (even incomplete) in sync on master, we follow a modified feature branch approach.

## Feature Branch Workflow

### When Working on a New Feature

1. **Start from master**
   ```bash
   git checkout master
   git pull origin master
   ```

2. **Create a new feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Do your work**
   - Make commits as you go
   - Use descriptive commit messages
   - Test locally

4. **Push the feature branch**
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Merge to master** (when you want it available)
   ```bash
   git checkout master
   git pull origin master
   git merge feature/your-feature-name
   git push origin master
   ```

6. **Delete the feature branch** (optional, after merge)
   ```bash
   git branch -d feature/your-feature-name
   git push origin --delete feature/your-feature-name
   ```

### What If You Start Working on the Wrong Branch?

If you realize you're on `feature/branch-a` but you're actually working on a completely different feature:

1. **Stash your current work**
   ```bash
   git stash push -u -m "description of work"
   ```

2. **Commit/push the current branch's actual work** (if any)
   ```bash
   git add .
   git commit -m "message"
   git push origin feature/branch-a
   ```

3. **Switch to master**
   ```bash
   git checkout master
   ```

4. **Create the correct feature branch**
   ```bash
   git checkout -b feature/correct-branch-name
   ```

5. **Pop the stash**
   ```bash
   git stash pop
   ```

6. **Resolve any conflicts** (if stash merge conflicts occur)
   - Edit the conflicted files
   - `git add <resolved-files>`
   - Continue with commit

7. **Commit the work to the correct branch**
   ```bash
   git add .
   git commit -m "message"
   ```

8. **Merge to master**
   ```bash
   git checkout master
   git merge feature/correct-branch-name
   git push origin master
   ```

## When to Delete a Branch

### Delete Local Branch After Merge
```bash
git branch -d feature/branch-name
```
Do this when:
- The branch has been merged to master
- You no longer need to work on that feature
- You want to keep your local branch list clean

### Delete Remote Branch After Merge
```bash
git push origin --delete feature/branch-name
```
Do this when:
- The branch has been merged to master
- The feature is complete
- You want to keep the remote branch list clean

### Keep a Branch Alive
Keep the branch when:
- The feature is still in development
- You're actively working on it
- You want to share it with others for review
- It's not ready for master yet

## When to Start a New Branch

Start a new branch when:
- Beginning work on a new feature
- Fixing a bug that's unrelated to current work
- Refactoring code that's separate from your current task
- Experimenting with something that might not work

**Don't start a new branch for:**
- Small typo fixes (unless it's a separate project)
- Documentation updates (unless it's a major change)
- Configuration changes

## Commit Message Format

Use conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples
```
feat(metadata): add photo filter metadata for Lightroom

Add custom metadata fields for filtering photos by aspect ratio and color profile.

fix(crash): improve exception handling in poll loop
refactor(keyboard): extract key code lookup to dedicated module
docs(api): update API documentation for new endpoints
```

## Common Scenarios

### Scenario 1: Feature Complete, Ready for Master
```bash
git checkout master
git pull origin master
git merge feature/your-feature
git push origin master
git branch -d feature/your-feature
```

### Scenario 2: Switch to Another Task Mid-Work
```bash
git stash push -u -m "partial work on feature A"
git checkout feature/feature-b
# work on feature B
git checkout feature/feature-a
git stash pop
```

### Scenario 3: Merge Conflict During Merge
```bash
git merge feature/your-feature
# conflict occurs
# edit conflicted files
git add <resolved-files>
git commit
git push origin master
```

### Scenario 4: Realize You're on Wrong Branch
```bash
# See the workflow section above for detailed steps
```

## Best Practices

1. **Always pull before starting work**
   ```bash
   git checkout master
   git pull origin master
   ```

2. **Commit often, commit early**
   - Small, focused commits are easier to review and revert
   - Don't wait until everything is perfect

3. **Write descriptive commit messages**
   - Explain WHY, not just WHAT
   - Keep the first line under 72 characters

4. **Keep master clean**
   - Only merge working code to master
   - Don't leave merge conflicts unresolved

5. **Push frequently**
   - Don't leave work only on your local machine
   - Push at least once per day

6. **Delete merged branches**
   - Keeps your branch list manageable
   - Reduces confusion about what's active

7. **Use meaningful branch names**
   - `feature/feature-name`
   - `fix/bug-description`
   - `refactor/component-name`

## Project-Specific Notes

### This Project's Philosophy

- **Solo project**: You're the only developer
- **Keep features in sync**: All features (even incomplete) are merged to master
- **Feature branches**: Used primarily for organization and clean history
- **Fast-forward merges**: Preferred when possible (no merge commits)

### Current Active Branches

- `feature/keyboard-layout-editor`: Keyboard layout editor implementation
- `master`: Main branch with all merged features

## Example Complete Workflow

```bash
# Start new feature
git checkout master
git pull origin master
git checkout -b feature/new-feature

# Do work (multiple commits)
git add .
git commit -m "feat: add initial implementation"
git add .
git commit -m "fix: resolve edge case"
git push origin feature/new-feature

# Merge to master
git checkout master
git pull origin master
git merge feature/new-feature
git push origin master

# Clean up
git branch -d feature/new-feature
```

## Troubleshooting

### Stash Pop Fails with Conflict
```bash
# Resolve the conflict manually
git add <resolved-files>
git stash drop  # if you're done with the stash
```

### Merge Conflict During Merge
```bash
# Resolve the conflict manually
git add <resolved-files>
git commit
```

### Wrong Commit Message
```bash
git commit --amend -m "correct message"
# Only do this if not pushed yet
```

### Need to Undo Last Commit
```bash
git reset --soft HEAD~1  # keeps changes staged
git reset --hard HEAD~1  # discards changes
```

## Resources

- [Git Branching and Merging](https://git-scm.com/book/en/v2/Git-Branching-Basic-Branching-and-Merging)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Stash](https://git-scm.com/docs/git-stash)
