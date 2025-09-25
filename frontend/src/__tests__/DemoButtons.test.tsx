import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { h } from 'preact';
import { DemoButtons } from '../components/DemoButtons';

describe('DemoButtons', () => {
  const mockOnConvert = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should render demo buttons', () => {
    render(<DemoButtons onConvert={mockOnConvert} />);

    expect(screen.getByText('Hardware Reviews')).toBeInTheDocument();
    expect(screen.getByText('Hacker News')).toBeInTheDocument();
    expect(screen.getByText('GitHub Trending')).toBeInTheDocument();
  });

  it('should call onConvert when demo button is clicked', async () => {
    render(<DemoButtons onConvert={mockOnConvert} />);

    const chipButton = screen.getByText('Hardware Reviews');
    fireEvent.click(chipButton);

    await waitFor(() => {
      expect(mockOnConvert).toHaveBeenCalledWith('https://www.chip.de/testberichte');
    });
  });
});
