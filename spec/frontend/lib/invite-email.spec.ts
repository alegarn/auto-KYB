import { describe, it, expect } from 'vitest';
import {
  ALLOWED_VARIABLES,
  DEFAULT_SUBJECT,
  DEFAULT_BODY,
  PREVIEW_VARIABLES,
  renderTemplate,
} from '@/lib/invite-email';

describe('ALLOWED_VARIABLES', () => {
  it('contains the five expected tokens', () => {
    expect(ALLOWED_VARIABLES).toEqual([
      '{{client_name}}',
      '{{client_email}}',
      '{{form_name}}',
      '{{invite_link}}',
      '{{password}}',
    ]);
  });

  it('contains only strings', () => {
    ALLOWED_VARIABLES.forEach((v) => expect(typeof v).toBe('string'));
  });
});

describe('DEFAULT_SUBJECT', () => {
  it('is a non-empty string', () => {
    expect(typeof DEFAULT_SUBJECT).toBe('string');
    expect(DEFAULT_SUBJECT.length).toBeGreaterThan(0);
  });

  it('contains no template tokens (safe to use as-is)', () => {
    expect(DEFAULT_SUBJECT).not.toMatch(/\{\{[a-z_]+\}\}/);
  });
});

describe('DEFAULT_BODY', () => {
  const BODY_VARIABLES = ['{{client_name}}', '{{form_name}}', '{{invite_link}}', '{{password}}'];

  it('contains the variables used in the default template', () => {
    for (const variable of BODY_VARIABLES) {
      expect(DEFAULT_BODY).toContain(variable);
    }
  });

  it('does not require {{client_email}} (optional variable not in default body)', () => {
    // {{client_email}} is an allowed variable but is not required in the default body template
    expect(ALLOWED_VARIABLES).toContain('{{client_email}}');
    expect(DEFAULT_BODY).not.toContain('{{client_email}}');
  });

  it('contains multiline content', () => {
    expect(DEFAULT_BODY).toContain('\n');
  });
});

describe('PREVIEW_VARIABLES', () => {
  it('provides a sample value for every allowed variable', () => {
    for (const variable of ALLOWED_VARIABLES) {
      expect(PREVIEW_VARIABLES).toHaveProperty(variable);
      expect(typeof PREVIEW_VARIABLES[variable]).toBe('string');
      expect(PREVIEW_VARIABLES[variable].length).toBeGreaterThan(0);
    }
  });
});

describe('renderTemplate', () => {
  it('replaces known tokens with provided values', () => {
    const result = renderTemplate('Hello {{client_name}}!', { '{{client_name}}': 'Jane' });
    expect(result).toBe('Hello Jane!');
  });

  it('leaves unknown tokens intact', () => {
    const result = renderTemplate('Hello {{unknown}}!', { '{{client_name}}': 'Jane' });
    expect(result).toBe('Hello {{unknown}}!');
  });

  it('replaces multiple distinct tokens in one pass', () => {
    const result = renderTemplate(
      '{{client_name}} — {{form_name}}',
      { '{{client_name}}': 'Jane', '{{form_name}}': 'KYB' },
    );
    expect(result).toBe('Jane — KYB');
  });

  it('replaces the same token appearing multiple times', () => {
    const result = renderTemplate(
      '{{client_name}} / {{client_name}}',
      { '{{client_name}}': 'Jane' },
    );
    expect(result).toBe('Jane / Jane');
  });

  it('returns the template unchanged when variable map is empty', () => {
    const tpl = 'Hello {{client_name}}!';
    expect(renderTemplate(tpl, {})).toBe(tpl);
  });

  it('renders the DEFAULT_BODY with PREVIEW_VARIABLES without leftover tokens', () => {
    const result = renderTemplate(DEFAULT_BODY, PREVIEW_VARIABLES);
    expect(result).not.toMatch(/\{\{[a-z_]+\}\}/);
  });

  it('renders the DEFAULT_SUBJECT with PREVIEW_VARIABLES without leftover tokens', () => {
    const result = renderTemplate(DEFAULT_SUBJECT, PREVIEW_VARIABLES);
    expect(result).not.toMatch(/\{\{[a-z_]+\}\}/);
  });

  it('handles an empty template string', () => {
    expect(renderTemplate('', { '{{client_name}}': 'Jane' })).toBe('');
  });
});
