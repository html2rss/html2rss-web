import { useEffect, useRef } from 'preact/hooks';
import { Notice } from '../components/Notice';
import { PreviewItem } from '../components/PreviewItem';
import { COPY } from '../journey/copy';
import { describeFailure, describeIssue, groupIssues } from './refineModel';
import type { RefineCandidate } from './refineService';
import {
  REFINE_FIELDS,
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
        onInput={(event) => onInput(event.currentTarget.value)}
      />
      {problems.map((problem) => (
        <span key={problem} class="field-error">
          {problem}
        </span>
      ))}
      {candidates.length > 0 && (
        <ul class="refine-suggestions" role="list" aria-label={COPY.refineSuggestions(label)}>
          {candidates.slice(0, 4).map((candidate) => (
            <li key={candidate.selector}>
              <button
                type="button"
                class="btn btn--quiet btn--linkish"
                aria-pressed={candidate.selector === value}
                title={candidate.sample}
                onClick={() => onInput(candidate.selector, candidate)}
              >
                <code>{candidate.selector}</code>
                {candidate.sample && <span class="refine-suggestions__sample"> {candidate.sample}</span>}
              </button>
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
}: RefineWorkspaceProperties) {
  const { draft, setDraft, suggestion, issues, preview, canSave } = useRefine({ url, token });
  const itemsReference = useRef<HTMLInputElement>(null);
  const grouped = groupIssues(issues);
  const candidates = suggestion.status === 'ready' ? suggestion.candidates : undefined;
  const problems = (place: keyof typeof grouped) =>
    (grouped[place] ?? []).map((issue) => describeIssue(issue));

  useEffect(() => {
    itemsReference.current?.focus();
  }, []);

  return (
    <section class="refine-shell layout-stack layout-rail-reading" aria-labelledby="refine-heading">
      <header class="layout-stack layout-stack--tight">
        <p class="ui-eyebrow">{COPY.refineEyebrow}</p>
        <h1 id="refine-heading" class="result-title ui-display-title">
          {COPY.refineTitle}
        </h1>
        <p class="field-help">{url}</p>
      </header>

      {suggestion.status === 'loading' && (
        <Notice state="loading" title={COPY.refineSuggesting} ariaLive="polite" />
      )}
      {suggestion.status === 'failed' && (
        <Notice tone="error" title={COPY.refineSuggestionsFailed}>
          <p>{COPY.refineSuggestionsFailedBody}</p>
        </Notice>
      )}

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

        <div role="status" aria-live="polite" class="layout-stack layout-stack--tight">
          {preview.status === 'loading' && <Notice state="loading" title={COPY.previewChecking} />}
          {preview.status === 'failed' && (
            <Notice tone="error" title={COPY.refinePreviewFailed}>
              <p>{preview.message}</p>
            </Notice>
          )}
          {preview.status === 'ready' && preview.preview.failureKind && (
            <Notice tone="error" title={COPY.refineNoResult}>
              <p>{describeFailure(preview.preview.failureKind)}</p>
            </Notice>
          )}
          {preview.status === 'ready' && !preview.preview.failureKind && (
            <>
              <p class="ui-eyebrow">{COPY.previewItemCount(preview.preview.itemCount)}</p>
              <ul class="ui-item-list" role="list">
                {preview.preview.items.map((item) => (
                  <li key={`${item.title}-${item.url}`} class="ui-item">
                    <PreviewItem title={item.title} excerpt="" url={item.url} publishedLabel="" />
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
          <button type="submit" class="btn btn--primary" disabled={!canSave || isSaving}>
            {isSaving ? COPY.creating : COPY.refineSave}
          </button>
          <button type="button" class="btn btn--quiet btn--linkish" onClick={onCancel} disabled={isSaving}>
            {COPY.back}
          </button>
        </div>
      </form>
    </section>
  );
}
