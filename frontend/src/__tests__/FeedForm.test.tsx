import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { h } from 'preact';
import { FeedForm } from '../components/FeedForm';

describe('FeedForm', () => {
  const mockOnConvert = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should render form fields', () => {
    render(<FeedForm onConvert={mockOnConvert} isConverting={false} />);

    expect(screen.getByLabelText('Website URL:')).toBeInTheDocument();
    expect(screen.getByLabelText('Feed Name (optional):')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Convert to RSS' })).toBeInTheDocument();
  });

  it('should call onConvert with form data when submitted', async () => {
    render(<FeedForm onConvert={mockOnConvert} isConverting={false} />);

    const urlInput = screen.getByLabelText('Website URL:');
    const nameInput = screen.getByLabelText('Feed Name (optional):');
    const submitButton = screen.getByRole('button', { name: 'Convert to RSS' });

    fireEvent.input(urlInput, { target: { value: 'https://example.com' } });
    fireEvent.input(nameInput, { target: { value: 'Test Feed' } });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockOnConvert).toHaveBeenCalledWith('https://example.com', 'Test Feed', 'ssrf_filter');
    });
  });

  it('should not submit form with empty URL', () => {
    render(<FeedForm onConvert={mockOnConvert} isConverting={false} />);

    const submitButton = screen.getByRole('button', { name: 'Convert to RSS' });
    fireEvent.click(submitButton);

    expect(mockOnConvert).not.toHaveBeenCalled();
  });

  it('should disable submit button when converting', () => {
    render(<FeedForm onConvert={mockOnConvert} isConverting={true} />);

    const submitButton = screen.getByRole('button', { name: 'Converting...' });
    expect(submitButton).toBeDisabled();
  });

  it('should show advanced options when toggle is clicked', () => {
    render(<FeedForm onConvert={mockOnConvert} isConverting={false} />);

    const advancedToggle = screen.getByText('Show Advanced Options');
    fireEvent.click(advancedToggle);

    expect(screen.getByText('Strategy:')).toBeInTheDocument();
    expect(screen.getByText('SSRF Filter (recommended)')).toBeInTheDocument();
    expect(screen.getByText('Browserless (for JS-heavy sites)')).toBeInTheDocument();
  });

  it('should use selected strategy when advanced options are shown', async () => {
    render(<FeedForm onConvert={mockOnConvert} isConverting={false} />);

    // Show advanced options
    const advancedToggle = screen.getByText('Show Advanced Options');
    fireEvent.click(advancedToggle);

    // Select a different strategy
    const strategyOption = screen.getByText('SSRF Filter (recommended)');
    fireEvent.click(strategyOption);

    const urlInput = screen.getByLabelText('Website URL:');
    const submitButton = screen.getByRole('button', { name: 'Convert to RSS' });

    fireEvent.input(urlInput, { target: { value: 'https://example.com' } });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockOnConvert).toHaveBeenCalledWith(
        'https://example.com',
        'Feed for example.com',
        'ssrf_filter'
      );
    });
  });

  it('should auto-generate feed name from URL', async () => {
    render(<FeedForm onConvert={mockOnConvert} isConverting={false} />);

    const urlInput = screen.getByLabelText('Website URL:');
    const submitButton = screen.getByRole('button', { name: 'Convert to RSS' });

    fireEvent.input(urlInput, { target: { value: 'https://example.com' } });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockOnConvert).toHaveBeenCalledWith(
        'https://example.com',
        'Feed for example.com',
        'ssrf_filter'
      );
    });
  });

  it('should handle Enter key submission', async () => {
    render(<FeedForm onConvert={mockOnConvert} isConverting={false} />);

    const urlInput = screen.getByLabelText('Website URL:');
    const form = urlInput.closest('form');

    fireEvent.input(urlInput, { target: { value: 'https://example.com' } });
    fireEvent.submit(form!);

    await waitFor(() => {
      expect(mockOnConvert).toHaveBeenCalledWith(
        'https://example.com',
        'Feed for example.com',
        'ssrf_filter'
      );
    });
  });

  it('should validate URL format', () => {
    render(<FeedForm onConvert={mockOnConvert} isConverting={false} />);

    const urlInput = screen.getByLabelText('Website URL:');
    const submitButton = screen.getByRole('button', { name: 'Convert to RSS' });

    fireEvent.input(urlInput, { target: { value: 'invalid-url' } });
    fireEvent.click(submitButton);

    expect(mockOnConvert).not.toHaveBeenCalled();
  });
});
