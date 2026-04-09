export type DashboardOnboardingStepKey = 'form' | 'client' | 'invite' | 'review' | 'crm';

export type DashboardOnboardingVariant = 'basic' | 'pro';

export type GuideKey = 'form_builder' | 'client_workflow' | 'crm_sync';

export type GuideTip = {
  title: string;
  body: string;
  href?: string;
};

export type Guide = {
  key: GuideKey;
  title: string;
  description: string;
  icon: string;
  pro_only: boolean;
  tips: GuideTip[];
};

export type DashboardOnboardingStep = {
  key: DashboardOnboardingStepKey;
  complete: boolean;
  href: string | null;
};

export type DashboardOnboarding = {
  visible: boolean;
  variant: DashboardOnboardingVariant;
  progress_percent: number;
  completion_rule: 'basic_core' | 'pro_with_crm';
  quick_steps: DashboardOnboardingStep[];
  can_dismiss: boolean;
  detailed_view_seen: boolean;
  guides_seen: Record<string, string | null>;
};