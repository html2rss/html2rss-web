import { useEffect, useRef, useState } from 'preact/hooks';
import { Notice } from '../components/Notice';
import { PreviewItem } from '../components/PreviewItem';
import { COPY } from '../journey/copy';
import { FIELD_LABELS, describeFailure, describeIssue, groupIssues } from './refineModel';
import type { RefineCandidate } from './refineService';
import {
  REFINE_FIELDS,
  selectorsFromDraft,
  withEnhance,
  withField,
  withItems,
  type RefineSelectors,
} from './selectorDraft';
import { useRefine } from './useRefine';

const MAX_CHOICES = 5;
const MAX_SAMPLE_LENGTH = 24;
const CUSTOM = '__custom__';

interface RefineWorkspaceProperties {
  url: string;
  token: string;
  isSaving: boolean;
  saveError?: string;
  onSave: (selectors: RefineSelectors) => void;
  onCancel: () => void;
  onAuthFailure: () => void;
}

interface SelectFieldProperties {
  id: string;
  label: string;
  value: string;
  candidates: readonly RefineCandidate[];
  /** Offers a "None" choice. */
  optional?: boolean;
  problems: readonly string[];
  onChange: (value: string, candidate?: RefineCandidate) => void;
}

function optionLabel({ sample, selector }: RefineCandidate): string {
  const text = sample.length > MAX_SAMPLE_LENGTH ? `${sample.slice(0, MAX_SAMPLE_LENGTH)}…` : sample;
  return text ? `${text} · ${selector}` : selector;
}

/** One part of an item: pick a suggestion, or fall back to a custom selector. */
function SelectField({
  id,
  label,
  value,
  candidates,
  optional = false,
  problems,
  onChange,
}: SelectFieldProperties) {
  const [customOpen, setCustomOpen] = useState(false);
  const choices = candidates.slice(0, MAX_CHOICES);
  const hasSelect = choices.length > 0 || optional;
  const isCustom = customOpen || !hasSelect || (value !== '' && choices.every((c) => c.selector !== value));

  return (
    <div class="field-block">
      <label class="ui-eyebrow" htmlFor={id}>
        {label}
      </label>
      {hasSelect && (
        <select
          id={id}
          class="input"
          value={isCustom ? CUSTOM : value}
          onChange={(event) => {
            const next = event.currentTarget.value;
            setCustomOpen(next === CUSTOM);
            if (next !== CUSTOM)
              onChange(
                next,
                choices.find((c) => c.selector === next)
              );
          }}
        >
          {choices.map((candidate) => (
            <option key={candidate.selector} value={candidate.selector}>
              {optionLabel(candidate)}
            </option>
          ))}
          {optional && <option value="">{COPY.refineNone}</option>}
          <option value={CUSTOM}>{COPY.refineCustom}</option>
        </select>
      )}
      {isCustom && (
        <input
          id={hasSelect ? `${id}-custom` : id}
          class="input input--mono"
          value={value}
          placeholder={COPY.refineSelectorPlaceholder}
          spellcheck={false}
          autoComplete="off"
          autoCapitalize="off"
          aria-label={hasSelect ? COPY.refineCustomSelector(label) : undefined}
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
    </div>
  );
}

/** Correction loop on an almost-right result: choose each part of an item, watch the result, create a new feed. */
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
  const isLoading = suggestion.status === 'loading';
  const sectionReference = useRef<HTMLElement>(null);
  const grouped = groupIssues(issues);
  const candidates = suggestion.status === 'ready' ? suggestion.candidates : undefined;
  const problems = (place: keyof typeof grouped) =>
    (grouped[place] ?? []).map((issue) => describeIssue(issue));

  // Move focus to the first control once there is something to choose; the loading panel announces itself.
  useEffect(() => {
    if (suggestion.status === 'loading') return;
    sectionReference.current?.querySelector<HTMLElement>('select, input')?.focus();
  }, [suggestion.status]);

  const retry = (
    <button type="button" class="btn btn--ghost" onClick={recheck}>
      {COPY.tryAgain}
    </button>
  );

  return (
    <section
      ref={sectionReference}
      class="refine-shell layout-stack"
      aria-labelledby="refine-heading"
      aria-busy={isLoading}
    >
      <header class="layout-stack layout-stack--tight">
        <h1 id="refine-heading" class="ui-display-title">
          {COPY.refineTitle}
        </h1>
        <p class="field-help refine-note">{COPY.refineHint}</p>
      </header>

      <form
        class="refine-grid"
        onSubmit={(event) => {
          event.preventDefault();
          if (canSave) onSave(selectorsFromDraft(draft));
        }}
      >
        <div class="refine-fields field-stack">
          {isLoading && (
            <Notice state="loading" title={COPY.refineSuggesting} ariaLive="polite">
              <p>{COPY.refineSuggestingBody}</p>
            </Notice>
          )}
          {suggestion.status === 'failed' && (
            <p class="field-help refine-note">{COPY.refineSuggestionsFailed}</p>
          )}
          {!isLoading && (
            <SelectField
              id="refine-items"
              label={COPY.refineItemsLabel}
              value={draft.items}
              candidates={candidates?.items ?? []}
              problems={problems('items')}
              onChange={(value, candidate) => setDraft(withItems(draft, value, candidate?.enhance))}
            />
          )}
          {!isLoading && (
            <label class="refine-check">
              <input
                type="checkbox"
                checked={draft.enhance}
                onChange={(event) => setDraft(withEnhance(draft, event.currentTarget.checked))}
              />
              <span>
                {COPY.refineEnhanceLabel}
                <span class="field-help">{COPY.refineEnhanceHint}</span>
              </span>
            </label>
          )}
          {!isLoading &&
            REFINE_FIELDS.map((field) => (
              <SelectField
                key={field}
                id={`refine-${field}`}
                label={FIELD_LABELS[field]}
                value={draft.fields[field]}
                candidates={candidates?.fields[field] ?? []}
                optional={field === 'published'}
                problems={problems(field)}
                onChange={(value) => setDraft(withField(draft, field, value))}
              />
            ))}
          {!isLoading &&
            problems('other').map((problem) => (
              <span key={problem} class="field-error">
                {problem}
              </span>
            ))}
        </div>

        <div
          role="status"
          aria-live="polite"
          hidden={isLoading}
          class="refine-result layout-stack layout-stack--tight"
        >
          {preview.status === 'idle' && <p class="field-help refine-note">{COPY.refineResultIdle}</p>}
          {preview.status === 'loading' && <Notice state="loading" title={COPY.previewChecking} />}
          {preview.status === 'failed' && (
            <Notice tone="error" title={COPY.refinePreviewFailed} actions={retry}>
              <p>{preview.message}</p>
            </Notice>
          )}
          {preview.status === 'ready' && preview.preview.failureKind && (
            <Notice
              tone="error"
              title={describeFailure(preview.preview.failureKind)}
              actions={preview.preview.failureKind === 'execution' ? undefined : retry}
            />
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

        <div class="refine-actions layout-stack layout-stack--tight">
          {saveError && (
            <Notice tone="error" title={COPY.refineSaveFailed}>
              <p>{saveError}</p>
            </Notice>
          )}
          <div class="ui-actions">
            {!isLoading && (
              <button type="submit" class="btn btn--primary" disabled={!canSave || isSaving}>
                {isSaving ? COPY.creating : COPY.createFeed}
              </button>
            )}
            <button type="button" class="btn btn--quiet btn--linkish" onClick={onCancel} disabled={isSaving}>
              {COPY.back}
            </button>
          </div>
        </div>
      </form>
    </section>
  );
}
