import { render } from 'preact';
import { App } from './components/App';
import './styles/main.css';

function Root() {
  return (
    <div class="page-shell">
      <main class="page-main">
        <App />
      </main>
    </div>
  );
}

render(<Root />, document.getElementById('app')!);
