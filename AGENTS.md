# Keebox Engineering Instructions

## Change Reporting and Commit Messages

- For every codebase change, provide the corresponding proposed commit message in the final response.
- Use Conventional Commits style, with a concise scope when one is useful.
- When a change contains multiple independently meaningful concerns, provide separate commit messages.
- Do not create a Git commit unless the user explicitly requests it.

## Pull Request Messages

- Use `.github/PULL_REQUEST_TEMPLATE.md` for every pull request message.
- Provide the pull request title separately from the message body.
- Preserve the template's section names and order exactly.
- Populate every section from the verified branch changes and test results.

## Test-Driven Development

- Follow test-driven development for all product behavior.
- Write the test before writing the production implementation.
- Begin with focused unit tests for each feature and regression.
- Run the relevant tests after implementation and report the result.
- Add integration tests when multiple backend components form a testable workflow.
- Add end-to-end tests when complete user-facing backend flows become testable.
- A feature is incomplete until its required tests exist and pass.

## Python Typing and Documentation

- Use explicit type annotations throughout the Python codebase.
- Every function and method must annotate every parameter and its return type.
- Every function and method must have a multiline docstring in the following form:

```python
def function_name(arg1: Type1, arg2: Type2) -> ReturnType:
    """
    Short description of what the function does.

    Args:
        arg1: Description of the first argument.
        arg2: Description of the second argument.

    Returns:
        Description of the returned value.

    Raises:
        ExceptionType: Description of when this exception is raised.
    """
```

- Keep each docstring accurate. Document all arguments, the return value, and every intentionally raised exception.
- Do not place a module-level docstring or top-level explanatory comment at the beginning of a source module.

## Python Import and File Layout

- Organize imports in this order:
  1. Python standard-library imports.
  2. Third-party package imports, including Django.
  3. Keebox application and project imports.
- Separate import groups with exactly one blank line.
- Leave exactly three blank lines between the final import statement and the first line of module code.
- End every source file with exactly one newline.
