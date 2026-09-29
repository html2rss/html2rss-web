import type { ComponentChildren, JSX } from 'preact';
import { useEffect, useRef, useState } from 'preact/hooks';
import { COPY } from '../journey/copy';
import { PreviewFeedback } from '../components/PreviewFeedback';
import { PreviewItem } from '../components/PreviewItem';
import { Notice } from '../components/Notice';
import { useClipboard } from '../hooks/useClipboard';
import {
  hasEverySelectorPart,
  STUDIO_FIELDS,
  type StudioFieldId,
  type StudioSelectors,
} from './selectorDraft';
import { canSaveStudio, studioIssues, studioPreviewSample, useStudio, type StudioState } from './useStudio';
import { buildDirectoryIssueHref } from './directoryHandoff';
import type { StudioFieldCandidate, StudioSuggestionState, StudioEditorMode } from './studioModel';
import {
  dormantStudioFields,
  groupStudioIssues,
  studioFieldSurfaces,
  studioSavePresentation,
} from './studioModel';
import type { StudioSampleItem } from './studioService';

/** Authenticated studio session. Absent ⇒ guest / studio-off. */
export interface AuthenticatedStudioCapability {
  readonly token: string;
  readonly url: string;
  readonly onGenerate: (selectors: StudioSelectors) => Promise<void>;
}

const FIELD_LABEL: Record<StudioFieldId, string> = {
  title: COPY.fieldTitle,
  link: COPY.fieldLink,
  published: COPY.fieldPublished,
};

interface ConfigStudioProperties {
  readonly url: string;
  readonly token: string;
  readonly mode: StudioEditorMode;
  readonly onGenerate: (selectors: StudioSelectors) => Promise<void>;
  readonly fallback?: ComponentChildren;
  readonly directoryHandoff?: boolean;
  /** Unresolved Decision#message — studio must not re-echo. */
  readonly decisionNotice?: string;
}

