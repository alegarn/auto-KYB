# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]  
**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]  
**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]  
**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]  
**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]
**Project Type**: [single/web/mobile - determines source structure]  
**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]  
**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]  
**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Code Quality (Principle I)
- [ ] Code follows Ruby on Rails community standards
- [ ] Code passes RuboCop linting with project-specific rules
- [ ] Code is self-documenting with clear variable and method names
- [ ] Complex logic is extracted into well-named methods or service objects
- [ ] Public methods have documentation comments

### DRY (Principle II)
- [ ] Code duplication is eliminated through proper abstraction
- [ ] Common functionality is extracted into shared modules, concerns, or service objects
- [ ] Views use partials and components for repeated UI patterns
- [ ] Database queries are scoped and reused

### Convention Over Configuration (Principle III)
- [ ] Ruby on Rails conventions for naming, file structure, and patterns are followed
- [ ] Custom configurations are only used when conventions cannot meet requirements
- [ ] Rails generators and standard directory structure are used
- [ ] RESTful routing conventions are followed

### MVC Architecture (Principle IV)
- [ ] Models contain business logic and data access rules
- [ ] Controllers are thin, handling only request/response orchestration
- [ ] Views are presentation logic only, with no business logic
- [ ] Cross-cutting concerns use concerns, services, or decorators appropriately

### RESTful Design (Principle V)
- [ ] API endpoints follow RESTful conventions with appropriate HTTP verbs
- [ ] Resources are nouns and actions are verbs
- [ ] Standard Rails resource routing is used
- [ ] Responses have appropriate status codes
- [ ] API is stateless with proper HTTP caching headers

### Test-Driven Development (Principle VI) - NON-NEGOTIABLE
- [ ] Tests are written before implementation code (Red-Green-Refactor cycle)
- [ ] All features have corresponding tests
- [ ] Tests cover happy paths, edge cases, and error conditions
- [ ] Test suite runs quickly and reliably
- [ ] Integration tests cover critical user journeys
- [ ] Unit tests cover business logic

### Quality Standards
- [ ] User interfaces follow consistent design patterns and components
- [ ] Shared Svelte components from `app/frontend/components/ui/` are used
- [ ] Consistent color schemes, typography, and spacing are maintained
- [ ] User-facing text is clear, concise, and uses consistent terminology
- [ ] Loading states and error messages are consistent
- [ ] UI is responsive and works across device sizes
- [ ] Accessibility compliance (WCAG 2.1 AA minimum) is ensured

### Performance Requirements
- [ ] API endpoints respond within 200ms (p95) for standard operations
- [ ] Page loads complete within 2 seconds on 3G connections
- [ ] Database queries are optimized with proper indexing
- [ ] N+1 queries are eliminated through eager loading
- [ ] Frontend bundle size is optimized through code splitting
- [ ] Images and assets are optimized and lazy-loaded
- [ ] Appropriate caching is implemented at multiple levels

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
