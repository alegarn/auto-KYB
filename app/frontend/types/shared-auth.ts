export type CrmAccessReason =
  | 'allowed'
  | 'subscription_inactive'
  | 'plan_insufficient'
  | 'unauthenticated';

export interface SharedCrmAccess {
  allowed: boolean;
  reason: CrmAccessReason;
  plan_eligible: boolean;
  subscription_active: boolean;
  auto_sync_allowed: boolean;
}

export interface SharedAuth {
  user: {
    id: string;
    email: string;
    onboarding_completed: boolean;
    plan: 'basic' | 'pro';
    crm_auto_sync_on_portal_submit: boolean;
  } | null;
  subscription: {
    status: string | null;
    active: boolean;
    canceled_at: string | null;
  } | null;
  features: {
    crm: SharedCrmAccess;
  } | null;
}