export function ConfigStudio(properties: ConfigStudioProperties) {
  const { url, token, mode, onGenerate, fallback, directoryHandoff = false, decisionNotice } = properties;
  const studio = useStudio({ url, token });
  const { state, suggestion, isDirty } = studio;
  const issues = groupStudioIssues(studioIssues(state));
  const [manualFields, setManualFields] = useState<ReadonlySet<StudioFieldId>>(() => new Set());
  const [focusField, setFocusField] = useState<StudioFieldId | undefined>();
  const fieldInputReferences = useRef<Partial<Record<StudioFieldId, HTMLInputElement | null>>>({});
  const { feedback, copy } = useClipboard();
  const sample = studioPreviewSample(state.live);
  const sampleItems = sample?.items ?? [];
  const isBusy = state.phase === 'validating' || state.phase === 'saving' || state.live.status === 'loading';
  const save = studioSavePresentation(mode, canSaveStudio(state), isDirty);
  const surfaces = studioFieldSurfaces(state.draft, suggestion, issues, manualFields);
  const dormantFields = dormantStudioFields(surfaces);
  const readyCandidates = suggestion.status === 'ready' ? suggestion.candidates : undefined;

  useEffect(() => {
    if (focusField === undefined) return;
    fieldInputReferences.current[focusField]?.focus();
    setFocusField(undefined);
  }, [focusField]);

  const shouldShowCreateMeadow =
    fallback !== undefined && sample === undefined && state.live.status !== 'failed';
  const meadow = shouldShowCreateMeadow ? (
    <>
      {fallback}
      {state.live.status === 'loading' ? (
        <div class="layout-rail-reading">
          <PreviewFeedback tone="loading">{COPY.previewChecking}</PreviewFeedback>
        </div>
      ) : undefined}
    </>
  ) : (
    <PreviewPane state={state} token={token} onRetry={studio.retryPreview} />
  );

  return (
    <div class="layout-stack" aria-busy={isBusy} data-clipboard={feedback}>
      <div class="layout-rail-reading layout-stack studio-controls">
        {state.phase === 'failed' && !isSameNotice(state.message, decisionNotice) ? (
          <Notice title={COPY.createFailedTitle} tone="error">
            {state.message.trim() && state.message !== COPY.createFailedTitle ? (
              <p>{state.message}</p>
            ) : undefined}
          </Notice>
        ) : undefined}

        <div class="studio-suggestion-status">
          <SuggestionStatus
            suggestion={suggestion}
            decisionNotice={decisionNotice}
            onRetry={studio.retrySuggestion}
          />
        </div>

        <div class="studio-fields">
          <div class="studio-field">
            <FieldBlock
              id="studio-items-selector"
              label={COPY.itemsSelector}
              value={state.draft.itemsSelector}
              errors={issues.items.map((issue) => issue.message)}
              onInput={(value) => studio.setItemsSelector(value)}
            />
            <ChoiceChips
              label={COPY.selectorChoices}
              current={state.draft.itemsSelector}
              choices={readyCandidates?.items ?? []}
              onToggle={studio.toggleItemsSelector}
            />
          </div>

          {STUDIO_FIELDS.map((field) => {
            if (surfaces[field].status !== 'visible') return;
            const label = FIELD_LABEL[field];
            return (
              <div key={field} class="studio-field">
                <FieldBlock
                  id={`studio-field-${field}`}
                  label={fieldStatusLabel(label, sample, sampleItems, field)}
                  ariaLabel={`${label} ${COPY.selector}`}
                  value={state.draft.fields[field].selector}
                  inputReference={(element) => {
                    fieldInputReferences.current[field] = element;
                  }}
                  errors={issues.fields[field].map((issue) => issue.message)}
                  onInput={(value) => studio.setFieldSelector(field, value)}
                />
                <ChoiceChips
                  label={COPY.choicesFor(label)}
                  current={state.draft.fields[field].selector}
                  choices={readyCandidates?.fields[field] ?? []}
                  onToggle={(selector) => studio.toggleFieldSelector(field, selector)}
                />
              </div>
            );
          })}

          {dormantFields.length > 0 ? (
            <div class="studio-manual" role="group" aria-label={COPY.addOptionalFields}>
              {dormantFields.map((field) => (
                <button
                  key={field}
                  type="button"
                  class="btn btn--quiet btn--linkish"
                  onClick={() => {
                    setManualFields((previous) => new Set([...previous, field]));
                    setFocusField(field);
                  }}
                >
                  {COPY.addOptionalField(FIELD_LABEL[field])}
                </button>
              ))}
            </div>
          ) : undefined}
        </div>

        <div class="studio-enhance">
          <label class="studio-enhance__label" htmlFor="studio-enhance">
            <input
              id="studio-enhance"
              class="studio-check"
              type="checkbox"
              checked={state.draft.enhance}
              onChange={(event) => studio.setEnhance(event.currentTarget.checked)}
            />
            <span class="ui-eyebrow">{COPY.enhanceItems}</span>
          </label>
          <FieldErrors messages={issues.enhance.map((issue) => issue.message)} />
        </div>

        {issues.hidden.length > 0 ? (
          <Notice tone="error">
            {issues.hidden.map((issue) => (
              <p key={`${issue.path.join('.')}:${issue.code}`}>{issue.message}</p>
            ))}
          </Notice>
        ) : undefined}

        {sample?.nativeFeedUrl ? (
          <Notice title={COPY.nativeFeedTitle}>
            <a class="input--mono" href={sample.nativeFeedUrl} target="_blank" rel="noopener noreferrer">
              {sample.nativeFeedUrl}
            </a>
          </Notice>
        ) : undefined}

        <div class="studio-actions">
          <button
            type="button"
            class={save.className}
            disabled={!save.enabled}
            onClick={() => {
              void studio.save(onGenerate);
            }}
          >
            {state.phase === 'saving' ? COPY.creating : COPY.saveAndGenerate}
          </button>
          <button
            type="button"
            class="btn btn--ghost"
            onClick={() => {
              void copy(state.yaml);
            }}
          >
            {feedback === 'copied' ? COPY.copied : COPY.copyYaml}
          </button>
          {directoryHandoff ? (
            <a
              class="btn btn--ghost"
              href={buildDirectoryIssueHref(url, state.yaml)}
              target="_blank"
              rel="noopener noreferrer"
            >
              {COPY.proposeDirectory}
            </a>
          ) : undefined}
        </div>
      </div>

      {meadow}
    </div>
  );
}

function SuggestionStatus({
  suggestion,
  decisionNotice,
  onRetry,
}: {
  readonly suggestion: StudioSuggestionState;
  readonly decisionNotice?: string;
  readonly onRetry: () => void;
}) {
  if (suggestion.status === 'loading') {
    return <PreviewFeedback tone="loading">{COPY.selectorSuggestionsLoading}</PreviewFeedback>;
  }
  if (suggestion.status === 'empty') {
    return <p class="field-help">{COPY.selectorSuggestionsEmpty}</p>;
  }
  if (suggestion.status === 'failed') {
    const message = isSameNotice(suggestion.message, decisionNotice)
      ? COPY.selectorSuggestionsFailed
      : suggestion.message;
    return (
      <PreviewFeedback tone="error" onRetry={onRetry} retryLabel={COPY.retrySelectorSuggestions}>
        {message}
      </PreviewFeedback>
    );
  }
  return;
}

