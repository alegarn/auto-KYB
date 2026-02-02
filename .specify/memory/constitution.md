<!--
SYNC IMPACT REPORT
==================
Version Change: 1.0.0 → 1.1.0
Modified Principles: N/A (no principle changes)
Added Sections: N/A
Removed Sections: N/A
Templates Status:
  ✅ plan-template.md - Constitution Check section now includes detailed checkboxes for all 6 principles
  ✅ spec-template.md - Requirements and success criteria align with quality standards
  ✅ tasks-template.md - Fixed constitutional violation: Tests are now MANDATORY (was "OPTIONAL") to align with TDD NON-NEGOTIABLE principle
  ⚠ No command templates found in .specify/templates/commands/
Follow-up TODOs: None
-->

# Quick KYB Constitution

## Core Principles

### I. Code Quality

Code MUST be clean, maintainable, and follow Ruby on Rails community standards. All code MUST pass RuboCop linting with project-specific rules. Code MUST be self-documenting with clear variable and method names. Complex logic MUST be extracted into well-named methods or service objects. All public methods MUST have documentation comments explaining purpose, parameters, and return values.

**Rationale**: High code quality reduces technical debt, improves maintainability, and enables faster feature development. Clean code is easier to debug, test, and extend.

### II. Don't Repeat Yourself (DRY)

Code duplication MUST be eliminated through proper abstraction and reuse. Common functionality MUST be extracted into shared modules, concerns, or service objects. Views MUST use partials and components for repeated UI patterns. Database queries MUST be scoped and reused.

**Rationale**: DRY reduces maintenance burden, ensures consistency, and minimizes bugs from divergent implementations of the same logic.

### III. Convention Over Configuration

Follow Ruby on Rails conventions for naming, file structure, and patterns. Custom configurations MUST only be used when conventions cannot meet requirements. Use Rails generators and standard directory structure. Follow RESTful routing conventions. Use standard Rails callbacks and validations where appropriate.

**Rationale**: Conventions reduce decision fatigue, improve onboarding, and enable developers to understand codebase structure quickly. Following conventions makes the codebase more predictable and maintainable.

### IV. Model-View-Controller Architecture

Maintain strict separation of concerns across MVC layers. Models MUST contain business logic and data access rules. Controllers MUST be thin, handling only request/response orchestration. Views MUST be presentation logic only, with no business logic. Cross-cutting concerns MUST use concerns, services, or decorators appropriately.

**Rationale**: Clear separation of concerns makes code testable, maintainable, and easier to understand. Each layer has a single responsibility, reducing complexity.

### V. RESTful Design

All API endpoints MUST follow RESTful conventions with appropriate HTTP verbs. Resources MUST be nouns and actions MUST be verbs. Use standard Rails resource routing. Responses MUST have appropriate status codes. API MUST be stateless with proper HTTP caching headers.

**Rationale**: RESTful design creates predictable, scalable APIs that are easy to consume and maintain. Following conventions reduces client-side complexity.

### VI. Test-Driven Development (TDD) - NON-NEGOTIABLE

Tests MUST be written before implementation code follows the Red-Green-Refactor cycle. All features MUST have corresponding tests. Tests MUST cover happy paths, edge cases, and error conditions. Test suite MUST run quickly and reliably. Integration tests MUST cover critical user journeys. Unit tests MUST cover business logic.

**Rationale**: TDD ensures code quality, catches regressions early, serves as living documentation, and enables confident refactoring. Tests are the safety net that allows rapid development.

## Quality Standards

### UX Consistency

All user interfaces MUST follow consistent design patterns and components. Use shared Svelte components from `app/frontend/components/ui/`. Maintain consistent color schemes, typography, and spacing. All user-facing text MUST be clear, concise, and use consistent terminology. Loading states and error messages MUST be consistent across the application.

**Rationale**: Consistent UX reduces user confusion, builds trust, and improves usability. Users learn patterns once and apply them throughout the application.

### Modern UI Standards

UI MUST be responsive and work across device sizes. Use modern CSS frameworks and component libraries. Implement smooth transitions and animations that enhance user experience without being distracting. Ensure accessibility compliance (WCAG 2.1 AA minimum). Dark mode support MUST be considered for all features.

**Rationale**: Modern UI standards ensure the application feels current, professional, and provides excellent user experience across all devices and accessibility needs.

## Performance Requirements

### Response Time Targets

API endpoints MUST respond within 200ms (p95) for standard operations. Page loads MUST complete within 2 seconds on 3G connections. Database queries MUST be optimized with proper indexing. N+1 queries MUST be eliminated through eager loading.

### Resource Efficiency

Frontend bundle size MUST be optimized through code splitting. Images and assets MUST be optimized and lazy-loaded. Database connections MUST be properly pooled and released. Memory usage MUST be monitored and optimized for production.

### Caching Strategy

Implement appropriate caching at multiple levels (HTTP caching, fragment caching, query caching). Cache invalidation MUST be handled correctly. Static assets MUST have long cache headers with proper cache busting.

**Rationale**: Performance directly impacts user satisfaction, SEO rankings, and infrastructure costs. Fast applications have higher conversion rates and better user engagement.

## Governance

### Amendment Process

Constitution amendments MUST be documented with clear rationale. Changes MUST be reviewed and approved by the development team. Version MUST follow semantic versioning (MAJOR.MINOR.PATCH). All dependent templates MUST be updated to reflect changes.

### Versioning Policy

- **MAJOR**: Backward incompatible changes, principle removals, or redefinitions
- **MINOR**: New principles or sections added, material guidance expansions
- **PATCH**: Clarifications, wording fixes, non-semantic refinements

### Compliance Review

All pull requests MUST verify constitutional compliance. Code reviews MUST check for violations of core principles. Continuous integration MUST run RuboCop and test suite. Features MUST meet performance requirements before merge.

### Complexity Justification

Any deviation from constitutional principles MUST be explicitly justified. Complexity MUST be documented with reasoning. Simpler alternatives MUST be considered and documented if rejected.

**Version**: 1.1.0 | **Ratified**: 2026-01-28 | **Last Amended**: 2026-02-02
