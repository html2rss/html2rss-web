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
      expect(mockOnConvert).toHaveBeenCalledWith(
        'https://www.chip.de/testberichte',
        'Demo: Hardware Reviews'
      );
    });
  });

  it('should call onConvert for Hacker News button', async () => {
    render(<DemoButtons onConvert={mockOnConvert} />);

    const hnButton = screen.getByText('Hacker News');
    fireEvent.click(hnButton);

    await waitFor(() => {
      expect(mockOnConvert).toHaveBeenCalledWith('https://news.ycombinator.com', 'Demo: Hacker News');
    });
  });

  it('should call onConvert for GitHub Trending button', async () => {
    render(<DemoButtons onConvert={mockOnConvert} />);

    const githubButton = screen.getByText('GitHub Trending');
    fireEvent.click(githubButton);

    await waitFor(() => {
      expect(mockOnConvert).toHaveBeenCalledWith('https://github.com/trending', 'Demo: GitHub Trending');
    });
  });

  it('should render all demo buttons with correct icons', () => {
    render(<DemoButtons onConvert={mockOnConvert} />);

    expect(screen.getByText('🇩🇪')).toBeInTheDocument(); // Hardware Reviews icon
    expect(screen.getByText('🔥')).toBeInTheDocument(); // Hacker News icon
    expect(screen.getByText('⭐')).toBeInTheDocument(); // GitHub icon
  });

  it('should handle multiple button clicks', async () => {
    render(<DemoButtons onConvert={mockOnConvert} />);

    const chipButton = screen.getByText('Hardware Reviews');
    const hnButton = screen.getByText('Hacker News');

    fireEvent.click(chipButton);
    fireEvent.click(hnButton);

    await waitFor(() => {
      expect(mockOnConvert).toHaveBeenCalledTimes(2);
    });
  });
});
