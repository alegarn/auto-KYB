import { cleanup, render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, expect, test, vi } from 'vitest';

import OnboardingTutorialHost from '../../../../app/frontend/components/onboarding/OnboardingTutorialHost.svelte';

beforeEach(() => {
  document.body.innerHTML = '';
  window.history.replaceState({}, '', '/forms/123/edit?onboarding_tutorial=form_builder_basics');
  HTMLElement.prototype.scrollIntoView = vi.fn();
});

afterEach(() => {
  cleanup();
});

test('runs step actions and exits without a network navigation', async () => {
  const user = userEvent.setup();
  const replaceSpy = vi.spyOn(window.history, 'replaceState');

  const input = document.createElement('input');
  input.id = 'form-name';
  document.body.appendChild(input);

  const palette = document.createElement('div');
  palette.setAttribute('data-onboarding-tutorial', 'form-builder-palette');
  document.body.appendChild(palette);

  const canvas = document.createElement('div');
  canvas.setAttribute('data-onboarding-tutorial', 'form-builder-canvas');
  document.body.appendChild(canvas);

  const previewToggle = document.createElement('button');
  previewToggle.setAttribute('data-onboarding-tutorial', 'form-preview-toggle');
  document.body.appendChild(previewToggle);

  render(OnboardingTutorialHost, { props: { tutorialKey: 'form_builder_basics' } });

  expect(screen.getByText('Rename the form')).toBeInTheDocument();

  await user.click(screen.getByRole('button', { name: 'Focus the name field' }));
  expect(document.activeElement).toBe(input);

  await user.click(screen.getByRole('button', { name: 'Quit tutorial' }));
  expect(replaceSpy).toHaveBeenCalled();
  expect(window.location.search).toBe('');
});