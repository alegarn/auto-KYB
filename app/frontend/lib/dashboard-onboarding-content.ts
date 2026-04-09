import type { DashboardOnboardingStepKey, DashboardOnboardingVariant, Guide, GuideKey } from '@/types/dashboard-onboarding';

type VariantContent = {
  eyebrow: string;
  title: string;
  description: string;
  detailsTitle: string;
  detailsDescription: string;
};

type StepContent = {
  quickLabel: string;
  quickDescription: string;
  detailsTitle: string;
  detailsBody: string;
  ctaLabel: string;
};

const VARIANT_CONTENT: Record<DashboardOnboardingVariant, VariantContent> = {
  basic: {
    eyebrow: 'Dashboard onboarding',
    title: 'Launch your first client workflow',
    description: 'Your default form is ready. Review it, add a client, and share secure access from the dashboard flow.',
    detailsTitle: 'Detailed onboarding',
    detailsDescription: 'Follow the same checklist with a bit more guidance so you can go from blank dashboard to real client handoff.'
  },
  pro: {
    eyebrow: 'Pro onboarding',
    title: 'Set up your client workflow and CRM handoff',
    description: 'Finish the core checklist, then connect your CRM so exports and follow-up work stay in one flow.',
    detailsTitle: 'Detailed pro onboarding',
    detailsDescription: 'Use the core checklist first, then wire the CRM step so your onboarding flow can move from local records to connected operations.'
  }
};

const STEP_CONTENT: Record<DashboardOnboardingStepKey, StepContent> = {
  form: {
    quickLabel: 'Review or create a new form',
    quickDescription: 'A default form already exists, so the next move is to review it and shape it to your workflow.',
    detailsTitle: 'Review or customize your default form',
    detailsBody: 'Open your existing form, rename it if needed, and adjust the fields so the first client receives a workflow that matches your onboarding process.',
    ctaLabel: 'Open form'
  },
  client: {
    quickLabel: 'Add a client',
    quickDescription: 'Create the first client record that will receive your onboarding form and hold the submitted results.',
    detailsTitle: 'Create the first client record',
    detailsBody: 'Add the core company and contact details you already know so the dashboard can track real onboarding progress instead of placeholder data.',
    ctaLabel: 'Open client workspace'
  },
  invite: {
    quickLabel: 'Share secure access',
    quickDescription: 'Link a client to a form and create the secure client subspace that gives them access to the portal.',
    detailsTitle: 'Create and share secure client access',
    detailsBody: 'From the client page, create the client subspace, reveal the one-time password, and share the secure portal access so the client can begin the onboarding flow.',
    ctaLabel: 'Open client page'
  },
  review: {
    quickLabel: 'Monitor & Export data',
    quickDescription: 'Once a client fills out their form, their status changes. Validate their data and export the results to CSV.',
    detailsTitle: 'Monitor submissions and export results',
    detailsBody: 'After you share the link, your client will fill out the form. The client state evolves to "Active", and once approved, to "Validated". At that point, you can easily export the data to integrate into your existing tools.',
    ctaLabel: 'View clients'
  },
  crm: {
    quickLabel: 'Connect your CRM',
    quickDescription: 'Enable the CRM connection so you can manage manual export and automatic sync from the real settings flow.',
    detailsTitle: 'Connect your CRM from Settings',
    detailsBody: 'Use the CRM settings area to connect the provider, decide how manual export differs from automatic sync, and review transfer failures from the CRM Transfers page when something needs attention.',
    ctaLabel: 'Open settings'
  }
};

export function getDashboardOnboardingVariantContent(variant: DashboardOnboardingVariant): VariantContent {
  return VARIANT_CONTENT[variant];
}

export function getDashboardOnboardingStepContent(stepKey: DashboardOnboardingStepKey): StepContent {
  return STEP_CONTENT[stepKey];
}

