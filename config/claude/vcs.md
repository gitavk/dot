# Version Control & Documentation

Git workflow, commit conventions, and documentation best practices.

## Git Workflow

### Branch Naming

```bash
# Feature branches
feature/user-authentication
feature/add-payment-gateway
feature/dashboard-redesign

# Bug fix branches
bugfix/fix-login-redirect
bugfix/resolve-memory-leak
fix/correct-timezone-handling

# Hotfix branches (urgent production fixes)
hotfix/security-patch
hotfix/payment-processing-error

# Release branches
release/v1.2.0
release/v2.0.0-beta

# Chore/maintenance branches
chore/update-dependencies
chore/improve-test-coverage
refactor/extract-user-service
```

### Branch Strategy

**Git Flow** (for scheduled releases):
```
main (production)
  ├── develop (integration)
  │   ├── feature/new-feature
  │   ├── feature/another-feature
  │   └── bugfix/fix-bug
  ├── release/v1.0.0
  └── hotfix/critical-fix
```

**GitHub Flow** (for continuous deployment):
```
main (production)
  ├── feature/new-feature
  ├── feature/another-feature
  └── bugfix/fix-bug
```

**Trunk-Based Development** (for high-velocity teams):
```
main (production)
  ├── short-lived feature branches (< 1 day)
  └── feature flags for incomplete features
```

## Commit Messages

### Conventional Commits Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, missing semicolons, etc.)
- **refactor**: Code refactoring (neither fixes a bug nor adds a feature)
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Maintenance tasks, dependency updates
- **ci**: CI/CD configuration changes
- **build**: Build system or external dependency changes
- **revert**: Revert a previous commit

### Examples

```bash
# Good commit messages
git commit -m "feat(auth): add JWT token refresh mechanism"

git commit -m "fix(api): resolve race condition in payment processing

The payment handler was not properly locking resources, causing
duplicate charges when users clicked submit multiple times.

Added mutex lock and idempotency key validation.

Fixes #123"

git commit -m "docs: update API authentication guide"

git commit -m "refactor(user): extract validation logic to separate service"

git commit -m "perf(db): add index on users.email for faster lookups"

git commit -m "test(orders): add integration tests for order creation"

git commit -m "chore: upgrade dependencies to latest versions"

git commit -m "ci: add automated deployment to staging environment"

# With breaking change
git commit -m "feat(api)!: change user endpoint response format

BREAKING CHANGE: The /api/users endpoint now returns an object
with 'data' and 'meta' fields instead of a plain array.

Migration guide: https://docs.example.com/migration/v2"

# Revert
git commit -m "revert: feat(auth): add JWT token refresh

This reverts commit abc123def456.
Reason: Causes memory leak in production"
```

### Bad Commit Messages

```bash
# Too vague
git commit -m "updates"
git commit -m "fix bug"
git commit -m "changes"
git commit -m "WIP"

# Not descriptive
git commit -m "fix"
git commit -m "update code"
git commit -m "minor changes"
```

### Commit Message Best Practices

- **Use imperative mood**: "add feature" not "added feature"
- **Keep subject line under 50 characters**
- **Capitalize subject line**
- **Don't end subject line with period**
- **Use body to explain what and why, not how**
- **Separate subject from body with blank line**
- **Wrap body at 72 characters**
- **Reference issues and PRs**

## Git Commands

### Basic Workflow

```bash
# Check status
git status

# Stage changes
git add file.py
git add .
git add -p  # Interactive staging

# Commit
git commit -m "feat: add user authentication"
git commit -am "fix: resolve login issue"  # Stage and commit modified files

# Push
git push origin feature/my-feature
git push -u origin feature/my-feature  # Set upstream

# Pull
git pull origin main
git pull --rebase origin main  # Rebase instead of merge

# Fetch
git fetch origin
git fetch --all --prune  # Remove deleted remote branches
```

### Branch Management

```bash
# Create and switch to new branch
git checkout -b feature/new-feature
git switch -c feature/new-feature  # Modern syntax

# Switch branches
git checkout main
git switch main  # Modern syntax

# List branches
git branch
git branch -a  # Include remote branches
git branch -vv  # Show tracking branches

# Delete branch
git branch -d feature/old-feature  # Safe delete
git branch -D feature/old-feature  # Force delete

# Delete remote branch
git push origin --delete feature/old-feature

# Rename branch
git branch -m old-name new-name
```

### Viewing History

```bash
# View commit history
git log
git log --oneline
git log --graph --oneline --all
git log --graph --oneline --decorate

# View specific file history
git log --follow file.py
git log -p file.py  # Show diffs

# Search commits
git log --grep="auth"
git log --author="John"
git log --since="2024-01-01"
git log --until="2024-12-31"

# Show commit
git show abc123
git show HEAD
git show HEAD~2  # 2 commits before HEAD

# Show changes
git diff
git diff --staged
git diff main..feature/branch
git diff HEAD~2..HEAD
```

