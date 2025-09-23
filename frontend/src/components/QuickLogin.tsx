interface QuickLoginProps {
  onShowLogin: () => void;
}

export function QuickLogin({ onShowLogin }: QuickLoginProps) {
  const handleClick = (e: Event) => {
    e.preventDefault();
    onShowLogin();
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      onShowLogin();
    }
  };

  return (
    <div class="quick-login" role="region" aria-label="Sign in options">
      <div class="quick-login-content">
        <span class="quick-login-text">Already have an account?</span>
        <button
          type="button"
          class="quick-login-btn"
          onClick={handleClick}
          onKeyDown={handleKeyDown}
          aria-label="Sign in to your account"
        >
          Sign in here
        </button>
      </div>
    </div>
  );
}
