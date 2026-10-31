import { useEffect, useRef } from 'preact/hooks';
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

interface SelectorFieldProperties {
  id: string;
  label: string;
  value: string;
  candidates: readonly RefineCandidate[];
  problems: readonly string[];
  inputRef?: { current: HTMLInputElement | null };
  onInput: (value: string, candidate?: RefineCandidate) => void;
}

function SelectorField({
  id,
  label,
  value,
  candidates,
  problems,
  inputRef,
  onInput,
}: SelectorFieldProperties) {
  return (
    <div class="field-block field-block--stretch">
      <label class="ui-eyebrow" htmlFor={id}>
        {label}
      </label>
      <input
        id={id}
        ref={inputRef}
        class="input input--mono"
        value={value}
        spellcheck={false}
        autoComplete="off"
        autoCapitalize="off"
        aria-invalid={problems.length > 0 || undefined}
        aria-describedby={problems.length > 0 ? `${id}-problems` : undefined}
        onInput={(event) => onInput(event.currentTarget.value)}
      />
      {problems.length > 0 && (
        <div id={`${id}-problems`} class="layout-stack layout-stack--tight">
          {problems.map((problem) => (
            <span key={problem} class="field-error">
              {problem}
            </span>
          ))}
        </div>
      )}
      {/* A lone suggestion already in the field adds nothing. */}
      {(candidates.length > 1 || (candidates.length === 1 && candidates[0].selector !== value)) && (
        <ul class="refine-suggestions" role="list" aria-label={COPY.refineSuggestions(label)}>
          {candidates.slice(0, 4).map((candidate) => (
            <li key={candidate.selector} class="refine-suggestions__item">
              <button
                type="button"
                class="btn btn--ghost refine-suggestions__chip"
                aria-pressed={candidate.selector === value}
                onClick={() => onInput(candidate.selector, candidate)}
              >
                <code>{candidate.selector}</code>
              </button>
              {candidate.sample && <span class="refine-suggestions__sample">{candidate.sample}</span>}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/** Correction loop on an almost-right result: edit selectors, see the extraction, save as a new feed. */
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
  const itemsReference = useRef<HTMLInputElement>(null);
  const grouped = groupIssues(issues);
  const candidates = suggestion.status === 'ready' ? suggestion.candidates : undefined;
  const problems = (place: keyof typeof grouped) =>
    (grouped[place] ?? []).map((issue) => describeIssue(issue));

  useEffect(() => {
    itemsReference.current?.focus();
  }, []);

  return (
    <section class="layout-stack layout-rail-reading" aria-labelledby="refine-heading">
      <header class="layout-stack layout-stack--tight">
        <p class="ui-eyebrow">{COPY.refineEyebrow}</p>
        <h1 id="refine-heading" class="ui-display-title">
          {COPY.refineTitle}
        </h1>
        <p class="field-help refine-url">{url}</p>
      </header>

      {/* One fixed-height line so the form below does not move when suggestions arrive. */}
      <p class="field-help refine-status" role="status">
        {suggestion.status === 'loading' && COPY.refineSuggesting}
        {suggestion.status === 'failed' && COPY.refineSuggestionsFailed}
      </p>

      <form
        class="field-stack"
        onSubmit={(event) => {
          event.preventDefault();
          if (canSave) onSave(selectorsFromDraft(draft));
        }}
      >
        <SelectorField
          id="refine-items"
          label={COPY.refineItemsLabel}
          value={draft.items}
          candidates={candidates?.items ?? []}
          problems={problems('items')}
          inputRef={itemsReference}
          onInput={(value, candidate) => setDraft(withItems(draft, value, candidate?.enhance))}
        />
        {REFINE_FIELDS.map((field) => (
          <SelectorField
            key={field}
            id={`refine-${field}`}
            label={FIELD_LABELS[field]}
            value={draft.fields[field]}
            candidates={candidates?.fields[field] ?? []}
            problems={problems(field)}
            onInput={(value) => setDraft(withField(draft, field, value))}
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
                {preview.preview.items.map((item) => (
                  <li key={`${item.title}-${item.url}`} class="ui-item">
                    <PreviewItem title={item.title} excerpt={item.url} />
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
    </section>
  );
}