function isSameNotice(message: string, decisionNotice: string | undefined): boolean {
  return decisionNotice !== undefined && message.trim() === decisionNotice.trim();
}

function FieldBlock({
  id,
  label,
  ariaLabel,
  value,
  errors,
  inputReference,
  onInput,
}: {
  readonly id: string;
  readonly label: string;
  readonly ariaLabel?: string;
  readonly value: string;
  readonly errors: readonly string[];
  readonly inputReference?: (element: HTMLInputElement | null) => void;
  readonly onInput: (value: string) => void;
}) {
  return (
    <label class="field-block" htmlFor={id}>
      <span class="ui-eyebrow">{label}</span>
      <input
        id={id}
        ref={inputReference}
        class="input input--mono"
        value={value}
        spellcheck={false}
        aria-label={ariaLabel}
        onInput={(event: JSX.TargetedEvent<HTMLInputElement>) => onInput(event.currentTarget.value)}
      />
      <FieldErrors messages={errors} />
    </label>
  );
}

function ChoiceChips({
  label,
  current,
  choices,
  onToggle,
}: {
  readonly label: string;
  readonly current: string;
  readonly choices: readonly StudioFieldCandidate[];
  readonly onToggle: (selector: string) => void;
}) {
  if (choices.length === 0) return;
  return (
    <ul class="studio-candidates__chips" role="group" aria-label={label}>
      {choices.map((choice) => {
        const pressed = hasEverySelectorPart(current, choice.selector);
        return (
          <li key={choice.selector}>
            <button
              type="button"
              class={pressed ? 'studio-chip is-pressed' : 'studio-chip'}
              aria-pressed={pressed}
              aria-label={pressed ? COPY.removeSelector(choice.sample) : COPY.addSelector(choice.sample)}
              onClick={() => onToggle(choice.selector)}
            >
              {choice.sample}
            </button>
          </li>
        );
      })}
    </ul>
  );
}

function PreviewPane({
  state,
  token,
  onRetry,
}: {
  readonly state: StudioState;
  readonly token: string;
  readonly onRetry: () => void;
}) {
  const items = studioPreviewSample(state.live)?.items ?? [];
  const canShowImages = token.trim().length > 0;

  return (
    <div class="layout-rail-reading layout-stack" aria-label={COPY.previewRegion}>
      {state.live.status === 'loading' ? (
        <PreviewFeedback tone="loading">{COPY.previewChecking}</PreviewFeedback>
      ) : undefined}
      {state.live.status === 'failed' ? (
        <PreviewFeedback tone="error" onRetry={onRetry} retryLabel={COPY.checkAgain}>
          {state.live.message}
        </PreviewFeedback>
      ) : undefined}
      {items.length > 0 ? (
        <>
          <p class="field-help">{COPY.previewFetchedCaption}</p>
          <p class="ui-eyebrow">{COPY.previewItemCount(items.length)}</p>
          <ul class="ui-item-list ui-item-list--grid" role="list">
            {items.map((item, index) => (
              <li key={`${item.title}-${item.url ?? ''}-${index}`} class="ui-item">
                <PreviewItem
                  title={item.title}
                  url={item.url}
                  publishedLabel={item.publishedAt}
                  imageUrl={canShowImages ? item.imageUrl : undefined}
                />
                {item.url ? <p class="ui-item__meta input--mono">{item.url}</p> : undefined}
              </li>
            ))}
          </ul>
        </>
      ) : undefined}
    </div>
  );
}

function FieldErrors({ messages }: { readonly messages: readonly string[] }) {
  if (messages.length === 0) return;
  return (
    <>
      {messages.map((message, index) => (
        <span key={`${index}-${message}`} class="field-error">
          {message}
        </span>
      ))}
    </>
  );
}

function fieldStatusLabel(
  label: string,
  sample: ReturnType<typeof studioPreviewSample>,
  sampleItems: readonly StudioSampleItem[],
  field: StudioFieldId
): string {
  if (sample === undefined) return label;
  return hasSampleField(sampleItems, field) ? COPY.fieldFound(label) : COPY.fieldMissing(label);
}

function hasSampleField(items: readonly StudioSampleItem[], field: StudioFieldId): boolean {
  switch (field) {
    case 'title': {
      return items.some((item) => item.title.trim().length > 0);
    }
    case 'link': {
      return items.some((item) => item.url !== undefined);
    }
    case 'published': {
      return items.some((item) => item.publishedAt !== undefined);
    }
  }
}
