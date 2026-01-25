import styles from './QuickLogin.module.css';

interface QuickLoginProps {
  onShowLogin: () => void;
}

export function QuickLogin({ onShowLogin }: QuickLoginProps) {
  const handleClick = (event: Event) => {
    event.preventDefault();
    onShowLogin();
  };

  return (
    <div class={styles.wrapper} role="region" aria-label="Sign in options">
      <span class={styles.text}>Already have an account?</span>
      <button
        type="button"
        class="btn btn--accent"
        onClick={handleClick}
        aria-label="Sign in to your account"
      >
        Sign in here
      </button>
    </div>
  );
}
