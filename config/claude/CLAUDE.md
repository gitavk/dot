# Claude Project Instructions

This document contains coding standards and best practices. The instructions are organized into separate files by technology.

## Structure

```
~/.config/claude/
├── CLAUDE.md              # This file (index)
├── general.md             # General principles
├── python.md              # Python guidelines
├── golang.md              # Go guidelines
├── svelte.md              # Svelte guidelines
├── database.md            # PostgreSQL & database guidelines
├── kafka.md               # Kafka & messaging guidelines
├── testing.md             # Testing practices
└── vcs.md                 # Version control & documentation
```

## Quick Reference

### [General Principles](general.md)
- Clean code principles
- Naming conventions
- Code organization

### [Python](python.md)
- PEP 8 style guide
- Type hints and annotations
- Project structure
- Common patterns

### [Go](golang.md)
- Go style guide
- Error handling
- Project layout
- Interfaces and testing

### [Svelte](svelte.md)
- Component patterns
- Reactive statements
- State management
- TypeScript integration

### [Kafka](kafka.md)
- Topic design
- Producer patterns
- Consumer patterns
- Error handling and monitoring

### [Testing](testing.md)
- Unit testing
- Integration testing
- Test organization

## Usage

Include relevant sections in your project by symlinking:

```bash
# Link all guidelines
ln -s ~/.config/claude/CLAUDE.md ~/project/

# Or link specific files
ln -s ~/.config/claude/python.md ~/project/CLAUDE-PYTHON.md
ln -s ~/.config/claude/database.md ~/project/CLAUDE-DATABASE.md
```