const GUIDE_CONTENT: Record<GuideKey, Guide> = {
  form_builder: {
    key: 'form_builder',
    title: 'Form Builder',
    description: 'Discover field types, layout options, validation, and export settings.',
    icon: '📝',
    pro_only: false,
    tips: [
      {
        title: 'Field types available',
        body: 'You can add text, textarea, email, phone, number, date, checkbox, select, radio, file upload, country, and more. Each field can be marked as required.',
      },
      {
        title: 'Drag-and-drop ordering',
        body: 'Reorder fields by dragging them. The order in the builder is the order your client sees in the portal.',
      },
      {
        title: 'Layout sections',
        body: 'Group related fields under section headings to keep long forms organized and readable.',
      },
      {
        title: 'Table / repeatable rows',
        body: 'Use table fields to let clients add multiple rows — useful for listing shareholders, subsidiaries, or documents.',
      },
      {
        title: 'Export key transforms',
        body: 'Each field has an export key. You can switch between snake_case, camelCase, and kebab-case to match the system you import into.',
        href: '/forms',
      },
      {
        title: 'Live preview',
        body: 'Use the preview button to see the form exactly as your client will. Check the flow before sharing access.',
        href: '/forms',
      },
    ],
  },
  client_workflow: {
    key: 'client_workflow',
    title: 'Client Workflow',
    description: 'Learn about client records, lifecycle states, portal access, and data export.',
    icon: '👥',
    pro_only: false,
    tips: [
      {
        title: 'Client record basics',
        body: 'Each client holds a company name, contact email, and any custom fields you added. The record is the container for all onboarding data.',
      },
      {
        title: 'Client lifecycle',
        body: 'Clients move through states: Inactive → Linked → Active → Validated. The state updates automatically when they complete the form and you approve.',
      },
      {
        title: 'Portal & secure access',
        body: 'Creating a subspace generates a unique portal link and a one-time password. Share both so the client can access their form securely.',
      },
      {
        title: 'CSV export',
        body: 'Select one or more clients, then export to CSV. The file uses the export keys from your form fields.',
        href: '/clients',
      },
      {
        title: 'JSON export',
        body: 'For API-style integrations, export client data as JSON. Same field mapping, different format.',
        href: '/clients',
      },
      {
        title: 'File uploads & attachments',
        body: 'Clients can upload documents through file fields. View and download them from the client detail page.',
      },
    ],
  },
  crm_sync: {
    key: 'crm_sync',
    title: 'CRM Integration',
    description: 'Connect HubSpot, Salesforce, or Zoho and automate data transfer.',
    icon: '🔗',
    pro_only: true,
    tips: [
      {
        title: 'Connecting a CRM',
        body: 'Go to Settings → CRM, choose your provider (HubSpot, Salesforce, or Zoho), and complete the OAuth flow. Connection takes under a minute.',
        href: '/settings/crm',
      },
      {
        title: 'Field mapping',
        body: 'Map your form fields to CRM properties. Unmapped fields are skipped during export. You can update mappings at any time.',
        href: '/settings/crm',
      },
      {
        title: 'Create vs. Link mode',
        body: 'Choose whether exports create a new CRM record each time or link to an existing one based on email or company name.',
      },
      {
        title: 'Manual export',
        body: 'From the client page, manually push one client at a time to your CRM. Useful for testing mappings before enabling auto-sync.',
      },
      {
        title: 'Auto-sync',
        body: 'Enable auto-sync so validated clients are exported to your CRM automatically. No manual step needed after approval.',
      },
      {
        title: 'Transfer monitoring',
        body: 'The CRM Transfers page shows every export attempt — successful or failed. Retry failed transfers or inspect errors from there.',
        href: '/crm_transfers',
      },
      {
        title: 'Change behavior on re-export',
        body: 'If a client is updated after the first export, re-exporting updates the existing CRM record instead of creating a duplicate.',
      },
    ],
  },
};

export function getGuides(variant: DashboardOnboardingVariant): Guide[] {
  const all = Object.values(GUIDE_CONTENT);
  if (variant === 'basic') return all.filter((g) => !g.pro_only);
  return all;
}

export function getGuide(key: GuideKey): Guide {
  return GUIDE_CONTENT[key];
}