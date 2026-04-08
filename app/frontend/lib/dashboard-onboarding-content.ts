import type { DashboardOnboardingStepKey, DashboardOnboardingVariant } from '@/types/dashboard-onboarding';

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