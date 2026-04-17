import type { CrmMappingValidationIssue, CrmMappingValidationIssueGroups } from './types';

export function groupCrmValidationIssues(
  issues: CrmMappingValidationIssue[] = [],
): CrmMappingValidationIssueGroups {
  return issues.reduce<CrmMappingValidationIssueGroups>((groupedIssues, issue) => {
    if (!groupedIssues[issue.provider]) {
      groupedIssues[issue.provider] = {};
    }

    if (!groupedIssues[issue.provider][issue.field_key]) {
      groupedIssues[issue.provider][issue.field_key] = [];
    }

    groupedIssues[issue.provider][issue.field_key].push(issue);
    return groupedIssues;
  }, {});
}

export function countCrmValidationIssuesForProvider(
  issues: CrmMappingValidationIssueGroups,
  provider: string,
): number {
  return Object.values(issues[provider] || {}).reduce((count, fieldIssues) => count + fieldIssues.length, 0);
}