### Undoing Changes

```bash
# Discard working directory changes
git checkout -- file.py
git restore file.py  # Modern syntax

# Unstage file
git reset HEAD file.py
git restore --staged file.py  # Modern syntax

# Amend last commit
git commit --amend -m "new message"
git commit --amend --no-edit  # Keep message

# Reset to previous commit
git reset --soft HEAD~1  # Keep changes staged
git reset --mixed HEAD~1  # Keep changes unstaged (default)
git reset --hard HEAD~1  # Discard changes (dangerous!)

# Revert commit (create new commit that undoes)
git revert abc123
git revert HEAD

# Discard all local changes
git reset --hard HEAD
git clean -fd  # Remove untracked files
```

### Stashing

```bash
# Stash changes
git stash
git stash save "work in progress on feature"
git stash -u  # Include untracked files

# List stashes
git stash list

# Apply stash
git stash apply
git stash apply stash@{0}
git stash pop  # Apply and remove

# Show stash contents
git stash show
git stash show -p stash@{0}

# Drop stash
git stash drop stash@{0}
git stash clear  # Remove all stashes
```

### Rebase

```bash
# Rebase current branch onto main
git rebase main

# Interactive rebase (last 3 commits)
git rebase -i HEAD~3

# Continue/abort rebase
git rebase --continue
git rebase --abort
git rebase --skip

# Rebase onto different base
git rebase --onto main feature-a feature-b
```

### Interactive Rebase Commands

```bash
# Edit commits interactively
git rebase -i HEAD~5

# Commands in interactive rebase:
# pick = use commit
# reword = use commit, but edit the commit message
# edit = use commit, but stop for amending
# squash = use commit, but meld into previous commit
# fixup = like squash, but discard commit message
# drop = remove commit

# Example:
pick abc123 feat: add user service
reword def456 fix: resolve bug
squash ghi789 test: add user tests
fixup jkl012 fix typo
drop mno345 WIP commit
```

### Cherry-Pick

```bash
# Apply specific commit to current branch
git cherry-pick abc123

# Cherry-pick multiple commits
git cherry-pick abc123 def456

# Cherry-pick without committing
git cherry-pick --no-commit abc123
```

### Tags

```bash
# Create lightweight tag
git tag v1.0.0

# Create annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# List tags
git tag
git tag -l "v1.*"

# Push tags
git push origin v1.0.0
git push origin --tags  # Push all tags

# Delete tag
git tag -d v1.0.0
git push origin --delete v1.0.0

# Checkout tag
git checkout v1.0.0
```

### Resolving Conflicts

```bash
# When conflict occurs
git status  # Show conflicted files

# Edit conflicted files, resolve markers:
<<<<<<< HEAD
Your changes
=======
Their changes
>>>>>>> branch-name

# After resolving
git add resolved-file.py
git commit

# Abort merge
git merge --abort

# Use one version entirely
git checkout --ours file.py  # Keep our version
git checkout --theirs file.py  # Take their version
```

## Git Configuration

```bash
# User configuration
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Editor
git config --global core.editor "vim"
git config --global core.editor "code --wait"  # VS Code

# Default branch name
git config --global init.defaultBranch main

# Aliases
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.lg "log --graph --oneline --all"
git config --global alias.undo "reset --soft HEAD~1"

# Useful settings
git config --global pull.rebase true
git config --global fetch.prune true
git config --global diff.colorMoved zebra
git config --global core.autocrlf input  # Linux/Mac
git config --global core.autocrlf true   # Windows

# View configuration
git config --list
git config --global --list
```

## .gitignore

```bash
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
.venv
pip-log.txt
pip-delete-this-directory.txt
.pytest_cache/
.coverage
htmlcov/
*.egg-info/
dist/
build/

# Go
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out
vendor/

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm
.eslintcache

# IDEs
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Environment files
.env
.env.local
.env.*.local
*.key
*.pem

# Logs
logs/
*.log

# Database
*.db
*.sqlite
*.sqlite3

# OS
.DS_Store
Thumbs.db

# Temporary files
tmp/
temp/
*.tmp

# Application specific
uploads/
cache/
.cache/
```

### .gitignore Best Practices

- Commit `.gitignore` to repository
- Never commit secrets, API keys, or credentials
- Don't ignore files that are part of the build
- Use global `.gitignore` for OS/editor files
- Comment sections in `.gitignore`

```bash
# Set up global gitignore
git config --global core.excludesfile ~/.gitignore_global

# Example ~/.gitignore_global
.DS_Store
.vscode/
.idea/
*.swp
```

