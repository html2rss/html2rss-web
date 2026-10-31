import { useEffect, useRef, useState } from 'preact/hooks';
import { Notice } from '../components/Notice';
import { PreviewItem } from '../components/PreviewItem';
import { COPY } from '../journey/copy';
import { describeFailure, describeIssue, failureTitle, groupIssues } from './refineModel';
import type { RefineCandidate } from './refineService';
import {
  REFINE_FIELDS,
  isDraftComplete,
  selectorsFromDraft,
  withField,
  withItems,
  type RefineFieldId,
  type RefineSelectors,
} from './selectorDraft';
import { useRefine } from './useRefine';

const FIELD_LABELS: Record<RefineFieldId, string> = {
  title: COPY.refineTitleLabel,
  link: COPY.refineLinkLabel,
  published: COPY.refinePublishedLabel,
};

interface RefineWorkspaceProperties {
  url: string;
  token: string;
  isSaving: boolean;
  saveError?: string;
  onSave: (selectors: RefineSelectors) => void;
  onCancel: () => void;
  onAuthFailure: () => void;
}

const MAX_CHOICES = 5;

interface ChoiceFieldProperties {
  id: string;
  legend: string;
  hint?: string;
  value: string;
  candidates: readonly RefineCandidate[];
  /** Offers a "None" choice. */
  optional?: boolean;
  problems: readonly string[];
  onChange: (value: string, candidate?: RefineCandidate) => void;
}

/** Multiple choice led by what the person recognises (the sample text), with a custom selector as the last resort. */
function ChoiceField({
  id,
  legend,
  hint,
  value,
  candidates,
  optional = false,
  problems,
  onChange,
}: ChoiceFieldProperties) {
  const [customOpen, setCustomOpen] = useState(false);
  const choices = candidates.slice(0, MAX_CHOICES);
  const isCustom =
    customOpen ||
    (choices.length === 0 && !optional) ||
    (value !== '' && choices.every((c) => c.selector !== value));
  const hasChoices = choices.length > 0 || optional;

  return (
    <fieldset class="refine-fieldset">
      <legend class="ui-eyebrow">{legend}</legend>
      {hint && <p class="field-help refine-hint">{hint}</p>}
      {hasChoices && (
        <div class="refine-choices">
          {choices.map((candidate, index) => (
            <label key={candidate.selector} class="refine-choice">
              <input
                type="radio"
                name={id}
                checked={!isCustom && value === candidate.selector}
                onChange={() => {
                  setCustomOpen(false);
                  onChange(candidate.selector, candidate);
                }}
              />
              <span class="refine-choice__body">
                <span class="refine-choice__sample">{candidate.sample || candidate.selector}</span>
                <code class="refine-choice__selector">{candidate.selector}</code>
              </span>
              {index === 0 && <span class="refine-choice__badge">{COPY.refineSuggested}</span>}
            </label>
          ))}
          {optional && (
            <label class="refine-choice">
              <input
                type="radio"
                name={id}
                checked={!isCustom && value === ''}
                onChange={() => {
                  setCustomOpen(false);
                  onChange('');
                }}
              />
              <span class="refine-choice__body">
                <span class="refine-choice__sample">{COPY.refineNone}</span>
              </span>
            </label>
          )}
          {hasChoices && (
            <label class="refine-choice">
              <input type="radio" name={id} checked={isCustom} onChange={() => setCustomOpen(true)} />
              <span class="refine-choice__body">
                <span class="refine-choice__sample">{COPY.refineCustom}</span>
              </span>
            </label>
          )}
        </div>
      )}
      {isCustom && (
        <input
          id={`${id}-custom`}
          class="input input--mono"
          value={value}
          spellcheck={false}
          autoComplete="off"
          autoCapitalize="off"
          aria-label={COPY.refineCustomSelector(legend)}
          aria-invalid={problems.length > 0 || undefined}
          aria-describedby={problems.length > 0 ? `${id}-problems` : undefined}
          onInput={(event) => onChange(event.currentTarget.value)}
        />
      )}
      {problems.length > 0 && (
        <div id={`${id}-problems`} class="layout-stack layout-stack--tight">
          {problems.map((problem) => (
            <span key={problem} class="field-error">
              {problem}
            </span>
          ))}
        </div>
      )}
    </fieldset>
  );
}

