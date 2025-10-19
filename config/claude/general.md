# General Principles

Core coding principles that apply across all technologies.

## General Best Practices

- Follow existing code style and patterns
- Prefer explicit over implicit
- Choose simple solutions
- Balance perfection with productivity
- Write clean, readable, and maintainable code
- Your code will be reviewed and maintained by others
- Keep functions small and focused (single responsibility)
- Write tests for new features and bug fixes
- Document complex logic and non-obvious decisions

## version control

- write clear, descriptive commit messages
- keep commits atomic and focused
- commit working code frequently
- don't commit commented-out code
- don't commit debugging statements
- review your own diff before committing

## Naming Conventions

### Variables and Functions
- Use descriptive names that reveal intent
- Avoid abbreviations unless widely known
- Use pronounceable names
- Avoid mental mapping (single-letter variables except in short loops)

**Good:**
```
userCount, calculateTotalPrice, isAuthenticated
```

**Bad:**
```
uc, calcTotPrc, auth
```

### Constants
- Use UPPER_CASE for true constants
- Group related constants
- Consider using enums for related values

### Boolean Variables
- Prefix with `is`, `has`, `can`, `should`
- Examples: `isActive`, `hasPermission`, `canEdit`, `shouldRetry`

## Function Design

### Single Responsibility
Each function should do one thing and do it well.

**Good:**
```
validateEmail(email)
sendEmail(to, subject, body)
```

**Bad:**
```
validateAndSendEmail(email, subject, body)
```

### Function Length
- Aim for functions under 20-30 lines
- If longer, consider breaking into smaller functions
- One level of abstraction per function
- Extract complex logic into helper functions

### Parameters
- Limit to 3-4 parameters when possible
- Use objects/structs for multiple related parameters
- Avoid boolean flags as parameters (often indicates two functions)

## Code Organization

### DRY (Don't Repeat Yourself)
- Extract repeated code into functions
- Create reusable utilities
- Balance DRY with readability (don't over-abstract)

### KISS (Keep It Simple, Stupid)
- Choose simple solutions over complex ones
- Avoid premature optimization
- Write code that's easy to understand

### YAGNI (You Aren't Gonna Need It)
- Don't build features "just in case"
- Add functionality when actually needed
- Focus on current requirements

## Error Handling

- Always handle errors, never ignore them
- Provide context in error messages
- Log errors with appropriate severity
- Fail fast when appropriate
- Use custom error types for domain-specific errors

### Error Messages
- Include what failed
- Include why it failed
- Include relevant context (IDs, values)
- Don't expose sensitive information

## Comments and Documentation

### When to Comment
- **Do comment:** Complex algorithms, business logic, workarounds, TODOs
- **Don't comment:** Obvious code, what code does (code should be self-documenting)

## Performance Considerations

- Write correct code first, optimize later
- Profile before optimizing (measure, don't guess)
- Focus on algorithmic complexity for big wins
- Consider caching for expensive operations
- Be mindful of database N+1 queries

## Security

- Never commit secrets, API keys, or credentials
- Use environment variables for sensitive configuration
- Validate and sanitize all user input
- Use parameterized queries (prevent SQL injection)
- Keep dependencies up to date
- Follow principle of least privilege
- Hash passwords with proper algorithms (bcrypt, argon2)
- Use HTTPS for all external communications
- Implement rate limiting for public APIs
- Log security events (failed logins, access attempts)

## Testing

- Write tests for new features
- Write tests for bug fixes
- Test edge cases and error conditions
- Keep tests independent and isolated
- Use descriptive test names
- Follow AAA pattern: Arrange, Act, Assert

## Code Review Checklist

- [ ] Does it work correctly?
- [ ] Is it readable and maintainable?
- [ ] Are there tests?
- [ ] Could this be simplified?
- [ ] Are there any security concerns?
- [ ] Is it consistent with existing code style?
- [ ] Is documentation adequate?
