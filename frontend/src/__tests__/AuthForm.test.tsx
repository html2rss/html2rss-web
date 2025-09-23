import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { h } from 'preact';
import { AuthForm } from '../components/AuthForm';

describe('AuthForm', () => {
  const mockOnLogin = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should render form fields', () => {
    render(<AuthForm onLogin={mockOnLogin} />);

    expect(screen.getByLabelText('Username:')).toBeInTheDocument();
    expect(screen.getByLabelText('Token:')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Login' })).toBeInTheDocument();
  });

  it('should call onLogin with credentials when form is submitted', async () => {
    render(<AuthForm onLogin={mockOnLogin} />);

    const usernameInput = screen.getByLabelText('Username:');
    const tokenInput = screen.getByLabelText('Token:');
    const submitButton = screen.getByRole('button', { name: 'Login' });

    fireEvent.input(usernameInput, { target: { value: 'testuser' } });
    fireEvent.input(tokenInput, { target: { value: 'testtoken' } });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockOnLogin).toHaveBeenCalledWith('testuser', 'testtoken');
    });
  });

  it('should not submit form with empty fields', () => {
    render(<AuthForm onLogin={mockOnLogin} />);

    const submitButton = screen.getByRole('button', { name: 'Login' });
    fireEvent.click(submitButton);

    expect(mockOnLogin).not.toHaveBeenCalled();
  });

  it('should not submit form with only username', () => {
    render(<AuthForm onLogin={mockOnLogin} />);

    const usernameInput = screen.getByLabelText('Username:');
    const submitButton = screen.getByRole('button', { name: 'Login' });

    fireEvent.input(usernameInput, { target: { value: 'testuser' } });
    fireEvent.click(submitButton);

    expect(mockOnLogin).not.toHaveBeenCalled();
  });

  it('should not submit form with only token', () => {
    render(<AuthForm onLogin={mockOnLogin} />);

    const tokenInput = screen.getByLabelText('Token:');
    const submitButton = screen.getByRole('button', { name: 'Login' });

    fireEvent.input(tokenInput, { target: { value: 'testtoken' } });
    fireEvent.click(submitButton);

    expect(mockOnLogin).not.toHaveBeenCalled();
  });

  it('should clear form after successful submission', async () => {
    render(<AuthForm onLogin={mockOnLogin} />);

    const usernameInput = screen.getByLabelText('Username:');
    const tokenInput = screen.getByLabelText('Token:');
    const submitButton = screen.getByRole('button', { name: 'Login' });

    fireEvent.input(usernameInput, { target: { value: 'testuser' } });
    fireEvent.input(tokenInput, { target: { value: 'testtoken' } });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockOnLogin).toHaveBeenCalled();
    });

    // Form should be cleared after submission
    expect((usernameInput as HTMLInputElement).value).toBe('');
    expect((tokenInput as HTMLInputElement).value).toBe('');
  });

  it('should handle Enter key submission', async () => {
    render(<AuthForm onLogin={mockOnLogin} />);

    const usernameInput = screen.getByLabelText('Username:');
    const tokenInput = screen.getByLabelText('Token:');
    const form = usernameInput.closest('form');

    fireEvent.input(usernameInput, { target: { value: 'testuser' } });
    fireEvent.input(tokenInput, { target: { value: 'testtoken' } });
    fireEvent.submit(form!);

    await waitFor(() => {
      expect(mockOnLogin).toHaveBeenCalledWith('testuser', 'testtoken');
    });
  });
});