/** Correction loop on an almost-right result: choose what each part of an item is, see the extraction, save as a new feed. */
export function RefineWorkspace({
  url,
  token,
  isSaving,
  saveError,
  onSave,
  onCancel,
  onAuthFailure,
}: RefineWorkspaceProperties) {
  const { draft, setDraft, suggestion, issues, preview, canSave, recheck } = useRefine({
    url,
    token,
    onAuthFailure,
  });
  const sectionReference = useRef<HTMLElement>(null);
  const grouped = groupIssues(issues);
  const candidates = suggestion.status === 'ready' ? suggestion.candidates : undefined;
  const problems = (place: keyof typeof grouped) =>
    (grouped[place] ?? []).map((issue) => describeIssue(issue));

  // Move focus to the first choice once there is something to choose; the loading panel announces itself.
  useEffect(() => {
    if (suggestion.status === 'loading') return;
    sectionReference.current?.querySelector<HTMLElement>('input:checked, input:not([type="radio"])')?.focus();
  }, [suggestion.status]);

  return (
    <section
      ref={sectionReference}
      class="layout-stack layout-rail-reading"
      aria-labelledby="refine-heading"
      aria-busy={suggestion.status === 'loading'}
    >
      <header class="layout-stack layout-stack--tight">
        <p class="ui-eyebrow">{COPY.refineEyebrow}</p>
        <h1 id="refine-heading" class="ui-display-title">
          {COPY.refineTitle}
        </h1>
        <p class="field-help refine-url">{url}</p>
      </header>

      {suggestion.status === 'loading' && (
        <>
          <Notice state="loading" title={COPY.refineSuggesting} ariaLive="polite">
            <p>{COPY.refineSuggestingBody}</p>
          </Notice>
          <div class="ui-actions">
            <button type="button" class="btn btn--quiet btn--linkish" onClick={onCancel}>
              {COPY.back}
            </button>
          </div>
        </>
      )}

      {suggestion.status === 'failed' && (
        <Notice tone="error" title={COPY.refineSuggestionsFailed}>
          <p>{COPY.refineSuggestionsFailedBody}</p>
        </Notice>
      )}

      {suggestion.status !== 'loading' && (
        <form
          class="field-stack"
          onSubmit={(event) => {
            event.preventDefault();
            if (canSave) onSave(selectorsFromDraft(draft));
          }}
        >
          <ChoiceField
            id="refine-items"
            legend={COPY.refineItemsLabel}
            hint={COPY.refineItemsHelp}
            value={draft.items}
            candidates={candidates?.items ?? []}
            problems={problems('items')}
            onChange={(value, candidate) => setDraft(withItems(draft, value, candidate?.enhance))}
          />
          {REFINE_FIELDS.map((field) => (
            <ChoiceField
              key={field}
              id={`refine-${field}`}
              legend={FIELD_LABELS[field]}
              value={draft.fields[field]}
              candidates={candidates?.fields[field] ?? []}
              optional={field === 'published'}
              problems={problems(field)}
              onChange={(value) => setDraft(withField(draft, field, value))}
            />
          ))}

          {problems('other').map((problem) => (
            <span key={problem} class="field-error">
              {problem}
            </span>
          ))}

          <div role="status" aria-live="polite" class="refine-preview layout-stack layout-stack--tight">
            {preview.status === 'idle' && !isDraftComplete(draft) && (
              <p id="refine-hint" class="field-help refine-hint">
                {COPY.refineItemsHint}
              </p>
            )}
            {preview.status === 'loading' && <Notice state="loading" title={COPY.previewChecking} />}
            {preview.status === 'failed' && (
              <Notice
                tone="error"
                title={COPY.refinePreviewFailed}
                actions={
                  <button type="button" class="btn btn--ghost" onClick={recheck}>
                    {COPY.refineRecheck}
                  </button>
                }
              >
                <p>{preview.message}</p>
              </Notice>
            )}
            {preview.status === 'ready' && preview.preview.failureKind && (
              <Notice
                tone="error"
                title={failureTitle(preview.preview.failureKind)}
                actions={
                  <button type="button" class="btn btn--ghost" onClick={recheck}>
                    {COPY.refineRecheck}
                  </button>
                }
              >
                <p>{describeFailure(preview.preview.failureKind)}</p>
              </Notice>
            )}
            {preview.status === 'ready' && !preview.preview.failureKind && (
              <>
                <p class="ui-eyebrow">{COPY.previewItemCount(preview.preview.itemCount)}</p>
                <ul class="ui-item-list" role="list">
                  {preview.preview.items.map((item, index) => (
                    <li key={index} class="ui-item">
                      <PreviewItem title={item.title || COPY.refineUntitled} excerpt={item.url} />
                    </li>
                  ))}
                </ul>
              </>
            )}
          </div>

          {saveError && (
            <Notice tone="error" title={COPY.refineSaveFailed}>
              <p>{saveError}</p>
            </Notice>
          )}

          <div class="ui-actions">
            <button
              type="submit"
              class="btn btn--primary"
              disabled={!canSave || isSaving}
              aria-describedby={isDraftComplete(draft) ? undefined : 'refine-hint'}
            >
              {isSaving ? COPY.refineSaving : COPY.refineSave}
            </button>
            <button type="button" class="btn btn--quiet btn--linkish" onClick={onCancel} disabled={isSaving}>
              {COPY.back}
            </button>
          </div>
        </form>
      )}
    </section>
  );
}
