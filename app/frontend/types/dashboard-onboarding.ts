export type DashboardOnboardingStepKey = 'form' | 'client' | 'invite' | 'crm';

export type DashboardOnboardingVariant = 'basic' | 'pro';

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
};