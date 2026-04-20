export const ALLOWED_VARIABLES: string[] = [
  '{{client_name}}',
  '{{client_email}}',
  '{{form_name}}',
  '{{invite_link}}',
  '{{password}}',
];

export const DEFAULT_SUBJECT = 'Your Quick KYB secure form access';

export const DEFAULT_BODY =
  'Hello {{client_name}},\n\n' +
  'You have been invited to fill out the {{form_name}} form on Quick KYB.\n\n' +
  'Access your portal here: {{invite_link}}\n\n' +
  'Your portal password: {{password}}\n\n' +
  'Please keep these credentials safe, as the password is shown only once.';

export const PREVIEW_VARIABLES: Record<string, string> = {
  '{{client_name}}': 'Jane Doe',
  '{{client_email}}': 'jane@example.com',
  '{{form_name}}': 'KYB Onboarding',
  '{{invite_link}}': 'https://app.quick-kyb.com/client_portal/login/abc123',
  '{{password}}': 'SamplePass42',
};

/** Replaces {{variable}} tokens in a template string using the supplied map. */
export function renderTemplate(template: string, variables: Record<string, string>): string {
  return template.replace(/\{\{[a-z_]+\}\}/g, (m) => variables[m] ?? m);
}

export interface InviteEmailSetting {
  auto_send: boolean;
  subject_template: string | null;
  body_template: string | null;
}
