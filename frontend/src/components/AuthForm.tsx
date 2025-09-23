import { useState } from 'preact/hooks';

interface AuthFormProps {
  onLogin: (username: string, token: string) => void;
}

export function AuthForm({ onLogin }: AuthFormProps) {
  const [username, setUsername] = useState('');
  const [token, setToken] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: Event) => {
    e.preventDefault();

    if (!username || !token) {
      return;
    }

    setIsSubmitting(true);
    try {
      await onLogin(username, token);
      // Clear form after successful login
      setUsername('');
      setToken('');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} class="auth-form">
      <div class="form-group">
        <label for="username">Username:</label>
        <input
          type="text"
          id="username"
          name="username"
          value={username}
          onInput={(e) => setUsername((e.target as HTMLInputElement).value)}
          required
          disabled={isSubmitting}
        />
      </div>

      <div class="form-group">
        <label for="token">Token:</label>
        <input
          type="password"
          id="token"
          name="token"
          value={token}
          onInput={(e) => setToken((e.target as HTMLInputElement).value)}
          required
          disabled={isSubmitting}
        />
      </div>

      <button type="submit" disabled={isSubmitting || !username || !token}>
        {isSubmitting ? 'Authenticating...' : 'Login'}
      </button>
    </form>
  );
}