## Pull Requests

### PR Title

Follow conventional commit format:
```
feat(auth): add OAuth2 authentication
fix(api): resolve timeout in user endpoint
docs: update deployment guide
```

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Related Issues
Fixes #123
Closes #456
Related to #789

## Changes Made
- Added JWT authentication
- Updated user model
- Added integration tests

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Screenshots (if applicable)
![Screenshot](url)

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added/updated and passing
- [ ] Changes are backward compatible

## Additional Notes
Any additional information or context
```

### PR Best Practices

- **Keep PRs small** (< 400 lines changed)
- **One feature/fix per PR**
- **Write clear description**
- **Reference related issues**
- **Add screenshots for UI changes**
- **Ensure tests pass**
- **Request reviews from appropriate team members**
- **Respond to review comments promptly**
- **Squash commits before merging** (if using squash merge)

## Code Review

### As a Reviewer

**DO:**
- Be constructive and kind
- Explain why, not just what
- Suggest alternatives
- Approve when ready
- Focus on important issues

**DON'T:**
- Be condescending
- Nitpick formatting (use linters)
- Block on personal preferences
- Delay reviews
- Review too quickly

### Review Comments

```markdown
# Good comments
"Consider using a try-catch here to handle potential errors from the API call"

"This could be more efficient using a hash map instead of array filter. 
Current: O(n²), Proposed: O(n)"

"Great work on the test coverage! 👍"

"This is a security concern - user input should be sanitized before passing to SQL query"

# Bad comments
"This is wrong"
"I don't like this"
"Change this"
"????"
```

## Documentation

### README.md Template

```markdown
# Project Name

Brief description of what this project does

## Features

- Feature 1
- Feature 2
- Feature 3

## Prerequisites

- Python 3.11+
- PostgreSQL 15+
- Node.js 18+

## Installation

```bash
# Clone repository
git clone https://github.com/username/project.git
cd project

# Install dependencies
pip install -r requirements.txt

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Run migrations
python manage.py migrate

# Start development server
python manage.py runserver
```

## Configuration

Environment variables:

- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY` - Application secret key
- `API_KEY` - External API key

## Usage

```python
from project import Client

client = Client(api_key="your-key")
result = client.fetch_data()
```

## Development

```bash
# Run tests
pytest

# Run linter
ruff check .

# Format code
black .

# Type check
mypy .
```

## API Documentation

See [API.md](./API.md) for detailed API documentation.

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'feat: add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## Contact

Your Name - your.email@example.com

Project Link: https://github.com/username/project
```

### API Documentation

```markdown
# API Documentation

## Authentication

All API requests require authentication using JWT token in header:
```
Authorization: Bearer <token>
```

## Endpoints

### Get User

```http
GET /api/users/{id}
```

**Parameters:**
- `id` (integer, required) - User ID

**Response:**
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "johndoe",
  "created_at": "2024-01-01T00:00:00Z"
}
```

**Status Codes:**
- `200 OK` - Success
- `404 Not Found` - User not found
- `401 Unauthorized` - Invalid or missing token

### Create User

```http
POST /api/users
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "username": "johndoe",
  "password": "securepassword"
}
```

**Response:**
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "johndoe",
  "created_at": "2024-01-01T00:00:00Z"
}
```

**Status Codes:**
- `201 Created` - User created successfully
- `400 Bad Request` - Invalid input
- `409 Conflict` - Email or username already exists
```

### Inline Code Documentation

```python
def calculate_discount(price: float, discount_percent: float) -> float:
    """
    Calculate discounted price.
    
    Args:
        price: Original price
        discount_percent: Discount percentage (0-100)
        
    Returns:
        Price after discount
        
    Raises:
        ValueError: If discount_percent is not between 0 and 100
        
    Example:
        >>> calculate_discount(100.0, 10.0)
        90.0
    """
    if not 0 <= discount_percent <= 100:
        raise ValueError("Discount must be between 0 and 100")
    
    return price * (1 - discount_percent / 100)
```

## Best Practices Summary

### DO
- Write clear, descriptive commit messages
- Commit often, push regularly
- Keep commits atomic and focused
- Use branches for features and fixes
- Review your own diff before pushing
- Pull before you push
- Keep PRs small and focused
- Write documentation
- Use `.gitignore` properly
- Never commit secrets
- Tag releases
- Respond to code reviews

### DON'T
- Commit broken code
- Commit commented-out code
- Commit debug statements
- Force push to shared branches
- Rewrite public history
- Commit large binary files
- Commit generated files
- Leave merge markers
- Ignore failing tests
- Push directly to main/master
- Commit sensitive data

---

*Version control is not just about code - it's about collaboration and history.*